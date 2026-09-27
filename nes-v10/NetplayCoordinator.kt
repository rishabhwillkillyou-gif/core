package com.swordfish.lemuroid.app.shared.game.netplay

import android.opengl.GLSurfaceView
import android.view.KeyEvent
import com.swordfish.libretrodroid.GLRetroView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.locks.LockSupport
import java.util.zip.CRC32

class NetplayCoordinator(
    private val view: GLRetroView,
    private val mode: String,
    private val hostIp: String,
    private val romHash: String,
    private val scope: CoroutineScope,
    private val onStatus: (String) -> Unit,
) {
    companion object {
        const val MODE_HOST = "HOST"
        const val MODE_GUEST = "GUEST"
        const val PORT = 48914

        private const val MAGIC = 0x4E455331
        private const val VERSION = 1

        private const val MSG_INPUT = 1
        private const val MSG_STATE = 2
        private const val MSG_READY = 3
        private const val MSG_CRC = 4

        private const val CHECKPOINT_FRAMES = 300
        private const val FRAME_NS = 16_666_667L
    }

    @Volatile
    private var running = false

    private var socket: Socket? = null
    private var serverSocket: ServerSocket? = null
    private var networkJob: Job? = null
    private var frameCollectorJob: Job? = null
    private val frameEvents = Channel<Unit>(Channel.CONFLATED)

    private val previousMasks = intArrayOf(0, 0)

    suspend fun start() {
        if (running) return
        running = true
        NetplayRuntimeInput.activate()

        withContext(Dispatchers.Main) {
            view.renderMode = GLSurfaceView.RENDERMODE_WHEN_DIRTY
            if (mode == MODE_GUEST) {
                view.audioEnabled = false
            }
        }

        frameCollectorJob =
            scope.launch(Dispatchers.Default) {
                view.getGLRetroEvents()
                    .filterIsInstance<GLRetroView.GLRetroEvents.FrameRendered>()
                    .collect {
                        frameEvents.trySend(Unit)
                    }
            }

        networkJob =
            scope.launch(Dispatchers.IO) {
                try {
                    val connectedSocket =
                        when (mode) {
                            MODE_HOST -> acceptGuest()
                            MODE_GUEST -> connectToHost()
                            else -> throw IllegalStateException("Invalid netplay mode: $mode")
                        }

                    socket = connectedSocket
                    connectedSocket.tcpNoDelay = true
                    connectedSocket.keepAlive = true

                    DataInputStream(BufferedInputStream(connectedSocket.getInputStream())).use { input ->
                        DataOutputStream(BufferedOutputStream(connectedSocket.getOutputStream())).use { output ->
                            handshake(input, output)
                            runLockstep(input, output)
                        }
                    }
                } catch (e: Throwable) {
                    if (running) {
                        postStatus("Netplay ended: ${e.message ?: "connection error"}")
                    }
                } finally {
                    restoreNormalEmulation()
                }
            }
    }

    private fun acceptGuest(): Socket {
        val server = ServerSocket()
        server.reuseAddress = true
        server.bind(InetSocketAddress(PORT))
        serverSocket = server

        val address = localAddress() ?: "host-phone-ip"
        postStatus("HOST ready: $address:$PORT · waiting for Player 2")
        return server.accept()
    }

    private fun connectToHost(): Socket {
        require(hostIp.isNotBlank()) { "Host IP is empty" }
        postStatus("Connecting to $hostIp:$PORT…")

        var lastError: Throwable? = null
        repeat(20) {
            if (!running) throw IllegalStateException("Netplay stopped")

            try {
                return Socket().apply {
                    tcpNoDelay = true
                    connect(InetSocketAddress(hostIp, PORT), 1500)
                }
            } catch (e: Throwable) {
                lastError = e
                Thread.sleep(500)
            }
        }

        throw lastError ?: IllegalStateException("Could not connect to host")
    }

    private fun handshake(
        input: DataInputStream,
        output: DataOutputStream,
    ) {
        output.writeInt(MAGIC)
        output.writeInt(VERSION)
        output.writeUTF(romHash)
        output.flush()

        val remoteMagic = input.readInt()
        val remoteVersion = input.readInt()
        val remoteHash = input.readUTF()

        require(remoteMagic == MAGIC) { "Not a compatible NES netplay peer" }
        require(remoteVersion == VERSION) { "Netplay version mismatch" }
        require(remoteHash == romHash) { "ROM mismatch — both phones must use the exact same ROM" }

        if (mode == MODE_HOST) {
            val state = view.serializeState()
            output.writeInt(MSG_STATE)
            output.writeInt(state.size)
            output.write(state)
            output.flush()

            require(input.readInt() == MSG_READY) { "Guest did not accept initial state" }
            postStatus("SYNCHRONIZED · You are Player 1")
        } else {
            require(input.readInt() == MSG_STATE) { "Host did not send initial state" }
            val size = input.readInt()
            require(size in 1..4_000_000) { "Invalid initial state size" }
            val state = ByteArray(size)
            input.readFully(state)
            require(view.unserializeState(state)) { "Could not synchronize emulator state" }

            output.writeInt(MSG_READY)
            output.flush()
            postStatus("SYNCHRONIZED · You are Player 2")
        }
    }

    private suspend fun runLockstep(
        input: DataInputStream,
        output: DataOutputStream,
    ) {
        var frame = 0
        var nextDeadline = System.nanoTime()

        while (running) {
            val localMask = NetplayRuntimeInput.snapshot()

            output.writeInt(MSG_INPUT)
            output.writeInt(frame)
            output.writeInt(localMask)
            output.flush()

            require(input.readInt() == MSG_INPUT) { "Unexpected netplay packet" }
            val remoteFrame = input.readInt()
            val remoteMask = input.readInt()
            require(remoteFrame == frame) {
                "Frame mismatch: local=$frame remote=$remoteFrame"
            }

            val player1Mask = if (mode == MODE_HOST) localMask else remoteMask
            val player2Mask = if (mode == MODE_HOST) remoteMask else localMask

            applyMask(0, player1Mask)
            applyMask(1, player2Mask)
            stepOneFrame()

            if (frame > 0 && frame % CHECKPOINT_FRAMES == 0) {
                verifyCheckpoint(frame, input, output)
            }

            frame++
            nextDeadline += FRAME_NS
            val remaining = nextDeadline - System.nanoTime()
            if (remaining > 0) {
                LockSupport.parkNanos(remaining)
            } else if (remaining < -FRAME_NS * 4) {
                nextDeadline = System.nanoTime()
            }
        }
    }

    private fun verifyCheckpoint(
        frame: Int,
        input: DataInputStream,
        output: DataOutputStream,
    ) {
        val state = view.serializeState()
        val crc = CRC32().apply { update(state) }.value

        output.writeInt(MSG_CRC)
        output.writeInt(frame)
        output.writeLong(crc)
        output.flush()

        require(input.readInt() == MSG_CRC) { "Checkpoint protocol error" }
        val remoteFrame = input.readInt()
        val remoteCrc = input.readLong()
        require(remoteFrame == frame) { "Checkpoint frame mismatch" }

        if (remoteCrc == crc) return

        if (mode == MODE_HOST) {
            output.writeInt(MSG_STATE)
            output.writeInt(state.size)
            output.write(state)
            output.flush()
            require(input.readInt() == MSG_READY) { "Guest state correction failed" }
            postStatus("Desync corrected at frame $frame")
        } else {
            require(input.readInt() == MSG_STATE) { "Host did not send correction state" }
            val size = input.readInt()
            require(size in 1..4_000_000) { "Invalid correction state size" }
            val correction = ByteArray(size)
            input.readFully(correction)
            require(view.unserializeState(correction)) { "Could not apply correction state" }
            output.writeInt(MSG_READY)
            output.flush()
        }
    }

    private suspend fun stepOneFrame() {
        while (frameEvents.tryReceive().isSuccess) {
            // Drain any replayed/old frame event before requesting the next deterministic frame.
        }

        view.requestRender()

        withTimeout(2_000) {
            frameEvents.receive()
        }
    }

    private fun applyMask(
        port: Int,
        mask: Int,
    ) {
        val old = previousMasks[port]

        val mappings =
            intArrayOf(
                NetplayRuntimeInput.UP, KeyEvent.KEYCODE_DPAD_UP,
                NetplayRuntimeInput.DOWN, KeyEvent.KEYCODE_DPAD_DOWN,
                NetplayRuntimeInput.LEFT, KeyEvent.KEYCODE_DPAD_LEFT,
                NetplayRuntimeInput.RIGHT, KeyEvent.KEYCODE_DPAD_RIGHT,
                NetplayRuntimeInput.A, KeyEvent.KEYCODE_BUTTON_A,
                NetplayRuntimeInput.B, KeyEvent.KEYCODE_BUTTON_B,
                NetplayRuntimeInput.TA, KeyEvent.KEYCODE_BUTTON_X,
                NetplayRuntimeInput.TB, KeyEvent.KEYCODE_BUTTON_Y,
                NetplayRuntimeInput.SELECT, KeyEvent.KEYCODE_BUTTON_SELECT,
                NetplayRuntimeInput.START, KeyEvent.KEYCODE_BUTTON_START,
            )

        var index = 0
        while (index < mappings.size) {
            val bit = mappings[index]
            val keyCode = mappings[index + 1]
            val wasDown = old and bit != 0
            val isDown = mask and bit != 0

            if (wasDown != isDown) {
                view.sendKeyEvent(
                    if (isDown) KeyEvent.ACTION_DOWN else KeyEvent.ACTION_UP,
                    keyCode,
                    port,
                )
            }
            index += 2
        }

        previousMasks[port] = mask
    }

    fun stop() {
        running = false
        runCatching { socket?.close() }
        runCatching { serverSocket?.close() }
        socket = null
        serverSocket = null
        networkJob?.cancel()
        frameCollectorJob?.cancel()
        networkJob = null
        frameCollectorJob = null
        NetplayRuntimeInput.deactivate()
    }

    private suspend fun restoreNormalEmulation() {
        running = false
        NetplayRuntimeInput.deactivate()
        runCatching { socket?.close() }
        runCatching { serverSocket?.close() }

        withContext(Dispatchers.Main) {
            view.audioEnabled = true
            view.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
    }

    private fun postStatus(message: String) {
        scope.launch(Dispatchers.Main) {
            onStatus(message)
        }
    }

    private fun localAddress(): String? {
        return runCatching {
            NetworkInterface.getNetworkInterfaces()
                .toList()
                .asSequence()
                .filter { it.isUp && !it.isLoopback }
                .flatMap { it.inetAddresses.toList().asSequence() }
                .filterIsInstance<Inet4Address>()
                .firstOrNull { !it.isLoopbackAddress && it.isSiteLocalAddress }
                ?.hostAddress
        }.getOrNull()
    }
}
