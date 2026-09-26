from pathlib import Path
import sys

root = Path(sys.argv[1])

def must_replace(text: str, old: str, new: str, label: str, count: int = 1) -> str:
    found = text.count(old)
    if found < count:
        raise SystemExit(f"{label}: expected at least {count} match(es), found {found}")
    return text.replace(old, new, count)

# Remove notification onboarding and launch gate.
home = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/home/HomeViewModel.kt"
s = home.read_text()
s = s.replace(
    "showNoNotificationPermissionCard = !notificationsPermissionEnabled",
    "showNoNotificationPermissionCard = false",
)
home.write_text(s)

interactor = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/GameInteractor.kt"
s = interactor.read_text()
gate = "        if (!ensureNotificationsPermissionAvailable()) {\n            return\n        }\n"
if s.count(gate) != 2:
    raise SystemExit(f"notification gates: expected 2, found {s.count(gate)}")
interactor.write_text(s.replace(gate, ""))

# Force FCEUmm turbo for player 1.
retro = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/viewmodel/GameViewModelRetroGameView.kt"
s = retro.read_text()
old = 'variables = gameData.coreVariables.map { Variable(it.key, it.value) }.toTypedArray()'
new = '''variables =
                (
                    gameData.coreVariables
                        .filterNot { it.key == "fceumm_turbo_enable" || it.key == "fceumm_turbo_delay" }
                        .map { Variable(it.key, it.value) } +
                        if (system.id == com.swordfish.lemuroid.lib.library.SystemID.NES) {
                            listOf(
                                Variable("fceumm_turbo_enable", "Player 1"),
                                Variable("fceumm_turbo_delay", "2"),
                            )
                        } else {
                            emptyList()
                        }
                ).toTypedArray()'''
s = must_replace(s, old, new, "initial turbo variables")

marker = '        retroGameView?.updateVariables(*updatedVariables)'
replacement = '''        retroGameView?.updateVariables(*updatedVariables)

        if (system.id == com.swordfish.lemuroid.lib.library.SystemID.NES) {
            retroGameView?.updateVariables(
                Variable("fceumm_turbo_enable", "Player 1"),
                Variable("fceumm_turbo_delay", "2"),
            )
        }'''
s = must_replace(s, marker, replacement, "runtime turbo variables")
retro.write_text(s)

# Enlarge the primary touch controls slightly.
base = root / "lemuroid-touchinput/src/main/java/com/swordfish/touchinput/radial/layouts/BaseLayout.kt"
s = base.read_text()
s = s.replace("primaryDialMaxSize = 160.dp", "primaryDialMaxSize = 178.dp")
base.write_text(s)

# Portrait layout: exact 4:3 game viewport inside a matching bezel.
layout = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/game/GameScreenLayout.kt"
s = layout.read_text()
s = must_replace(
    s,
    "import androidx.constraintlayout.compose.Dimension",
    "import androidx.constraintlayout.compose.Dimension\nimport androidx.compose.ui.unit.dp",
    "layout dp import",
)
s = must_replace(
    s,
    '    const val CONSTRAINTS_GAME_VIEW = "gameView"',
    '    const val CONSTRAINTS_GAME_VIEW = "gameView"\n    const val CONSTRAINTS_GAME_BEZEL = "gameBezel"',
    "bezel constant",
)

old = '''            val gameView = createRefFor(CONSTRAINTS_GAME_VIEW)
            val leftPad = createRefFor(CONSTRAINTS_LEFT_PAD)
            val rightPad = createRefFor(CONSTRAINTS_RIGHT_PAD)
            val gameContainer = createRefFor(CONSTRAINTS_GAME_CONTAINER)
            val bottomContainer = createRefFor(CONSTRAINTS_BOTTOM_CONTAINER)

            val gamePadChain = createHorizontalChain(leftPad, rightPad, chainStyle = ChainStyle.SpreadInside)

            constrain(gameView) {
                width = Dimension.fillToConstraints
                height = Dimension.fillToConstraints
                top.linkTo(parent.top)
                absoluteLeft.linkTo(parent.absoluteLeft)
                absoluteRight.linkTo(parent.absoluteRight)
                bottom.linkTo(leftPad.top)
            }

            constrain(bottomContainer) {
                width = Dimension.fillToConstraints
                height = Dimension.fillToConstraints
                absoluteLeft.linkTo(parent.absoluteLeft)
                absoluteRight.linkTo(parent.absoluteRight)
                top.linkTo(leftPad.top)
                bottom.linkTo(parent.bottom)
            }'''
new = '''            val gameView = createRefFor(CONSTRAINTS_GAME_VIEW)
            val gameBezel = createRefFor(CONSTRAINTS_GAME_BEZEL)
            val leftPad = createRefFor(CONSTRAINTS_LEFT_PAD)
            val rightPad = createRefFor(CONSTRAINTS_RIGHT_PAD)
            val gameContainer = createRefFor(CONSTRAINTS_GAME_CONTAINER)
            val bottomContainer = createRefFor(CONSTRAINTS_BOTTOM_CONTAINER)

            val gamePadChain = createHorizontalChain(leftPad, rightPad, chainStyle = ChainStyle.SpreadInside)

            constrain(gameBezel) {
                width = Dimension.fillToConstraints
                height = Dimension.ratio("6:5")
                top.linkTo(parent.top, margin = 12.dp)
                absoluteLeft.linkTo(parent.absoluteLeft, margin = 8.dp)
                absoluteRight.linkTo(parent.absoluteRight, margin = 8.dp)
            }

            constrain(gameView) {
                width = Dimension.fillToConstraints
                height = Dimension.ratio("4:3")
                top.linkTo(gameBezel.top, margin = 24.dp)
                absoluteLeft.linkTo(gameBezel.absoluteLeft, margin = 20.dp)
                absoluteRight.linkTo(gameBezel.absoluteRight, margin = 20.dp)
            }

            constrain(bottomContainer) {
                width = Dimension.fillToConstraints
                height = Dimension.fillToConstraints
                absoluteLeft.linkTo(parent.absoluteLeft)
                absoluteRight.linkTo(parent.absoluteRight)
                top.linkTo(gameBezel.bottom)
                bottom.linkTo(parent.bottom)
            }'''
s = must_replace(s, old, new, "portrait screen constraints")

old = '''            constrain(rightPad) {
                width = Dimension.fillToConstraints
                bottom.linkTo(parent.bottom)
            }

            constrain(leftPad) {
                width = Dimension.fillToConstraints
                bottom.linkTo(parent.bottom)
            }'''
new = '''            constrain(rightPad) {
                width = Dimension.fillToConstraints
                top.linkTo(gameBezel.bottom, margin = 8.dp)
                bottom.linkTo(parent.bottom, margin = 20.dp)
                verticalBias = 0.58f
            }

            constrain(leftPad) {
                width = Dimension.fillToConstraints
                top.linkTo(gameBezel.bottom, margin = 8.dp)
                bottom.linkTo(parent.bottom, margin = 20.dp)
                verticalBias = 0.58f
            }'''
s = must_replace(s, old, new, "portrait pad constraints")

layout.write_text(s)

# Visual shell and bezel.
screen = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/game/MobileGameScreen.kt"
s = screen.read_text()
s = must_replace(
    s,
    "import androidx.compose.foundation.layout.Arrangement",
    "import androidx.compose.foundation.border\nimport androidx.compose.foundation.layout.Arrangement",
    "screen border import",
)
s = must_replace(
    s,
    "import androidx.compose.ui.draw.rotate",
    "import androidx.compose.ui.draw.rotate\nimport androidx.compose.ui.draw.drawBehind",
    "drawBehind import",
)
s = must_replace(
    s,
    "import androidx.compose.ui.geometry.Rect",
    "import androidx.compose.ui.geometry.Rect\nimport androidx.compose.ui.geometry.Offset\nimport androidx.compose.ui.geometry.Size",
    "geometry imports",
)
s = must_replace(
    s,
    "import androidx.compose.ui.graphics.vector.ImageVector",
    "import androidx.compose.ui.graphics.Color\nimport androidx.compose.ui.graphics.vector.ImageVector",
    "color import",
)
s = must_replace(
    s,
    "import androidx.compose.ui.unit.dp",
    "import androidx.compose.ui.unit.dp\nimport androidx.compose.foundation.shape.RoundedCornerShape",
    "rounded shape import",
)

marker = '''            ) {
                Box(
                    modifier =
                        Modifier
                            .layoutId(GameScreenLayout.CONSTRAINTS_GAME_VIEW)'''
replacement = '''            ) {
                if (!isLandscape) {
                    Box(
                        modifier =
                            Modifier
                                .layoutId(GameScreenLayout.CONSTRAINTS_GAME_BEZEL)
                                .drawBehind {
                                    val olive = Color(0xFF697045)
                                    val dark = Color(0xFF1D211D)
                                    val side = 20.dp.toPx()
                                    val topFrame = 24.dp.toPx()
                                    val bottomFrame = 24.dp.toPx()

                                    drawRect(olive, Offset.Zero, Size(size.width, topFrame))
                                    drawRect(olive, Offset(0f, size.height - bottomFrame), Size(size.width, bottomFrame))
                                    drawRect(olive, Offset(0f, topFrame), Size(side, size.height - topFrame - bottomFrame))
                                    drawRect(olive, Offset(size.width - side, topFrame), Size(side, size.height - topFrame - bottomFrame))

                                    val inner = 4.dp.toPx()
                                    drawRect(dark, Offset(side - inner, topFrame - inner), Size(size.width - 2f * (side - inner), inner))
                                    drawRect(dark, Offset(side - inner, size.height - bottomFrame), Size(size.width - 2f * (side - inner), inner))
                                    drawRect(dark, Offset(side - inner, topFrame), Size(inner, size.height - topFrame - bottomFrame))
                                    drawRect(dark, Offset(size.width - side, topFrame), Size(inner, size.height - topFrame - bottomFrame))
                                }
                                .border(
                                    width = 2.dp,
                                    color = Color(0xFF32372A),
                                    shape = RoundedCornerShape(24.dp),
                                ),
                    )
                }

                Box(
                    modifier =
                        Modifier
                            .layoutId(GameScreenLayout.CONSTRAINTS_GAME_VIEW)'''
s = must_replace(s, marker, replacement, "bezel insertion")

old_pad = '''private fun PadContainer(modifier: Modifier = Modifier) {
    val theme = LocalLemuroidPadTheme.current
    GlassSurface(
        modifier = modifier,
        cornerRadius = theme.level0CornerRadius,
        fillColor = theme.level0Fill,
        shadowColor = theme.level0Shadow,
        shadowWidth = theme.level0ShadowWidth,
    )
}'''
new_pad = '''private fun PadContainer(modifier: Modifier = Modifier) {
    val theme = LocalLemuroidPadTheme.current
    GlassSurface(
        modifier =
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
            },
        cornerRadius = 18.dp,
        fillColor = Color.Transparent,
        shadowColor = theme.level0Shadow,
        shadowWidth = theme.level0ShadowWidth,
    )
}'''
s = must_replace(s, old_pad, new_pad, "pad container")
screen.write_text(s)

# Sharp NES output.
shader = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/ShaderChooser.kt"
shader.write_text(
    shader.read_text().replace(
        "SystemID.NES -> ShaderConfig.CRT",
        "SystemID.NES -> ShaderConfig.Sharp",
    )
)

# Dark tactile cross/menu styling while action buttons use their custom olive face.
theme = root / "lemuroid-touchinput/src/main/java/com/swordfish/touchinput/radial/LemuroidPadTheme.kt"
s = theme.read_text()
replacements = {
    "private val icons = gray(0.0f, 0.50f)": "private val icons = gray(0.92f, 0.92f)",
    "private val iconsPressed = gray(1.0f, 0.50f)": "private val iconsPressed = gray(1.0f, 1.0f)",
    "private val level3Fill = gray(1.0f, 0.50f)": "private val level3Fill = gray(0.06f, 0.98f)",
    "private val level3FillPressed = gray(0.0f, 0.50f)": "private val level3FillPressed = gray(0.22f, 0.98f)",
    "private val level2Fill = gray(1.0f, 0.125f)": "private val level2Fill = gray(0.04f, 0.94f)",
    "private val level2FillPressed = gray(0.0f, 0.125f)": "private val level2FillPressed = gray(0.20f, 0.96f)",
    "val level1Fill = gray(1.0f, 0.10f)": "val level1Fill = gray(0.18f, 0.72f)",
}
for old, new in replacements.items():
    if old not in s:
        raise SystemExit(f"theme token missing: {old}")
    s = s.replace(old, new, 1)
theme.write_text(s)

print("V6 portrait patch applied")
