from pathlib import Path
import sys

root = Path(sys.argv[1])

# Portrait control sizing only; landscape has its own V8.2 hardware controls.
base = root / "lemuroid-touchinput/src/main/java/com/swordfish/touchinput/radial/layouts/BaseLayout.kt"
s = base.read_text()
s = s.replace("primaryDialMaxSize = 184.dp", "primaryDialMaxSize = 190.dp")
base.write_text(s)

# Tighten the portrait screen/control relationship without changing the proven
# large 4:3 game viewport.
layout = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/game/GameScreenLayout.kt"
s = layout.read_text()
s = s.replace(
    """            constrain(rightPad) {
                width = Dimension.fillToConstraints
                top.linkTo(gameBezel.bottom, margin = 2.dp)
                bottom.linkTo(parent.bottom, margin = 40.dp)
                verticalBias = 0.24f
            }

            constrain(leftPad) {
                width = Dimension.fillToConstraints
                top.linkTo(gameBezel.bottom, margin = 8.dp)
                bottom.linkTo(parent.bottom, margin = 20.dp)
                verticalBias = 0.24f
            }""",
    """            constrain(rightPad) {
                width = Dimension.fillToConstraints
                top.linkTo(gameBezel.bottom)
                bottom.linkTo(parent.bottom, margin = 42.dp)
                verticalBias = 0.16f
            }

            constrain(leftPad) {
                width = Dimension.fillToConstraints
                top.linkTo(gameBezel.bottom)
                bottom.linkTo(parent.bottom, margin = 28.dp)
                verticalBias = 0.16f
            }""",
)
layout.write_text(s)

# Refine the lower shell: stronger separation below the screen, subtle grip
# panels, status lights and speaker details so the portrait no longer feels
# like controls floating on an empty rectangle.
screen = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/game/MobileGameScreen.kt"
s = screen.read_text()

old = """        modifier =
            modifier.drawBehind {
                val metal = Color(0xFFB9B6A7)
                val olive = Color(0xFF697045)
                drawRect(metal)

                val ledY = 26.dp.toPx()
                val ledX = size.width * 0.54f
                drawCircle(Color(0xFF69B83C), 5.dp.toPx(), Offset(ledX, ledY))
                drawCircle(Color(0xFF53583A), 5.dp.toPx(), Offset(ledX + 24.dp.toPx(), ledY))
                drawCircle(Color(0xFF53583A), 5.dp.toPx(), Offset(ledX + 48.dp.toPx(), ledY))

                val r = 2.dp.toPx()
                val startX = size.width - 78.dp.toPx()
                val startY = 18.dp.toPx()
                repeat(6) { row ->
                    repeat(4) { col ->
                        drawCircle(
                            Color(0xFF555649),
                            r,
                            Offset(startX + col * 10.dp.toPx(), startY + row * 9.dp.toPx()),
                        )
                    }
                }

                val band = 22.dp.toPx()
                drawRect(olive, Offset(0f, size.height - band), Size(size.width, band))

                val ventBase = size.height - 78.dp.toPx()
                repeat(7) { i ->
                    val lx = 18.dp.toPx() + i * 10.dp.toPx()
                    drawLine(
                        olive,
                        Offset(lx, ventBase),
                        Offset(lx + 30.dp.toPx(), size.height - 28.dp.toPx()),
                        strokeWidth = 5.dp.toPx(),
                    )

                    val rx = size.width - 18.dp.toPx() - i * 10.dp.toPx()
                    drawLine(
                        olive,
                        Offset(rx, ventBase),
                        Offset(rx - 30.dp.toPx(), size.height - 28.dp.toPx()),
                        strokeWidth = 5.dp.toPx(),
                    )
                }

                val cx = size.width / 2f
                drawLine(
                    olive,
                    Offset(cx - 12.dp.toPx(), size.height - 34.dp.toPx()),
                    Offset(cx, size.height - 18.dp.toPx()),
                    strokeWidth = 3.dp.toPx(),
                )
                drawLine(
                    olive,
                    Offset(cx, size.height - 18.dp.toPx()),
                    Offset(cx + 12.dp.toPx(), size.height - 34.dp.toPx()),
                    strokeWidth = 3.dp.toPx(),
                )
            },"""

new = """        modifier =
            modifier.drawBehind {
                val metal = Color(0xFFB8B5A7)
                val metalDark = Color(0xFFA7A495)
                val olive = Color(0xFF697045)
                val dark = Color(0xFF4E5144)
                drawRect(metal)

                // A deliberate transition line directly under the screen.
                drawRect(
                    color = metalDark,
                    topLeft = Offset(0f, 0f),
                    size = Size(size.width, 3.dp.toPx()),
                )
                drawRect(
                    color = olive,
                    topLeft = Offset(0f, 7.dp.toPx()),
                    size = Size(size.width, 2.dp.toPx()),
                )

                // Status cluster.
                val ledY = 28.dp.toPx()
                val ledX = size.width * 0.54f
                drawCircle(Color(0xFF69C83E), 5.dp.toPx(), Offset(ledX, ledY))
                drawCircle(Color(0xFF565A3E), 5.dp.toPx(), Offset(ledX + 25.dp.toPx(), ledY))
                drawCircle(Color(0xFF565A3E), 5.dp.toPx(), Offset(ledX + 50.dp.toPx(), ledY))

                // Speaker grille.
                val r = 2.2.dp.toPx()
                val startX = size.width - 80.dp.toPx()
                val startY = 18.dp.toPx()
                repeat(6) { row ->
                    repeat(4) { col ->
                        drawCircle(
                            dark,
                            r,
                            Offset(startX + col * 10.dp.toPx(), startY + row * 9.dp.toPx()),
                        )
                    }
                }

                // Subtle recessed grip fields occupy the formerly blank lower area.
                val gripTop = size.height * 0.58f
                val gripBottom = size.height - 58.dp.toPx()
                val gripInset = 22.dp.toPx()
                drawRoundRect(
                    color = Color(0xFFAEAB9C),
                    topLeft = Offset(gripInset, gripTop),
                    size = Size(size.width * 0.25f, gripBottom - gripTop),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(22.dp.toPx()),
                )
                drawRoundRect(
                    color = Color(0xFFAEAB9C),
                    topLeft = Offset(size.width - gripInset - size.width * 0.25f, gripTop),
                    size = Size(size.width * 0.25f, gripBottom - gripTop),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(22.dp.toPx()),
                )

                // Bottom accent and ventilation grooves.
                val band = 24.dp.toPx()
                drawRect(olive, Offset(0f, size.height - band), Size(size.width, band))

                val ventBase = size.height - 82.dp.toPx()
                repeat(7) { i ->
                    val lx = 18.dp.toPx() + i * 10.dp.toPx()
                    drawLine(
                        olive,
                        Offset(lx, ventBase),
                        Offset(lx + 30.dp.toPx(), size.height - 30.dp.toPx()),
                        strokeWidth = 5.dp.toPx(),
                    )
                    val rx = size.width - 18.dp.toPx() - i * 10.dp.toPx()
                    drawLine(
                        olive,
                        Offset(rx, ventBase),
                        Offset(rx - 30.dp.toPx(), size.height - 30.dp.toPx()),
                        strokeWidth = 5.dp.toPx(),
                    )
                }

                // Small centre notch detail.
                val cx = size.width / 2f
                drawLine(
                    olive,
                    Offset(cx - 12.dp.toPx(), size.height - 36.dp.toPx()),
                    Offset(cx, size.height - 20.dp.toPx()),
                    strokeWidth = 3.dp.toPx(),
                )
                drawLine(
                    olive,
                    Offset(cx, size.height - 20.dp.toPx()),
                    Offset(cx + 12.dp.toPx(), size.height - 36.dp.toPx()),
                    strokeWidth = 3.dp.toPx(),
                )
            },"""

if old not in s:
    raise SystemExit("V9 portrait PadContainer block not found")
s = s.replace(old, new, 1)
screen.write_text(s)

print("V9 portrait polish applied")
