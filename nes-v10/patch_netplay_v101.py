from pathlib import Path
import sys

root = Path(sys.argv[1])
src = Path(sys.argv[2])

def must_replace(text: str, old: str, new: str, label: str, count: int = 1) -> str:
    found = text.count(old)
    if found < count:
        raise SystemExit(f"{label}: expected at least {count} match(es), found {found}")
    return text.replace(old, new, count)

# ---------------------------------------------------------------------------
# Refresh V10.1 sources and add discovery / LED status models.
# ---------------------------------------------------------------------------
copy_map = {
    "NetplaySetupActivity.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/netplay/NetplaySetupActivity.kt",
    "NetplayDiscovery.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/netplay/NetplayDiscovery.kt",
    "NetplayRuntimeInput.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/netplay/NetplayRuntimeInput.kt",
    "NetplayCoordinator.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/netplay/NetplayCoordinator.kt",
    "NetplayUiStatus.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/netplay/NetplayUiStatus.kt",
}

for name, dst in copy_map.items():
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text((src / name).read_text())

# ---------------------------------------------------------------------------
# Do not cover gameplay with netplay status Toasts.
# Reset becomes a synchronized netplay command when a session is active.
# ---------------------------------------------------------------------------
activity = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/BaseGameActivity.kt"
s = activity.read_text()

s = must_replace(
    s,
    """            baseGameScreenViewModel.startNetplay { message ->
                displayToast(message)
            }""",
    """            baseGameScreenViewModel.startNetplay()""",
    "remove netplay status toasts",
)

old_reset = """            if (data?.getBooleanExtra(GameMenuContract.RESULT_RESET, false) == true) {
                GlobalScope.launch {
                    baseGameScreenViewModel.reset()
                }
            }"""
new_reset = """            if (data?.getBooleanExtra(GameMenuContract.RESULT_RESET, false) == true) {
                if (!baseGameScreenViewModel.requestSynchronizedReset()) {
                    GlobalScope.launch {
                        baseGameScreenViewModel.reset()
                    }
                }
            }"""
s = must_replace(s, old_reset, new_reset, "synchronized reset hook")
activity.write_text(s)

# ---------------------------------------------------------------------------
# VM: no status callback; expose reset request to Activity.
# ---------------------------------------------------------------------------
vm = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/BaseGameScreenViewModel.kt"
s = vm.read_text()

s = must_replace(
    s,
    "    suspend fun startNetplay(onStatus: (String) -> Unit) {",
    "    suspend fun startNetplay() {",
    "startNetplay signature",
)

s = must_replace(
    s,
    """                romHash = romHash,
                scope = viewModelScope,
                onStatus = onStatus,
            )""",
    """                romHash = romHash,
                scope = viewModelScope,
            )""",
    "coordinator status callback removal",
)

stop_anchor = """    fun stopNetplay() {
        netplayCoordinator?.stop()"""
reset_method = """    fun requestSynchronizedReset(): Boolean {
        val coordinator = netplayCoordinator ?: return false
        if (!coordinator.isActive()) return false
        coordinator.requestReset()
        return true
    }

    fun stopNetplay() {
        netplayCoordinator?.stop()"""
s = must_replace(s, stop_anchor, reset_method, "VM synchronized reset method")
vm.write_text(s)

# ---------------------------------------------------------------------------
# Netplay status uses the physical LED holes on portrait + landscape shells.
# ---------------------------------------------------------------------------
screen = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/game/MobileGameScreen.kt"
s = screen.read_text()

if "NetplayLedState" not in s:
    s = must_replace(
        s,
        "import com.swordfish.lemuroid.app.shared.game.BaseGameScreenViewModel",
        "import com.swordfish.lemuroid.app.shared.game.BaseGameScreenViewModel\n"
        "import com.swordfish.lemuroid.app.shared.game.netplay.NetplayLedState\n"
        "import com.swordfish.lemuroid.app.shared.game.netplay.NetplayUiStatus",
        "netplay LED imports",
    )

landscape_header = """private fun LandscapeHardwarePanel(
    modifier: Modifier = Modifier,
    rightSide: Boolean,
) {
    val body = Color(0xFF666A49)
    val edge = Color(0xFF24261B)
    val detail = Color(0xFF303325)
    val led = Color(0xFF8FEA35)"""
landscape_new = """private fun LandscapeHardwarePanel(
    modifier: Modifier = Modifier,
    rightSide: Boolean,
) {
    val body = Color(0xFF666A49)
    val edge = Color(0xFF24261B)
    val detail = Color(0xFF303325)
    val netplayState = NetplayUiStatus.state.collectAsState().value
    val ledGreen =
        if (netplayState == NetplayLedState.SYNCED || netplayState == NetplayLedState.RESYNCING) {
            Color(0xFF8FEA35)
        } else {
            detail
        }
    val ledAmber =
        if (netplayState == NetplayLedState.WAITING || netplayState == NetplayLedState.RESYNCING) {
            Color(0xFFFFBF3F)
        } else {
            detail
        }
    val ledRed =
        if (netplayState == NetplayLedState.ERROR) {
            Color(0xFFE84A45)
        } else {
            detail
        }"""
s = must_replace(s, landscape_header, landscape_new, "landscape LED state")

old_landscape_leds = """                        drawCircle(led, 4.dp.toPx(), Offset(size.width * 0.36f, ledY))
                        drawCircle(detail, 4.dp.toPx(), Offset(size.width * 0.50f, ledY))
                        drawCircle(detail, 4.dp.toPx(), Offset(size.width * 0.64f, ledY))"""
new_landscape_leds = """                        drawCircle(ledGreen, 4.dp.toPx(), Offset(size.width * 0.36f, ledY))
                        drawCircle(ledAmber, 4.dp.toPx(), Offset(size.width * 0.50f, ledY))
                        drawCircle(ledRed, 4.dp.toPx(), Offset(size.width * 0.64f, ledY))"""
s = must_replace(s, old_landscape_leds, new_landscape_leds, "landscape LED colors")

portrait_header = """private fun PadContainer(modifier: Modifier = Modifier) {
    val theme = LocalLemuroidPadTheme.current
    GlassSurface("""
portrait_new = """private fun PadContainer(modifier: Modifier = Modifier) {
    val theme = LocalLemuroidPadTheme.current
    val netplayState = NetplayUiStatus.state.collectAsState().value
    val ledOff = Color(0xFF53583A)
    val ledGreen =
        if (netplayState == NetplayLedState.SYNCED || netplayState == NetplayLedState.RESYNCING) {
            Color(0xFF69D13E)
        } else {
            ledOff
        }
    val ledAmber =
        if (netplayState == NetplayLedState.WAITING || netplayState == NetplayLedState.RESYNCING) {
            Color(0xFFFFBF3F)
        } else {
            ledOff
        }
    val ledRed =
        if (netplayState == NetplayLedState.ERROR) {
            Color(0xFFE84A45)
        } else {
            ledOff
        }

    GlassSurface("""
s = must_replace(s, portrait_header, portrait_new, "portrait LED state")

old_portrait_leds = """                drawCircle(Color(0xFF69B83C), 5.dp.toPx(), Offset(ledX, ledY))
                drawCircle(Color(0xFF53583A), 5.dp.toPx(), Offset(ledX + 24.dp.toPx(), ledY))
                drawCircle(Color(0xFF53583A), 5.dp.toPx(), Offset(ledX + 48.dp.toPx(), ledY))"""
new_portrait_leds = """                drawCircle(ledGreen, 5.dp.toPx(), Offset(ledX, ledY))
                drawCircle(ledAmber, 5.dp.toPx(), Offset(ledX + 24.dp.toPx(), ledY))
                drawCircle(ledRed, 5.dp.toPx(), Offset(ledX + 48.dp.toPx(), ledY))"""
s = must_replace(s, old_portrait_leds, new_portrait_leds, "portrait LED colors")

screen.write_text(s)

print("V10.1 netplay quality patch applied")
