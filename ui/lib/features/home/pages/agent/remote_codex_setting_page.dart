import 'package:ui/widgets/navigation/page_route.dart';
import 'package:ui/widgets/omni_adaptive_layout.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/features/home/pages/agent/codex_bridge_qr_scanner_page.dart';
import 'package:ui/features/home/pages/agent/codex_remote_directory_picker.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/settings_section_title.dart';
import 'package:ui/widgets/settings_ui.dart';

class RemoteCodexSettingPage extends StatefulWidget {
  const RemoteCodexSettingPage({super.key});

  @override
  State<RemoteCodexSettingPage> createState() => _RemoteCodexSettingPageState();
}

class _RemoteCodexSettingPageState extends State<RemoteCodexSettingPage> {
  static const Duration _autoSaveDelay = Duration(milliseconds: 700);

  late final TextEditingController _bridgeUrlController;
  late final TextEditingController _bridgeTokenController;
  late final TextEditingController _bridgeCwdController;

  Timer? _saveDebounce;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _syncing = false;
  bool _enabled = false;
  bool _obscureToken = true;
  String? _error;
  String? _status;
  String? _lastSavedSignature;

  bool get _english =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'en';

  String _text(String zh, String en) => _english ? en : zh;

  bool get _complete =>
      !_enabled ||
      (_bridgeUrlController.text.trim().isNotEmpty &&
          _bridgeCwdController.text.trim().isNotEmpty);

  String get _signature => [
    _enabled ? 'enabled' : 'disabled',
    _bridgeUrlController.text.trim(),
    _bridgeTokenController.text.trim(),
    _bridgeCwdController.text.trim(),
  ].join('\n');

  @override
  void initState() {
    super.initState();
    _bridgeUrlController = TextEditingController();
    _bridgeTokenController = TextEditingController();
    _bridgeCwdController = TextEditingController();
    for (final controller in [
      _bridgeUrlController,
      _bridgeTokenController,
      _bridgeCwdController,
    ]) {
      controller.addListener(_handleEdited);
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    for (final controller in [
      _bridgeUrlController,
      _bridgeTokenController,
      _bridgeCwdController,
    ]) {
      controller.removeListener(_handleEdited);
      controller.dispose();
    }
    super.dispose();
  }

  void _setText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _sync(CodexRemoteBridgeConfig config) {
    _syncing = true;
    try {
      _setText(_bridgeUrlController, config.remoteBridgeUrl);
      _setText(_bridgeTokenController, config.remoteBridgeToken);
      _setText(_bridgeCwdController, config.remoteCwd);
      _enabled = config.remoteEnabled;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _load() async {
    try {
      final config = await AgentRuntimeService.readRemoteBridgeConfig();
      if (!mounted) return;
      _sync(config);
      setState(() {
        _loading = false;
        _error = null;
        _status = null;
        _lastSavedSignature = _signature;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'فشل قراءة إعدادات جسر الحاسوب عن بُعد: $error';
      });
    }
  }

  void _handleEdited() {
    if (_syncing || !mounted) return;
    _saveDebounce?.cancel();
    setState(() {
      _error = null;
      _status = !_complete
          ? 'رابط الجسر ومجلد العمل عن بُعد مطلوبان عند تفعيل الوضع عن بُعد.'
          : _signature == _lastSavedSignature
          ? 'تم الحفظ تلقائياً.'
          : 'الحفظ التلقائي معلّق…';
    });
    if (_complete && _signature != _lastSavedSignature) {
      _saveDebounce = Timer(_autoSaveDelay, () => unawaited(_save()));
    }
  }

  void _setEnabled(bool value) {
    if (_enabled == value || _saving) return;
    setState(() => _enabled = value);
    _handleEdited();
  }

  Future<bool> _save() async {
    if (_saving || !_complete) return false;
    final signature = _signature;
    if (signature == _lastSavedSignature) return true;
    setState(() {
      _saving = true;
      _error = null;
      _status = 'جارٍ الحفظ التلقائي…';
    });
    try {
      final saved = await AgentRuntimeService.writeRemoteBridgeConfig(
        remoteEnabled: _enabled,
        remoteBridgeUrl: _bridgeUrlController.text.trim(),
        remoteBridgeToken: _bridgeTokenController.text.trim(),
        remoteCwd: _bridgeCwdController.text.trim(),
      );
      if (!mounted) return false;
      if (_signature == signature) {
        _sync(saved);
      }
      setState(() {
        _lastSavedSignature = [
          saved.remoteEnabled ? 'enabled' : 'disabled',
          saved.remoteBridgeUrl,
          saved.remoteBridgeToken,
          saved.remoteCwd,
        ].join('\n');
        _status = _signature == _lastSavedSignature
            ? 'تم الحفظ تلقائياً.'
            : 'الحفظ التلقائي معلّق…';
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _error = 'فشل حفظ إعدادات جسر الحاسوب عن بُعد: $error';
        _status = null;
      });
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    final url = _bridgeUrlController.text.trim();
    final cwd = _bridgeCwdController.text.trim();
    if (url.isEmpty || cwd.isEmpty) {
      showToast(
        'أدخل رابط الجسر ومجلد العمل عن بُعد أولاً.',
        type: ToastType.warning,
      );
      return;
    }
    setState(() => _testing = true);
    try {
      final result = await AgentRuntimeService.testRemoteConfig(
        remoteBridgeUrl: url,
        remoteBridgeToken: _bridgeTokenController.text.trim(),
        remoteCwd: cwd,
      );
      if (!mounted) return;
      final ok = result['ok'] == true || result['ready'] == true;
      showToast(
        ok
            ? 'جسر الحاسوب عن بُعد جاهز.'
            : 'فشل الاتصال: ${result['error'] ?? 'unknown'}',
        type: ok ? ToastType.success : ToastType.error,
      );
    } catch (error) {
      if (!mounted) return;
      showToast(
        'فشل الاتصال: $error',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _chooseDirectory() async {
    final url = _bridgeUrlController.text.trim();
    if (url.isEmpty) {
      showToast(
        'أدخل رابط الجسر أولاً.',
        type: ToastType.warning,
      );
      return;
    }
    final selected = await showCodexRemoteDirectoryPicker(
      context: context,
      remoteBridgeUrl: url,
      remoteBridgeToken: _bridgeTokenController.text.trim(),
      initialPath: _bridgeCwdController.text.trim(),
    );
    if (!mounted || selected == null || selected.trim().isEmpty) return;
    _setText(_bridgeCwdController, selected.trim());
    _handleEdited();
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<CodexBridgeQrScanResult>(
      OmniPageRoute(
        builder: (_) => const CodexBridgeQrScannerPage(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || result == null) return;
    _syncing = true;
    try {
      _setText(_bridgeUrlController, result.bridgeUrl.trim());
      _setText(_bridgeTokenController, result.token.trim());
      _setText(_bridgeCwdController, result.cwd.trim());
      _enabled = true;
    } finally {
      _syncing = false;
    }
    _handleEdited();
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    final palette = context.omniPalette;
    return TextField(
      key: key,
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      style: TextStyle(color: palette.textPrimary, fontSize: 13.5),
      decoration: omniSettingsInputDecoration(
        context,
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: CommonAppBar(
        title: 'جسر الحاسوب عن بُعد',
        primary: true,
      ),
      body: OmniContentWidth(
        child: SafeArea(
          top: false,
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: edgeToEdgeScrollPadding(
                    context,
                    const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  ),
                  children: [
                    SettingsSectionTitle(
                      label: 'تشغيل Codex عن بُعد',
                      subtitle: 'تدير هذه الصفحة جسر الحاسوب عن بُعد فقط. اضبط واجهة برمجة التطبيقات والحساب والنموذج الافتراضي لكل وكيل محلي في وضع الوكيل.',
                    ),
                    OmniSettingsCard(
                      key: const Key('remote-pc-bridge-settings-card'),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'تفعيل جسر الحاسوب عن بُعد',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              OmniSettingsSwitch(
                                value: _enabled,
                                enabled: !_saving,
                                onToggle: _setEnabled,
                              ),
                            ],
                          ),
                          Text(
                            _enabled
                                ? 'ستستخدم دردشة الوكيل بيئة تشغيل ACP عن بُعد.'
                                : 'الاتصال عن بُعد مغلق؛ تستخدم الدردشة المحلية وكيل ACP المحدد.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _field(
                            key: const Key(
                              'codex-config-remote-bridge-url-field',
                            ),
                            controller: _bridgeUrlController,
                            label: 'Bridge URL',
                            hint: 'ws://192.168.1.10:17321/codex',
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            key: const Key('codex-config-remote-cwd-field'),
                            controller: _bridgeCwdController,
                            label: 'مجلد العمل عن بُعد',
                            hint: '/Users/name/code/project',
                            suffix: IconButton(
                              tooltip: 'اختر المجلد',
                              onPressed: _chooseDirectory,
                              icon: const Icon(
                                LucideIcons.folderOpen,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _field(
                            key: const Key('codex-config-remote-token-field'),
                            controller: _bridgeTokenController,
                            label: 'رمز الجسر (اختياري)',
                            hint: 'OMNIBOT_BRIDGE_TOKEN',
                            obscure: _obscureToken,
                            suffix: IconButton(
                              tooltip: _obscureToken
                                  ? 'إظهار الرمز'
                                  : 'إخفاء الرمز',
                              onPressed: () => setState(
                                () => _obscureToken = !_obscureToken,
                              ),
                              icon: Icon(
                                _obscureToken
                                    ? LucideIcons.eye
                                    : LucideIcons.eyeOff,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const Key(
                                  'codex-config-scan-bridge-qr-button',
                                ),
                                onPressed: _saving ? null : _scanQr,
                                icon: const Icon(
                                  LucideIcons.scanQrCode,
                                  size: 17,
                                ),
                                label: Text('مسح رمز QR'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _testing ? null : _testConnection,
                                icon: _testing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        LucideIcons.radioTower,
                                        size: 17,
                                      ),
                                label: Text(
                                  _testing
                                      ? 'جارٍ الاختبار…'
                                      : 'اختبار الاتصال',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_status != null || _error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error ?? _status!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _error != null
                              ? Theme.of(context).colorScheme.error
                              : palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
