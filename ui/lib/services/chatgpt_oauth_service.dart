import 'package:flutter/services.dart';
import 'package:ui/services/assists_core_service.dart';

/// Only allowlisted codes cross into diagnostics; never retain native messages,
/// callback URLs, authorization codes, or exception details.
class ChatGptOAuthFailure implements Exception {
  const ChatGptOAuthFailure({required this.code, required this.phase});

  final String code;
  final String phase;

  static const _nativeCodes = {
    'secure_storage_unavailable',
    'secure_storage_invalid_format',
    'callback_unavailable',
    'callback_failed',
    'invalid_profile',
    'invalid_attempt',
    'not_initialized',
    'too_many_attempts',
    'login_cancelled',
    'login_timeout',
    'authorization_declined',
    'account_mismatch',
    'registration_incomplete',
    'missing_code',
    'invalid_state',
    'invalid_identity',
    'invalid_client',
    'invalid_response',
    'network_error',
    'oauth_request_failed',
    'login_failed',
    'sign_in_required',
    'plan_disabled',
    'refresh_not_ready',
    'invalid_grant',
    'invalid_refresh_token',
    'token_expired',
    'refresh_token_expired',
    'refresh_token_invalidated',
    'refresh_token_reused',
    'native_error',
    'internal_error',
  };
  static const _nativePhases = {
    'start_login',
    'read_account',
    'logout',
    'login_status',
    'cancel_login',
  };

  factory ChatGptOAuthFailure.fromNativeCode(Object? code, String phase) =>
      ChatGptOAuthFailure(
        code: _nativeCodes.contains(code) ? code as String : 'native_error',
        phase: phase,
      );

  factory ChatGptOAuthFailure.fromError(
    Object error, {
    required String phase,
    String fallbackCode = 'native_error',
  }) {
    if (error is ChatGptOAuthFailure) return error;
    if (error is MissingPluginException) {
      return ChatGptOAuthFailure(
        code: phase == 'open_browser'
            ? 'browser_unavailable'
            : 'native_unavailable',
        phase: phase,
      );
    }
    if (error is PlatformException && error.code == 'CHATGPT_AUTH_ERROR') {
      final details = error.details;
      final nativeCode = details is Map ? details['errorCode'] : null;
      final nativePhase = details is Map ? details['phase'] : null;
      return ChatGptOAuthFailure.fromNativeCode(
        nativeCode,
        _nativePhases.contains(nativePhase) ? nativePhase as String : phase,
      );
    }
    return ChatGptOAuthFailure(code: fallbackCode, phase: phase);
  }

  bool get isStorageFailure =>
      code == 'secure_storage_unavailable' ||
      code == 'secure_storage_invalid_format';

  String get diagnostic => '$phase / $code';

  // Arabic-only: the `english` parameter is kept for API compatibility
  // (callers pass `english:`) and is ignored.
  String message({required bool english}) {
    return switch (code) {
      'secure_storage_unavailable' || 'secure_storage_invalid_format' => 'التخزين الآمن المحلي لبيانات الاعتماد غير متاح. حدّث التطبيق وأعد تشغيله ثم حاول مجدداً.',
      'callback_unavailable' || 'callback_failed' => 'تعذّر بدء رد الاتصال المحلي لتسجيل الدخول أو انقطع. حاول تسجيل الدخول مجدداً.',
      'invalid_profile' => 'تغيّر إعداد المزوّد. أعد اختيار مزوّد ChatGPT.',
      'not_initialized' || 'native_unavailable' => 'مكوّن تسجيل الدخول داخل التطبيق غير متاح. حدّث التطبيق وأعد تشغيله.',
      'invalid_authorization_response' => 'أعاد التطبيق رابط تسجيل دخول غير صالح ولم يُفتح المتصفح. حدّث التطبيق وحاول مجدداً.',
      'browser_unavailable' => 'تعذّر فتح متصفح النظام. عيّن متصفحاً افتراضياً وحاول مجدداً.',
      'network_error' => 'تعذّر الاتصال بخدمة تسجيل الدخول في OpenAI. تحقق من الشبكة وحاول مجدداً.',
      'authorization_declined' => 'لم تتم الموافقة على التفويض. أكمل تسجيل الدخول واسمح به في المتصفح.',
      'plan_disabled' => 'الوصول إلى خطة ChatGPT غير مفعّل. أعد التفويض للسماح بالوصول إلى الخطة.',
      'account_mismatch' => 'الحساب المُعاد لا يطابق هذا الإعداد. أضف مزوّداً لحساب آخر.',
      'invalid_identity' ||
      'invalid_state' ||
      'missing_code' ||
      'registration_incomplete' => 'تعذّر التحقق من رد اتصال تسجيل الدخول في OpenAI أو من الهوية. سجّل الدخول مجدداً.',
      'invalid_client' => 'لم تقبل OpenAI تسجيل التطبيق. حدّث التطبيق وحاول مجدداً.',
      'sign_in_required' ||
      'invalid_grant' ||
      'invalid_refresh_token' ||
      'token_expired' ||
      'refresh_token_expired' ||
      'refresh_token_invalidated' ||
      'refresh_token_reused' => 'انتهت صلاحية تفويض ChatGPT أو أُلغي. سجّل الدخول مجدداً.',
      'login_timeout' => 'انتهت مهلة تسجيل الدخول. حاول مجدداً.',
      'login_cancelled' || 'invalid_attempt' => 'أُلغي تسجيل الدخول. حاول مجدداً.',
      'refresh_not_ready' => 'تعذّر تحديث تفويض ChatGPT حالياً. حاول لاحقاً.',
      'profile_save_failed' => 'لم يُحفظ إعداد المزوّد، ولم يبدأ تسجيل الدخول. حاول مجدداً بعد قليل.',
      'profile_refresh_failed' => 'اكتملت عملية الحساب، لكن تعذّر تحديث معلومات المزوّد. أعد فتح هذه الصفحة.',
      'too_many_attempts' => 'هناك محاولات تسجيل دخول كثيرة جداً. حاول مجدداً بعد قليل.',
      'invalid_response' || 'oauth_request_failed' => 'تعذّرت خدمة تسجيل الدخول في OpenAI من إكمال الطلب. حاول مجدداً.',
      _ => switch (phase) {
        'read_account' => 'تعذّرت قراءة حالة حساب ChatGPT المحلي. حاول مجدداً.',
        'logout' => 'تعذّر إكمال تسجيل الخروج. حاول مجدداً.',
        'login_status' => 'تعذّر تأكيد نتيجة تسجيل الدخول إلى ChatGPT. حاول مجدداً.',
        _ => 'تعذّر على التطبيق تجهيز تسجيل الدخول إلى ChatGPT. حدّث التطبيق وأعد تشغيله ثم حاول مجدداً.',
      },
    };
  }

  @override
  String toString() => 'ChatGptOAuthFailure($diagnostic)';
}

/// Public account information only. OAuth credentials remain in native storage.
class ChatGptAccount {
  const ChatGptAccount({
    required this.connected,
    required this.email,
    required this.planEnabled,
    required this.needsReauth,
    this.secureStorageAvailable = true,
    this.errorCode,
  });

  final bool connected;
  final String email;
  final bool planEnabled;
  final bool needsReauth;
  final bool secureStorageAvailable;
  final String? errorCode;

  factory ChatGptAccount.fromMap(Map<dynamic, dynamic>? map) => ChatGptAccount(
    connected: map?['connected'] == true,
    email: (map?['email'] ?? '').toString(),
    planEnabled: map?['planEnabled'] == true,
    needsReauth: map?['needsReauth'] == true,
    secureStorageAvailable: map?['secureStorageAvailable'] != false,
    errorCode: map?['errorCode'] == null
        ? null
        : ChatGptOAuthFailure.fromNativeCode(
            map?['errorCode'],
            'read_account',
          ).code,
  );
}

class ChatGptLoginAttempt {
  const ChatGptLoginAttempt({required this.id, required this.authorizationUrl});

  final String id;
  final Uri authorizationUrl;
}

class ChatGptLoginStatus {
  const ChatGptLoginStatus({required this.status, this.error, this.errorCode});

  final String status;
  final String? error;
  final String? errorCode;
}

class ChatGptOAuthService {
  static const sourceType = 'chatgpt_oauth';
  static const baseUrl = 'https://api.openai.com/v1';

  static Future<Map<String, dynamic>?> _invokeMap(
    String method,
    Map<String, dynamic> arguments,
    String phase,
  ) async {
    try {
      return await AssistsMessageService.assistCore
          .invokeMapMethod<String, dynamic>(method, arguments);
    } catch (error) {
      throw ChatGptOAuthFailure.fromError(error, phase: phase);
    }
  }

  static Future<ChatGptLoginAttempt> startLogin(String profileId) async {
    final result = await _invokeMap('startChatGptLogin', {
      'profileId': profileId,
    }, 'start_login');
    final id = result?['attemptId'] is String
        ? result!['attemptId'] as String
        : '';
    final rawUrl = result?['authUrl'] is String
        ? result!['authUrl'] as String
        : '';
    final url = Uri.tryParse(rawUrl);
    if (id.isEmpty ||
        url == null ||
        url.scheme != 'https' ||
        url.host != 'auth.openai.com' ||
        url.userInfo.isNotEmpty ||
        url.port != 443 ||
        url.hasFragment) {
      if (id.isNotEmpty) {
        // Cancellation failure must not hide the original response-validation
        // phase. The native attempt also owns a bounded timeout.
        try {
          await cancelLogin(id);
        } catch (_) {}
      }
      throw const ChatGptOAuthFailure(
        code: 'invalid_authorization_response',
        phase: 'authorization_response',
      );
    }
    return ChatGptLoginAttempt(id: id, authorizationUrl: url);
  }

  static Future<ChatGptLoginStatus> getLoginStatus(String attemptId) async {
    final result = await _invokeMap('getChatGptLoginStatus', {
      'attemptId': attemptId,
    }, 'login_status');
    return ChatGptLoginStatus(
      status: result?['status']?.toString() ?? 'failed',
      error: result?['error']?.toString(),
      errorCode: result?['errorCode']?.toString(),
    );
  }

  static Future<void> cancelLogin(String attemptId) => AssistsMessageService
      .assistCore
      .invokeMethod<void>('cancelChatGptLogin', {'attemptId': attemptId});

  static Future<ChatGptAccount> getAccount(String profileId) async =>
      ChatGptAccount.fromMap(
        await _invokeMap('getChatGptAccount', {
          'profileId': profileId,
        }, 'read_account'),
      );

  static Future<bool> logout(String profileId) async {
    final result = await _invokeMap('logoutChatGpt', {
      'profileId': profileId,
    }, 'logout');
    return result?['remoteRevocationConfirmed'] == true;
  }
}
