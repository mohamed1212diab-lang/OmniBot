import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

typedef NaGrantRequest = Future<Map<String, dynamic>> Function(
  String operation, {
  String? id,
  Map<String, dynamic> payload,
});

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : {};

bool canSaveNaRepeatGrant(Map<String, dynamic> action) {
  final connector = _map(action['connector']);
  final account = _map(action['account']);
  if (action['id'] is! String ||
      (action['id'] as String).isEmpty ||
      action['routineId'] is! String ||
      (action['routineId'] as String).isEmpty ||
      !['pending', 'completed'].contains(action['status']) ||
      action['args'] is! Map ||
      connector['provider'] != 'composio' ||
      connector['noAuth'] is! bool ||
      !RegExp(r'^[A-Z0-9_][A-Z0-9_]{1,159}$')
          .hasMatch(connector['tool']?.toString() ?? '') ||
      (connector['tool']?.toString() ?? '').startsWith('COMPOSIO_') ||
      action['operation'] != 'composio.${connector['tool']}' ||
      !connector.containsKey('authConfigId') ||
      !RegExp(r'^[a-z0-9_][a-z0-9_-]{0,63}$')
          .hasMatch(connector['toolkit']?.toString() ?? '') ||
      !RegExp(r'^\d{8}_\d{2}$')
          .hasMatch(connector['version']?.toString() ?? '') ||
      connector['version'] == '00000000_00') {
    return false;
  }
  for (final key in ['schemaHash', 'policyHash', 'reviewHash']) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(connector[key]?.toString() ?? '')) {
      return false;
    }
  }
  if (connector['noAuth'] == true) {
    return connector['accountId'] == null &&
        connector['authConfigId'] == null &&
        account['id'] == 'no-auth:${connector['toolkit']}';
  }
  return connector['accountId'] is String &&
      connector['authConfigId'] is String &&
      (connector['authConfigId'] as String).isNotEmpty &&
      account['id'] == connector['accountId'];
}

String _actionIdentity(Map<String, dynamic> action) =>
    '${action['id']}\u0000${action['routineId']}\u0000${action['status']}\u0000${_map(action['connector'])['reviewHash']}';

Future<bool> _confirmGrant(
  BuildContext context,
  Widget content,
  String title,
  String confirm,
) async {
  var accepted = false;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: content),
          actions: [
            TextButton(
              onPressed: () {
                if (!accepted) Navigator.of(dialog).pop(false);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (accepted) return;
                accepted = true;
                Navigator.of(dialog).pop(true);
              },
              child: Text(confirm),
            ),
          ],
        ),
      ) ??
      false;
}

class NaRepeatGrantButton extends StatefulWidget {
  const NaRepeatGrantButton({
    super.key,
    required this.action,
    required this.request,
    this.onChanged,
    this.disabled = false,
    this.ownerKey,
  });
  final Map<String, dynamic> action;
  final NaGrantRequest request;
  final FutureOr<void> Function()? onChanged;
  final bool disabled;
  final Object? ownerKey;
  @override
  State<NaRepeatGrantButton> createState() => _NaRepeatGrantButtonState();
}

class _NaRepeatGrantButtonState extends State<NaRepeatGrantButton> {
  bool _busy = false, _saved = false;
  int _generation = 0;
  String? _error;
  BuildContext? _dialog;

  @override
  void didUpdateWidget(covariant NaRepeatGrantButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerKey != widget.ownerKey ||
        oldWidget.request != widget.request ||
        _actionIdentity(oldWidget.action) != _actionIdentity(widget.action) ||
        (!oldWidget.disabled && widget.disabled)) {
      ++_generation;
      _busy = false;
      _saved = false;
      _error = null;
      final dialog = _dialog;
      if (dialog != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (dialog.mounted && ModalRoute.of(dialog)?.isCurrent == true) {
            Navigator.of(dialog).pop(false);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }

  Future<void> _review() async {
    if (_busy ||
        _saved ||
        widget.disabled ||
        !canSaveNaRepeatGrant(widget.action)) {
      return;
    }
    final generation = ++_generation;
    final action =
        jsonDecode(jsonEncode(widget.action)) as Map<String, dynamic>;
    final connector = _map(action['connector']),
        account = _map(action['account']);
    final request = widget.request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final accepted = await _confirmGrant(
        context,
        Builder(
          builder: (dialog) {
            _dialog = dialog;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المهمة: ${action['routineTitle'] ?? action['routineId']}'),
                Text('العملية: ${connector['tool']}'),
                Text('الحساب: ${account['label'] ?? account['id']}'),
                const SizedBox(height: 12),
                const Text('المعاملات الدقيقة'),
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(action['args']),
                ),
                const SizedBox(height: 12),
                const Text(
                  'صالح افتراضيًا لمدة 30 يومًا، ويقتصر على تكرار تنفيذ هذه المهمة بنفس الحساب والمعاملات؛ ويمكن إلغاؤه في أي وقت.',
                ),
                if (action['status'] == 'pending') ...[
                  const SizedBox(height: 8),
                  const Text('الحفظ لن ينفّذ هذه العملية.'),
                ],
              ],
            );
          },
        ),
        'حفظ هذا الإذن المتكرر؟',
        'تأكيد حفظ الإذن المتكرر',
      );
      _dialog = null;
      if (!accepted ||
          !mounted ||
          generation != _generation ||
          widget.disabled) {
        return;
      }
      await request(
        'connectors.grants.create',
        payload: {'actionId': action['id']},
      );
      if (!mounted || generation != _generation) return;
      setState(() => _saved = true);
      await widget.onChanged?.call();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'تعذّر تأكيد الإذن، يُرجى التحديث وإعادة المراجعة.');
      }
    } finally {
      _dialog = null;
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canSaveNaRepeatGrant(widget.action)) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          key: ValueKey('na-save-repeat-${widget.action['id']}'),
          onPressed: widget.disabled || _busy || _saved ? null : _review,
          child: Text(
            _saved
                ? 'تم حفظ الإذن المتكرر'
                : _busy
                ? 'جارٍ تأكيد الإذن المتكرر…'
                : 'حفظ الإذن المتكرر',
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

String _grantStatus(dynamic value) =>
    const {
      'active': 'صالح',
      'revoked': 'أُلغي',
      'expired': 'منتهي الصلاحية',
      'invalidated': 'غير صالح',
      'suspended': 'متوقف مؤقتًا، يلزم إعادة المراجعة',
    }[value] ??
    'الحالة بانتظار التأكيد';
String _grantReason(dynamic value) =>
    const {
      'expired': 'انتهت مدة الإذن.',
      'user_revoked': 'لقد ألغيت هذا الإذن.',
      'routine_deleted': 'حُذفت المهمة الأصلية.',
      'routine_changed': 'عُدّلت المهمة، ويلزم إعادة المراجعة.',
      'connection_policy_changed': 'تغيّر إعداد الاتصال، ويلزم إعادة المراجعة.',
      'account_or_schema_changed': 'تغيّر الحساب أو تعريف الأداة.',
      'account_or_schema_unavailable': 'تعذّر التحقق من الحساب الأصلي أو تعريف الأداة.',
      'unconfirmed_result': 'نتيجة العملية الأخيرة غير واضحة، ويلزم التحقق أولًا.',
      'execution_interrupted': 'انقطع التنفيذ الأخير، ويلزم التحقق من النتيجة أولًا.',
    }[value] ??
    'هذا الإذن غير متاح مؤقتًا، يُرجى إعادة المراجعة.';

class NaConnectorGrantList extends StatefulWidget {
  const NaConnectorGrantList({
    super.key,
    required this.request,
    this.disabled = false,
    this.ownerKey,
  });
  final NaGrantRequest request;
  final bool disabled;
  final Object? ownerKey;
  @override
  State<NaConnectorGrantList> createState() => _NaConnectorGrantListState();
}

class _NaConnectorGrantListState extends State<NaConnectorGrantList> {
  List<Map<String, dynamic>> _grants = [];
  bool _loading = true;
  String? _busy, _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.disabled) {
      unawaited(_load());
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NaConnectorGrantList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerKey != widget.ownerKey ||
        oldWidget.request != widget.request ||
        oldWidget.disabled != widget.disabled) {
      ++_generation;
      _grants = [];
      _busy = null;
      _error = null;
      if (!widget.disabled) {
        unawaited(_load());
      } else {
        _loading = false;
      }
    }
  }

  Future<void> _load() async {
    if (widget.disabled) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.request(
        'connectors.grants.list',
        payload: {},
      );
      if (!mounted || generation != _generation) return;
      setState(
        () => _grants = (result['grants'] as List? ?? [])
            .whereType<Map>()
            .map(_map)
            .toList(),
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'تعذّر قراءة الأذونات المتكررة مؤقتًا، يُرجى إعادة المحاولة.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _revoke(Map<String, dynamic> grant) async {
    if (_busy != null || widget.disabled) return;
    final generation = ++_generation, request = widget.request;
    setState(() => _busy = grant['id']?.toString());
    try {
      final accepted = await _confirmGrant(
        context,
        const Text('بعد الإلغاء، ستحتاج المهمة إلى إعادة المراجعة قبل تنفيذ هذه العملية مجددًا. ولا يمكن التراجع عن العمليات البعيدة التي أُرسلت بالفعل.'),
        'إلغاء هذا الإذن المتكرر؟',
        'تأكيد الإلغاء',
      );
      if (!accepted ||
          !mounted ||
          generation != _generation ||
          widget.disabled) {
        return;
      }
      final result = await request(
        'connectors.grants.revoke',
        id: grant['id']?.toString(),
        payload: {},
      );
      if (!mounted || generation != _generation) return;
      final changed = _map(result['grant']);
      if (changed['id'] != grant['id']) throw StateError('授权归属不符');
      setState(
        () => _grants = _grants
            .map((row) => row['id'] == grant['id'] ? changed : row)
            .toList(),
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'تعذّر تأكيد نتيجة الإلغاء، يُرجى التحديث والتحقق.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('na-connector-grants'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('أذونات العمليات المتكررة', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      const Text('بعد الحفظ، لن تحتاج المهمة إلى مراجعة متكررة عند تنفيذ العملية نفسها مجددًا.'),
      TextButton(
        onPressed: widget.disabled || _loading || _busy != null ? null : _load,
        child: Text(_loading ? 'جارٍ قراءة الأذونات…' : 'تحديث الأذونات المتكررة'),
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (!_loading && _error == null && _grants.isEmpty)
        const Text('لا توجد أذونات عمليات متكررة بعد.'),
      for (final grant in _grants)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${grant['routineTitle'] ?? grant['routineId']} · ${_grantStatus(grant['status'])}',
              ),
              Text('العملية: ${grant['tool']}'),
              if (grant['noAuth'] != true) Text('الحساب: ${grant['accountId']}'),
              Text(
                'الانتهاء: ${DateTime.tryParse(grant['expiresAt']?.toString() ?? '')?.toLocal().toString().split('.').first ?? 'بانتظار التأكيد'}',
              ),
              if (grant['status'] != 'active')
                Text(_grantReason(grant['reason'])),
              if (['active', 'suspended'].contains(grant['status']))
                TextButton(
                  key: ValueKey('na-revoke-grant-${grant['id']}'),
                  onPressed: widget.disabled || _busy != null
                      ? null
                      : () => _revoke(grant),
                  child: Text(_busy == grant['id'] ? 'جارٍ التأكيد…' : 'إلغاء الإذن'),
                ),
            ],
          ),
        ),
    ],
  );
}
