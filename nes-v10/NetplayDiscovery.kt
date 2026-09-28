package com.swordfish.lemuroid.app.mobile.feature.netplay

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.SocketTimeoutException

object NetplayDiscovery {
    const val DISCOVERY_PORT = 48915
    const val BEACON_PREFIX = "NESNET10"

    fun localAddress(): String? {
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

    fun discoverHost(timeoutMs: Int = 2200): String? {
        val socket = DatagramSocket(DISCOVERY_PORT).apply {
            reuseAddress = true
            soTimeout = 350
        }

        return socket.use {
            val deadline = System.currentTimeMillis() + timeoutMs
            val buffer = ByteArray(256)

            while (System.currentTimeMillis() < deadline) {
                val packet = DatagramPacket(buffer, buffer.size)
                try {
                    socket.receive(packet)
                    val message =
                        String(
                            packet.data,
                            packet.offset,
                            packet.length,
                            Charsets.UTF_8,
                        )

                    if (message.startsWith("$BEACON_PREFIX|")) {
                        return@use packet.address.hostAddress
                    }
                } catch (_: SocketTimeoutException) {
                    // Keep listening until the overall deadline.
                }
            }

            null
        }
    }
}
