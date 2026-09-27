package com.swordfish.lemuroid.app.shared.game.netplay

import android.view.KeyEvent
import java.util.concurrent.atomic.AtomicInteger

object NetplayRuntimeInput {
    const val UP = 1 shl 0
    const val DOWN = 1 shl 1
    const val LEFT = 1 shl 2
    const val RIGHT = 1 shl 3
    const val A = 1 shl 4
    const val B = 1 shl 5
    const val TA = 1 shl 6
    const val TB = 1 shl 7
    const val SELECT = 1 shl 8
    const val START = 1 shl 9

    private val mask = AtomicInteger(0)

    @Volatile
    var active: Boolean = false
        private set

    fun activate() {
        mask.set(0)
        active = true
    }

    fun deactivate() {
        active = false
        mask.set(0)
    }

    fun snapshot(): Int = mask.get()

    fun setButton(
        keyCode: Int,
        pressed: Boolean,
    ) {
        val bit =
            when (keyCode) {
                KeyEvent.KEYCODE_DPAD_UP -> UP
                KeyEvent.KEYCODE_DPAD_DOWN -> DOWN
                KeyEvent.KEYCODE_DPAD_LEFT -> LEFT
                KeyEvent.KEYCODE_DPAD_RIGHT -> RIGHT
                KeyEvent.KEYCODE_BUTTON_A -> A
                KeyEvent.KEYCODE_BUTTON_B -> B
                KeyEvent.KEYCODE_BUTTON_X -> TA
                KeyEvent.KEYCODE_BUTTON_Y -> TB
                KeyEvent.KEYCODE_BUTTON_SELECT -> SELECT
                KeyEvent.KEYCODE_BUTTON_START -> START
                else -> return
            }

        while (true) {
            val old = mask.get()
            val next = if (pressed) old or bit else old and bit.inv()
            if (mask.compareAndSet(old, next)) return
        }
    }

    fun setDpad(
        xAxis: Float,
        yAxis: Float,
    ) {
        var directionMask = 0
        if (xAxis < -0.35f) directionMask = directionMask or LEFT
        if (xAxis > 0.35f) directionMask = directionMask or RIGHT
        if (yAxis < -0.35f) directionMask = directionMask or UP
        if (yAxis > 0.35f) directionMask = directionMask or DOWN

        val clearDirections = (UP or DOWN or LEFT or RIGHT).inv()

        while (true) {
            val old = mask.get()
            val next = (old and clearDirections) or directionMask
            if (mask.compareAndSet(old, next)) return
        }
    }
}
