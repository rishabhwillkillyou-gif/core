package com.swordfish.touchinput.radial.layouts

import android.view.KeyEvent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.dp
import com.swordfish.touchinput.radial.controls.LemuroidControlCross
import com.swordfish.touchinput.radial.controls.LemuroidControlFaceButtons
import com.swordfish.touchinput.radial.layouts.shared.ComposeTouchLayouts
import com.swordfish.touchinput.radial.ui.LemuroidButtonForeground
import com.swordfish.touchinput.radial.ui.LemuroidControlBackground
import gg.padkit.PadKitScope
import gg.padkit.anchors.Anchor
import gg.padkit.controls.ControlButton
import gg.padkit.ids.Id
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.persistentMapOf
import kotlinx.collections.immutable.persistentSetOf

@Composable
fun PadKitScope.NESLandscapeHardwareLeft(modifier: Modifier = Modifier) {
    Column(
        modifier =
            modifier
                .width(156.dp)
                .fillMaxHeight()
                .padding(horizontal = 10.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        LemuroidControlCross(
            modifier = Modifier.size(134.dp),
            id = Id.DiscreteDirection(ComposeTouchLayouts.MOTION_SOURCE_DPAD),
        )

        Spacer(modifier = Modifier.height(12.dp))

        NESLandscapeHardwareButton(
            modifier = Modifier.width(106.dp).height(38.dp),
            id = Id.Key(KeyEvent.KEYCODE_BUTTON_SELECT),
            label = "SELECT",
        )
    }
}

@Composable
fun PadKitScope.NESLandscapeHardwareRight(modifier: Modifier = Modifier) {
    Column(
        modifier =
            modifier
                .width(156.dp)
                .fillMaxHeight()
                .padding(horizontal = 10.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        LemuroidControlFaceButtons(
            modifier = Modifier.size(144.dp),
            primaryAnchors =
                persistentListOf(
                    Anchor(
                        Offset(-0.54f, -0.54f),
                        persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_B)),
                        0.36f,
                    ),
                    Anchor(
                        Offset(0.54f, -0.54f),
                        persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_Y)),
                        0.36f,
                    ),
                    Anchor(
                        Offset(-0.54f, 0.54f),
                        persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_A)),
                        0.36f,
                    ),
                    Anchor(
                        Offset(0.54f, 0.54f),
                        persistentSetOf(Id.Key(KeyEvent.KEYCODE_BUTTON_X)),
                        0.36f,
                    ),
                ),
            idsForegrounds =
                persistentMapOf<Id.Key, @Composable (State<Boolean>) -> Unit>(
                    Id.Key(KeyEvent.KEYCODE_BUTTON_B) to {
                        LemuroidButtonForeground(pressed = it, label = "B")
                    },
                    Id.Key(KeyEvent.KEYCODE_BUTTON_Y) to {
                        LemuroidButtonForeground(pressed = it, label = "TB")
                    },
                    Id.Key(KeyEvent.KEYCODE_BUTTON_A) to {
                        LemuroidButtonForeground(pressed = it, label = "A")
                    },
                    Id.Key(KeyEvent.KEYCODE_BUTTON_X) to {
                        LemuroidButtonForeground(pressed = it, label = "TA")
                    },
                ),
        )

        Spacer(modifier = Modifier.height(12.dp))

        NESLandscapeHardwareButton(
            modifier = Modifier.width(106.dp).height(38.dp),
            id = Id.Key(KeyEvent.KEYCODE_BUTTON_START),
            label = "START",
        )

        Spacer(modifier = Modifier.height(6.dp))

        NESLandscapeHardwareButton(
            modifier = Modifier.width(44.dp).height(34.dp),
            id = Id.Key(KeyEvent.KEYCODE_BUTTON_MODE),
            label = "≡",
        )
    }
}

@Composable
private fun PadKitScope.NESLandscapeHardwareButton(
    modifier: Modifier,
    id: Id.Key,
    label: String,
) {
    ControlButton(
        modifier = modifier,
        id = id,
        foreground = {
            LemuroidButtonForeground(
                pressed = it,
                label = label,
            )
        },
        background = { LemuroidControlBackground() },
    )
}
