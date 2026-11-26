import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/widgets/omni_circle_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/core/router/go_router_manager.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/agent_brand_icon.dart';
import 'package:ui/widgets/flclash/page_activity.dart';
import 'package:ui/widgets/omni_root_toolbar.dart';
import 'package:ui/widgets/navigation/open_container.dart';
import 'package:ui/widgets/settings_detail_sheet.dart';
import 'package:ui/widgets/settings_ui.dart';

/// The Agents page shows OpenCode only. The native catalog still lists every
/// agent; this page filters at the read site and never deletes agent code.
class AgentModeSettingPage extends StatefulWidget {
  const AgentModeSettingPage({
    super.key,
    this.embedded = false,
    this.active = true,
  });

  /// A root tab keeps its own title and actions, without a route back button.
  final bool embedded;

  /// Kept-alive tabs refresh cached catalog/configuration on becoming visible.
  final bool active;

  @override
  State<AgentModeSettingPage> createState() => _AgentModeSettingPageState();
}

class _AgentModeSettingPageState extends State<AgentModeSettingPage>
    with FlClashPageLoadMixin {
  static const _openCodeAgentId = 'opencode-acp';

  AcpAgentCatalog? _catalog;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _busyAgentId;
  int _catalogRequestId = 0;
  late Map<String, AgentPackageOperation> _packageOperations;
  StreamSubscription<Map<String, AgentPackageOperation>>?
  _packageOperationSubscription;
  // One automatic OpenCode install per page lifetime. Set only when an
  // install actually starts, so a failed install never auto-retries and a
  // missing terminal environment is re-checked on the next load instead.
  bool _autoInstallAttempted = false;

  bool get _english =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'en';

  @override
  void initState() {
    super.initState();
    _packageOperations = AgentRuntimeService.agentPackageOperations;
    _packageOperationSubscription = AgentRuntimeService
        .agentPackageOperationChanges
        .listen((operations) {
          if (!mounted) return;
          final completed = _packageOperations.keys.any(
            (id) => !operations.containsKey(id),
          );
          // Package operation ownership stays immediate; only its repaint waits.
          _packageOperations = operations;
          unawaited(publishPageState(() {}));
          if (completed) unawaited(_load());
        });
    // The native agent/list endpoint returns cached health. Keep route entry
    // immediate; users can request the full terminal/proot probe with the
    // refresh action without blocking this page.
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AgentModeSettingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    unawaited(_packageOperationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) => refresh
      ? _readCatalog(refresh: true)
      : runPageLoad(#catalog, _readCatalog, revalidate: true);

  Future<void> _readCatalog({bool refresh = false}) async {
    if (!await waitForPageReady()) return;
    final requestId = ++_catalogRequestId;
    if (refresh) {
      setState(() => _refreshing = true);
    }
    try {
      final catalog = refresh
          ? await AgentRuntimeService.refreshAgents()
          : await AgentRuntimeService.listAgents();
      if (!await waitForPageReady() ||
          requestId != _catalogRequestId ||
          !pageLoadIsCurrent(#catalog)) {
        return;
      }
      setState(() {
        _catalog = catalog;
        _loading = false;
        _refreshing = false;
        _error = null;
      });
      unawaited(_maybeAutoInstallOpenCode());
    } catch (error) {
      if (!await waitForPageReady() ||
          requestId != _catalogRequestId ||
          !pageLoadIsCurrent(#catalog)) {
        return;
      }
      setState(() {
        _loading = false;
        _refreshing = false;
        // The native ACP catalog is the only source of truth. Keep an
        // already loaded catalog on transient errors, but never invent a
        // second list in Dart.
        _error = formatAgentRuntimeErrorForUser(error, english: _english);
      });
    }
  }

  AgentPackageVersion? _resultVersion(Map<String, dynamic> result) {
    final agent = result['agent'];
    return agent is Map && agent['packageVersion'] is Map
        ? AgentPackageVersion.fromMap(agent['packageVersion'] as Map)
        : null;
  }

  /// The only agent this page shows. Every other catalog entry (Na, Claude
  /// Code, Codex, Pi, Kimi, custom agents) stays in the native catalog and
  /// in the service; it is filtered out here at the read site only.
  AcpAgentProfile? get _openCodeAgent {
    for (final agent in _catalog?.agents ?? const <AcpAgentProfile>[]) {
      if (agent.id == _openCodeAgentId) return agent;
    }
    return null;
  }

  /// Starts the OpenCode install automatically once the terminal environment
  /// is ready (the catalog carries a distribution id) and OpenCode is not
  /// installed yet. Uses the same [_runAgentAction] install path as the
  /// manual install button, silently: no result sheet pops up on its own.
  /// The tile itself shows the installing state, and on failure the install
  /// button stays visible as the manual retry.
  Future<void> _maybeAutoInstallOpenCode() async {
    if (_autoInstallAttempted || !mounted) return;
    final distributionId = _catalog?.distributionId;
    if (distributionId == null || distributionId.isEmpty) return;
    final agent = _openCodeAgent;
    if (agent == null || !agent.enabled || !agent.managedAdapter) return;
    final installed =
        agent.installed == true ||
        agent.packageVersion?.installedVersion != null;
    if (installed || _packageOperations.containsKey(agent.id)) return;
    _autoInstallAttempted = true;
    await _runAgentAction(agent, prepare: true, silent: true);
  }

  Future<void> _test(AcpAgentProfile agent) async {
    if (_busyAgentId == agent.id ||
        _packageOperations.containsKey(agent.id) ||
        !agent.enabled) {
      return;
    }
    await _runAgentAction(agent, prepare: false);
  }

  void _prepare(AcpAgentProfile agent) {
    if (_packageOperations.containsKey(agent.id) || !agent.enabled) return;
    unawaited(
      _runAgentAction(
        agent,
        prepare: true,
        upgrade: agent.packageVersion?.updateAvailable == true,
      ),
    );
  }

  Future<void> _uninstall(AcpAgentProfile agent) async {
    if (!agent.uninstallable ||
        _packageOperations.containsKey(agent.id) ||
        _busyAgentId == agent.id) {
      return;
    }
    final distributionId = _catalog?.distributionId;
    if (distributionId == null || distributionId.isEmpty) {
      await _showActionResult(
        agent,
        'تعذّر إلغاء التثبيت',
        'حدّث قائمة الوكلاء وحاول مجدداً.',
      );
      return;
    }
    final confirmed = await showSettingsDetailSheet<bool>(
      context: context,
      builder: (sheetContext) => SettingsDetailSheet(
        key: ValueKey('agent-uninstall-confirm-${agent.id}'),
        title: 'إلغاء تثبيت ${agent.name}؟',
        body: Text(
          'ألغِ تثبيت البرنامج من بيئة الطرفية الحالية. مع الاحتفاظ بالإعدادات ومعلومات تسجيل الدخول والسجل.',
        ),
        actions: [
          TextButton(
            key: Key('agent-uninstall-cancel-${agent.id}'),
            style: settingsDetailSheetActionStyle(sheetContext),
            onPressed: () => Navigator.of(sheetContext).pop(false),
            child: Text('إلغاء'),
          ),
          TextButton(
            key: Key('agent-uninstall-confirm-action-${agent.id}'),
            style: settingsDetailSheetActionStyle(
              sheetContext,
              foregroundColor: Theme.of(sheetContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: Text('إلغاء التثبيت'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runUninstall(agent, distributionId);
  }

  Future<void> _runUninstall(
    AcpAgentProfile agent,
    String distributionId,
  ) async {
    // The service owns the queued operation after this page is disposed.
    // A retry stays attached to the originally confirmed distribution.
    while (mounted) {
      if (_packageOperations.containsKey(agent.id)) return;
      var ok = false;
      Object? failure;
      try {
        final result = await AgentRuntimeService.uninstallAgentInBackground(
          agent.id,
          distributionId: distributionId,
        );
        ok = result['ok'] == true;
        failure = ok
            ? null
            : PlatformException(
                code: 'agent_uninstall_failed',
                message: result['error']?.toString(),
                details: result,
              );
      } catch (error) {
        failure = error;
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final retry = await showSettingsDetailSheet<bool>(
        context: context,
        builder: (sheetContext) => SettingsDetailSheet(
          key: ValueKey('agent-uninstall-result-${agent.id}'),
          title: ok
              ? 'تم إلغاء تثبيت المساعد'
              : 'لم يكتمل إلغاء التثبيت',
          body: SelectableText(
            ok
                ? 'تم إلغاء تثبيت ${agent.name}. تم الاحتفاظ بالإعدادات ومعلومات تسجيل الدخول والسجل.'
                : formatAgentRuntimeErrorForUser(
                    failure,
                    english: _english,
                    fallback: 'لم يكتمل إلغاء التثبيت. حاول مجدداً.',
                  ),
          ),
          actions: [
            TextButton(
              key: Key('agent-uninstall-result-close-${agent.id}'),
              style: settingsDetailSheetActionStyle(sheetContext),
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: Text('إغلاق'),
            ),
            if (!ok)
              TextButton(
                key: Key('agent-uninstall-retry-${agent.id}'),
                style: settingsDetailSheetActionStyle(sheetContext),
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text('إعادة المحاولة'),
              ),
          ],
        ),
      );
      if (retry != true || !mounted) return;
    }
  }

  Future<void> _runAgentAction(
    AcpAgentProfile agent, {
    required bool prepare,
    bool upgrade = false,
    // Silent runs (automatic install) update the tile and refresh the
    // catalog but never pop a result sheet on their own.
    bool silent = false,
  }) async {
    if (!prepare) setState(() => _busyAgentId = agent.id);
    try {
      final result = prepare
          ? await AgentRuntimeService.prepareAgentInBackground(
              agent.id,
              force: true,
              distributionId: _catalog?.distributionId,
            )
          : await AgentRuntimeService.testAgent(agent.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final version = _resultVersion(result);
      final verifiedUpgrade =
          version?.installedVersion != null &&
          version?.targetVersion != null &&
          version?.error == null &&
          version?.updateAvailable == false;
      final ok = result['ok'] == true && (!upgrade || verifiedUpgrade);
      final installed =
          result['agent'] is Map &&
          (result['agent'] as Map)['installed'] == true;
      final initializationFailed = prepare && !ok && installed;
      final title = upgrade
          ? (ok
                ? 'تم تحديث المساعد'
                : verifiedUpgrade
                ? 'تم التحديث، لكن تعذّر بدء المساعد'
                : 'التحديث غير مكتمل')
          : prepare
          ? (ok
                ? 'تم تثبيت المساعد'
                : initializationFailed
                ? 'تم التثبيت، لكن تعذّر بدء المساعد'
                : 'فشل تثبيت المساعد')
          : (ok
                ? 'المساعد جاهز'
                : 'تعذّر بدء المساعد');
      if (!silent) {
        await _showActionResult(
          agent,
          title,
          upgrade && ok
              ? 'تم تثبيت ${version!.installedVersion}. ستستخدمه المساعدات قيد التشغيل عند بدئها التالي.'
              : upgrade && result['ok'] == true && !verifiedUpgrade
              ? 'تعذّر العثور على الإصدار المستهدف. تحقق من الاتصال وحاول مجدداً.'
              : ok
              ? 'المساعد جاهز للدردشة.'
              : _actionError(
                  result['error'],
                  installation: prepare && !installed,
                ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (!silent) {
        await _showActionResult(
          agent,
          upgrade
              ? 'التحديث غير مكتمل'
              : prepare
              ? 'لم يكتمل التثبيت'
              : 'تعذّر بدء المساعد',
          _actionError(error, installation: prepare),
        );
      }
    } finally {
      if (!prepare && mounted) setState(() => _busyAgentId = null);
    }
  }

  Future<void> _showActionResult(
    AcpAgentProfile agent,
    String title,
    String message,
  ) async {
    await showSettingsDetailSheet<void>(
      context: context,
      builder: (sheetContext) => SettingsDetailSheet(
        key: ValueKey('agent-check-result-${agent.id}'),
        title: title,
        body: Semantics(
          container: true,
          liveRegion: true,
          label: title,
          child: SelectableText(message),
        ),
      ),
    );
  }

  String _actionError(Object? error, {bool installation = false}) {
    return formatAgentRuntimeErrorForUser(
      error,
      english: _english,
      fallback: installation
          ? 'لم يكتمل التثبيت. تحقق من الاتصال وحاول مجدداً.'
          : 'تعذّر بدء المساعد. حاول مجدداً، أو أعد التثبيت إذا استمرت المشكلة.',
    );
  }

  Future<Object?> _openAgentConfig(
    AcpAgentProfile agent,
    OmniContainerSource source,
  ) async {
    if (_packageOperations.containsKey(agent.id)) return null;
    final extra = {omniContainerExtraKey: source};
    if (!agent.configurationAvailable) return null;
    final changed = await GoRouterManager.pushForResult<bool>(
      '/home/agent_config/${Uri.encodeComponent(agent.id)}',
      extra: extra,
    );
    if (changed == true && mounted) {
      await _load();
    }
    return changed;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: OmniRootToolbar(
        title: 'الوكيل',
        primary: true,
        showBackButton: !widget.embedded,
        actions: [
          IconButton(
            key: const Key('agent-refresh-button'),
            tooltip: 'تحديث',
            onPressed:
                _refreshing || _packageOperations.isNotEmpty
                ? null
                : () => _load(refresh: true),
            icon: _refreshing
                ? const _AgentBusyIndicator()
                : const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: OmniContentWidth(
        child: SafeArea(
          top: false,
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _openCodeAgent == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildList(),
        ),
      ),
    );
  }

  /// One section, one card: OpenCode with its status. Nothing else.
  Widget _buildList() {
    final agent = _openCodeAgent;
    return ListView(
      key: const PageStorageKey('agent-settings-list'),
      padding: edgeToEdgeScrollPadding(
        context,
        const EdgeInsets.fromLTRB(22, 20, 22, 32),
      ),
      children: [
        if (agent == null)
          OmniSettingsCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
            child: Column(
              children: [
                Icon(
                  LucideIcons.bot,
                  size: 24,
                  color: context.omniPalette.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'OpenCode غير متاح حالياً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.omniPalette.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          OmniSettingsGroup(
            title: 'الوكيل',
            translateTitle: false,
            dividerIndent: 76,
            children: [
              _buildAgentTile(agent, first: true, last: true),
            ],
          ),
      ],
    );
  }

  Widget _buildAgentTile(
    AcpAgentProfile agent, {
    required bool first,
    required bool last,
  }) {
    final palette = context.omniPalette;
    final status = _statusPresentation(
      agent.status,
      _english,
      palette.textTertiary,
    );
    final statusColor = agent.enabled ? status.color : palette.textTertiary;
    final hasError =
        (agent.lastCheckError ?? '').isNotEmpty && agent.status != 'online';
    final canTest =
        agent.enabled && (agent.status != 'missing' || agent.managedAdapter);
    final operation = _packageOperations[agent.id];
    final changingPackage = operation != null;
    final queued = AgentRuntimeService.queuedAgentIds.contains(agent.id);
    final busy = agent.id == _busyAgentId || changingPackage;
    final canUninstall =
        agent.builtIn &&
        agent.managedAdapter &&
        agent.uninstallable &&
        (agent.installed == true ||
            agent.packageVersion?.installedVersion != null);
    final testLabel = agent.managedAdapter
        ? agent.packageVersion?.updateAvailable == true
              ? 'تحديث'
              : agent.installed == true ||
                    agent.packageVersion?.installedVersion != null
              ? 'إعادة التثبيت'
              : 'تثبيت'
        : 'تحقق مجدداً';
    final action = agent.managedAdapter ? _prepare : _test;
    final needsAttention =
        agent.status != 'online' ||
        agent.packageVersion?.updateAvailable == true ||
        agent.packageVersion?.error != null;
    Widget buildTile(VoidCallback? onTap) => _AgentContactTile(
      tileKey: Key('agent-config-${agent.id}'),
      leading: AgentBrandIcon(
        agentId: agent.id,
        size: 32,
        fallbackColor: palette.accentPrimary,
      ),
      title: agent.name,
      statusColor: changingPackage ? const Color(0xFFE3A52B) : statusColor,
      statusLabel: changingPackage
          ? operation == AgentPackageOperation.uninstall
                ? queued
                      ? 'بانتظار إلغاء التثبيت'
                      : 'جارٍ إلغاء التثبيت'
                : queued
                ? 'في الانتظار'
                : 'جارٍ تثبيت OpenCode...'
          : !agent.enabled
          ? 'معطّل'
          : status.label,
      subtitle: !agent.builtIn && agent.description.isNotEmpty
          ? agent.description
          : null,
      detailText:
          agent.packageVersion?.updateAvailable == true ||
              agent.packageVersion?.error != null
          ? _versionSummary(agent)
          : null,
      detailIsError: agent.packageVersion?.error != null,
      errorText: hasError && !changingPackage
          ? _actionError(
              agent.lastCheckError,
              installation: agent.installed == false,
            )
          : null,
      actionLabel: canTest ? testLabel : null,
      actionKey: Key('agent-check-${agent.id}'),
      quietAction: !needsAttention,
      onAction: canTest ? () => action(agent) : null,
      secondaryActionLabel: canUninstall ? 'إلغاء التثبيت' : null,
      secondaryActionKey: Key('agent-uninstall-${agent.id}'),
      onSecondaryAction: canUninstall ? () => _uninstall(agent) : null,
      navigationLabel: agent.configurationAvailable ? 'إعداد' : null,
      navigationKey: Key('agent-navigation-${agent.id}'),
      busy: busy,
      onTap: onTap,
    );
    if (!agent.configurationAvailable || busy) {
      return buildTile(null);
    }
    final rowShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: first ? const Radius.circular(22) : Radius.zero,
        bottom: last ? const Radius.circular(22) : Radius.zero,
      ),
    );
    return OmniOpenContainer(
      key: ValueKey('agent-open-${agent.id}'),
      closedBuilder: (rowContext, open) => Material(
        color: rowContext.omniPalette.surfacePrimary,
        shape: rowShape,
        clipBehavior: Clip.antiAlias,
        child: buildTile(open),
      ),
      onOpen: (source) => _openAgentConfig(agent, source),
    );
  }

  String? _versionSummary(AcpAgentProfile agent) {
    if (!agent.managedAdapter ||
        (agent.status == 'missing' && agent.installed == false)) {
      return null;
    }
    final version = agent.packageVersion;
    if (version == null) return 'لم يتم التحقق من الإصدار';
    final current = version.installedVersion;
    final prefix = current == null ? '' : '$current · ';
    if (version.error != null) {
      return '$prefix${version.error == 'local_probe_failed' ? 'تعذّر قراءة الإصدار المثبّت' : 'فشل التحقق من التحديثات؛ حاول مجدداً'}';
    }
    if (version.updateAvailable) {
      return '$prefix${'يتوفر تحديث'} ${version.targetVersion}';
    }
    if (version.pinned) {
      final upstream = version.latestVersion;
      return '$prefix${'الإصدار مدار من التطبيق'}'
          '${upstream != null && upstream != current ? '\n${'إصدار المصدر'} $upstream' : ''}';
    }
    if (current == null) {
      return version.latestVersion == null
          ? null
          : '${'الأحدث'} ${version.latestVersion}';
    }
    return version.checkedAt == null
        ? current
        : '$current · ${'لا توجد تحديثات'}';
  }
}

/// The single OpenCode row. Healthy rows keep maintenance quiet; attention
/// states retain explicit actions.
class _AgentContactTile extends StatelessWidget {
  const _AgentContactTile({
    required this.leading,
    required this.title,
    required this.onTap,
    this.tileKey,
    this.statusColor,
    this.statusLabel,
    this.subtitle,
    this.errorText,
    this.detailText,
    this.detailIsError = false,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    this.quietAction = false,
    this.secondaryActionLabel,
    this.secondaryActionKey,
    this.onSecondaryAction,
    this.navigationLabel,
    this.navigationKey,
    this.busy = false,
  });

  final Widget leading;
  final String title;
  final VoidCallback? onTap;
  final Key? tileKey;
  final Color? statusColor;
  final String? statusLabel;
  final String? subtitle;
  final String? errorText;
  final String? detailText;
  final bool detailIsError;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;
  final bool quietAction;
  final String? secondaryActionLabel;
  final Key? secondaryActionKey;
  final VoidCallback? onSecondaryAction;
  final String? navigationLabel;
  final Key? navigationKey;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final showAction = actionLabel != null && onAction != null;
    final showSecondaryAction = secondaryActionLabel != null && !busy;
    final details = <Widget>[
      if ((subtitle ?? '').isNotEmpty)
        Text(
          subtitle!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: palette.textSecondary,
          ),
        ),
      if ((detailText ?? '').isNotEmpty)
        Text(
          detailText!,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: detailIsError
                ? Theme.of(context).colorScheme.error
                : palette.textSecondary,
          ),
        ),
      if ((errorText ?? '').isNotEmpty)
        Text(
          errorText!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
    ];
    final maintenanceActions = <Widget>[
      if (!quietAction && showAction && !busy)
        _actionButton(
          key: actionKey,
          label: actionLabel!,
          color: palette.accentPrimary,
          onPressed: onAction,
        ),
      if (showSecondaryAction)
        _actionButton(
          key: secondaryActionKey,
          label: secondaryActionLabel!,
          color: Theme.of(context).colorScheme.error,
          onPressed: onSecondaryAction,
        ),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tileKey,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use the row's available space, including when this page is in a
            // split window. Larger text keeps maintenance on its own line.
            final inlineActions =
                constraints.maxWidth >= OmniLayoutBreakpoints.medium &&
                MediaQuery.textScalerOf(context).scale(15) <= 19.5;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        key: ValueKey('agent-avatar-$title'),
                        width: 44,
                        height: 44,
                        child: Center(child: leading),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: palette.textPrimary,
                                height: 1.38,
                              ),
                            ),
                            if (statusLabel != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      statusLabel!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.45,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (inlineActions && details.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ...details,
                            ],
                          ],
                        ),
                      ),
                      if (inlineActions && maintenanceActions.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              var index = 0;
                              index < maintenanceActions.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 8),
                              maintenanceActions[index],
                            ],
                          ],
                        ),
                      ],
                      if (busy) ...[
                        const SizedBox(width: 10),
                        const SizedBox.square(
                          dimension: 48,
                          child: Center(child: _AgentBusyIndicator()),
                        ),
                      ] else if (quietAction && showAction)
                        OmniCircleButton(
                          key: actionKey,
                          tooltip: actionLabel!,
                          onPressed: onAction,
                          icon: LucideIcons.rotateCw,
                          size: 40,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          foregroundColor: palette.textTertiary,
                        ),
                      if (navigationLabel != null)
                        IconButton(
                          key: navigationKey,
                          onPressed: onTap,
                          tooltip: navigationLabel,
                          icon: const Icon(LucideIcons.chevronRight, size: 18),
                          style: IconButton.styleFrom(
                            foregroundColor: palette.textTertiary,
                            minimumSize: const Size.square(48),
                            visualDensity: VisualDensity.standard,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                        ),
                    ],
                  ),
                  if (!inlineActions &&
                      (details.isNotEmpty || maintenanceActions.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(left: 58, top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...details,
                          if (maintenanceActions.isNotEmpty)
                            Wrap(
                              spacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: maintenanceActions,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Key? key,
    required Color color,
    required VoidCallback? onPressed,
  }) => TextButton(
    key: key,
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(48, 48),
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
    ),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

class _AgentBusyIndicator extends StatelessWidget {
  const _AgentBusyIndicator();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

({String label, Color color}) _statusPresentation(
  String status,
  bool english,
  Color inactiveColor,
) {
  return switch (status) {
    'online' => (
      label:'جاهز',
      color: const Color(0xFF2EAF67),
    ),
    'missing' => (
      label:'غير مثبّت',
      color: inactiveColor,
    ),
    'offline' => (
      label:'تعذّر البدء',
      color: const Color(0xFFE05252),
    ),
    _ => (label:'لم يتم التحقق', color: const Color(0xFFE3A52B)),
  };
}
