from pathlib import Path
import sys

root = Path(sys.argv[1])

def must_replace(text: str, old: str, new: str, label: str, count: int = 1) -> str:
    found = text.count(old)
    if found < count:
        raise SystemExit(f"{label}: expected at least {count} match(es), found {found}")
    return text.replace(old, new, count)

# ---------------------------------------------------------------------------
# Give this build a real newer Android version so updates are never ambiguous.
# ---------------------------------------------------------------------------
gradle = root / "lemuroid-app/build.gradle.kts"
s = gradle.read_text()
s = must_replace(s, "versionCode = 252", "versionCode = 260", "version code")
s = must_replace(s, 'versionName = "1.17.0"', 'versionName = "10.2"', "version name")
gradle.write_text(s)

# ---------------------------------------------------------------------------
# VM: expose whether THIS game launch is actually a netplay launch.
# ---------------------------------------------------------------------------
vm = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/BaseGameScreenViewModel.kt"
s = vm.read_text()

anchor = """    fun getGameState(): Flow<GameViewModelRetroGameView.GameState> {
        return retroGameView.getGameState()
    }"""
replacement = """    fun isNetplayConfigured(): Boolean {
        return netplayMode == NetplayCoordinator.MODE_HOST || netplayMode == NetplayCoordinator.MODE_GUEST
    }

    fun getGameState(): Flow<GameViewModelRetroGameView.GameState> {
        return retroGameView.getGameState()
    }"""
s = must_replace(s, anchor, replacement, "VM netplay configured helper")
vm.write_text(s)

# ---------------------------------------------------------------------------
# Activity: do not even enter netplay startup code during normal single-player.
# Also expose the actual exception class/stack trace on future diagnostics.
# ---------------------------------------------------------------------------
activity = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/BaseGameActivity.kt"
s = activity.read_text()

s = must_replace(
    s,
    """            baseGameScreenViewModel.startNetplay()""",
    """            if (baseGameScreenViewModel.isNetplayConfigured()) {
                baseGameScreenViewModel.startNetplay()
            }""",
    "single-player netplay startup isolation",
)

old_error = """        val resultIntent =
            Intent().apply {
                putExtra(PLAY_GAME_RESULT_ERROR, exception.message)
            }"""
new_error = """        val resultIntent =
            Intent().apply {
                val detail =
                    buildString {
                        append(exception.javaClass.name)
                        exception.message?.let {
                            append(": ")
                            append(it)
                        }
                        append("\\n\\n")
                        append(exception.stackTraceToString().take(6000))
                    }
                putExtra(PLAY_GAME_RESULT_ERROR, detail)
            }"""
s = must_replace(s, old_error, new_error, "crash diagnostic detail")
activity.write_text(s)

# ---------------------------------------------------------------------------
# Game UI: normal single-player must not subscribe to the netplay StateFlow.
# LEDs remain functional only when this launch is HOST/GUEST netplay.
# ---------------------------------------------------------------------------
screen = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/game/MobileGameScreen.kt"
s = screen.read_text()

orientation_anchor = """        val isLandscape = constraints.maxWidth > constraints.maxHeight

        LaunchedEffect(isLandscape) {"""
orientation_new = """        val isLandscape = constraints.maxWidth > constraints.maxHeight
        val netplayEnabled = viewModel.isNetplayConfigured()

        LaunchedEffect(isLandscape) {"""
s = must_replace(s, orientation_anchor, orientation_new, "screen netplay flag")

s = s.replace(
    """LandscapeHardwarePanel(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_LEFT_CONTAINER),
                                rightSide = false,
                            )""",
    """LandscapeHardwarePanel(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_LEFT_CONTAINER),
                                rightSide = false,
                                netplayEnabled = netplayEnabled,
                            )""",
)
s = s.replace(
    """LandscapeHardwarePanel(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_RIGHT_CONTAINER),
                                rightSide = true,
                            )""",
    """LandscapeHardwarePanel(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_RIGHT_CONTAINER),
                                rightSide = true,
                                netplayEnabled = netplayEnabled,
                            )""",
)

s = s.replace(
    """PadContainer(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_BOTTOM_CONTAINER),
                            )""",
    """PadContainer(
                                modifier = Modifier.layoutId(GameScreenLayout.CONSTRAINTS_BOTTOM_CONTAINER),
                                netplayEnabled = netplayEnabled,
                            )""",
)

landscape_sig = """private fun LandscapeHardwarePanel(
    modifier: Modifier = Modifier,
    rightSide: Boolean,
) {"""
landscape_sig_new = """private fun LandscapeHardwarePanel(
    modifier: Modifier = Modifier,
    rightSide: Boolean,
    netplayEnabled: Boolean,
) {"""
s = must_replace(s, landscape_sig, landscape_sig_new, "landscape netplay flag")

s = must_replace(
    s,
    """    val netplayState = NetplayUiStatus.state.collectAsState().value""",
    """    val netplayState =
        if (netplayEnabled) {
            NetplayUiStatus.state.collectAsState().value
        } else {
            NetplayLedState.OFF
        }""",
    "landscape conditional stateflow",
    1,
)

pad_sig = """private fun PadContainer(modifier: Modifier = Modifier) {
    val theme = LocalLemuroidPadTheme.current
    val netplayState = NetplayUiStatus.state.collectAsState().value"""
pad_sig_new = """private fun PadContainer(
    modifier: Modifier = Modifier,
    netplayEnabled: Boolean,
) {
    val theme = LocalLemuroidPadTheme.current
    val netplayState =
        if (netplayEnabled) {
            NetplayUiStatus.state.collectAsState().value
        } else {
            NetplayLedState.OFF
        }"""
s = must_replace(s, pad_sig, pad_sig_new, "portrait conditional stateflow")

screen.write_text(s)

print("V10.2 compatibility isolation applied")
