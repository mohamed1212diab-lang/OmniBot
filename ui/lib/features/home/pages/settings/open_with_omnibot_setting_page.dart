import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/l10n/l10n.dart';
import 'package:ui/services/app_state_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/settings_ui.dart';

class OpenWithOmnibotSettingPage extends StatefulWidget {
  const OpenWithOmnibotSettingPage({super.key});

  @override
  State<OpenWithOmnibotSettingPage> createState() =>
      _OpenWithOmnibotSettingPageState();
}

class _OpenWithOmnibotSettingPageState
    extends State<OpenWithOmnibotSettingPage> {
  static const String _sharedOpenModeDefault = 'default';
  static const String _sharedOpenModeWorkspace = 'workspace';
  static const String _targetImage = 'image';
  static const String _targetFile = 'file';

  String _sharedOpenImageMode = _sharedOpenModeDefault;
  String _sharedOpenFileMode = _sharedOpenModeDefault;
  bool _sharedOpenModesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSharedOpenMode();
  }

  Future<void> _loadSharedOpenMode() async {
    final modes = await AppStateService.getSharedOpenModes();
    if (!mounted) return;
    setState(() {
      _sharedOpenImageMode = _normalizeSharedOpenMode(modes['imageMode']);
      _sharedOpenFileMode = _normalizeSharedOpenMode(modes['fileMode']);
      _sharedOpenModesLoaded = true;
    });
  }

  Future<void> _onSharedOpenModeChanged({
    required String target,
    required String? value,
  }) async {
    final nextMode = _normalizeSharedOpenMode(value);
    final isImageTarget = target == _targetImage;
    final currentMode = isImageTarget
        ? _sharedOpenImageMode
        : _sharedOpenFileMode;
    if (nextMode == currentMode) return;
    final previousMode = currentMode;
    setState(() {
      if (isImageTarget) {
        _sharedOpenImageMode = nextMode;
      } else {
        _sharedOpenFileMode = nextMode;
      }
    });
    final saved = await AppStateService.setSharedOpenMode(
      nextMode,
      target: target,
    );
    if (!mounted) return;
    final normalizedSaved = _normalizeSharedOpenMode(saved);
    setState(() {
      if (isImageTarget) {
        _sharedOpenImageMode = normalizedSaved;
      } else {
        _sharedOpenFileMode = normalizedSaved;
      }
    });
    if (normalizedSaved != nextMode) {
      setState(() {
        if (isImageTarget) {
          _sharedOpenImageMode = previousMode;
        } else {
          _sharedOpenFileMode = previousMode;
        }
      });
      showToast(context.l10n.settingsSaveFailed, type: ToastType.error);
    }
  }

  String _normalizeSharedOpenMode(String? value) {
    return switch (value?.trim()) {
      _sharedOpenModeWorkspace => _sharedOpenModeWorkspace,
      _ => _sharedOpenModeDefault,
    };
  }

  String _defaultModeLabel(String target) {
    return target == _targetImage
        ? 'الإرفاق بصندوق إدخال المحادثة'
        : 'إنشاء رابط ملف على الشبكة المحلية';
  }

  String _modeSubtitle({required String target, required String mode}) {
    if (mode == _sharedOpenModeWorkspace) {
      return 'الإضافة إلى workspace والإرفاق بالمحادثة وإرسال مسار الملف في التوجيه';
    }
    return target == _targetImage
        ? 'سيتم إرفاق الصور مباشرة بصندوق إدخال المحادثة'
        : 'ستقوم الملفات غير الصور بتشغيل خادم ملفات وإنشاء رابط على الشبكة المحلية';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final sections = [
      _SettingSection(
        label: 'الفتح باستخدام Doser AI',
        items: [
          _SettingItem(
            icon: LucideIcons.image,
            title: 'الصور',
            subtitle: _modeSubtitle(
              target: _targetImage,
              mode: _sharedOpenImageMode,
            ),
            trailing: _buildSharedOpenModeDropdown(
              target: _targetImage,
              value: _sharedOpenImageMode,
              onChanged: (value) =>
                  _onSharedOpenModeChanged(target: _targetImage, value: value),
            ),
          ),
          _SettingItem(
            icon: LucideIcons.file,
            title: 'الملفات',
            subtitle: _modeSubtitle(
              target: _targetFile,
              mode: _sharedOpenFileMode,
            ),
            trailing: _buildSharedOpenModeDropdown(
              target: _targetFile,
              value: _sharedOpenFileMode,
              onChanged: (value) =>
                  _onSharedOpenModeChanged(target: _targetFile, value: value),
            ),
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: CommonAppBar(title: 'الفتح باستخدام Doser AI', primary: true),
      body: OmniContentWidth(
        child: SafeArea(
          top: false,
          bottom: false,
          child: ListView.separated(
            padding: edgeToEdgeScrollPadding(
              context,
              const EdgeInsets.fromLTRB(22, 12, 22, 32),
            ),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 22),
            itemBuilder: (context, index) {
              return _buildSettingsSection(sections[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSharedOpenModeDropdown({
    required String target,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    final palette = context.omniPalette;
    if (!_sharedOpenModesLoaded) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: palette.accentPrimary,
        ),
      );
    }
    return OmniSettingsDropdown<String>(
      value: value,
      maxWidth: 168,
      menuMinWidth: 204,
      options: [
        OmniSettingsOption(
          value: _sharedOpenModeDefault,
          label: _defaultModeLabel(target),
        ),
        OmniSettingsOption(
          value: _sharedOpenModeWorkspace,
          label: 'الحفظ في workspace وإرسال المسار',
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildSettingsSection(_SettingSection section) {
    return OmniSettingsGroup(
      title: section.label,
      children: [
        for (final item in section.items)
          OmniSettingsTile(
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            trailing: item.trailing,
          ),
      ],
    );
  }
}

class _SettingSection {
  final String label;
  final List<_SettingItem> items;

  const _SettingSection({required this.label, required this.items});
}

class _SettingItem {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingItem({
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });
}
