import 'package:ui/services/special_permission.dart';

class RootAccessSnapshot {
  const RootAccessSnapshot({this.enabled = false, this.status = 'DISABLED'});

  final bool enabled;
  final String status;
  bool get granted => enabled && status == 'GRANTED';
  bool get checking => enabled && status == 'CHECKING';

  factory RootAccessSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    final enabled = map?['enabled'] == true;
    return RootAccessSnapshot(
      enabled: enabled,
      status: enabled
          ? (map?['status'] as String? ?? 'UNAVAILABLE')
          : 'DISABLED',
    );
  }

  String label(bool english) => switch (status) {
    'NOT_GRANTED' => 'غير مصرّح',
    'CHECKING' => 'جارٍ التحقق من الصلاحية…',
    'GRANTED' => 'مصرّح · يُفضَّل Root',
    'DENIED' => 'تم رفض الصلاحية',
    'TIMED_OUT' => 'انتهت مهلة الصلاحية',
    'DISABLED' => 'معطّل',
    _ => 'Root غير متاح',
  };
}

abstract final class RootAccessService {
  static Future<RootAccessSnapshot> status() async =>
      RootAccessSnapshot.fromMap(
        await spePermission.invokeMapMethod('getRootStatus'),
      );

  static Future<RootAccessSnapshot> setEnabled(bool enabled) async =>
      RootAccessSnapshot.fromMap(
        await spePermission.invokeMapMethod('setRootEnabled', {
          'enabled': enabled,
        }),
      );

  static Future<RootAccessSnapshot> requestAccess() async =>
      RootAccessSnapshot.fromMap(
        await spePermission.invokeMapMethod('requestRootAccess'),
      );
}
