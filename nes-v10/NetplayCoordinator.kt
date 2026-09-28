package com.swordfish.lemuroid.app.shared.game.netplay

import android.opengl.GLSurfaceView
import android.view.KeyEvent
import com.swordfish.lemuroid.app.mobile.feature.netplay.NetplayDiscovery
import com.swordfish.libretrodroid.GLRetroView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.LockSupport
import java.util.zip.CRC32

class NetplayCoordinator(
    private val view: GLRetroView,
    private val mode: String,
    private val hostIp: String,
    private val romHash: String,
    private val scope: CoroutineScope,
) {
    companion object {
        const val MODE_HOST = "HOST"
        const val MODE_GUEST = "GUEST"
        const val PORT = 48914

        private const val MAGIC = 0x4E455331
        private const val VERSION = 2

        private const val MSG_INPUT = 1
        private const val MSG_STATE = 2
        private const val MSG_READY = 3
        private const val MSG_CRC = 4

        private const val FLAG_RESET = 1

        private const val INPUT_DELAY_FRAMES = 3
        private const val CHECKPOINT_FRAMES = 900
        private const val FRAME_NS = 16_666_667L
    }

    private data class FramePacket(
        val mask: Int,
        val flags: Int,
    )

    @Volatile
    private var running = false

    @Volatile
    private var userStopped = false

    private var socket: Socket? = null
    private var serverSocket: ServerSocket? = null
    private var networkJob: Job? = null
    private var receiverJob: Job? = null
    private var frameCollectorJob: Job? = null
    private var discoveryJob: Job? = null

    private val frameEvents = Channel<Unit>(Channel.CONFLATED)
    private val readyFrames = Channel<Int>(Channel.UNLIMITED)

    private val incomingInputs = ConcurrentHashMap<Int, FramePacket>()
    private val incomingCrcs = ConcurrentHashMap<Int, Long>()
    private val incomingStates = ConcurrentHashMap<Int, ByteArray>()
    private val localInputs = ConcurrentHashMap<Int, FramePacket>()

    private val resetRequested = AtomicBoolean(false)
    private val previousMasks = intArrayOf(0, 0)

    suspend fun start() {
        if (running) return

        running = true
        userStopped = false
        NetplayRuntimeInput.activate()
        NetplayUiStatus.set(NetplayLedState.WAITING)

        withContext(Dispatchers.Main) {
            view.renderMode = GLSurfaceView.RENDERMODE_WHEN_DIRTY
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

                    val input = DataInputStream(BufferedInputStream(connectedSocket.getInputStream()))
                    val output = DataOutputStream(BufferedOutputStream(connectedSocket.getOutputStream()))

                    handshake(input, output)
                    startReceiver(input)
                    runBufferedLockstep(output)
                } catch (_: Throwable) {
                    if (running && !userStopped) {
                        NetplayUiStatus.set(NetplayLedState.ERROR)
                    }
                } finally {
                    restoreNormalEmulation()
                }
            }
    }

    fun requestReset() {
        if (running) {
            resetRequested.set(true)
        }
    }

    fun isActive(): Boolean = running

    private fun acceptGuest(): Socket {
        val server = ServerSocket()
        server.reuseAddress = true
        server.bind(InetSocketAddress(PORT))
        serverSocket = server

        startDiscoveryBeacon()
        NetplayUiStatus.set(NetplayLedState.WAITING)
        return server.accept()
    }

    private fun connectToHost(): Socket {
        require(hostIp.isNotBlank()) { "Host IP is empty" }
        NetplayUiStatus.set(NetplayLedState.WAITING)

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

    private fun startDiscoveryBeacon() {
        if (mode != MODE_HOST) return

        discoveryJob =
            scope.launch(Dispatchers.IO) {
                runCatching {
                    DatagramSocket().use { udp ->
                        udp.broadcast = true
                        val target = InetAddress.getByName("255.255.255.255")

                        while (running) {
                            val message =
                                "${NetplayDiscovery.BEACON_PREFIX}|$PORT|" +
                                    romHash.take(12)
                            val bytes = message.toByteArray(Charsets.UTF_8)
                            val packet =
                                DatagramPacket(
                                    bytes,
                                    bytes.size,
                                    target,
                                    NetplayDiscovery.DISCOVERY_PORT,
                                )
                            udp.send(packet)
                            delay(450)
                        }
                    }
                }
            }
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
        require(remoteHash == romHash) { "ROM mismatch — both phones need the exact same ROM" }

        if (mode == MODE_HOST) {
            val state = view.serializeState()
            output.writeInt(MSG_STATE)
            output.writeInt(0)
            output.writeInt(state.size)
            output.write(state)
            output.flush()

            require(input.readInt() == MSG_READY) { "Guest did not accept initial state" }
            input.readInt()
        } else {
            require(input.readInt() == MSG_STATE) { "Host did not send initial state" }
            input.readInt()
            val size = input.readInt()
            require(size in 1..4_000_000) { "Invalid initial state size" }

            val state = ByteArray(size)
            input.readFully(state)
            require(view.unserializeState(state)) { "Could not synchronize emulator state" }

            output.writeInt(MSG_READY)
            output.writeInt(0)
            output.flush()
        }

        NetplayUiStatus.set(NetplayLedState.SYNCED)
    }

    private fun startReceiver(input: DataInputStream) {
        receiverJob =
            scope.launch(Dispatchers.IO) {
                try {
                    while (running) {
                        when (input.readInt()) {
                            MSG_INPUT -> {
                                val frame = input.readInt()
                                val mask = input.readInt()
                                val flags = input.readInt()
                                incomingInputs[frame] = FramePacket(mask, flags)
                            }

                            MSG_CRC -> {
                                val frame = input.readInt()
                                incomingCrcs[frame] = input.readLong()
                            }

                            MSG_STATE -> {
                                val frame = input.readInt()
                                val size = input.readInt()
                                require(size in 1..4_000_000) { "Invalid correction state size" }

                                val state = ByteArray(size)
                                input.readFully(state)
                                incomingStates[frame] = state
                            }

                            MSG_READY -> {
                                readyFrames.trySend(input.readInt())
                            }

                            else -> throw IllegalStateException("Unknown netplay packet")
                        }
                    }
                } catch (_: Throwable) {
                    if (running && !userStopped) {
                        NetplayUiStatus.set(NetplayLedState.ERROR)
                        runCatching { socket?.close() }
                    }
                }
            }
    }

    private suspend fun runBufferedLockstep(output: DataOutputStream) {
        var frame = 0
        var nextDeadline = System.nanoTime()

        while (running) {
            val targetFrame = frame + INPUT_DELAY_FRAMES
            val localPacket =
                FramePacket(
                    mask = NetplayRuntimeInput.snapshot(),
                    flags = if (resetRequested.getAndSet(false)) FLAG_RESET else 0,
                )

            localInputs[targetFrame] = localPacket

            synchronized(output) {
                output.writeInt(MSG_INPUT)
                output.writeInt(targetFrame)
                output.writeInt(localPacket.mask)
                output.writeInt(localPacket.flags)
                output.flush()
            }

            val ownPacket =
                if (frame < INPUT_DELAY_FRAMES) {
                    FramePacket(0, 0)
                } else {
                    localInputs.remove(frame) ?: FramePacket(0, 0)
                }

            val remote =
                if (frame < INPUT_DELAY_FRAMES) {
                    FramePacket(0, 0)
                } else {
                    awaitRemoteInput(frame)
                }

            val player1Packet = if (mode == MODE_HOST) ownPacket else remote
            val player2Packet = if (mode == MODE_HOST) remote else ownPacket

            if ((player1Packet.flags or player2Packet.flags) and FLAG_RESET != 0) {
                applySynchronizedReset()
            }

            applyMask(0, player1Packet.mask)
            applyMask(1, player2Packet.mask)

            stepOneFrame()

            if (frame > 0 && frame % CHECKPOINT_FRAMES == 0) {
                verifyCheckpoint(frame, output)
            }

            frame++
            nextDeadline += FRAME_NS

            val remaining = nextDeadline - System.nanoTime()
            if (remaining > 0) {
                LockSupport.parkNanos(remaining)
            } else if (remaining < -FRAME_NS * 5) {
                nextDeadline = System.nanoTime()
            }
        }
    }

    private suspend fun awaitRemoteInput(frame: Int): FramePacket {
        return withTimeout(2_000) {
            while (true) {
                incomingInputs.remove(frame)?.let {
                    return@withTimeout it
                }
                delay(1)
            }
            error("unreachable")
        }
    }

    private suspend fun awaitRemoteCrc(frame: Int): Long {
        return withTimeout(2_000) {
            while (true) {
                incomingCrcs.remove(frame)?.let {
                    return@withTimeout it
                }
                delay(1)
            }
            error("unreachable")
        }
    }

    private suspend fun awaitCorrectionState(frame: Int): ByteArray {
        return withTimeout(2_000) {
            while (true) {
                incomingStates.remove(frame)?.let {
                    return@withTimeout it
                }
                delay(1)
            }
            error("unreachable")
        }
    }

    private suspend fun awaitReady(frame: Int) {
        withTimeout(2_000) {
            while (true) {
                val ready = readyFrames.receive()
                if (ready == frame) return@withTimeout
            }
        }
    }

    private fun applySynchronizedReset() {
        NetplayRuntimeInput.clear()
        previousMasks[0] = 0
        previousMasks[1] = 0
        view.reset()
    }

    private suspend fun verifyCheckpoint(
        frame: Int,
        output: DataOutputStream,
    ) {
        val state = view.serializeState()
        val crc = CRC32().apply { update(state) }.value

        synchronized(output) {
            output.writeInt(MSG_CRC)
            output.writeInt(frame)
            output.writeLong(crc)
            output.flush()
        }

        val remoteCrc = awaitRemoteCrc(frame)
        if (remoteCrc == crc) {
            NetplayUiStatus.set(NetplayLedState.SYNCED)
            return
        }

        NetplayUiStatus.set(NetplayLedState.RESYNCING)

        if (mode == MODE_HOST) {
            synchronized(output) {
                output.writeInt(MSG_STATE)
                output.writeInt(frame)
                output.writeInt(state.size)
                output.write(state)
                output.flush()
            }
            awaitReady(frame)
        } else {
            val correction = awaitCorrectionState(frame)
            require(view.unserializeState(correction)) { "Could not apply correction state" }

            synchronized(output) {
                output.writeInt(MSG_READY)
                output.writeInt(frame)
                output.flush()
            }
        }

        NetplayUiStatus.set(NetplayLedState.SYNCED)
    }

    private suspend fun stepOneFrame() {
        while (frameEvents.tryReceive().isSuccess) {
            // Drain a stale rendered event before requesting this deterministic frame.
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
        userStopped = true
        running = false

        runCatching { socket?.close() }
        runCatching { serverSocket?.close() }

        socket = null
        serverSocket = null

        networkJob?.cancel()
        receiverJob?.cancel()
        frameCollectorJob?.cancel()
        discoveryJob?.cancel()

        networkJob = null
        receiverJob = null
        frameCollectorJob = null
        discoveryJob = null

        incomingInputs.clear()
        incomingCrcs.clear()
        incomingStates.clear()
        localInputs.clear()

        NetplayRuntimeInput.deactivate()
        NetplayUiStatus.set(NetplayLedState.OFF)
    }

    private suspend fun restoreNormalEmulation() {
        val wasUserStopped = userStopped

        running = false
        NetplayRuntimeInput.deactivate()

        runCatching { socket?.close() }
        runCatching { serverSocket?.close() }

        receiverJob?.cancel()
        discoveryJob?.cancel()

        withContext(Dispatchers.Main) {
            view.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }

        if (wasUserStopped) {
            NetplayUiStatus.set(NetplayLedState.OFF)
        } else if (NetplayUiStatus.state.value != NetplayLedState.ERROR) {
            NetplayUiStatus.set(NetplayLedState.ERROR)
        }
    }
}
