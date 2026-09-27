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

private val Olive = Color(0xFF9AA75A)
private val OlivePressed = Color(0xFF7F8C48)
private val OlivePlate = Color(0xFF6C7348)
private val Ink = Color(0xFF171814)
private val Rim = Color(0xFF20211D)
private val Label = Color(0xFFF1EEE2)

@Composable
private fun NesDpadBase() {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val ringRadius = size.minDimension * 0.49f
        drawCircle(color = OlivePlate, radius = ringRadius)
        drawCircle(
            color = Color(0xFF4A5033),
            radius = ringRadius,
            style = Stroke(width = 3.dp.toPx()),
        )

        val armThickness = size.minDimension * 0.25f
        val armLength = size.minDimension * 0.80f
        val hTop = (size.height - armThickness) / 2f
        val hLeft = (size.width - armLength) / 2f
        drawRoundRect(
            color = Color(0xFF11120F),
            topLeft = Offset(hLeft, hTop),
            size = androidx.compose.ui.geometry.Size(armLength, armThickness),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(9.dp.toPx()),
        )

        val vLeft = (size.width - armThickness) / 2f
        val vTop = (size.height - armLength) / 2f
        drawRoundRect(
            color = Color(0xFF11120F),
            topLeft = Offset(vLeft, vTop),
            size = androidx.compose.ui.geometry.Size(armThickness, armLength),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(9.dp.toPx()),
        )

        drawCircle(
            color = Color(0xFF25261F),
            radius = size.minDimension * 0.095f,
        )
    }
}

@Composable
private fun NesDpadForeground(direction: State<Offset>) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val arrowColor =
            if (direction.value != Offset.Zero) Color.White else Color(0xFFD8D7CF)
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
            fontWeight = FontWeight.Black,
            fontSize = if (label.length > 1) 18.sp else 25.sp,
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
                            .requiredWidth(76.dp)
                            .requiredHeight(31.dp)
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (pressed.value) Color(0xFF34362F) else Color(0xFF11120F))
                            .border(2.dp, Color(0xFF45483D), RoundedCornerShape(18.dp)),
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
                    color = Label,
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.sp,
                    letterSpacing = 0.5.sp,
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
                modifier = Modifier.radialPosition(320f).radialScale(1.38f),
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
                            Offset(-0.64f, -0.66f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_B)),
                            0.34f,
                        ),
                        Anchor(
                            Offset(0.64f, -0.66f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_Y)),
                            0.34f,
                        ),
                        Anchor(
                            Offset(-0.64f, 0.66f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_A)),
                            0.34f,
                        ),
                        Anchor(
                            Offset(0.64f, 0.66f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_X)),
                            0.34f,
                        ),
                    ),
                background = { },
                applyPadding = false,
                idsForegrounds =
                    persistentMapOf<Id.Key, @Composable (State<Boolean>) -> Unit>(
                        Id.Key(KeyEvent.KEYCODE_BUTTON_B) to { NesFaceButton(it, "B") },
                        Id.Key(KeyEvent.KEYCODE_BUTTON_Y) to { NesFaceButton(it, "TB") },
                        Id.Key(KeyEvent.KEYCODE_BUTTON_A) to { NesFaceButton(it, "A") },
                        Id.Key(KeyEvent.KEYCODE_BUTTON_X) to { NesFaceButton(it, "TA") },
                    ),
            )
        },
        secondaryDials = {
            NesPillButton(
                modifier = Modifier.radialPosition(220f).radialScale(1.38f),
                id = Id.Key(KeyEvent.KEYCODE_BUTTON_START),
                label = "START",
            )
            SecondaryButtonMenu(settings)
        },
    )
}
