import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/services/special_permission.dart';

/// Device delivery preferences for server-owned Na notifications. This widget
/// never creates a chat, starts a model turn, or receives connector credentials.
class NaNotificationSettings extends StatefulWidget {
  const NaNotificationSettings({super.key, this.disabled = false});
  final bool disabled;

  @override
  State<NaNotificationSettings> createState() => _NaNotificationSettingsState();
}

class _NaNotificationSettingsState extends State<NaNotificationSettings>
    with WidgetsBindingObserver {
  Map<String, dynamic> _data = {};
  String? _owner, _error;
  bool _loading = true, _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant NaNotificationSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disabled && !widget.disabled && !_busy) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final response = await AgentRuntimeService.requestNaNotifications();
      if (!mounted || generation != _generation) return;
      setState(() {
        _owner = response.owner;
        _data = response.data;
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'تعذّر قراءة إعدادات الإشعارات مؤقتاً. حاول مجدداً.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy || widget.disabled || _owner == null) return;
    final owner = _owner!;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (enabled && !await ensureNotificationPermission()) {
        if (mounted && generation == _generation) {
          setState(() => _error = 'لم يتم السماح بإرسال الإشعارات بعد. فعّلها في إعدادات النظام.');
        }
        return;
      }
      final response = await AgentRuntimeService.requestNaNotifications(
        owner: owner,
        enabled: enabled,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _data = response.data);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'تعذّر تغيير إعدادات التذكير. حدّث الصفحة وحاول مجدداً.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _data['enabled'] == true;
    final disabled = widget.disabled || _loading || _busy || _owner == null;
    final warning = _error ?? _data['error']?.toString();
    return Column(
      key: const Key('na-notification-settings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('رسائل Na الاستباقية', style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(
          key: const Key('na-notifications-enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('استلام الرسائل الاستباقية'),
          subtitle: Text(
            enabled
                ? _data['connectionActive'] == true
                      ? 'الاتصال الخلفي مفعّل، انقر على الإشعار للعودة إلى المحادثة الأصلية.'
                      : 'مفعّلة، سيبقى الاتصال الخلفي نشطاً وسيتم جلب التذكيرات الفائتة.'
                : 'عند التفعيل، تُرسل تذكيرات Na ومواضيع المتابعة إلى إشعارات النظام.',
          ),
          value: enabled,
          onChanged: disabled ? null : _setEnabled,
        ),
        if (_data['developmentMode'] == true)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('يُحفظ الرمز مشفراً على هذا الجهاز ويُحذف عند الإيقاف.'),
          ),
        if (enabled)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('قد تؤخر قيود توفير البطارية وصول التذكيرات.'),
          ),
        if (_data['permissionGranted'] == false && enabled)
          const Text('إذن إشعارات النظام مغلق، فعّله لاستلام التذكيرات.'),
        if (warning != null && warning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              warning,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          key: const Key('na-notifications-refresh'),
          onPressed: _busy || _loading ? null : _load,
          child: Text(_loading ? 'جارٍ قراءة إعدادات الإشعارات…' : 'تحديث إعدادات الإشعارات'),
        ),
      ],
    );
  }
}
