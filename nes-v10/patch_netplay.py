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
# Copy V10 sources
# ---------------------------------------------------------------------------
copy_map = {
    "NetplayLaunchConfig.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/netplay/NetplayLaunchConfig.kt",
    "NetplaySetupActivity.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/netplay/NetplaySetupActivity.kt",
    "NetplayRuntimeInput.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/netplay/NetplayRuntimeInput.kt",
    "NetplayCoordinator.kt":
        root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/netplay/NetplayCoordinator.kt",
}
for name, dst in copy_map.items():
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text((src / name).read_text())

# ---------------------------------------------------------------------------
# Home screen: add LAN NETPLAY setup button
# ---------------------------------------------------------------------------
home = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/mobile/feature/home/HomeScreen.kt"
s = home.read_text()

if "import android.content.Intent" not in s:
    s = must_replace(
        s,
        "import android.Manifest",
        "import android.Manifest\nimport android.content.Intent",
        "Home Intent import",
    )

if "NetplaySetupActivity" not in s:
    s = must_replace(
        s,
        "import com.swordfish.lemuroid.R",
        "import com.swordfish.lemuroid.R\nimport com.swordfish.lemuroid.app.mobile.feature.netplay.NetplaySetupActivity",
        "Home netplay import",
    )

call_anchor = """        onGameLongClick,
        onOpenCoreSelection,
        {"""
call_replacement = """        onGameLongClick,
        onOpenCoreSelection,
        { context.startActivity(Intent(context, NetplaySetupActivity::class.java)) },
        {"""
s = must_replace(s, call_anchor, call_replacement, "Home netplay callback")

signature_anchor = """    onGameLongClick: (Game) -> Unit,
    onOpenCoreSelection: () -> Unit,
    onEnableNotificationsClicked: () -> Unit,"""
signature_replacement = """    onGameLongClick: (Game) -> Unit,
    onOpenCoreSelection: () -> Unit,
    onNetplayClicked: () -> Unit,
    onEnableNotificationsClicked: () -> Unit,"""
s = must_replace(s, signature_anchor, signature_replacement, "Home netplay signature")

column_anchor = """    ) {
        AnimatedVisibility(state.showNoNotificationPermissionCard) {"""
column_replacement = """    ) {
        OutlinedButton(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            onClick = onNetplayClicked,
        ) {
            Text("LAN NETPLAY")
        }

        AnimatedVisibility(state.showNoNotificationPermissionCard) {"""
s = must_replace(s, column_anchor, column_replacement, "Home netplay button")
home.write_text(s)

# ---------------------------------------------------------------------------
# Manifest: register setup Activity in the main process
# ---------------------------------------------------------------------------
manifest = root / "lemuroid-app/src/main/AndroidManifest.xml"
s = manifest.read_text()
activity_decl = """        <activity
            android:name="com.swordfish.lemuroid.app.mobile.feature.netplay.NetplaySetupActivity"
            android:exported="false"
            android:theme="@style/LemuroidMaterialTheme" />

"""
s = must_replace(
    s,
    '        <activity\n            android:name="com.swordfish.lemuroid.app.mobile.feature.main.MainActivity"',
    activity_decl + '        <activity\n            android:name="com.swordfish.lemuroid.app.mobile.feature.main.MainActivity"',
    "netplay manifest activity",
)
manifest.write_text(s)

# ---------------------------------------------------------------------------
# GameLauncher: consume armed netplay config and pass it to game process
# ---------------------------------------------------------------------------
launcher = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/GameLauncher.kt"
s = launcher.read_text()

if "NetplayLaunchConfig" not in s:
    s = must_replace(
        s,
        "import com.swordfish.lemuroid.R",
        "import com.swordfish.lemuroid.R\nimport com.swordfish.lemuroid.app.mobile.feature.netplay.NetplayLaunchConfig",
        "GameLauncher netplay import",
    )

anchor = """        GlobalScope.launch {
            val system = GameSystem.findById(game.systemId)"""
replacement = """        val netplay = NetplayLaunchConfig.consume()

        GlobalScope.launch {
            val system = GameSystem.findById(game.systemId)"""
s = must_replace(s, anchor, replacement, "GameLauncher consume config")

old_call = "BaseGameActivity.launchGame(activity, coreConfig, game, loadSave, leanback)"
new_call = """BaseGameActivity.launchGame(
                activity,
                coreConfig,
                game,
                loadSave,
                leanback,
                netplay.mode,
                netplay.hostIp,
            )"""
s = must_replace(s, old_call, new_call, "GameLauncher launch extras")
launcher.write_text(s)

# ---------------------------------------------------------------------------
# BaseGameActivity: receive netplay extras, pass to VM, start coordinator
# ---------------------------------------------------------------------------
activity = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/BaseGameActivity.kt"
s = activity.read_text()

factory_anchor = """                statesPreviewManager,
                coreVariablesManager,
                rumbleManager,
            )"""
factory_replacement = """                statesPreviewManager,
                coreVariablesManager,
                rumbleManager,
                intent.getStringExtra(EXTRA_NETPLAY_MODE) ?: "NONE",
                intent.getStringExtra(EXTRA_NETPLAY_HOST_IP) ?: "",
            )"""
s = must_replace(s, factory_anchor, factory_replacement, "Activity VM netplay args")

load_anchor = """            baseGameScreenViewModel.loadGame(
                applicationContext,
                game,
                systemCoreConfig,
                gameLoader,
                intent.getBooleanExtra(EXTRA_LOAD_SAVE, false),
            )"""
load_replacement = """            baseGameScreenViewModel.loadGame(
                applicationContext,
                game,
                systemCoreConfig,
                gameLoader,
                intent.getBooleanExtra(EXTRA_LOAD_SAVE, false),
            )
            baseGameScreenViewModel.startNetplay { message ->
                displayToast(message)
            }"""
s = must_replace(s, load_anchor, load_replacement, "Activity start netplay")

destroy_anchor = """    override fun onDestroy() {
        if (!isChangingConfigurations) {
            GameService.requestTermination()
        }
        super.onDestroy()
    }"""
destroy_replacement = """    override fun onDestroy() {
        if (!isChangingConfigurations) {
            baseGameScreenViewModel.stopNetplay()
            GameService.requestTermination()
        }
        super.onDestroy()
    }"""
s = must_replace(s, destroy_anchor, destroy_replacement, "Activity stop netplay")

const_anchor = """        private const val EXTRA_SYSTEM_CORE_CONFIG = "EXTRA_SYSTEM_CORE_CONFIG""""
const_replacement = """        private const val EXTRA_SYSTEM_CORE_CONFIG = "EXTRA_SYSTEM_CORE_CONFIG"
        private const val EXTRA_NETPLAY_MODE = "EXTRA_NETPLAY_MODE"
        private const val EXTRA_NETPLAY_HOST_IP = "EXTRA_NETPLAY_HOST_IP""""
s = must_replace(s, const_anchor, const_replacement, "Activity netplay constants")

sig_anchor = """            loadSave: Boolean,
            useLeanback: Boolean,
        ) {"""
sig_replacement = """            loadSave: Boolean,
            useLeanback: Boolean,
            netplayMode: String = "NONE",
            netplayHostIp: String = "",
        ) {"""
s = must_replace(s, sig_anchor, sig_replacement, "launchGame netplay signature")

extras_anchor = """                    putExtra(EXTRA_LEANBACK, useLeanback)
                    putExtra(EXTRA_SYSTEM_CORE_CONFIG, systemCoreConfig)"""
extras_replacement = """                    putExtra(EXTRA_LEANBACK, useLeanback)
                    putExtra(EXTRA_SYSTEM_CORE_CONFIG, systemCoreConfig)
                    putExtra(EXTRA_NETPLAY_MODE, netplayMode)
                    putExtra(EXTRA_NETPLAY_HOST_IP, netplayHostIp)"""
s = must_replace(s, extras_anchor, extras_replacement, "launchGame netplay extras")
activity.write_text(s)

# ---------------------------------------------------------------------------
# BaseGameScreenViewModel: construct and own deterministic netplay coordinator
# ---------------------------------------------------------------------------
vm = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/BaseGameScreenViewModel.kt"
s = vm.read_text()

imports_anchor = "import android.content.SharedPreferences"
imports_new = """import android.content.SharedPreferences
import android.net.Uri
import com.swordfish.lemuroid.app.shared.game.netplay.NetplayCoordinator
import com.swordfish.lemuroid.app.shared.game.netplay.NetplayRuntimeInput
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest"""
s = must_replace(s, imports_anchor, imports_new, "VM netplay imports")

s = must_replace(
    s,
    "    game: Game,",
    "    private val game: Game,",
    "VM game property",
    1,
)

ctor_anchor = """    coreVariablesManager: CoreVariablesManager,
    rumbleManager: RumbleManager,
) : ViewModel(), DefaultLifecycleObserver {"""
ctor_replacement = """    coreVariablesManager: CoreVariablesManager,
    rumbleManager: RumbleManager,
    private val netplayMode: String,
    private val netplayHostIp: String,
) : ViewModel(), DefaultLifecycleObserver {"""
s = must_replace(s, ctor_anchor, ctor_replacement, "VM constructor netplay args")

factory_fields_anchor = """        private val coreVariablesManager: CoreVariablesManager,
        private val rumbleManager: RumbleManager,
    ) : ViewModelProvider.Factory {"""
factory_fields_replacement = """        private val coreVariablesManager: CoreVariablesManager,
        private val rumbleManager: RumbleManager,
        private val netplayMode: String,
        private val netplayHostIp: String,
    ) : ViewModelProvider.Factory {"""
s = must_replace(s, factory_fields_anchor, factory_fields_replacement, "VM Factory fields")

factory_call_anchor = """                coreVariablesManager,
                rumbleManager,
            ) as T"""
factory_call_replacement = """                coreVariablesManager,
                rumbleManager,
                netplayMode,
                netplayHostIp,
            ) as T"""
s = must_replace(s, factory_call_anchor, factory_call_replacement, "VM Factory constructor call")

loading_anchor = "    val loadingState = MutableStateFlow(false)"
loading_replacement = """    val loadingState = MutableStateFlow(false)

    private var netplayCoordinator: NetplayCoordinator? = null

    init {
        if (netplayMode == NetplayCoordinator.MODE_HOST || netplayMode == NetplayCoordinator.MODE_GUEST) {
            NetplayRuntimeInput.activate()
        } else {
            NetplayRuntimeInput.deactivate()
        }
    }"""
s = must_replace(s, loading_anchor, loading_replacement, "VM netplay init")

request_finish_anchor = """    fun requestFinish() {
        if (loadingState.value) return"""
netplay_methods = """    suspend fun startNetplay(onStatus: (String) -> Unit) {
        if (netplayMode != NetplayCoordinator.MODE_HOST && netplayMode != NetplayCoordinator.MODE_GUEST) {
            return
        }

        val view = retroGameView.retroGameViewFlow()
        retroGameView.waitGLEvent<GLRetroView.GLRetroEvents.FrameRendered>()

        val romHash =
            withContext(Dispatchers.IO) {
                computeRomSha256()
            }

        val coordinator =
            NetplayCoordinator(
                view = view,
                mode = netplayMode,
                hostIp = netplayHostIp,
                romHash = romHash,
                scope = viewModelScope,
                onStatus = onStatus,
            )

        netplayCoordinator = coordinator
        coordinator.start()
    }

    fun stopNetplay() {
        netplayCoordinator?.stop()
        netplayCoordinator = null
        NetplayRuntimeInput.deactivate()
    }

    private fun computeRomSha256(): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val parsed = Uri.parse(game.fileUri)

        val stream =
            runCatching {
                if (parsed.scheme.isNullOrBlank()) {
                    FileInputStream(File(game.fileUri))
                } else {
                    appContext.contentResolver.openInputStream(parsed)
                }
            }.getOrNull()
                ?: runCatching {
                    FileInputStream(File(parsed.path ?: game.fileUri))
                }.getOrElse {
                    throw IllegalStateException("Could not open ROM for netplay verification")
                }

        stream.use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count <= 0) break
                digest.update(buffer, 0, count)
            }
        }

        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    fun requestFinish() {
        if (loadingState.value) return"""
s = must_replace(s, request_finish_anchor, netplay_methods, "VM netplay methods")
vm.write_text(s)

# ---------------------------------------------------------------------------
# Touch controls: route local NES input to the netplay input mask
# ---------------------------------------------------------------------------
touch = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/viewmodel/GameViewModelTouchControls.kt"
s = touch.read_text()

if "NetplayRuntimeInput" not in s:
    s = must_replace(
        s,
        "import com.swordfish.lemuroid.app.shared.settings.HapticFeedbackMode",
        "import com.swordfish.lemuroid.app.shared.settings.HapticFeedbackMode\nimport com.swordfish.lemuroid.app.shared.game.netplay.NetplayRuntimeInput",
        "touch netplay import",
    )

old_button = """    private fun handleVirtualInputButton(event: InputEvent.Button) {
        val action = if (event.pressed) KeyEvent.ACTION_DOWN else KeyEvent.ACTION_UP
        retroGameView.retroGameView?.sendKeyEvent(action, event.id)
    }"""
new_button = """    private fun handleVirtualInputButton(event: InputEvent.Button) {
        if (NetplayRuntimeInput.active && event.id != KeyEvent.KEYCODE_BUTTON_MODE) {
            NetplayRuntimeInput.setButton(event.id, event.pressed)
            return
        }

        val action = if (event.pressed) KeyEvent.ACTION_DOWN else KeyEvent.ACTION_UP
        retroGameView.retroGameView?.sendKeyEvent(action, event.id)
    }"""
s = must_replace(s, old_button, new_button, "touch button netplay routing")

direction_anchor = """    private fun handleVirtualInputDirection(
        id: Int,
        xAxis: Float,
        yAxis: Float,
    ) {
        when (id) {"""
direction_replacement = """    private fun handleVirtualInputDirection(
        id: Int,
        xAxis: Float,
        yAxis: Float,
    ) {
        if (NetplayRuntimeInput.active && id == ComposeTouchLayouts.MOTION_SOURCE_DPAD) {
            NetplayRuntimeInput.setDpad(xAxis, yAxis)
            return
        }

        when (id) {"""
s = must_replace(s, direction_anchor, direction_replacement, "touch dpad netplay routing")
touch.write_text(s)

# ---------------------------------------------------------------------------
# NES controller port 2 + turbo for both players
# ---------------------------------------------------------------------------
system_file = root / "retrograde-app-shared/src/main/java/com/swordfish/lemuroid/lib/library/GameSystem.kt"
s = system_file.read_text()
nes_pos = s.find("SystemID.NES,")
if nes_pos < 0:
    raise SystemExit("NES system block not found")
block_end = s.find('uniqueExtensions = listOf("nes")', nes_pos)
if block_end < 0:
    raise SystemExit("NES system block end not found")
block = s[nes_pos:block_end]
old_ports = """controllerConfigs =
                                hashMapOf(
                                    0 to arrayListOf(ControllerConfigs.NES),
                                ),"""
new_ports = """controllerConfigs =
                                hashMapOf(
                                    0 to arrayListOf(ControllerConfigs.NES),
                                    1 to arrayListOf(ControllerConfigs.NES),
                                ),"""
if old_ports not in block:
    raise SystemExit("NES controller ports block not found")
block = block.replace(old_ports, new_ports, 1)
s = s[:nes_pos] + block + s[block_end:]
system_file.write_text(s)

retro = root / "lemuroid-app/src/main/java/com/swordfish/lemuroid/app/shared/game/viewmodel/GameViewModelRetroGameView.kt"
s = retro.read_text()
count = s.count('Variable("fceumm_turbo_enable", "Player 1")')
if count < 2:
    raise SystemExit(f"Expected two Player 1 turbo overrides after V6 patch, found {count}")
s = s.replace('Variable("fceumm_turbo_enable", "Player 1")', 'Variable("fceumm_turbo_enable", "Both")')
retro.write_text(s)

print("V10 synchronized LAN netplay patch applied")
