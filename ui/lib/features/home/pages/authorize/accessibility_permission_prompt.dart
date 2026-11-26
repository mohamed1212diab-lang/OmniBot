import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ui/widgets/omni_glass.dart';
import 'package:flutter/services.dart';
import 'package:ui/services/special_permission.dart';

Future<bool> showAccessibilityPermissionPrompt(BuildContext context) async {
  if (await _isAccessibilityReady()) return true;
  if (!context.mounted) return false;
  return await showOmniGlassCardSheet<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AccessibilityPermissionDialog(),
      ) ??
      false;
}

class _AccessibilityPermissionDialog extends StatefulWidget {
  const _AccessibilityPermissionDialog();

  @override
  State<_AccessibilityPermissionDialog> createState() =>
      _AccessibilityPermissionDialogState();
}

class _AccessibilityPermissionDialogState
    extends State<_AccessibilityPermissionDialog>
    with WidgetsBindingObserver {
  bool _settingsOpened = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settingsOpened) {
      unawaited(_finishWhenReady());
    }
  }

  Future<void> _openSettings() async {
    if (_checking) return;
    setState(() {
      _settingsOpened = true;
      _error = null;
    });
    try {
      await spePermission.invokeMethod<void>(
        'openAndroidGuiAccessibilitySettings',
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _settingsOpened = false;
        _error = error.message ?? error.code;
      });
    }
  }

  Future<void> _finishWhenReady() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      for (var attempt = 0; attempt < 20; attempt += 1) {
        if (await _isAccessibilityReady()) {
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!mounted) return;
      setState(() {
        _error = 'لم يتم تفعيل إمكانية الوصول بعد، فعّل المفتاح في النظام ثم عُد.';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OmniGlassAlertDialog(
      title: const Text('تفعيل إذن إمكانية الوصول'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'يحتاج Doser AI إلى قراءة الشاشة وتنفيذ النقر والتمرير والإدخال.',
          ),
          const SizedBox(height: 14),
          Text(
            'مكان التفعيل',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'إعدادات النظام ← إمكانية الوصول ← التطبيقات المنزّلة (أو الخدمات المثبّتة) ← Doser AI ← تفعيل',
          ),
          if (_checking) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _checking ? null : _openSettings,
          child: const Text('فتح إعدادات إمكانية الوصول في النظام'),
        ),
      ],
    );
  }
}

Future<bool> _isAccessibilityReady() async {
  try {
    return await spePermission.invokeMethod<bool>(
          'isAndroidGuiAccessibilityReady',
        ) ??
        false;
  } on PlatformException {
    return false;
  }
}

