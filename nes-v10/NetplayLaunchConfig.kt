package com.swordfish.lemuroid.app.mobile.feature.netplay

data class NetplayLaunchOptions(
    val mode: String,
    val hostIp: String,
)

object NetplayLaunchConfig {
    const val MODE_NONE = "NONE"
    const val MODE_HOST = "HOST"
    const val MODE_GUEST = "GUEST"

    @Volatile
    private var mode: String = MODE_NONE

    @Volatile
    private var hostIp: String = ""

    fun armHost() {
        mode = MODE_HOST
        hostIp = ""
    }

    fun armGuest(host: String) {
        mode = MODE_GUEST
        hostIp = host.trim()
    }

    fun clear() {
        mode = MODE_NONE
        hostIp = ""
    }

    fun peek(): NetplayLaunchOptions = NetplayLaunchOptions(mode, hostIp)

    fun consume(): NetplayLaunchOptions {
        val result = NetplayLaunchOptions(mode, hostIp)
        clear()
        return result
    }
}
