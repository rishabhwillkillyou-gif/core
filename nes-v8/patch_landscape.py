from pathlib import Path
import sys

root = Path(sys.argv[1])
screen = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/game/MobileGameScreen.kt"
s = screen.read_text()

# Landscape controls live in a dedicated hardware-shell layout.
if "NESLandscapeHardwareLeft" not in s:
    s = s.replace(
        "import com.swordfish.touchinput.radial.LocalLemuroidPadTheme",
        "import com.swordfish.touchinput.radial.LocalLemuroidPadTheme\n"
        "import com.swordfish.touchinput.radial.layouts.NESLandscapeHardwareLeft\n"
        "import com.swordfish.touchinput.radial.layouts.NESLandscapeHardwareRight",
        1,
    )

# Force side-panel (non-overlay) mode whenever the phone is landscape.
constraint_token = "currentControllerConfig?.allowTouchOverlay ?: true"
if constraint_token not in s:
    raise SystemExit("Landscape constraint token not found")
s = s.replace(
    constraint_token,
    "if (isLandscape) false else currentControllerConfig?.allowTouchOverlay ?: true",
    1,
)

# Replace the generic landscape touch overlay with fixed left/right hardware controls.
composition_pos = s.find("CompositionLocalProvider(LocalLemuroidPadTheme provides LemuroidPadTheme())")
controls_start = s.find("                        if (!isLandscape) {", composition_pos)
controls_end = s.find("                        GameScreenRunningCentralMenu(", controls_start)
if composition_pos < 0 or controls_start < 0 or controls_end < 0:
    raise SystemExit("Landscape control rendering region not found")

new_controls = """                        if (!isLandscape) {
                            PadContainer(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_BOTTOM_CONTAINER),
                            )
                        } else {
                            LandscapeHardwarePanel(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_LEFT_CONTAINER),
                                rightSide = false,
                            )
                            LandscapeHardwarePanel(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_RIGHT_CONTAINER),
                                rightSide = true,
                            )
                        }

                        if (isLandscape) {
                            NESLandscapeHardwareLeft(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_LEFT_PAD),
                            )
                            NESLandscapeHardwareRight(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_RIGHT_PAD),
                            )
                        } else {
                            leftGamePad?.invoke(
                                this,
                                Modifier.layoutId(GameScreenLayout.CONSTRAINTS_LEFT_PAD),
                                touchControllerSettings,
                            )
                            rightGamePad?.invoke(
                                this,
                                Modifier.layoutId(GameScreenLayout.CONSTRAINTS_RIGHT_PAD),
                                touchControllerSettings,
                            )
                        }

"""
s = s[:controls_start] + new_controls + s[controls_end:]

# Minimal dark bezel around the maximized landscape gameplay surface.
viewport_token = ".layoutId(GameScreenLayout.CONSTRAINTS_GAME_VIEW)"
if viewport_token not in s:
    raise SystemExit("Landscape viewport token not found")
viewport_insert = """.layoutId(GameScreenLayout.CONSTRAINTS_GAME_VIEW)
                            .then(
                                if (isLandscape) {
                                    Modifier.border(
                                        width = 3.dp,
                                        color = Color(0xFF171A12),
                                        shape = RoundedCornerShape(8.dp),
                                    )
                                } else {
                                    Modifier
                                },
                            )"""
s = s.replace(viewport_token, viewport_insert, 1)

# Olive rugged side shells: screws, grille perforations and small status LEDs.
insert_point = "@Composable\nprivate fun PadContainer"
if insert_point not in s:
    raise SystemExit("PadContainer insertion point not found")

hardware_fn = """@Composable
private fun LandscapeHardwarePanel(
    modifier: Modifier = Modifier,
    rightSide: Boolean,
) {
    val body = Color(0xFF666A49)
    val edge = Color(0xFF24261B)
    val detail = Color(0xFF303325)
    val led = Color(0xFF8FEA35)

    Box(
        modifier =
            modifier
                .drawBehind {
                    drawRect(body)

                    val screwRadius = 5.dp.toPx()
                    val inset = 13.dp.toPx()
                    drawCircle(detail, screwRadius, Offset(inset, inset))
                    drawCircle(detail, screwRadius, Offset(size.width - inset, inset))
                    drawCircle(detail, screwRadius, Offset(inset, size.height - inset))
                    drawCircle(detail, screwRadius, Offset(size.width - inset, size.height - inset))

                    val grilleRadius = 2.dp.toPx()
                    val grilleGap = 8.dp.toPx()
                    val baseY = size.height - 48.dp.toPx()
                    val baseX =
                        if (rightSide) {
                            size.width - 52.dp.toPx()
                        } else {
                            20.dp.toPx()
                        }

                    for (row in 0..3) {
                        for (col in 0..4) {
                            drawCircle(
                                detail,
                                grilleRadius,
                                Offset(
                                    baseX + col * grilleGap,
                                    baseY + row * grilleGap,
                                ),
                            )
                        }
                    }

                    if (rightSide) {
                        val ledY = 23.dp.toPx()
                        drawCircle(led, 4.dp.toPx(), Offset(size.width * 0.36f, ledY))
                        drawCircle(detail, 4.dp.toPx(), Offset(size.width * 0.50f, ledY))
                        drawCircle(detail, 4.dp.toPx(), Offset(size.width * 0.64f, ledY))
                    }
                }
                .border(
                    width = 2.dp,
                    color = edge,
                    shape = RoundedCornerShape(10.dp),
                ),
    )
}

@Composable
private fun PadContainer"""
s = s.replace(insert_point, hardware_fn, 1)

screen.write_text(s)
print("Landscape hardware mode applied")
