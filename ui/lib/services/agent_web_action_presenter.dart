import 'package:ui/core/router/go_router_manager.dart';
import 'package:ui/services/agent_web_status_service.dart';
import 'package:ui/services/omni_plugin_service.dart';
import 'package:ui/utils/ui.dart';

/// Presents the user-facing result of an Agent Web plugin action.
///
/// Both the Agent settings page and global quick launch surfaces use this
/// presenter so runtime outcomes never drift into page-specific behavior.
class AgentWebActionPresenter {
  const AgentWebActionPresenter._();

  static Future<void> invoke(
    OmniPluginActionItem action, {
    required bool english,
  }) async {
    final label = action.localizedPresentationValue(
      'label',
      english: english,
      fallback: action.displayName,
    );

    try {
      final response = await OmniPluginService.invokeAction(
        action.pluginId,
        action.id,
      );
      final code = response['code']?.toString().trim() ?? '';
      switch (code) {
        case 'OPENED':
          showToast('تم فتح $label');
          return;
        case 'RUNTIME_MISSING':
          final responsePackageId =
              response['packageId']?.toString().trim() ?? '';
          final packageId = responsePackageId.isNotEmpty
              ? responsePackageId
              : action.presentation['packageId']?.toString().trim() ?? '';
          GoRouterManager.push(
            packageId.isEmpty
                ? '/home/termux_setting'
                : '/home/termux_setting?focus=${Uri.encodeComponent(packageId)}',
          );
          return;
        case 'PROVIDER_REQUIRED':
          showToast(
            'يرجى إعداد مزوّد Dispatch الموحّد أولاً',
            type: ToastType.warning,
          );
          GoRouterManager.push('/home/model_provider_setting');
          return;
        case 'MODEL_REQUIRED':
          showToast(
            'يرجى اختيار نموذج لـ Dispatch أولاً',
            type: ToastType.warning,
          );
          GoRouterManager.push('/home/model_provider_setting');
          return;
        case 'UNSUPPORTED_PROVIDER':
          showToast(
            'لا يدعم $label بروتوكول المزوّد الحالي',
            type: ToastType.warning,
          );
          return;
        case 'URL_TIMEOUT':
          showToast(
            'انتهت مهلة تشغيل $label وتوقفت العملية الخلفية',
            type: ToastType.error,
          );
          return;
        case 'STOP_FAILED':
          showToast(
            'تعذّر إيقاف العملية السابقة لـ $label، يرجى معالجتها من إعدادات الطرفية ثم إعادة المحاولة',
            type: ToastType.error,
          );
          return;
        case 'BROWSER_UNAVAILABLE':
          showToast(
            'لا يوجد متصفح نظام متاح',
            type: ToastType.error,
          );
          return;
        case 'PAIRING_FAILED':
          showToast(
            'تعذّر إنشاء رابط تسجيل الدخول لـ $label، يرجى إعادة فتحه',
            type: ToastType.error,
          );
          return;
        default:
          showToast(
            'تعذّر تشغيل $label',
            type: ToastType.error,
          );
      }
    } catch (error) {
      showToast(
        'تعذّر فتح واجهة الويب: $error',
        type: ToastType.error,
      );
    }
  }

  /// Stops the managed Web process behind [action] and presents the outcome.
  /// Returns true when the runtime confirms the process stopped.
  static Future<bool> stop(
    OmniPluginActionItem action, {
    required bool english,
  }) async {
    final label = action.localizedPresentationValue(
      'label',
      english: english,
      fallback: action.displayName,
    );

    try {
      final stopped = await AgentWebStatusService.stop(action);
      if (stopped) {
        showToast('تم إيقاف $label');
        return true;
      }
      showToast(
        'تعذّر إيقاف $label، يرجى إعادة المحاولة',
        type: ToastType.error,
      );
      return false;
    } catch (error) {
      showToast(
        'تعذّر إيقاف واجهة الويب: $error',
        type: ToastType.error,
      );
      return false;
    }
  }
}
