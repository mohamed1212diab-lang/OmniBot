import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/widgets/omni_circle_button.dart';

typedef NaComposioEventsRequest = Future<Map<String, dynamic>> Function(
  String operation, {
  String? id,
  Map<String, dynamic> payload,
});

/// Server resource management only. The supplied callback owns the Na identity.
class NaComposioEventsPage extends StatefulWidget {
  const NaComposioEventsPage({super.key, required this.request, this.ownerKey});
  final NaComposioEventsRequest request;
  final Object? ownerKey;

  @override
  State<NaComposioEventsPage> createState() => _NaComposioEventsPageState();
}

class _NaComposioEventsPageState extends State<NaComposioEventsPage> {
  final _url = TextEditingController(), _secret = TextEditingController();
  final _config = TextEditingController(text: '{}');
  Map<String, dynamic> _settings = {}, _definition = {};
  List<Map<String, dynamic>> _triggers = [],
      _accounts = [],
      _routines = [],
      _types = [];
  List<String> _toolkits = [];
  String? _toolkit, _account, _routine, _cursor, _error, _resourceWarning;
  bool _enabled = false,
      _clearSecret = false,
      _loading = true,
      _busy = false,
      _ready = false,
      _catalogLoading = false,
      _confirming = false;
  int _generation = 0,
      _catalogGeneration = 0,
      _definitionGeneration = 0,
      _mutationGeneration = 0;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? value.map((k, v) => MapEntry(k.toString(), v)) : {};
  List<Map<String, dynamic>> _list(dynamic value) =>
      value is List ? value.whereType<Map>().map(_map).toList() : [];
  String _json(dynamic value) =>
      const JsonEncoder.withIndent('  ').convert(value);
  bool get _disabled => !_ready || _loading || _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant NaComposioEventsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerKey != widget.ownerKey ||
        oldWidget.request != widget.request) {
      ++_generation;
      ++_catalogGeneration;
      ++_definitionGeneration;
      ++_mutationGeneration;
      _secret.clear();
      _url.clear();
      _config.text = '{}';
      _definition = {};
      _types = [];
      _accounts = [];
      _routines = [];
      _triggers = [];
      _settings = {};
      _account = null;
      _routine = null;
      _toolkit = null;
      _cursor = null;
      _busy = false;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    ++_generation;
    ++_catalogGeneration;
    ++_definitionGeneration;
    ++_mutationGeneration;
    _url.dispose();
    _secret.dispose();
    _config.dispose();
    super.dispose();
  }

  String _message(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is PlatformException &&
        error.code == 'AGENT_RUNTIME_CALL_FAILED' &&
        error.message?.trim().isNotEmpty == true) {
      return error.message!.trim();
    }
    return formatAgentRuntimeErrorForUser(error, fallback: 'تعذّر إكمال الإجراء، حدِّث الحالة ثم أعد المحاولة.');
  }

  void _adopt(Map<String, dynamic> settings) {
    _settings = settings;
    _enabled = settings['enabled'] == true;
    _url.text = settings['publicUrl']?.toString() ?? '';
    _secret.clear();
    _clearSecret = false;
  }

  Future<void> _load() async {
    final generation = ++_generation, request = widget.request;
    setState(() {
      _loading = true;
      _ready = false;
      _error = null;
    });
    try {
      final response = await request('composio.events.list');
      List<Map<String, dynamic>> accounts = [], routines = [];
      List<String> toolkits = [];
      String? warning;
      try {
        final data = await Future.wait([
          request('composio.read'),
          request('routines.list'),
        ]);
        accounts = _list(data[0]['accounts'])
            .where((a) => a['status'] == 'ACTIVE')
            .toList();
        toolkits = (data[0]['toolkits'] as List? ?? [])
            .whereType<String>()
            .toList();
        routines = _list(data[1]['routines'])
            .where((r) => r['trigger'] == 'event' && r['enabled'] == true)
            .toList();
      } catch (_) {
        await request('status');
        warning = 'قائمة الحسابات أو المهام غير متاحة مؤقتًا؛ ما زال بإمكانك تعديل إعدادات استقبال الأحداث.';
      }
      if (!mounted || generation != _generation || request != widget.request) {
        return;
      }
      setState(() {
        _adopt(_map(response['settings']));
        _triggers = _list(response['triggers']);
        _accounts = accounts;
        _routines = routines;
        if (!accounts.any(
          (a) => a['id'] == _account && a['toolkit'] == _definition['toolkit'],
        )) {
          _account = null;
        }
        if (!routines.any((r) => r['id'] == _routine)) _routine = null;
        _toolkits = toolkits;
        _resourceWarning = warning;
        _ready = true;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _mutate(
    String operation, {
    String? id,
    Map<String, dynamic> payload = const {},
  }) async {
    if (_disabled) return null;
    final generation = _generation, request = widget.request;
    final mutation = ++_mutationGeneration;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await request('status');
      if (!mounted || generation != _generation || request != widget.request) {
        return null;
      }
      final result = await request(operation, id: id, payload: payload);
      if (!mounted || generation != _generation || request != widget.request) {
        return null;
      }
      _secret.clear();
      await _load();
      return result;
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = _message(error);
          if (error is StateError) _ready = false;
        });
      }
      return null;
    } finally {
      if (mounted &&
          request == widget.request &&
          mutation == _mutationGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  bool _validUrl() {
    final value = Uri.tryParse(_url.text.trim());
    if (value == null ||
        value.scheme != 'https' ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasQuery ||
        value.hasFragment) {
      setState(() => _error = 'أدخل عنوان HTTPS عامًا دون حساب أو رمز أو معاملات استعلام.');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_url.text.trim().isNotEmpty && !_validUrl()) return;
    await _mutate(
      'composio.events.settings.update',
      payload: {
        'expectedRevision': _settings['revision'],
        'enabled': _enabled,
        'publicUrl': _url.text.trim(),
        if (_clearSecret)
          'clearSigningSecret': true
        else if (_secret.text.isNotEmpty)
          'signingSecret': _secret.text,
      },
    );
  }

  Future<void> _catalog({bool append = false}) async {
    if (_disabled || _catalogLoading || (append && _cursor == null)) return;
    final generation = ++_catalogGeneration,
        request = widget.request,
        owner = widget.ownerKey;
    setState(() {
      _catalogLoading = true;
      _error = null;
    });
    try {
      final result = await request(
        'composio.events.catalog',
        payload: {
          'limit': 30,
          if (_toolkit != null) 'toolkit': _toolkit,
          if (append) 'cursor': _cursor,
        },
      );
      if (!mounted ||
          generation != _catalogGeneration ||
          request != widget.request ||
          owner != widget.ownerKey) {
        return;
      }
      setState(() {
        _types = <String, Map<String, dynamic>>{
          if (append)
            for (final item in _types) item['slug'].toString(): item,
          for (final item in _list(result['items']))
            item['slug'].toString(): item,
        }.values.toList();
        _cursor = result['nextCursor'] as String?;
      });
    } catch (error) {
      if (mounted && generation == _catalogGeneration) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && generation == _catalogGeneration) {
        setState(() => _catalogLoading = false);
      }
    }
  }

  Future<void> _select(Map<String, dynamic> type) async {
    if (_disabled) return;
    final generation = ++_definitionGeneration, request = widget.request;
    setState(() {
      _definition = {};
      _error = null;
      _account = null;
      _routine = null;
      _config.text = '{}';
    });
    try {
      final definition = await request(
        'composio.events.describe',
        payload: {'slug': type['slug']},
      );
      if (!mounted ||
          generation != _definitionGeneration ||
          request != widget.request) {
        return;
      }
      setState(() => _definition = definition);
    } catch (error) {
      if (mounted && generation == _definitionGeneration) {
        setState(() => _error = _message(error));
      }
    }
  }

  Map<String, dynamic>? _parseConfig(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (value.contains('[redacted]')) throw const FormatException();
      return decoded;
    } catch (_) {
      setState(() => _error = 'أدخل كائن JSON؛ يجب إعادة إدخال قيم الإعدادات الخاصة المخفية.');
      return null;
    }
  }

  Future<bool> _confirm(String title, String message) async {
    if (_disabled || _confirming) return false;
    final generation = _generation, request = widget.request;
    _confirming = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          scrollable: true,
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      return accepted == true &&
          mounted &&
          generation == _generation &&
          request == widget.request;
    } finally {
      _confirming = false;
    }
  }

  Future<void> _create() async {
    if (_definition.isEmpty ||
        _account == null ||
        _routine == null ||
        _disabled) {
      return;
    }
    final config = _parseConfig(_config.text);
    if (config == null) return;
    if (!await _confirm(
      'إنشاء اشتراك في أحداث التطبيق',
      '${_definition['name'] ?? _definition['slug']}\nالحساب: $_account\nالمهمة: ${_routines.where((r) => r['id'] == _routine).first['title']}\n\nسيؤدي هذا إلى تسجيل مستمع في Composio. تُسلَّم الأحداث إلى المهمة الحالية للمعالجة، وتبقى إجراءات التطبيق خاضعة لسياسات التفويض والمراجعة.',
    )) {
      return;
    }
    await _mutate(
      'composio.events.create',
      payload: {
        'slug': _definition['slug'],
        'routineId': _routine,
        'accountId': _account,
        'config': config,
      },
    );
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    if (_disabled || _confirming) return;
    final generation = _generation,
        request = widget.request,
        controller = TextEditingController(text: _json(row['config'] ?? {}));
    _confirming = true;
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تعديل إعدادات الحدث'),
          scrollable: true,
          content: TextField(
            key: const Key('na-event-edit-config'),
            controller: controller,
            minLines: 4,
            maxLines: 12,
            decoration: const InputDecoration(labelText: 'إعدادات JSON'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
      if (value == null ||
          !mounted ||
          generation != _generation ||
          request != widget.request) {
        return;
      }
      final config = _parseConfig(value);
      if (config != null) {
        await _mutate(
          'composio.events.update',
          id: row['id'].toString(),
          payload: {'config': config},
        );
      }
    } finally {
      _confirming = false;
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _accounts
        .where((a) => a['toolkit'] == _definition['toolkit'])
        .toList();
    return Scaffold(
      backgroundColor: context.omniPalette.pageBackground,
      appBar: CommonAppBar(
        primary: true,
        title: 'أحداث التطبيق',
        onBackPressed: () => Navigator.of(context).pop(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OmniCircleButton(
              icon: LucideIcons.refreshCw,
              tooltip: 'تحديث أحداث التطبيق',
              onPressed: _busy ? null : _load,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: OmniContentWidth(
          child: SingleChildScrollView(
            key: const Key('na-composio-events-scroll'),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اسمح للتطبيقات المتصلة بتنبيه Na عند حدوث تغيير، وستصلك نتائج المعالجة عبر إشعارات Android. الرسائل النشطة المجدولة لا تحتاج إلى رد اتصال عام.'),
                const SizedBox(height: 20),
                if (_loading || _busy)
                  const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _error!,
                      key: const Key('na-events-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_resourceWarning != null) Text(_resourceWarning!),
                Text(
                  _settings['enabled'] == true ? 'استقبال الأحداث مفعّل' : 'استقبال الأحداث غير مفعّل',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _settings['providerRegistered'] == true
                      ? 'سجّلت Composio رد الاتصال'
                      : 'لم يتم تأكيد تسجيل رد الاتصال في Composio بعد',
                ),
                Text(
                  _settings['deliveryVerifiedAt'] != null
                      ? 'تم استلام أحداث اجتازت التحقق من التوقيع'
                      : 'لم يتم استلام أحداث اجتازت التحقق من التوقيع بعد',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('na-event-public-url'),
                  controller: _url,
                  enabled: !_disabled,
                  decoration: const InputDecoration(
                    labelText: 'عنوان URL العام لرد اتصال HTTPS',
                    hintText: 'https://your-na.example/api/integrations/composio/events/receive',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 12),
                  child: Text('يلزم عنوان Na يمكن الوصول إليه من الخارج. إدخال عنوان محلي أو حفظ الإعدادات لا يعني أن Composio تستطيع التسليم.'),
                ),
                FilledButton(
                  onPressed: _disabled
                      ? null
                      : () async {
                          if (_validUrl() &&
                              await _confirm(
                                'إعداد استقبال الأحداث',
                                'سيتم تسجيل هذا العنوان في مشروع Composio الحالي:\n${_url.text.trim()}\n\nلن يتم استبدال اشتراكات Webhook الأخرى إن وُجدت. يُحفظ مفتاح التوقيع في خادم Na فقط.',
                              )) {
                            await _mutate(
                              'composio.events.webhook',
                              payload: {
                                'expectedRevision': _settings['revision'],
                                'publicUrl': _url.text.trim(),
                              },
                            );
                          }
                        },
                  child: const Text('إعداد استقبال الأحداث'),
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('يوجد Webhook أو إعداد يدوي'),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تفعيل استقبال الأحداث'),
                      value: _enabled,
                      onChanged: _disabled
                          ? null
                          : (value) => setState(() => _enabled = value),
                    ),
                    TextField(
                      key: const Key('na-event-signing-secret'),
                      controller: _secret,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      enabled: !_disabled && !_clearSecret,
                      decoration: InputDecoration(
                        labelText: 'مفتاح توقيع Webhook في Composio',
                        hintText: _settings['signingSecretConfigured'] == true
                            ? 'اتركه فارغًا للاحتفاظ بالمفتاح الحالي'
                            : 'يُكتب في الخادم فقط ولا يُعرض مجددًا',
                      ),
                    ),
                    if (_settings['signingSecretConfigured'] == true)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('مسح مفتاح التوقيع من الخادم'),
                        value: _clearSecret,
                        onChanged: _disabled
                            ? null
                            : (value) => setState(() {
                                _clearSecret = value == true;
                                if (_clearSecret) _secret.clear();
                              }),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _disabled ? null : _save,
                          child: const Text('حفظ إعدادات الأحداث'),
                        ),
                        if (_settings['subscriptionId'] != null)
                          TextButton(
                            onPressed: _disabled
                                ? null
                                : () async {
                                    if (await _confirm(
                                      'إزالة اشتراك رد اتصال Na',
                                      'يُزال فقط رد اتصال Na المُسجَّل على هذا الجهاز والمطابق. لن تتأثر اشتراكات المشاريع الأخرى.',
                                    )) {
                                      await _mutate(
                                        'composio.events.webhookRemove',
                                        payload: {
                                          'expectedRevision':
                                              _settings['revision'],
                                        },
                                      );
                                    }
                                  },
                            child: const Text('إزالة رد اتصال Na'),
                          ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'اشتراكات الأحداث',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _disabled
                          ? null
                          : () => _mutate('composio.events.reconcile'),
                      child: const Text('مزامنة الحالة من المصدر'),
                    ),
                  ],
                ),
                if (_triggers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('لم يتم إنشاء أي اشتراك في الأحداث بعد.'),
                  ),
                for (final row in _triggers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(row['slug']?.toString() ?? 'أحداث التطبيق'),
                          subtitle: Text(
                            row['stale'] == true
                                ? 'تغيّرت إعدادات الاتصال وتحتاج إلى إعادة تحقق'
                                : '${row['state'] ?? 'unknown'} · ${row['accountId'] ?? ''}',
                          ),
                          value: row['enabled'] == true,
                          onChanged: _disabled
                              ? null
                              : (enabled) => _mutate(
                                  'composio.events.update',
                                  id: row['id'].toString(),
                                  payload: {'enabled': enabled},
                                ),
                        ),
                        if (row['problem'] != null)
                          Text(row['problem'].toString()),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _disabled ? null : () => _edit(row),
                              child: const Text('تعديل الإعدادات'),
                            ),
                            TextButton(
                              onPressed: _disabled
                                  ? null
                                  : () async {
                                      if (await _confirm(
                                        'حذف اشتراك الحدث',
                                        'إيقاف الاستماع إلى أحداث هذه المهمة؟ سيبقى الاستماع المشترك محفوظًا للمهام الأخرى.',
                                      )) {
                                        await _mutate(
                                          'composio.events.delete',
                                          id: row['id'].toString(),
                                        );
                                      }
                                    },
                              child: const Text('حذف الاشتراك'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 32),
                Text('إنشاء اشتراك', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('na-events-toolkit'),
                  initialValue: _toolkit,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تصفية التطبيقات المتاحة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل التطبيقات المتاحة')),
                    for (final toolkit in _toolkits)
                      DropdownMenuItem(value: toolkit, child: Text(toolkit)),
                  ],
                  onChanged: _disabled
                      ? null
                      : (value) {
                          ++_catalogGeneration;
                          setState(() {
                            _toolkit = value;
                            _types = [];
                            _cursor = null;
                            _catalogLoading = false;
                          });
                          unawaited(_catalog());
                        },
                ),
                TextButton(
                  onPressed: _disabled || _catalogLoading
                      ? null
                      : () => _catalog(),
                  child: Text(_catalogLoading ? 'جارٍ قراءة أنواع الأحداث…' : 'تصفح أنواع الأحداث'),
                ),
                for (final type in _types)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      type['name']?.toString() ?? type['slug'].toString(),
                    ),
                    subtitle: Text(type['slug'].toString()),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: _disabled ? null : () => _select(type),
                  ),
                if (_cursor != null)
                  TextButton(
                    onPressed: _disabled || _catalogLoading
                        ? null
                        : () => _catalog(append: true),
                    child: const Text('تحميل المزيد من أنواع الأحداث'),
                  ),
                if (_definition.isNotEmpty) ...[
                  Text(
                    _definition['name']?.toString() ??
                        _definition['slug'].toString(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(_definition['description']?.toString() ?? ''),
                  if (_definition['instructions']?.toString().isNotEmpty ==
                      true)
                    Text(_definition['instructions'].toString()),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('الإعدادات الكاملة للحدث وتعريف البيانات'),
                    children: [
                      SelectableText(
                        _json({
                          'version': _definition['version'],
                          'configSchema': _definition['configSchema'],
                          'payloadSchema': _definition['payloadSchema'],
                        }),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('na-event-account:${_definition['slug']}'),
                    initialValue: _account,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'حساب التنفيذ'),
                    items: [
                      for (final account in eligible)
                        DropdownMenuItem(
                          value: account['id'].toString(),
                          child: Text(
                            account['label']?.toString() ??
                                account['id'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _disabled
                        ? null
                        : (value) => setState(() => _account = value),
                  ),
                  if (eligible.isEmpty) const Text('صِل حساب هذا التطبيق أولًا.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('na-event-routine:${_definition['slug']}'),
                    initialValue: _routine,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المهمة التي تعالج الحدث'),
                    items: [
                      for (final routine in _routines)
                        DropdownMenuItem(
                          value: routine['id'].toString(),
                          child: Text(
                            routine['title'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _disabled
                        ? null
                        : (value) => setState(() => _routine = value),
                  ),
                  if (_routines.isEmpty) const Text('أنشئ مهمة أحداث وفعّلها من «المهام» أو عبر المحادثة.'),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('na-event-config-json'),
                    controller: _config,
                    minLines: 3,
                    maxLines: 8,
                    enabled: !_disabled,
                    decoration: const InputDecoration(
                      labelText: 'إعدادات الحدث بصيغة JSON',
                      hintText: '{}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        _disabled ||
                            _settings['configured'] != true ||
                            _account == null ||
                            _routine == null
                        ? null
                        : _create,
                    child: const Text('إنشاء اشتراك حدث'),
                  ),
                  if (_settings['configured'] != true)
                    const Text('اضبط استقبال الأحداث قبل الإنشاء؛ وستستمر الرسائل النشطة المجدولة في العمل.'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
