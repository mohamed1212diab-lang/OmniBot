import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/core/router/go_router_manager.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/omni_circle_button.dart';

import 'na_composio_settings.dart';
import 'na_connector_grants.dart';
import 'na_composio_catalog.dart';
import 'na_composio_events.dart';
import 'na_notification_settings.dart';
import 'na_connector_result.dart';
import 'na_routine_editor.dart';

import 'package:ui/widgets/navigation/page_route.dart';

import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/widgets/omni_glass.dart';
import 'package:ui/widgets/omni_segmented_slider.dart';
import 'package:ui/widgets/settings_ui.dart';

/// Client views of the existing Na service. Chat/session/turn ownership stays
/// with the shared Agent runtime; this page never starts another Agent loop.
class NaPersonalPage extends StatefulWidget {
  const NaPersonalPage({super.key});

  @override
  State<NaPersonalPage> createState() => _NaPersonalPageState();
}

class _NaPersonalPageState extends State<NaPersonalPage>
    with WidgetsBindingObserver {
  static const _labels = ['البريد الوارد', 'التطبيقات المتصلة', 'الذاكرة', 'المهام', 'البيانات'];
  String? _owner;
  String? _dataOwner;
  Set<String> _capabilities = {};
  Map<String, dynamic> _data = {};
  int _tab = 0, _revision = 0;
  bool _loading = true, _busy = false;
  bool _connectionConfigurationAvailable = false;
  bool _openingConnection = false, _openingCatalog = false;
  String? _error;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    unawaited(_loadConnectionAccess());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_busy &&
        !_openingConnection &&
        !_openingCatalog) {
      unawaited(_load());
    }
  }

  // The catalog is native/local policy and remains readable without a working
  // cloud connection. It does not return a development access token.
  Future<void> _loadConnectionAccess() async {
    try {
      final catalog = await AgentRuntimeService.listAgents();
      final available = catalog.agents.any(
        (agent) => agent.id == 'na-cloud' && agent.configurationAvailable,
      );
      if (mounted) {
        setState(() => _connectionConfigurationAvailable = available);
      }
    } catch (_) {
      if (mounted) setState(() => _connectionConfigurationAvailable = false);
    }
  }

  Future<void> _openConnection() async {
    if (!_connectionConfigurationAvailable || _openingConnection || _busy) {
      return;
    }
    ++_revision;
    setState(() {
      _openingConnection = true;
      _owner = null;
      _dataOwner = null;
      _data = {};
      _error = null;
    });
    try {
      await GoRouterManager.pushForResult<Object?>('/home/na/connection');
    } finally {
      if (mounted) {
        setState(() => _openingConnection = false);
        await _loadConnectionAccess();
        if (mounted) await _load(reconnect: true);
      }
    }
  }

  bool get _disabled =>
      _loading ||
      _busy ||
      _openingConnection ||
      _error != null ||
      _owner == null ||
      _dataOwner != _owner;
  Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.map((key, value) => MapEntry(key.toString(), value))
      : {};
  List<Map<String, dynamic>> _list(dynamic value) =>
      value is List ? value.whereType<Map>().map(_map).toList() : [];
  String _json(dynamic value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  Future<Map<String, dynamic>> _request(
    String operation, {
    String? id,
    Map<String, dynamic> payload = const {},
  }) async {
    final capturedOwner = _owner;
    final capturedRevision = _revision;
    final response = await AgentRuntimeService.requestNaPersonal(
      operation: operation,
      owner: capturedOwner,
      id: id,
      payload: payload,
    );
    if (capturedRevision != _revision) {
      throw StateError('انتهت صلاحية طلب صفحة Na.');
    }
    if (capturedOwner != null && response.owner != capturedOwner) {
      throw StateError('تغيّر اتصال Na، يُرجى إعادة تحميل الاتصال.');
    }
    if (!mounted) return {};
    if (_owner != capturedOwner) throw StateError('تغيّر اتصال صفحة Na.');
    _owner = response.owner;
    return response.data;
  }

  Future<void> _load({bool reconnect = false}) async {
    final revision = ++_revision;
    if (reconnect) {
      _owner = null;
      _dataOwner = null;
      _data = {};
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _request('status');
      if (!mounted || revision != _revision) return;
      _capabilities = (status['capabilities'] as List? ?? [])
          .whereType<String>()
          .toSet();
      if (!_capabilities.contains('profile')) {
        throw StateError('لا توفّر خدمة Na هذه إدارة المساعد الشخصي بعد، يُرجى ترقية خدمة التطوير.');
      }
      final tab = _tab;
      Map<String, dynamic> data;
      switch (tab) {
        case 0:
          final result = await Future.wait([
            _request('notifications.list'),
            _request('actions.list'),
          ]);
          data = {...result[0], ...result[1]};
        case 1:
          final settingsResponse = await _request('composio.settings.read');
          final settings = _map(settingsResponse['settings']);
          Map<String, dynamic> inventory = {};
          String? inventoryError;
          try {
            inventory = await _request('composio.read');
          } catch (_) {
            // Recheck the Na owner separately: provider/key trouble should not
            // hide the very settings needed to repair that connection.
            await _request('status');
            inventoryError = 'قائمة الحسابات غير متاحة مؤقتًا، تحقق من المفتاح أو الشبكة ثم حدِّث.';
          }
          data = {
            'composio': inventory,
            'composioSettings': settings,
            'inventoryError': ?inventoryError,
          };
        case 2:
          data =
              _search.text.trim().isNotEmpty &&
                  _capabilities.contains('memory_search')
              ? await _request(
                  'memories.search',
                  payload: {'query': _search.text.trim(), 'limit': 20},
                )
              : await _request('memories.list');
        case 3:
          final result = await Future.wait([
            _request('scenarios.list'),
            _request('routines.list'),
          ]);
          data = {...result[0], ...result[1]};
        default:
          data = await _request('profile.read');
      }
      if (mounted && revision == _revision) {
        setState(() {
          _data = data;
          _dataOwner = _owner;
        });
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _error = _message(error);
          _data = {};
          _dataOwner = null;
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  String _message(Object error) {
    if (error is StateError) return error.message.toString();
    // This page calls only the bounded native Na bridge, whose public errors
    // already remove credentials and access-bearing URLs.
    if (error is PlatformException &&
        error.code == 'AGENT_RUNTIME_CALL_FAILED' &&
        error.message?.trim().isNotEmpty == true) {
      return error.message!.trim();
    }
    return formatAgentRuntimeErrorForUser(error, fallback: 'لم يكتمل الإجراء، حدِّث الحالة ثم أعد المحاولة.');
  }

  Future<void> _mutate(
    String operation, {
    String? id,
    Map<String, dynamic> payload = const {},
  }) async {
    if (_disabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _request(operation, id: id, payload: payload);
      if (!mounted) return;
      final action = _map(result['action']);
      final message =
          result['warning']?.toString() ??
          (action['status'] == 'unknown' ? 'نتيجة الإجراء بانتظار التحقق، تحقق في التطبيق المعني أولًا ولا تكرر التنفيذ.' : 'تم التحديث.');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    Widget content, {
    String confirm = 'تأكيد',
  }) async {
    final displayedOwner = _dataOwner;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            scrollable: true,
            content: content,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirm),
              ),
            ],
          ),
        ) ==
        true;
    if (!mounted) return false;
    if (confirmed &&
        (displayedOwner == null ||
            displayedOwner != _owner ||
            displayedOwner != _dataOwner)) {
      setState(() => _error = 'تغيّر اتصال Na، أعد التحميل ثم راجع.');
      return false;
    }
    return confirmed;
  }

  Future<Map<String, String>?> _edit(
    String title,
    List<({String key, String label, String value, int lines})> fields,
  ) async {
    final displayedOwner = _dataOwner;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _NaPersonalEditDialog(title: title, fields: fields),
    );
    if (!mounted) return null;
    if (result != null &&
        (displayedOwner == null ||
            displayedOwner != _owner ||
            displayedOwner != _dataOwner)) {
      setState(() => _error = 'تغيّر اتصال Na، أعد التحميل ثم عدِّل.');
      return null;
    }
    return result;
  }

  Future<void> _openEvents() async {
    if (_disabled || _openingCatalog) return;
    setState(() => _openingCatalog = true);
    try {
      await Navigator.of(context).push<void>(
        OmniPageRoute<void>(
          builder: (_) =>
              NaComposioEventsPage(request: _request, ownerKey: _owner),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingCatalog = false);
        await _load();
      }
    }
  }

  Future<void> _openCatalog() async {
    if (_disabled || _openingCatalog) return;
    setState(() => _openingCatalog = true);
    try {
      await Navigator.of(context).push<void>(
        OmniPageRoute<void>(
          builder: (_) => NaComposioCatalogPage(
            request: (operation, payload) =>
                _request(operation, payload: payload),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingCatalog = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.omniPalette.pageBackground,
    appBar: CommonAppBar(
      titleWidget: _connectionConfigurationAvailable
          ? TextButton(
              key: const Key('na-connection-title'),
              onPressed: _openingConnection || _busy ? null : _openConnection,
              style: TextButton.styleFrom(
                foregroundColor: context.omniPalette.textPrimary,
              ),
              child: const Text(
                'Na',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            )
          : const Text(
              'Na',
              key: Key('na-personal-title'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
      primary: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: OmniCircleButton(
            key: const Key('na-personal-refresh'),
            tooltip: 'تحديث',
            onPressed: _loading || _busy ? null : () => _load(),
            icon: LucideIcons.refreshCw,
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: OmniContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: OmniSegmentedSlider<int>(
                keyPrefix: 'na-personal-tab',
                value: _tab,
                options: [
                  for (var index = 0; index < _labels.length; index++)
                    OmniSegmentedOption(
                      value: index,
                      label: _labels[index],
                      id: '$index',
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (index) {
                        if (index == _tab) return;
                        setState(() {
                          _tab = index;
                          _data = {};
                        });
                        unawaited(_load());
                      },
              ),
            ),
            if (_loading || _busy) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _load(reconnect: true),
                      child: const Text('إعادة تحميل الاتصال'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _busy ? () async {} : _load,
                child: ListView(
                  key: ValueKey(_tab),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: switch (_tab) {
                    0 => _inbox(),
                    1 => _connections(),
                    2 => _memories(),
                    3 => _responsibilities(),
                    _ => _profile(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _heading(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
  Widget _note(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(
        color: color ?? context.omniPalette.textSecondary,
        height: 1.5,
      ),
    ),
  );
  Widget _record(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: OmniGlassCard(child: child),
  );
  Widget _details(String label, dynamic value) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    title: Text(label),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          _json(value),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
    ],
  );

  List<Widget> _inbox() {
    final notices = _list(_data['notifications']),
        actions = _list(_data['actions']);
    return [
      NaNotificationSettings(disabled: _busy || _openingConnection),
      const SizedBox(height: 12),
      _heading(
        'بانتظار تأكيدك',
        trailing: TextButton(
          onPressed: _disabled ? null : () => _mutate('notifications.readAll'),
          child: const Text('تعليم الكل كمقروء'),
        ),
      ),
      if (actions.isEmpty && !_loading) _note('لا توجد إجراءات بانتظار التأكيد'),
      for (final action in actions) _actionCard(action),
      _heading('رسائل المتابعة'),
      if (notices.isEmpty && !_loading) _note('لا توجد رسائل متابعة'),
      for (final notice in notices)
        _record(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notice['title']?.toString() ?? 'رسائل المتابعة',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SelectableText(notice['body']?.toString() ?? ''),
              _note(
                notice['deliveredAt'] == null
                    ? 'بانتظار وقت التذكير'
                    : notice['createdAt']?.toString() ?? '',
              ),
              if (notice['readAt'] == null)
                TextButton(
                  onPressed: _disabled
                      ? null
                      : () => _mutate(
                          'notifications.read',
                          id: notice['id'].toString(),
                          payload: {'read': true},
                        ),
                  child: const Text('تعليم كمقروء'),
                ),
            ],
          ),
        ),
    ];
  }

  static const _actionStatusLabels = {
    'pending': 'بانتظار التأكيد',
    'executing': 'قيد التنفيذ',
    'completed': 'مكتمل',
    'unknown': 'النتيجة بانتظار التحقق',
    'failed': 'فشل التنفيذ',
    'rejected': 'مرفوض',
  };

  Color _actionStatusColor(String status) {
    final palette = context.omniPalette;
    return switch (status) {
      'pending' || 'executing' || 'unknown' => palette.accentPrimary,
      'failed' || 'rejected' => Theme.of(context).colorScheme.error,
      _ => palette.textTertiary,
    };
  }

  Widget _actionCard(Map<String, dynamic> action) {
    final account = _map(action['account']),
        connector = _map(action['connector']);
    final status = action['status']?.toString() ?? '';
    final accountId = account['id']?.toString();
    var accountLabel = '—';
    for (final candidate in [account['label'], account['email'], account['alias']]) {
      final text = candidate?.toString();
      if (text != null && text.isNotEmpty && text != accountId) {
        accountLabel = text;
        break;
      }
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (accountLabel != '—') Text('حساب التنفيذ: $accountLabel'),
        if (account['id'] != null) SelectableText(account['id'].toString()),
        const SizedBox(height: 12),
        SelectableText(_json(action['args'] ?? {})),
      ],
    );
    return _record(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  action['summary']?.toString() ??
                      action['operation']?.toString() ??
                      '',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              OmniSettingsStatusBadge(
                label: _actionStatusLabels[status] ?? status,
                color: _actionStatusColor(status),
              ),
            ],
          ),
          if (accountLabel != '—') _note('حساب التنفيذ: $accountLabel'),
          _details('التفاصيل', {
            'operation': action['operation'],
            if (account['id'] != null) 'accountId': account['id'],
            if (connector['version'] != null) 'version': connector['version'],
            'args': action['args'] ?? {},
          }),
          if (action['result'] != null) _details('نتيجة التنفيذ', action['result']),
          if (_map(_map(action['result'])['overflow']).isNotEmpty)
            NaConnectorResultViewer(
              overflow: _map(_map(action['result'])['overflow']),
              readPage: (id, payload) =>
                  _request('connectors.resultPage', id: id, payload: payload),
            ),
          if (_capabilities.contains('connector_grants'))
            NaRepeatGrantButton(
              action: action,
              request: _request,
              onChanged: _load,
              disabled: _busy,
              ownerKey: _owner,
            ),
          if (action['error'] != null)
            _note(
              action['error'].toString(),
              color: Theme.of(context).colorScheme.error,
            ),
          if (action['unavailableReason'] != null)
            _note(action['unavailableReason'].toString()),
          if (status == 'pending')
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: _disabled || action['unavailableReason'] != null
                      ? null
                      : () async {
                          if (await _confirm(
                                'تأكيد تنفيذ هذا الإجراء مرة واحدة',
                                content,
                                confirm: 'تأكيد التنفيذ',
                              ) &&
                              mounted) {
                            await _mutate(
                              'actions.approve',
                              id: action['id'].toString(),
                            );
                          }
                        },
                  child: const Text('مراجعة وتنفيذ'),
                ),
                TextButton(
                  onPressed: _disabled
                      ? null
                      : () => _mutate(
                          'actions.reject',
                          id: action['id'].toString(),
                        ),
                  child: const Text('رفض'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _saveComposioSettings(
    Map<String, dynamic> payload,
  ) async {
    if (_disabled) return null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _request(
        'composio.settings.update',
        payload: payload,
      );
      final saved = _map(response['settings']);
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
      await _load();
      return saved;
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _connectionStatusLabels = {
    'ACTIVE': 'متصل',
    'DISABLED': 'معطّل',
    'EXPIRED': 'انتهت صلاحية التفويض',
    'INITIATED': 'بانتظار التفويض',
    'INITIALIZING': 'جارٍ تجهيز التفويض',
    'FAILED': 'فشل الاتصال',
    'REVOKED': 'أُلغي التفويض',
  };

  String _connectionStatus(dynamic status) =>
      _connectionStatusLabels[status] ?? status?.toString() ?? 'حالة غير معروفة';

  Color _connectionStatusColor(dynamic status) {
    final palette = context.omniPalette;
    return switch (status) {
      'ACTIVE' || 'INITIATED' || 'INITIALIZING' => palette.accentPrimary,
      'EXPIRED' || 'FAILED' || 'REVOKED' => Theme.of(context).colorScheme.error,
      _ => palette.textTertiary,
    };
  }

  // Providers may surface the raw account id as the label/alias; a name that
  // is just the id is not user-facing, so fall back to the app (toolkit) name.
  String _accountTitle(Map<String, dynamic> account) {
    final id = account['id']?.toString();
    for (final candidate in [account['label'], account['alias']]) {
      final text = candidate?.toString();
      if (text != null && text.isNotEmpty && text != id) return text;
    }
    final toolkit = account['toolkit']?.toString();
    if (toolkit != null && toolkit.isNotEmpty) return toolkit;
    return 'الحسابات المتصلة';
  }

  List<Widget> _connections() {
    final composio = _map(_data['composio']);
    final settings = _map(_data['composioSettings']);
    final accounts = _list(composio['accounts']);
    return [
      _heading(
        'اتصال التطبيقات',
        trailing: TextButton.icon(
          key: const Key('na-composio-browse'),
          onPressed: _disabled || _openingCatalog ? null : _openCatalog,
          icon: const Icon(LucideIcons.layoutGrid, size: 16),
          label: const Text('تصفح كل التطبيقات'),
        ),
      ),
      if (_capabilities.contains('composio_events'))
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('na-composio-events'),
            onPressed: _disabled || _openingCatalog ? null : _openEvents,
            icon: const Icon(LucideIcons.zap, size: 16),
            label: const Text('إدارة أحداث التطبيقات'),
          ),
        ),
      if (_data['inventoryError'] != null)
        _note(_data['inventoryError'].toString()),
      if (settings.isNotEmpty)
        NaComposioSettings(
          key: ValueKey('composio-settings-$_dataOwner'),
          settings: settings,
          busy: _disabled,
          onSave: _saveComposioSettings,
        ),
      if (composio['configured'] != true)
        _note(
          settings['enabled'] == false ? 'خدمة الاتصال مغلقة، يمكنك تشغيلها من الأعلى.' : 'احفظ مفتاح المشروع أولًا.',
        )
      else ...[
        for (final account in accounts)
          _record(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _accountTitle(account),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    OmniSettingsStatusBadge(
                      label: _connectionStatus(account['status']),
                      color: _connectionStatusColor(account['status']),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _disabled
                      ? null
                      : () async {
                          if (await _confirm(
                                'فصل هذا الحساب',
                                Text(
                                  '${_accountTitle(account)}\n${account['id']}',
                                ),
                              ) &&
                              mounted) {
                            await _mutate(
                              'composio.disconnect',
                              payload: {
                                'toolkit': account['toolkit'],
                                'accountId': account['id'],
                              },
                            );
                          }
                        },
                  child: const Text('فصل هذا الحساب'),
                ),
              ],
            ),
          ),
        if (accounts.isEmpty) _note('لا توجد حسابات متصلة بعد'),
      ],
    ];
  }

  Future<void> _editMemory([Map<String, dynamic>? memory]) async {
    final result = await _edit(memory == null ? 'ذكرى جديدة' : 'تعديل الذكرى', [
      (
        key: 'key',
        label: 'الاسم',
        value: memory?['key']?.toString() ?? '',
        lines: 1,
      ),
      (
        key: 'value',
        label: 'محتوى الذكرى',
        value: memory?['value']?.toString() ?? '',
        lines: 3,
      ),
    ]);
    if (result != null && mounted) {
      await _mutate(
        memory == null ? 'memories.save' : 'memories.update',
        id: memory?['id']?.toString(),
        payload: result,
      );
    }
  }

  List<Widget> _memories() => [
    _heading(
      'الذاكرة طويلة المدى',
      trailing: TextButton.icon(
        onPressed: _disabled ? null : _editMemory,
        icon: const Icon(LucideIcons.plus, size: 16),
        label: const Text('إضافة'),
      ),
    ),
    OmniSettingsSearchField(
      key: const Key('na-memory-search'),
      controller: _search,
      hintText: 'ابحث في الذاكرة',
      onChanged: _disabled
          ? null
          : (text) {
              if (text.isEmpty) unawaited(_load());
            },
      onSubmitted: _disabled ? null : (_) => _load(),
    ),
    const SizedBox(height: 16),
    if (_list(_data['memories']).isEmpty && !_loading) _note('لا توجد ذكريات مطابقة'),
    for (final memory in _list(_data['memories']))
      _record(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memory['key'].toString(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SelectableText(memory['value'].toString()),
            if (memory['truncated'] == true) _note('المحتوى طويل وتم اقتطاعه، امسح كلمة البحث لعرض النص كاملًا'),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: _disabled || memory['truncated'] == true
                      ? null
                      : () => _editMemory(memory),
                  child: const Text('تعديل'),
                ),
                TextButton(
                  onPressed: _disabled
                      ? null
                      : () async {
                          if (await _confirm(
                                'نسيان هذه الذكرى',
                                Text(memory['key'].toString()),
                              ) &&
                              mounted) {
                            await _mutate(
                              'memories.delete',
                              id: memory['id'].toString(),
                            );
                          }
                        },
                  child: const Text('نسيان'),
                ),
              ],
            ),
          ],
        ),
      ),
  ];

  List<Widget> _responsibilities() => [
    if (_capabilities.contains('connector_grants'))
      NaConnectorGrantList(
        request: _request,
        disabled: _busy,
        ownerKey: _owner,
      ),
    _heading('سيناريوهات المتابعة النشطة'),
    for (final scenario in _list(_data['scenarios']))
      _record(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scenario['title'].toString(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _note(scenario['description']?.toString() ?? ''),
            if (scenario['available'] != true)
              _note(
                scenario['unavailableReason']?.toString() ?? 'أكمل البيانات المطلوبة واتصال التطبيقات أولًا.',
              ),
            FilledButton(
              onPressed:
                  _disabled ||
                      scenario['available'] != true ||
                      scenario['enabled'] == true
                  ? null
                  : () => _mutate(
                      'scenarios.activate',
                      id: scenario['id'].toString(),
                    ),
              child: Text(scenario['enabled'] == true ? 'مفعّلة' : 'تفعيل هذه المهمة'),
            ),
          ],
        ),
      ),
    _heading(
      'المهام المستمرة',
      trailing: TextButton.icon(
        onPressed: _disabled ? null : () => _editRoutine(),
        icon: const Icon(LucideIcons.plus, size: 16),
        label: const Text('إضافة'),
      ),
    ),
    for (final routine in _list(_data['routines']))
      _record(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmniSettingsTile(
              padding: EdgeInsets.zero,
              title: routine['title'].toString(),
              translateText: false,
              trailing: OmniSettingsSwitch(
                value: routine['enabled'] == true,
                enabled: !_disabled,
                onToggle: (enabled) => _mutate(
                  'routines.update',
                  id: routine['id'].toString(),
                  payload: {'enabled': enabled},
                ),
              ),
            ),
            _note(routine['prompt']?.toString() ?? ''),
            Text(naRoutineStatus(routine)),
            Text(
              'التنفيذ التالي: ${routine['nextRunAt'] ?? (routine['trigger'] == 'event' ? 'بانتظار حدث من التطبيق' : '—')}',
            ),
            if (routine['lastCheckFailureCause'] != null)
              _note(
                'فشل الفحص الأخير: ${routine['lastCheckFailureCause']}',
                color: Theme.of(context).colorScheme.error,
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _disabled
                      ? null
                      : () => _mutate(
                          'routines.run',
                          id: routine['id'].toString(),
                        ),
                  child: const Text('فحص مرة واحدة'),
                ),
                TextButton(
                  onPressed: _disabled ? null : () => _editRoutine(routine),
                  child: const Text('تعديل'),
                ),
                TextButton(
                  onPressed: _disabled
                      ? null
                      : () async {
                          if (await _confirm(
                                'حذف المهمة',
                                Text(routine['title'].toString()),
                              ) &&
                              mounted) {
                            await _mutate(
                              'routines.delete',
                              id: routine['id'].toString(),
                            );
                          }
                        },
                  child: const Text('حذف'),
                ),
              ],
            ),
          ],
        ),
      ),
    if (_list(_data['routines']).isEmpty && !_loading) _note('لا توجد مهام مستمرة بعد'),
  ];

  Future<void> _editRoutine([Map<String, dynamic>? routine]) async {
    final owner = _owner, revision = _revision;
    try {
      final profile = await _request('profile.read');
      if (!mounted || owner != _owner || revision != _revision) return;
      final user = _map(_map(profile['profile'])['user']);
      final timezone = user['timezone']?.toString();
      if (timezone == null || timezone.isEmpty) {
        throw StateError('حدّد المنطقة الزمنية المجدولة في البيانات أولًا.');
      }
      final result = await showNaRoutineEditor(
        context,
        routine: routine,
        timezone: timezone,
        isCurrent: () => mounted && owner == _owner && revision == _revision,
      );
      if (result == null ||
          !mounted ||
          owner != _owner ||
          revision != _revision) {
        return;
      }
      await _mutate(
        routine == null ? 'routines.create' : 'routines.update',
        id: routine?['id']?.toString(),
        payload: result,
      );
    } catch (error) {
      if (mounted && owner == _owner && revision == _revision) {
        setState(
          () => _error = error is PlatformException
              ? (error.message ?? 'تعذّر فتح محرر المهمة، أعد المحاولة.')
              : error.toString(),
        );
      }
    }
  }

  List<Widget> _profile() {
    final profile = _map(_data['profile']),
        user = _map(profile['user']),
        agent = _map(profile['agent']),
        proactivity = _map(profile['proactivity']);
    return [
      _heading(
        'أنت وNa',
        trailing: TextButton(
          onPressed: _disabled ? null : () => _editProfile(profile),
          child: const Text('تعديل البيانات'),
        ),
      ),
      _record(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['name']?.toString().isNotEmpty == true
                  ? user['name'].toString()
                  : 'بياناتك',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _note('المنطقة الزمنية: ${user['timezone'] ?? '—'}'),
            _note(user['about']?.toString() ?? ''),
            _note(user['goals']?.toString() ?? ''),
            const Divider(),
            Text('${agent['name'] ?? 'Na'} · ${agent['role'] ?? 'مساعد شخصي'}'),
            _note(agent['tone']?.toString() ?? ''),
            _note(agent['instructions']?.toString() ?? ''),
          ],
        ),
      ),
      _heading('التذكيرات النشطة'),
      OmniSettingsTile(
        padding: EdgeInsets.zero,
        title: 'السماح بالمتابعة النشطة',
        subtitle: 'عند الإغلاق، تتوقف الفحوصات التلقائية وتسليم التذكيرات.',
        translateText: false,
        trailing: OmniSettingsSwitch(
          value: proactivity['enabled'] == true,
          enabled: !_disabled,
          onToggle: (value) => _mutate(
            'profile.update',
            payload: {
              'proactivity': {'enabled': value},
            },
          ),
        ),
      ),
      _note(
        'فترة الهدوء ${proactivity['quietStart'] ?? '—'}–${proactivity['quietEnd'] ?? '—'} · الحد الأدنى للفاصل بين التذكيرات ${proactivity['minIntervalMinutes'] ?? '—'} دقيقة',
      ),
      TextButton(
        onPressed: _disabled
            ? null
            : () async {
                final result = await _edit('أوقات التذكير', [
                  (
                    key: 'quietStart',
                    label: 'بداية الهدوء (HH:mm)',
                    value: proactivity['quietStart']?.toString() ?? '22:00',
                    lines: 1,
                  ),
                  (
                    key: 'quietEnd',
                    label: 'نهاية الهدوء (HH:mm)',
                    value: proactivity['quietEnd']?.toString() ?? '08:00',
                    lines: 1,
                  ),
                  (
                    key: 'minIntervalMinutes',
                    label: 'الحد الأدنى للفاصل بين التذكيرات (بالدقائق)',
                    value:
                        proactivity['minIntervalMinutes']?.toString() ?? '15',
                    lines: 1,
                  ),
                ]);
                if (result != null && mounted) {
                  final minutes = num.tryParse(result['minIntervalMinutes']!);
                  if (minutes == null) {
                    setState(() => _error = 'يجب أن يكون فاصل التذكير رقمًا.');
                    return;
                  }
                  await _mutate(
                    'profile.update',
                    payload: {
                      'proactivity': {...result, 'minIntervalMinutes': minutes},
                    },
                  );
                }
              },
        child: const Text('ضبط أوقات التذكير'),
      ),
    ];
  }

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    final user = _map(profile['user']), agent = _map(profile['agent']);
    final result = await _edit('تعديل بيانات المساعد الشخصي', [
      for (final field in [
        ('name', 'اسمك'),
        ('timezone', 'المنطقة الزمنية (مثل Asia/Shanghai)'),
        ('locale', 'اللغة'),
        ('about', 'نبذة عنك'),
        ('goals', 'الأهداف الحالية'),
      ])
        (
          key: 'user.${field.$1}',
          label: field.$2,
          value: user[field.$1]?.toString() ?? '',
          lines: field.$1 == 'about' || field.$1 == 'goals' ? 3 : 1,
        ),
      for (final field in [
        ('name', 'اسم المساعد'),
        ('role', 'مهام المساعد'),
        ('tone', 'أسلوب التواصل'),
        ('instructions', 'التفضيلات'),
      ])
        (
          key: 'agent.${field.$1}',
          label: field.$2,
          value: agent[field.$1]?.toString() ?? '',
          lines: field.$1 == 'instructions' ? 3 : 1,
        ),
    ]);
    if (result != null && mounted) {
      await _mutate(
        'profile.update',
        payload: {
          'user': {
            for (final entry in result.entries.where(
              (entry) => entry.key.startsWith('user.'),
            ))
              entry.key.substring(5): entry.value,
          },
          'agent': {
            for (final entry in result.entries.where(
              (entry) => entry.key.startsWith('agent.'),
            ))
              entry.key.substring(6): entry.value,
          },
        },
      );
    }
  }
}

class _NaPersonalEditDialog extends StatefulWidget {
  const _NaPersonalEditDialog({required this.title, required this.fields});
  final String title;
  final List<({String key, String label, String value, int lines})> fields;
  @override
  State<_NaPersonalEditDialog> createState() => _NaPersonalEditDialogState();
}

class _NaPersonalEditDialogState extends State<_NaPersonalEditDialog> {
  late final Map<String, TextEditingController> _controllers;
  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        field.key: TextEditingController(text: field.value),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _controllers[field.key],
                minLines: field.lines,
                maxLines: field.lines + 3,
                maxLength: field.key == 'value'
                    ? 8000
                    : field.key == 'prompt'
                    ? 16000
                    : 4000,
                decoration: InputDecoration(
                  labelText: field.label,
                  counterText: '',
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          for (final field in widget.fields)
            field.key: _controllers[field.key]!.text.trim(),
        }),
        child: const Text('حفظ'),
      ),
    ],
  );
}
