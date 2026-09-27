from pathlib import Path
import sys

root = Path(sys.argv[1])

def must_replace(text: str, old: str, new: str, label: str, count: int = 1) -> str:
    found = text.count(old)
    if found < count:
        raise SystemExit(f"{label}: expected at least {count} match(es), found {found}")
    return text.replace(old, new, count)

src_root = Path(sys.argv[2])

host_src = src_root / "LanP2Host.kt"
guest_src = src_root / "LanP2ControllerActivity.kt"

host_dst = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/LanP2Host.kt"
host_dst.parent.mkdir(parents=True, exist_ok=True)
host_dst.write_text(host_src.read_text())

guest_dst = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/lan/LanP2ControllerActivity.kt"
guest_dst.parent.mkdir(parents=True, exist_ok=True)
guest_dst.write_text(guest_src.read_text())

vm = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/BaseGameScreenViewModel.kt"
s = vm.read_text()
marker = "    override fun onCreate(owner: LifecycleOwner) {"
insert = """    fun injectLanKeyEvent(
        action: Int,
        keyCode: Int,
    ) {
        retroGameView.retroGameView?.sendKeyEvent(action, keyCode, 1)
    }

"""
s = must_replace(s, marker, insert + marker, "LAN VM input hook")
vm.write_text(s)

activity = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/BaseGameActivity.kt"
s = activity.read_text()
s = must_replace(
    s,
    "    private var finishTriggered = false",
    """    private var finishTriggered = false
    private var lanP2Host: LanP2Host? = null""",
    "LAN host field",
)

old_load = """        lifecycleScope.launch {
            baseGameScreenViewModel.loadGame(
                applicationContext,
                game,
                systemCoreConfig,
                gameLoader,
                intent.getBooleanExtra(EXTRA_LOAD_SAVE, false),
            )
        }"""
new_load = """        lifecycleScope.launch {
            baseGameScreenViewModel.loadGame(
                applicationContext,
                game,
                systemCoreConfig,
                gameLoader,
                intent.getBooleanExtra(EXTRA_LOAD_SAVE, false),
            )

            val host =
                LanP2Host { action, keyCode ->
                    baseGameScreenViewModel.injectLanKeyEvent(action, keyCode)
                }
            lanP2Host = host
            host.start()

            host.hostAddress()?.let { address ->
                displayToast("LAN P2 ready: $address:${LanP2Host.PORT}")
            }
        }"""
s = must_replace(s, old_load, new_load, "LAN host startup")

old_destroy = """    override fun onDestroy() {
        if (!isChangingConfigurations) {
            GameService.requestTermination()
        }
        super.onDestroy()
    }"""
new_destroy = """    override fun onDestroy() {
        lanP2Host?.stop()
        lanP2Host = null

        if (!isChangingConfigurations) {
            GameService.requestTermination()
        }
        super.onDestroy()
    }"""
s = must_replace(s, old_destroy, new_destroy, "LAN host shutdown")
activity.write_text(s)

system_file = root / "retrograde-app-shared/src/main/java/com/swordfish/lemuroid/lib/library/GameSystem.kt"
s = system_file.read_text()
nes_anchor = 'SystemID.NES,'
nes_pos = s.find(nes_anchor)
if nes_pos < 0:
    raise SystemExit("NES system block not found")
block_end = s.find('uniqueExtensions = listOf("nes")', nes_pos)
if block_end < 0:
    raise SystemExit("NES system block end not found")
nes_block = s[nes_pos:block_end]
old_ports = """controllerConfigs =
                                hashMapOf(
                                    0 to arrayListOf(ControllerConfigs.NES),
                                ),"""
new_ports = """controllerConfigs =
                                hashMapOf(
                                    0 to arrayListOf(ControllerConfigs.NES),
                                    1 to arrayListOf(ControllerConfigs.NES),
                                ),"""
if old_ports not in nes_block:
    raise SystemExit("NES controller config block not found")
nes_block = nes_block.replace(old_ports, new_ports, 1)
s = s[:nes_pos] + nes_block + s[block_end:]
system_file.write_text(s)

retro = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/viewmodel/GameViewModelRetroGameView.kt"
s = retro.read_text()
count = s.count('Variable("fceumm_turbo_enable", "Player 1")')
if count < 2:
    raise SystemExit(f"Expected Player 1 turbo overrides, found {count}")
s = s.replace(
    'Variable("fceumm_turbo_enable", "Player 1")',
    'Variable("fceumm_turbo_enable", "Both")',
)
retro.write_text(s)

home = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/home/HomeScreen.kt"
s = home.read_text()
s = must_replace(
    s,
    "import android.Manifest",
    "import android.Manifest\nimport android.content.Intent",
    "Home Intent import",
)
s = must_replace(
    s,
    "import com.swordfish.lemuroid.R",
    "import com.swordfish.lemuroid.R\nimport com.swordfish.lemuroid.app.mobile.feature.lan.LanP2ControllerActivity",
    "Home LAN import",
)

call_anchor = """        onGameLongClick,
        onOpenCoreSelection,
        {"""
call_replacement = """        onGameLongClick,
        onOpenCoreSelection,
        { context.startActivity(Intent(context, LanP2ControllerActivity::class.java)) },
        {"""
s = must_replace(s, call_anchor, call_replacement, "Home LAN callback")

signature_anchor = """    onGameLongClick: (Game) -> Unit,
    onOpenCoreSelection: () -> Unit,
    onEnableNotificationsClicked: () -> Unit,"""
signature_replacement = """    onGameLongClick: (Game) -> Unit,
    onOpenCoreSelection: () -> Unit,
    onLanControllerClicked: () -> Unit,
    onEnableNotificationsClicked: () -> Unit,"""
s = must_replace(s, signature_anchor, signature_replacement, "Home private signature")

column_anchor = """    ) {
        AnimatedVisibility(state.showNoNotificationPermissionCard) {"""
column_replacement = """    ) {
        OutlinedButton(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            onClick = onLanControllerClicked,
        ) {
            Text("LAN PLAYER 2 CONTROLLER")
        }

        AnimatedVisibility(state.showNoNotificationPermissionCard) {"""
s = must_replace(s, column_anchor, column_replacement, "Home LAN button")
home.write_text(s)

manifest = root / "lemuroid-app/src/main/AndroidManifest.xml"
s = manifest.read_text()
activity_decl = """        <activity
            android:name="com.swordfish.lemuroid.app.mobile.feature.lan.LanP2ControllerActivity"
            android:exported="false"
            android:screenOrientation="portrait"
            android:theme="@style/LemuroidMaterialTheme" />

"""
s = must_replace(
    s,
    '        <activity\n            android:name="com.swordfish.lemuroid.app.mobile.feature.main.MainActivity"',
    activity_decl + '        <activity\n            android:name="com.swordfish.lemuroid.app.mobile.feature.main.MainActivity"',
    "LAN manifest activity",
)
manifest.write_text(s)

print("V9 LAN Player 2 prototype patch applied")
