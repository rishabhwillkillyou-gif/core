package com.swordfish.lemuroid.app.shared.game.netplay

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class NetplayLedState {
    OFF,
    WAITING,
    SYNCED,
    RESYNCING,
    ERROR,
}

object NetplayUiStatus {
    private val mutableState = MutableStateFlow(NetplayLedState.OFF)
    val state: StateFlow<NetplayLedState> = mutableState

    fun set(value: NetplayLedState) {
        mutableState.value = value
    }
}
