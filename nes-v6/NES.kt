package com.swordfish.touchinput.radial.layouts

import android.view.KeyEvent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swordfish.touchinput.radial.controls.LemuroidControlCross
import com.swordfish.touchinput.radial.controls.LemuroidControlFaceButtons
import com.swordfish.touchinput.radial.layouts.shared.ComposeTouchLayouts
import com.swordfish.touchinput.radial.layouts.shared.SecondaryButtonMenu
import com.swordfish.touchinput.radial.settings.TouchControllerSettingsManager
import gg.padkit.PadKitScope
import gg.padkit.anchors.Anchor
import gg.padkit.controls.ControlButton
import gg.padkit.ids.Id
import gg.padkit.layouts.radial.secondarydials.LayoutRadialSecondaryDialsScope
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.persistentMapOf
import kotlinx.collections.immutable.persistentSetOf

private val Olive = Color(0xFF96A253)
private val OlivePressed = Color(0xFF7B8743)
private val OlivePlate = Color(0xFF6E7446)
private val Ink = Color(0xFF1B1B18)
private val Rim = Color(0xFF20211D)

@Composable
private fun NesDpadBase() {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val ringRadius = size.minDimension * 0.49f
        drawCircle(color = OlivePlate, radius = ringRadius)
        drawCircle(
            color = Color(0xFF4C5133),
            radius = ringRadius,
            style = Stroke(width = 3.dp.toPx()),
        )

        val armThickness = size.minDimension * 0.24f
        val armLength = size.minDimension * 0.78f
        val hTop = (size.height - armThickness) / 2f
        val hLeft = (size.width - armLength) / 2f
        drawRoundRect(
            color = Color(0xFF11120F),
            topLeft = Offset(hLeft, hTop),
            size = androidx.compose.ui.geometry.Size(armLength, armThickness),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(10.dp.toPx()),
        )

        val vLeft = (size.width - armThickness) / 2f
        val vTop = (size.height - armLength) / 2f
        drawRoundRect(
            color = Color(0xFF11120F),
            topLeft = Offset(vLeft, vTop),
            size = androidx.compose.ui.geometry.Size(armThickness, armLength),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(10.dp.toPx()),
        )

        drawCircle(
            color = Color(0xFF24251F),
            radius = size.minDimension * 0.09f,
        )
    }
}

@Composable
private fun NesDpadForeground(direction: State<Offset>) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val arrowColor =
            if (direction.value != Offset.Zero) {
                Color(0xFFF0EFE5)
            } else {
                Color(0xFF8C9085)
            }
        val cx = size.width / 2f
        val cy = size.height / 2f
        val d = size.minDimension * 0.285f
        val q = size.minDimension * 0.045f
        val sw = 3.dp.toPx()

        drawLine(arrowColor, Offset(cx - d + q, cy - q), Offset(cx - d, cy), sw)
        drawLine(arrowColor, Offset(cx - d, cy), Offset(cx - d + q, cy + q), sw)

        drawLine(arrowColor, Offset(cx + d - q, cy - q), Offset(cx + d, cy), sw)
        drawLine(arrowColor, Offset(cx + d, cy), Offset(cx + d - q, cy + q), sw)

        drawLine(arrowColor, Offset(cx - q, cy - d + q), Offset(cx, cy - d), sw)
        drawLine(arrowColor, Offset(cx, cy - d), Offset(cx + q, cy - d + q), sw)

        drawLine(arrowColor, Offset(cx - q, cy + d - q), Offset(cx, cy + d), sw)
        drawLine(arrowColor, Offset(cx, cy + d), Offset(cx + q, cy + d - q), sw)
    }
}

@Composable
private fun NesFaceButton(
    pressed: State<Boolean>,
    label: String,
) {
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .clip(CircleShape)
                .background(if (pressed.value) OlivePressed else Olive)
                .border(3.dp, Rim, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Ink,
            fontWeight = FontWeight.Bold,
            fontSize = if (label.startsWith("TURBO")) 10.sp else 25.sp,
        )
    }
}

context(PadKitScope, LayoutRadialSecondaryDialsScope)
@Composable
private fun NesPillButton(
    modifier: Modifier,
    id: Id.Key,
    label: String,
) {
    ControlButton(
        modifier = modifier,
        id = id,
        background = { pressed ->
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier =
                        Modifier
                            .requiredWidth(64.dp)
                            .requiredHeight(28.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(if (pressed.value) Color(0xFF2F302B) else Color(0xFF11120F))
                            .border(2.dp, Color(0xFF3E4038), RoundedCornerShape(16.dp)),
                )
            }
        },
        foreground = {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    color = Color(0xFFE6E1D3),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 10.sp,
                )
            }
        },
    )
}

@Composable
fun PadKitScope.NESLeft(
    modifier: Modifier = Modifier,
    settings: TouchControllerSettingsManager.Settings,
) {
    BaseLayoutLeft(
        settings = settings,
        modifier = modifier,
        primaryDial = {
            LemuroidControlCross(
                id = Id.DiscreteDirection(ComposeTouchLayouts.MOTION_SOURCE_DPAD),
                background = { NesDpadBase() },
                foreground = { NesDpadForeground(it) },
            )
        },
        secondaryDials = {
            NesPillButton(
                modifier = Modifier.radialPosition(315f).radialScale(1.30f),
                id = Id.Key(KeyEvent.KEYCODE_BUTTON_SELECT),
                label = "SELECT",
            )
        },
    )
}

@Composable
fun PadKitScope.NESRight(
    modifier: Modifier = Modifier,
    settings: TouchControllerSettingsManager.Settings,
) {
    BaseLayoutRight(
        settings = settings,
        modifier = modifier,
        primaryDial = {
            LemuroidControlFaceButtons(
                primaryAnchors =
                    persistentListOf(
                        Anchor(
                            Offset(-0.62f, -0.62f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_B)),
                            0.32f,
                        ),
                        Anchor(
                            Offset(0.62f, -0.62f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_Y)),
                            0.32f,
                        ),
                        Anchor(
                            Offset(-0.62f, 0.62f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_A)),
                            0.32f,
                        ),
                        Anchor(
                            Offset(0.62f, 0.62f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_X)),
                            0.32f,
                        ),
                    ),
                background = { },
                applyPadding = false,
                idsForegrounds =
                    persistentMapOf<Id.Key, @Composable (State<Boolean>) -> Unit>(
                        Id.Key(KeyEvent.KEYCODE_BUTTON_B) to { NesFaceButton(it, "B") },
                        Id.Key(KeyEvent.KEYCODE_BUTTON_Y) to { NesFaceButton(it, "TURBO B") },
                        Id.Key(KeyEvent.KEYCODE_BUTTON_A) to { NesFaceButton(it, "A") },
                        Id.Key(KeyEvent.KEYCODE_BUTTON_X) to { NesFaceButton(it, "TURBO A") },
                    ),
            )
        },
        secondaryDials = {
            NesPillButton(
                modifier = Modifier.radialPosition(225f).radialScale(1.30f),
                id = Id.Key(KeyEvent.KEYCODE_BUTTON_START),
                label = "START",
            )
            SecondaryButtonMenu(settings)
        },
    )
}
