package com.swordfish.lemuroid.app.shared.game

import android.util.Log
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.SocketException

class LanP2Host(
    private val onKeyEvent: (action: Int, keyCode: Int) -> Unit,
) {
    companion object {
        const val PORT = 48913
        private const val TAG = "LanP2Host"
    }

    @Volatile
    private var running = false

    @Volatile
    private var serverSocket: ServerSocket? = null

    private var serverThread: Thread? = null

    fun start() {
        if (running) return
        running = true

        serverThread =
            Thread(
                {
                    try {
                        ServerSocket(PORT).use { server ->
                            server.reuseAddress = true
                            serverSocket = server

                            while (running) {
                                val socket = server.accept()
                                socket.tcpNoDelay = true

                                socket.use { client ->
                                    BufferedReader(InputStreamReader(client.getInputStream())).use { reader ->
                                        while (running) {
                                            val line = reader.readLine() ?: break
                                            handleMessage(line)
                                        }
                                    }
                                }
                            }
                        }
                    } catch (e: Throwable) {
                        if (running) {
                            Log.e(TAG, "LAN P2 server failed", e)
                        }
                    } finally {
                        serverSocket = null
                        running = false
                    }
                },
                "NES-LAN-P2-Host",
            ).apply {
                isDaemon = true
                start()
            }
    }

    private fun handleMessage(line: String) {
        val parts = line.split(",")
        if (parts.size != 3 || parts[0] != "K") return

        val action = parts[1].toIntOrNull() ?: return
        val keyCode = parts[2].toIntOrNull() ?: return
        onKeyEvent(action, keyCode)
    }

    fun stop() {
        running = false
        runCatching { serverSocket?.close() }
        serverSocket = null
        serverThread = null
    }

    fun hostAddress(): String? {
        return try {
            NetworkInterface.getNetworkInterfaces()
                .toList()
                .asSequence()
                .filter { it.isUp && !it.isLoopback }
                .flatMap { it.inetAddresses.toList().asSequence() }
                .filterIsInstance<Inet4Address>()
                .firstOrNull { !it.isLoopbackAddress && it.isSiteLocalAddress }
                ?.hostAddress
        } catch (_: SocketException) {
            null
        }
    }
}
