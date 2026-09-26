package com.swordfish.touchinput.radial.layouts

import android.view.KeyEvent
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
                background = {
                    Box(
                        modifier =
                            Modifier
                                .fillMaxSize()
                                .clip(CircleShape)
                                .background(OlivePlate)
                                .border(2.dp, Color(0xFF4C5133), CircleShape),
                    )
                },
            )
        },
        secondaryDials = {
            NesPillButton(
                modifier = Modifier.radialPosition(315f).radialScale(1.25f),
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
                            Offset(-0.56f, -0.56f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_B)),
                            0.34f,
                        ),
                        Anchor(
                            Offset(0.56f, -0.56f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_Y)),
                            0.34f,
                        ),
                        Anchor(
                            Offset(-0.56f, 0.56f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_A)),
                            0.34f,
                        ),
                        Anchor(
                            Offset(0.56f, 0.56f),
                            persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_X)),
                            0.34f,
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
                modifier = Modifier.radialPosition(225f).radialScale(1.25f),
                id = Id.Key(KeyEvent.KEYCODE_BUTTON_START),
                label = "START",
            )
            SecondaryButtonMenu(settings)
        },
    )
}
