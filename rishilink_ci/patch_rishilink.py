from pathlib import Path
import sys

ROOT = Path(sys.argv[1]).resolve()

def replace_once(rel, old, new):
    p = ROOT / rel
    s = p.read_text(encoding="utf-8")
    if old not in s:
        raise RuntimeError(f"Expected text not found in {rel}: {old[:120]!r}")
    p.write_text(s.replace(old, new, 1), encoding="utf-8")
    print(f"patched {rel}")

def replace_all(rel, old, new):
    p = ROOT / rel
    s = p.read_text(encoding="utf-8")
    n = s.count(old)
    if n == 0:
        raise RuntimeError(f"Expected text not found in {rel}: {old[:120]!r}")
    p.write_text(s.replace(old, new), encoding="utf-8")
    print(f"patched {rel} ({n} replacements)")

replace_once(
    "app/lib/pages/home_page.dart",
    """                              Text(
                                'LocalSend',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),""",
    """                              Text(
                                'RishiLink',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),""",
)

replace_once("app/lib/main.dart", "              title: t.appName,", "              title: 'RishiLink',")
replace_once("app/lib/main.dart", "                  initialTab: HomeTab.receive,", "                  initialTab: HomeTab.send,")

replace_all("app/android/app/src/main/AndroidManifest.xml", 'android:label="LocalSend"', 'android:label="RishiLink"')
replace_once("app/windows/runner/main.cpp", '  if (!window.Create(L"LocalSend", origin, size)) {', '  if (!window.Create(L"RishiLink", origin, size)) {')
replace_once("app/windows/runner/Runner.rc", '"FileDescription", "LocalSend"', '"FileDescription", "RishiLink"')
replace_once("app/windows/runner/Runner.rc", '"ProductName", "LocalSend"', '"ProductName", "RishiLink"')
replace_once("app/lib/util/native/context_menu_helper.dart", "const _windowsFileName = 'LocalSend';", "const _windowsFileName = 'RishiLink';")

# Upstream compatibility fix: the pinned revision generated AppLocale.ky but
# had not yet added Kyrgyz to the exhaustive locale-name switch.
replace_once(
    "app/lib/util/i18n.dart",
    "      AppLocale.ko => '한국어',\n      AppLocale.lo => 'ລາວ',",
    "      AppLocale.ko => '한국어',\n      AppLocale.ky => 'Кыргызча',\n      AppLocale.lo => 'ລາວ',",
)

for p in (ROOT / "app/assets/i18n").glob("*.json"):
    s = p.read_text(encoding="utf-8")
    if '"appName": "LocalSend"' in s:
        p.write_text(s.replace('"appName": "LocalSend"', '"appName": "RishiLink"'), encoding="utf-8")

for p in (ROOT / "app/lib/gen").glob("strings*.g.dart"):
    s = p.read_text(encoding="utf-8")
    if "String get appName => 'LocalSend';" in s:
        p.write_text(s.replace("String get appName => 'LocalSend';", "String get appName => 'RishiLink';"), encoding="utf-8")

replace_once(
    "app/lib/pages/home_page.dart",
    """    return DropTarget(
      onDragEntered: (_) {""",
    """    return DropTarget(
      // RishiLink: on the Send tab, each device card owns its own drop target.
      // This prevents the page-wide target from handling the same native drop twice.
      enable: vm.currentTab != HomeTab.send,
      onDragEntered: (_) {""",
)

replace_once(
    "app/lib/pages/tabs/send_tab.dart",
    "import 'package:collection/collection.dart';",
    """import 'dart:io';

import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';""",
)

replace_once(
    "app/lib/pages/tabs/send_tab.dart",
    """import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/file_picker.dart';""",
    """import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/native/file_picker.dart';""",
)

replace_once(
    "app/lib/pages/tabs/send_tab.dart",
    """                      : DeviceListTile(
                          device: device,
                          isFavorite: favoriteEntry != null,
                          nameOverride: favoriteEntry?.alias,
                          onDetailsTap: () async => await context.push(() => DeviceDetailsPage(device: device)),
                          onTap: () async => await vm.onTapDevice(context, device),
                        ),""",
    """                      : _RishiLinkDeviceDropTarget(
                          device: device,
                          child: DeviceListTile(
                            device: device,
                            isFavorite: favoriteEntry != null,
                            nameOverride: favoriteEntry?.alias,
                            onDetailsTap: () async => await context.push(() => DeviceDetailsPage(device: device)),
                            onTap: () async => await vm.onTapDevice(context, device),
                          ),
                        ),""",
)

marker = """/// A button that opens a popup menu to select [T].
/// This is used for the scan button and the send mode button.
class _CircularPopupButton<T> extends StatelessWidget {"""

direct_drop = r'''/// RishiLink's device-first transfer target.
class _RishiLinkDeviceDropTarget extends StatefulWidget {
  final Device device;
  final Widget child;

  const _RishiLinkDeviceDropTarget({
    required this.device,
    required this.child,
  });

  @override
  State<_RishiLinkDeviceDropTarget> createState() => _RishiLinkDeviceDropTargetState();
}

class _RishiLinkDeviceDropTargetState extends State<_RishiLinkDeviceDropTarget> with Refena {
  bool _hovering = false;
  bool _busy = false;

  Future<void> _handleDrop(DropDoneDetails event) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _hovering = false;
    });

    try {
      final selection = ref.redux(selectedSendingFilesProvider);
      selection.dispatch(ClearSelectionAction());

      final droppedDirectories = event.files
          .where((item) => item is DropItemDirectory || Directory(item.path).existsSync())
          .toList();
      final droppedFiles = event.files
          .where((item) => item is! DropItemDirectory && !Directory(item.path).existsSync())
          .toList();

      for (final directory in droppedDirectories) {
        await selection.dispatchAsync(AddDirectoryAction(directory.path));
      }

      if (droppedFiles.isNotEmpty) {
        await selection.dispatchAsync(
          AddFilesAction(
            files: droppedFiles,
            converter: CrossFileConverters.convertXFile,
          ),
        );
      }

      final files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty) {
        return;
      }

      await ref.notifier(sendProvider).startSession(
            target: widget.device,
            files: files,
            background: false,
          );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: _handleDrop,
      child: Stack(
        children: [
          widget.child,
          if (_hovering)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    border: Border.all(color: colorScheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          'Drop to send',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

''' + marker

replace_once("app/lib/pages/tabs/send_tab.dart", marker, direct_drop)

(ROOT / "RISHILINK_MODIFICATIONS.md").write_text(
    """# RishiLink modifications

RishiLink v0.1 is derived from LocalSend at commit
230fb692962668ca22ce0e61a8f53ce1cfd32102.

Original project: https://github.com/localsend/localsend
Original copyright: Copyright 2022-2026 Tien Do Nam
License: Apache License 2.0

RishiLink changes include product branding, a device-first startup flow, and
direct file/folder drop onto a discovered device card. Upstream copyright,
license, and attribution files are retained.
""",
    encoding="utf-8",
)

print("RishiLink patch complete.")
