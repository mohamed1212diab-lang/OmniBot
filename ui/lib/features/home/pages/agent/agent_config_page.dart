import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/widgets/conversation_model_selector.dart';
import 'package:ui/core/router/go_router_manager.dart';

import 'dart:async';
import 'dart:convert';

import 'package:ui/widgets/glass_popup.dart';
import 'package:ui/widgets/flclash/popup.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/services/model_provider_config_service.dart';
import 'package:ui/services/scene_model_config_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/settings_detail_sheet.dart';
import 'package:ui/widgets/settings_section_title.dart';
import 'package:ui/widgets/settings_ui.dart';

class AgentConfigPage extends StatefulWidget {
  const AgentConfigPage({super.key, required this.agentId});

  final String agentId;

  @override
  State<AgentConfigPage> createState() => _AgentConfigPageState();
}

class _AgentConfigPageState extends State<AgentConfigPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _contentController;
  late final TextEditingController _commandController;
  late final TextEditingController _argumentsController;
  late final TextEditingController _environmentController;
  final _sharedModelContentKey = GlobalKey();

  AcpAgentProfile? _agent;
  String _kind = '';
  String _configPath = '';
  String _authPath = '';
  int _configRevision = 0;
  bool _loading = true;
  bool _saving = false;
  bool _obscureApiKey = true;
  bool _enabled = true;
  bool _changed = false;
  bool _naDevelopment = false;
  bool _naDevelopmentAvailable = false;
  bool _naSignedIn = false;
  bool _sharedModelLoading = true;
  bool _sharedModelSaving = false;
  List<ModelProviderProfileSummary> _providerProfiles = const [];
  Map<String, List<ProviderModelOption>> _providerModels = {};
  SceneModelBindingEntry? _sharedModelBinding;
  String? _error;

  bool get _english =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'en';

  String _text(String zh, String en) => _english ? en : zh;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _modelController = TextEditingController();
    _apiKeyController = TextEditingController();
    _contentController = TextEditingController();
    _commandController = TextEditingController();
    _argumentsController = TextEditingController();
    _environmentController = TextEditingController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _contentController.dispose();
    _commandController.dispose();
    _argumentsController.dispose();
    _environmentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await AgentRuntimeService.listAgents();
      final agent = catalog.agents
          .where((candidate) => candidate.id == widget.agentId)
          .firstOrNull;
      if (agent == null) {
        throw StateError('Unknown ACP Agent: ${widget.agentId}');
      }
      Map<String, dynamic> payload = const {};
      if (agent.builtIn && agent.configurationAvailable) {
        payload = await AgentRuntimeService.readAgentConfig(agent.id);
      }
      if (!mounted) return;
      _syncAgent(agent);
      _syncPayload(payload);
      setState(() {
        _agent = agent;
        _kind = !agent.configurationAvailable
            ? ''
            : agent.builtIn
            ? (payload['kind']?.toString() ?? '')
            : 'profile';
        _loading = false;
        _error = null;
      });
      if (agent.builtIn &&
          agent.configurationAvailable &&
          _kind != 'na-cloud') {
        unawaited(_loadSharedModelSelection());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _syncAgent(AcpAgentProfile agent) {
    _setText(_commandController, agent.command);
    _setText(_argumentsController, agent.arguments.join('\n'));
    _setText(
      _environmentController,
      agent.environment.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('\n'),
    );
    _enabled = agent.enabled;
  }

  void _syncPayload(Map<String, dynamic> payload) {
    _naDevelopmentAvailable = payload['developmentAvailable'] == true;
    _naDevelopment =
        _naDevelopmentAvailable && payload['connectionMode'] == 'development';
    _naSignedIn = payload['signedIn'] == true;
    _configRevision = switch (payload['revision']) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    _setText(_baseUrlController, payload['baseUrl']?.toString() ?? '');
    _setText(_modelController, payload['model']?.toString() ?? '');
    _setText(_apiKeyController, payload['apiKey']?.toString() ?? '');
    _setText(_contentController, payload['content']?.toString() ?? '');
    _configPath =
        payload['configPath']?.toString() ?? payload['path']?.toString() ?? '';
    _authPath = payload['authPath']?.toString() ?? '';
  }

  Future<void> _loadSharedModelSelection() async {
    try {
      final profilesPayload = await ModelProviderConfigService.listProfiles();
      final bindings = await SceneModelConfigService.getSceneModelBindings();
      final models = <String, List<ProviderModelOption>>{};
      for (final profile in profilesPayload.profiles) {
        // This page reads the persisted Provider document. It must not turn
        // merely opening Agent settings into a serialized /models sweep.
        models[profile.id] = profile.configured
            ? await ModelProviderConfigService.getStoredModelOptionsForProfile(
                profile.id,
                profile: profile,
                enrichMetadata: false,
              )
            : const <ProviderModelOption>[];
      }
      final persistedBinding = bindings
          .where((item) => item.sceneId == 'scene.dispatch.model')
          .firstOrNull;
      final binding = persistedBinding;
      if (!mounted) return;
      setState(() {
        _providerProfiles = profilesPayload.profiles;
        _providerModels = models;
        _sharedModelBinding = binding;
        _sharedModelLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sharedModelLoading = false;
      });
      debugPrint('Load shared Agent Provider selection failed: $error');
    }
  }

  Future<void> _selectSharedModel(BuildContext anchorContext) async {
    if (_sharedModelSaving || _sharedModelLoading) return;
    final anchor = glassPopupAnchorFromContext(anchorContext);
    if (anchor == null) return;
    final selection = await showGlassPopup<ConversationModelSelection>(
      context: context,
      sourceContext: anchorContext,
      anchor: anchor,
      child: Builder(
        builder: (popupContext) => LayoutBuilder(
          builder: (context, constraints) => ConversationModelSelectorContent(
            width: 320,
            maxHeight: constraints.maxHeight.clamp(220.0, 460.0),
            loadLiveProviders: true,
            currentSelection: _sharedModelBinding == null
                ? null
                : ConversationModelSelection(
                    providerProfileId: _sharedModelBinding!.providerProfileId,
                    modelId: _sharedModelBinding!.modelId,
                  ),
            onSelect: (value) => Navigator.of(popupContext).pop(value),
          ),
        ),
      ),
    );
    if (!mounted || selection == null) return;
    await _saveSharedModel(
      _SharedModelSelection(
        providerProfileId: selection.providerProfileId,
        modelId: selection.modelId,
      ),
    );
  }

  Future<void> _saveSharedModel(_SharedModelSelection selection) async {
    setState(() {
      _sharedModelSaving = true;
      _error = null;
    });
    try {
      final bindings = await SceneModelConfigService.saveSceneModelBinding(
        sceneId: 'scene.dispatch.model',
        providerProfileId: selection.providerProfileId,
        modelId: selection.modelId,
      );
      if (!mounted) return;
      setState(() {
        _sharedModelBinding = bindings
            .where((item) => item.sceneId == 'scene.dispatch.model')
            .firstOrNull;
        _sharedModelSaving = false;
        _changed = true;
      });
      showToast(
        'تم تحديث مزوّد الوكيل / النموذج.',
        type: ToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sharedModelSaving = false;
        _error = error.toString();
      });
      showToast(error.toString(), type: ToastType.error);
    }
  }

  void _setText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _save() async {
    if (_saving || _agent == null || !_agent!.configurationAvailable) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      switch (_kind) {
        case 'na-cloud':
          final payload = await AgentRuntimeService.writeAgentConfig(
            _agent!.id,
            connectionMode: _naDevelopment ? 'development' : 'managed',
            baseUrl: _naDevelopment ? _baseUrlController.text.trim() : null,
            apiKey: _naDevelopment ? _apiKeyController.text.trim() : null,
          );
          if (!mounted) return;
          _syncPayload(payload);
          if (!_naDevelopment) {
            final status = await AgentRuntimeService.testAgent(_agent!.id);
            if (status['connected'] != true) {
              throw StateError(
                status['error']?.toString() ??
                    'السحابة غير متاحة.',
              );
            }
          }
          break;
        case 'codex':
          final payload = await AgentRuntimeService.writeAgentConfig(
            _agent!.id,
            expectedRevision: _configRevision > 0 ? _configRevision : null,
          );
          if (!mounted) return;
          _syncPayload(payload);
          break;
        case 'json':
          final content = _contentController.text;
          final decoded = jsonDecode(content);
          if (decoded is! Map) {
            throw const FormatException(
              'settings.json must contain a JSON object.',
            );
          }
          final payload = await AgentRuntimeService.writeAgentConfig(
            _agent!.id,
            content: content,
            expectedRevision: _configRevision > 0 ? _configRevision : null,
          );
          if (!mounted) return;
          _syncPayload(payload);
          break;
        case 'jsonc':
          final payload = await AgentRuntimeService.writeAgentConfig(
            _agent!.id,
            content: _contentController.text,
            expectedRevision: _configRevision > 0 ? _configRevision : null,
          );
          if (!mounted) return;
          _syncPayload(payload);
          break;
        case 'profile':
          final command = _commandController.text.trim();
          if (command.isEmpty) {
            throw ArgumentError(
              'أمر التشغيل مطلوب.',
            );
          }
          final catalog = await AgentRuntimeService.saveAgent(
            AcpAgentProfile(
              id: _agent!.id,
              name: _agent!.name,
              description: _agent!.description,
              command: command,
              arguments: _nonEmptyLines(_argumentsController.text),
              environment: _parseEnvironment(_environmentController.text),
              enabled: _enabled,
              builtIn: false,
              source: _agent!.source,
            ),
          );
          if (!mounted) return;
          final saved = catalog.agents
              .where((candidate) => candidate.id == _agent!.id)
              .firstOrNull;
          if (saved != null) {
            _agent = saved;
            _syncAgent(saved);
          }
          break;
        default:
          throw UnsupportedError(
            'لا يوجد إعداد محلي قابل للتحرير لهذا الوكيل.',
          );
      }
      if (!mounted) return;
      setState(() => _changed = true);
      showToast(
        _kind == 'na-cloud' && !_naDevelopment
            ? 'تم الاتصال بمساحة عملك السحابية.'
            : 'تم حفظ الإعدادات.',
        type: ToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : error.toString();
      setState(() => _error = message);
      showToast(message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCustomAgent() async {
    final agent = _agent;
    if (agent == null || agent.builtIn || _saving) return;
    final confirmed = await showSettingsDetailSheet<bool>(
      context: context,
      builder: (sheetContext) => SettingsDetailSheet(
        title: 'حذف الوكيل؟',
        body: Text(
          'سيؤدي هذا إلى حذف إعدادات “${agent.name}” دون إلغاء تثبيت أمره.',
        ),
        actions: [
          TextButton(
            style: settingsDetailSheetActionStyle(sheetContext),
            onPressed: () => Navigator.of(sheetContext).pop(false),
            child: Text('إلغاء'),
          ),
          TextButton(
            style: settingsDetailSheetActionStyle(
              sheetContext,
              foregroundColor: const Color(0xFFE05252),
            ),
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await AgentRuntimeService.deleteAgent(agent.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
      showToast(error.toString(), type: ToastType.error);
    }
  }

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return PopScope(
      // Built-in Agent configuration does not mutate the catalog entry, so it
      // does not need to intercept system back just to return `_changed`.
      // A poppable route also lets the shared pointer gesture return.
      canPop: _agent?.builtIn == true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: palette.pageBackground,
        appBar: CommonAppBar(
          title: _agent?.name ?? 'إعداد الوكيل',
          primary: true,
          onBackPressed: _close,
          actions: [
            if (_agent?.builtIn == false)
              IconButton(
                tooltip: 'حذف الوكيل',
                onPressed: _saving ? null : _deleteCustomAgent,
                icon: const Icon(LucideIcons.trash2),
              ),
          ],
        ),
        body: OmniContentWidth(
          child: SafeArea(
            top: false,
            bottom: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _agent == null
                ? _ErrorState(error: _error!, onRetry: _load)
                : _agent?.configurationAvailable == false
                ? _buildManagedAccountNotice()
                : ListView(
                    padding: edgeToEdgeScrollPadding(
                      context,
                      const EdgeInsets.fromLTRB(22, 12, 22, 28),
                    ),
                    children: [
                      SettingsSectionTitle(
                        label: _pageTitle,
                        subtitle: _pageSubtitle,
                      ),
                      OmniSettingsCard(
                        padding: const EdgeInsets.all(16),
                        child: _buildEditor(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_kind.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          key: const Key('agent-config-save'),
                          onPressed:
                              _saving ||
                                  (_kind == 'na-cloud' &&
                                      !_naDevelopment &&
                                      !_naSignedIn)
                              ? null
                              : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.save),
                          label: Text(
                            _kind == 'na-cloud' && !_naDevelopment
                                ? 'الاتصال بمساحة عملي'
                                : 'حفظ الإعدادات',
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagedAccountNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'يستخدم Na حسابك المسجّل تلقائياً. لا حاجة لأي إعداد.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const Key('na-account'),
              onPressed: () => GoRouterManager.push('/my/account'),
              child: Text('إدارة الحساب'),
            ),
          ],
        ),
      ),
    );
  }

  String get _pageTitle {
    return switch (_kind) {
      'na-cloud' => 'اتصال سحابة Na',
      'codex' => 'إعداد Codex API',
      'json' => 'إعداد Claude Code',
      'jsonc' => 'إعداد OpenCode',
      'profile' => 'إعداد تشغيل ACP',
      _ => 'إعداد الوكيل',
    };
  }

  String get _pageSubtitle {
    return switch (_kind) {
      'na-cloud' => 'يتصل Na بمساحة عملك باستخدام حسابك المسجّل. تدير المنصة النماذج والاستهلاك.',
      'codex' => 'يُستخدم المزوّد المشترك افتراضياً. تعرض هذه الصفحة ملفات Codex الرسمية أو تستبدلها فقط؛ وتُطبَّق التغييرات عند بدء ACP التالي.',
      'json' => 'حرّر $_configPath مباشرة. هذا هو المحتوى الحالي للملف.',
      'jsonc' => 'حرّر $_configPath مباشرة. يدعم OpenCode تنسيقي JSON وJSONC.',
      'profile' => 'الحفظ لا يقطع المحادثة الحالية. تُطبَّق تغييرات الأمر والوسائط ومتغيرات البيئة عند بدء عملية الوكيل التالية. ويدير الوكيل نفسه إعدادات المزوّد والنموذج.',
      _ => '',
    };
  }

  Widget _buildEditor() {
    return switch (_kind) {
      'na-cloud' => _buildNaConnectionEditor(),
      'codex' => _buildCodexEditor(),
      'json' || 'jsonc' => _buildRawFileEditor(),
      'profile' => _buildProfileEditor(),
      _ => Text('لا يوجد إعداد قابل للتحرير.'),
    };
  }

  Widget _buildNaConnectionEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_naDevelopmentAvailable)
          OmniSettingsTile(
            tileKey: const Key('na-development-connection'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            title: 'استخدام خادم تطوير',
            translateText: false,
            trailing: OmniSettingsSwitch(
              value: _naDevelopment,
              enabled: !_saving,
              onToggle: (value) => setState(() {
                _naDevelopment = value;
                _apiKeyController.clear();
                if (value) {
                  _baseUrlController.text = 'http://127.0.0.1:8787';
                }
              }),
            ),
          ),
        if (!_naDevelopment) ...[
          Text(
            _naSignedIn
                ? 'تم تسجيل الدخول. تُخصَّص مساحة عملك المصرّح بها تلقائياً. لا حاجة لإدخال رمز بعد إعادة تشغيل التطبيق.'
                : 'سجّل الدخول بحساب لديه وصول إلى Na.',
          ),
          const SizedBox(height: 14),
          TextButton(
            key: const Key('na-account'),
            onPressed: () async {
              await GoRouterManager.pushForResult('/my/account');
              if (mounted) await _load();
            },
            child: Text(
              _naSignedIn
                  ? 'إدارة الحساب'
                  : 'تسجيل الدخول',
            ),
          ),
        ] else ...[
          TextField(
            key: const Key('na-service-address'),
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'عنوان الخدمة',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('na-access-token'),
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'رمز الوصول إلى الحساب',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
                icon: Icon(
                  _obscureApiKey ? LucideIcons.eye : LucideIcons.eyeOff,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'بعد الحفظ، اختر Na من قائمة الوكلاء في الدردشة.',
          ),
        ],
      ],
    );
  }

  Widget _buildCodexEditor() {
    return Column(
      children: [
        _buildSharedProviderModelSelector(),
        const SizedBox(height: 12),
        Text(
          'يدير المزوّد المحدد الاتصال والمصادقة. تسجيل الدخول إلى ChatGPT لا يحتاج مفتاح API منفصلاً. ملف الإعداد الرسمي: $_configPath؛ ملف المصادقة: $_authPath',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSharedProviderModelSelector() {
    final binding = _sharedModelBinding;
    final profile = binding == null
        ? null
        : _providerProfiles
              .where((item) => item.id == binding.providerProfileId)
              .firstOrNull;
    final label = binding == null
        ? 'اختر المزوّد / النموذج'
        : '${profile?.name ?? binding.providerProfileId} / ${binding.modelId}';
    final decoration = InputDecoration(
      labelText: 'مزوّد الوكيل / النموذج المشترك',
      suffixIcon: _sharedModelSaving
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : const Icon(LucideIcons.chevronDown),
    ).applyDefaults(Theme.of(context).inputDecorationTheme);
    return FlClashPopupSource(
      glass: false,
      color: decoration.filled == true
          ? decoration.fillColor ?? Colors.transparent
          : Colors.transparent,
      shape: decoration.enabledBorder ?? decoration.border ?? InputBorder.none,
      captureRect: (context) => glassPopupInputContainerRect(
        context,
        _sharedModelContentKey.currentContext,
      ),
      captureOverflow: (context) => glassPopupInputLabelRects(
        context,
        _sharedModelContentKey.currentContext,
      ),
      builder: (anchorContext) => InkWell(
        key: const Key('agent-shared-provider-model-selector'),
        onTap: _sharedModelSaving || _sharedModelLoading
            ? null
            : () => _selectSharedModel(anchorContext),
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: decoration,
          child: Text(
            _sharedModelLoading
                ? 'جارٍ تحميل المزوّدين…'
                : label,
            key: _sharedModelContentKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildRawFileEditor() {
    return Column(
      children: [
        _buildSharedProviderModelSelector(),
        const SizedBox(height: 14),
        TextField(
          key: const Key('agent-raw-config-content'),
          controller: _contentController,
          minLines: 16,
          maxLines: 28,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            labelText: 'إعدادات متقدمة: $_configPath',
            alignLabelWithHint: true,
            hintText: '{\n}\n',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'حرّر هذا فقط لخيارات Adapter الخاصة. لا تُدخل بيانات اعتماد المزوّد هنا.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileEditor() {
    return Column(
      children: [
        TextField(
          controller: _commandController,
          decoration: InputDecoration(
            labelText: 'أمر أو مسار',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _argumentsController,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'وسائط (واحدة في كل سطر)',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _environmentController,
          minLines: 5,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: 'متغيرات البيئة',
            hintText: 'KEY=VALUE',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'تفعيل الوكيل',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.omniPalette.textPrimary,
                ),
              ),
            ),
            OmniSettingsSwitch(
              value: _enabled,
              onToggle: (value) => setState(() => _enabled = value),
            ),
          ],
        ),
      ],
    );
  }
}

class _SharedModelSelection {
  const _SharedModelSelection({
    required this.providerProfileId,
    required this.modelId,
  });

  final String providerProfileId;
  final String modelId;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final english =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'en';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _nonEmptyLines(String source) {
  return source
      .split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

Map<String, String> _parseEnvironment(String source) {
  final environment = <String, String>{};
  for (final line in source.split('\n')) {
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    if (key.isEmpty) continue;
    environment[key] = line.substring(separator + 1);
  }
  return environment;
}
