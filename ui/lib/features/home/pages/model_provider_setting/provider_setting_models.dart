import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/services/builtin_official_provider_catalog.dart';
import 'package:ui/services/chatgpt_oauth_service.dart';
import 'package:ui/services/model_provider_config_service.dart';
import 'package:ui/services/model_vendor_catalog.dart';
import 'package:ui/widgets/omni_menu.dart';

OmniPopupMenuItem<String> buildProviderActionMenuItem({
  Key? key,
  required String value,
  required IconData icon,
  required String label,
  bool enabled = true,
  bool destructive = false,
}) {
  return OmniPopupMenuItem<String>(
    key: key,
    value: value,
    enabled: enabled,
    destructive: destructive,
    child: Row(
      children: [
        Icon(icon, size: OmniMenuStyle.iconSize),
        const SizedBox(width: OmniMenuStyle.iconGap),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

enum ProviderDetailTab { connection, models }

enum ProviderModelSource { manual, remote }

enum ProviderSaveState { idle, dirty, saving, saved, failed }

enum ModelTestStatus { untested, testing, passed, failed }

class ModelTestState {
  const ModelTestState({
    this.status = ModelTestStatus.untested,
    this.message,
    this.diagnosis,
    this.statusCode,
  });

  final ModelTestStatus status;
  final String? message;
  final ProviderErrorDiagnosis? diagnosis;
  final int? statusCode;
}

/// Four supported wire interfaces for custom and compatible connections.
enum ProviderWireProtocol {
  openAiChatCompletions(
    value: 'openai_chat_completions',
    protocolType: 'openai_compatible',
    wireApi: 'chat_completions',
    label: 'OpenAI Chat Completions',
    shortLabel: 'Chat Completions',
  ),
  openAiResponses(
    value: 'openai_responses',
    protocolType: 'openai_compatible',
    wireApi: 'responses',
    label: 'OpenAI Responses',
    shortLabel: 'Responses',
  ),
  anthropicMessages(
    value: 'anthropic_messages',
    protocolType: 'anthropic',
    wireApi: 'chat_completions',
    label: 'Anthropic Messages',
    shortLabel: 'Anthropic Messages',
  ),
  geminiInteractions(
    value: 'gemini_interactions',
    protocolType: 'gemini_interactions',
    wireApi: 'chat_completions',
    label: 'Gemini Interactions',
    shortLabel: 'Gemini Interactions',
  );

  const ProviderWireProtocol({
    required this.value,
    required this.protocolType,
    required this.wireApi,
    required this.label,
    required this.shortLabel,
  });

  final String value;
  final String protocolType;
  final String wireApi;
  final String label;
  final String shortLabel;

  static ProviderWireProtocol fromProfile({
    required String protocolType,
    required String wireApi,
  }) {
    final normalizedProtocol = protocolType.trim().toLowerCase();
    final normalizedWire = wireApi.trim().toLowerCase();
    if (normalizedProtocol == 'gemini_interactions') {
      return ProviderWireProtocol.geminiInteractions;
    }
    if (normalizedProtocol == 'anthropic') {
      return ProviderWireProtocol.anthropicMessages;
    }
    if (normalizedProtocol == 'openai_compatible' &&
        normalizedWire == 'responses') {
      return ProviderWireProtocol.openAiResponses;
    }
    return ProviderWireProtocol.openAiChatCompletions;
  }
}

class ProviderPresetOption {
  const ProviderPresetOption({
    required this.value,
    required this.label,
    this.labelEn,
    required this.sourceType,
    required this.protocolType,
    required this.wireApi,
    this.baseUrl = '',
    this.defaultName = '',
    this.defaultNameEn,
    this.vendorKey,
    this.requiresCredentials = false,
    this.isCustom = false,
  });

  final String value;
  final String label;
  final String? labelEn;
  final String sourceType;
  final String baseUrl;
  final String defaultName;
  final String? defaultNameEn;
  final String protocolType;
  final String wireApi;
  final String? vendorKey;
  final bool requiresCredentials;
  final bool isCustom;

  bool get isChatGptOAuth => sourceType == ChatGptOAuthService.sourceType;

  String displayLabel({required bool english}) =>
      english && labelEn != null ? labelEn! : label;

  String resolvedDefaultName({required bool english}) {
    if (english && defaultNameEn != null && defaultNameEn!.isNotEmpty) {
      return defaultNameEn!;
    }
    if (defaultName.isNotEmpty) {
      return defaultName;
    }
    return displayLabel(english: english);
  }

  ProviderWireProtocol get wireProtocol => ProviderWireProtocol.fromProfile(
    protocolType: protocolType,
    wireApi: wireApi,
  );
}

/// Presets shown in the provider pickers: Gemini, OpenAI and custom only.
/// The full [kProviderPresets] list stays intact so existing profiles
/// (DeepSeek, Anthropic, Kimi, MiniMax, ...) still resolve and keep working.
const List<String> kVisibleProviderPresetValues = <String>[
  'gemini_interactions',
  'openai_compatible',
  'custom',
];

List<ProviderPresetOption> get visibleProviderPresets =>
    kProviderPresets
        .where((preset) => kVisibleProviderPresetValues.contains(preset.value))
        .toList(growable: false);

/// Wire protocols offered in the picker: Anthropic Messages is hidden
/// (unused); OpenAI Chat/Responses and Gemini stay available.
List<ProviderWireProtocol> get visibleWireProtocols =>
    ProviderWireProtocol.values
        .where((protocol) => protocol != ProviderWireProtocol.anthropicMessages)
        .toList(growable: false);

const List<ProviderPresetOption> kProviderPresets = <ProviderPresetOption>[
  ProviderPresetOption(
    value: 'gemini_interactions',
    label: 'Gemini',
    sourceType: 'custom',
    baseUrl: 'https://generativelanguage.googleapis.com/v1',
    defaultName: 'Gemini',
    protocolType: 'gemini_interactions',
    wireApi: 'chat_completions',
    vendorKey: 'google',
    requiresCredentials: true,
  ),
  ProviderPresetOption(
    value: ChatGptOAuthService.sourceType,
    label: 'ChatGPT',
    sourceType: ChatGptOAuthService.sourceType,
    baseUrl: ChatGptOAuthService.baseUrl,
    defaultName: 'ChatGPT',
    protocolType: 'openai_compatible',
    wireApi: 'responses',
    vendorKey: 'openai',
  ),
  ProviderPresetOption(
    value: 'deepseek',
    label: 'DeepSeek',
    sourceType: 'deepseek',
    baseUrl: 'https://api.deepseek.com',
    defaultName: 'DeepSeek',
    protocolType: 'deepseek',
    wireApi: 'chat_completions',
    vendorKey: 'deepseek',
    requiresCredentials: true,
  ),
  ProviderPresetOption(
    value: 'mimo',
    label: 'Mimo',
    sourceType: 'mimo',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    defaultName: 'Mimo',
    protocolType: 'openai_compatible',
    wireApi: 'chat_completions',
    vendorKey: 'xiaomi',
    requiresCredentials: true,
  ),
  ProviderPresetOption(
    value: 'moonshot',
    label: 'Kimi',
    sourceType: 'moonshot',
    baseUrl: 'https://api.moonshot.cn/v1',
    defaultName: 'Kimi',
    protocolType: 'openai_compatible',
    wireApi: 'chat_completions',
    vendorKey: 'moonshot',
    requiresCredentials: true,
  ),
  ProviderPresetOption(
    value: 'minimax',
    label: 'MiniMax',
    sourceType: 'minimax',
    baseUrl: 'https://api.minimaxi.com/v1',
    defaultName: 'MiniMax',
    protocolType: 'openai_compatible',
    wireApi: 'chat_completions',
    vendorKey: 'minimax',
    requiresCredentials: true,
  ),
  ProviderPresetOption(
    value: 'bailian',
    label: 'علي بابا بايليان',
    sourceType: 'bailian',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultName: 'علي بابا بايليان',
    protocolType: 'openai_compatible',
    wireApi: 'chat_completions',
    vendorKey: 'alibaba',
    requiresCredentials: true,
  ),
  ProviderPresetOption(
    value: 'openai_compatible',
    label: 'OpenAI',
    sourceType: 'custom',
    baseUrl: 'https://api.openai.com/v1',
    defaultName: 'OpenAI',
    protocolType: 'openai_compatible',
    wireApi: 'chat_completions',
    vendorKey: 'openai',
  ),
  ProviderPresetOption(
    value: 'anthropic',
    label: 'Anthropic',
    sourceType: 'custom',
    baseUrl: 'https://api.anthropic.com',
    defaultName: 'Anthropic',
    protocolType: 'anthropic',
    wireApi: 'chat_completions',
    vendorKey: 'anthropic',
  ),
  ProviderPresetOption(
    value: 'custom',
    label: 'مزوّد مخصص',
    labelEn: 'مزوّد مخصص',
    sourceType: 'custom',
    baseUrl: '',
    defaultName: 'مزوّد مخصص',
    defaultNameEn: 'مزوّد مخصص',
    protocolType: 'openai_compatible',
    wireApi: 'chat_completions',
    isCustom: true,
  ),
];

ProviderPresetOption resolvePresetForValues({
  required String sourceType,
  required String protocolType,
  required String wireApi,
  String baseUrl = '',
  String? explicitPresetValue,
}) {
  if (explicitPresetValue != null) {
    for (final option in kProviderPresets) {
      if (option.value == explicitPresetValue) {
        return option;
      }
    }
  }
  if (sourceType == ChatGptOAuthService.sourceType) {
    return kProviderPresets.firstWhere(
      (item) => item.value == ChatGptOAuthService.sourceType,
    );
  }
  final official = BuiltinOfficialProviderCatalog.findByKey(sourceType);
  if (official != null) {
    return kProviderPresets.firstWhere(
      (item) => item.value == official.key,
      orElse: () => kProviderPresets.first,
    );
  }
  if (protocolType == 'deepseek') {
    return kProviderPresets.firstWhere((item) => item.value == 'deepseek');
  }
  if (protocolType == 'gemini_interactions') {
    return kProviderPresets.firstWhere(
      (item) => item.value == 'gemini_interactions',
    );
  }
  if (protocolType == 'anthropic') {
    return kProviderPresets.firstWhere((item) => item.value == 'anthropic');
  }
  return kProviderPresets.firstWhere(
    (item) => item.value == 'openai_compatible',
  );
}

bool isDefaultPresetName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return true;
  if (RegExp(r'^Provider\s+\d+$', caseSensitive: false).hasMatch(trimmed) ||
      RegExp(r'^自定义服务商(?:\s*\d+)?$').hasMatch(trimmed) ||
      RegExp(r'^مزوّد مخصص(?:\s*\d+)?$').hasMatch(trimmed) ||
      RegExp(
        r'^Custom Provider(?:\s*\d+)?$',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
    return true;
  }
  for (final preset in kProviderPresets) {
    if (trimmed.toLowerCase() == preset.label.toLowerCase() ||
        trimmed.toLowerCase() == preset.defaultName.toLowerCase() ||
        (preset.labelEn != null &&
            trimmed.toLowerCase() == preset.labelEn!.toLowerCase()) ||
        (preset.defaultNameEn != null &&
            trimmed.toLowerCase() == preset.defaultNameEn!.toLowerCase())) {
      return true;
    }
  }
  return false;
}

class ProviderModelItem {
  const ProviderModelItem({required this.model, required this.source});

  final ProviderModelOption model;
  final ProviderModelSource source;

  String get id => model.id;
}

class EditableHeaderEntry {
  EditableHeaderEntry({required this.id, String name = '', String value = ''})
    : nameController = TextEditingController(text: name),
      valueController = TextEditingController(text: value);

  final int id;
  final TextEditingController nameController;
  final TextEditingController valueController;
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode valueFocusNode = FocusNode();

  void dispose() {
    nameController.dispose();
    valueController.dispose();
    nameFocusNode.dispose();
    valueFocusNode.dispose();
  }
}

enum ProviderErrorCategory { auth, address, network, quota, model, general }

class ProviderErrorDiagnosis {
  const ProviderErrorDiagnosis({
    required this.category,
    required this.categoryLabel,
    required this.summary,
    required this.hint,
    this.technicalDetail,
  });

  final ProviderErrorCategory category;
  final String categoryLabel;
  final String summary;
  final String hint;
  final String? technicalDetail;

  static ProviderErrorDiagnosis analyze(
    Object? error, {
    required bool english,
    String? fallbackSummary,
    int? statusCode,
  }) {
    String? failureKind;
    String? errorCode;
    final rawMessage = error is PlatformException
        ? error.message
        : error?.toString();
    if (error is PlatformException) {
      errorCode = error.code;
      if (error.details is Map) {
        failureKind = (error.details as Map)['failureKind']?.toString().trim();
      }
    }
    final raw = (rawMessage ?? '').toLowerCase();
    final httpMatch = RegExp(r'\b([1-5]\d{2})\b').firstMatch(raw);
    final resolvedCode =
        statusCode ?? int.tryParse(httpMatch?.group(1) ?? '');

    final formattedSummary = formatAgentRuntimeErrorForUser(
      error,
      english: english,
      fallback:
          fallbackSummary ??
          'تعذّر جلب قائمة النماذج، يرجى التحقق من الإعدادات وإعادة المحاولة',
    );

    ProviderErrorCategory category = ProviderErrorCategory.general;
    if (failureKind == 'provider_authentication_failed' ||
        failureKind == 'provider_unavailable' ||
        resolvedCode == 401 ||
        resolvedCode == 403 ||
        raw.contains('unauthorized') ||
        raw.contains('invalid api key') ||
        raw.contains('authentication') ||
        raw.contains('api key') ||
        raw.contains('密钥') ||
        raw.contains('鉴权') ||
        raw.contains('未授权')) {
      category = ProviderErrorCategory.auth;
    } else if (failureKind == 'provider_tls_certificate_failure' ||
        failureKind == 'provider_request_timeout' ||
        failureKind == 'provider_connection_failed' ||
        raw.contains('timeout') ||
        raw.contains('timed out') ||
        raw.contains('socket') ||
        raw.contains('certificate') ||
        raw.contains('tls') ||
        raw.contains('ssl') ||
        raw.contains('network') ||
        raw.contains('connection refused') ||
        raw.contains('unreachable') ||
        raw.contains('网络') ||
        raw.contains('超时') ||
        raw.contains('连接')) {
      category = ProviderErrorCategory.network;
    } else if (failureKind == 'provider_quota_exceeded' ||
        failureKind == 'provider_rate_limited' ||
        failureKind == 'provider_request_limited' ||
        resolvedCode == 429 ||
        raw.contains('quota') ||
        raw.contains('rate limit') ||
        raw.contains('额度') ||
        raw.contains('余额')) {
      category = ProviderErrorCategory.quota;
    } else if (resolvedCode == 404 ||
        resolvedCode == 405 ||
        raw.contains('not found') ||
        raw.contains('invalid url') ||
        raw.contains('unexpected character') ||
        raw.contains('format') ||
        raw.contains('html') ||
        raw.contains('地址') ||
        raw.contains('路径')) {
      category = ProviderErrorCategory.address;
    } else if (failureKind == 'provider_model_unavailable' ||
        raw.contains('model') ||
        raw.contains('模型')) {
      category = ProviderErrorCategory.model;
    }

    final categoryLabel = switch (category) {
      ProviderErrorCategory.auth => 'فشل المصادقة',
      ProviderErrorCategory.address => 'مشكلة في العنوان أو البروتوكول',
      ProviderErrorCategory.network => 'خطأ في الشبكة',
      ProviderErrorCategory.quota => 'تجاوز الحصة أو حد التكرار',
      ProviderErrorCategory.model => 'النموذج غير متاح',
      ProviderErrorCategory.general => 'فشل الطلب',
    };

    final hint = switch (category) {
      ProviderErrorCategory.auth => 'تحقق من مفتاح API في تبويب «الاتصال»، أو أعد تسجيل الدخول.',
      ProviderErrorCategory.address => 'تحقق من عنوان API وطريقة الاتصال في تبويب «الاتصال».',
      ProviderErrorCategory.network => 'تحقق من اتصال الشبكة ثم أعد المحاولة.',
      ProviderErrorCategory.quota => 'تجاوزت الحصة أو حد التكرار. تحقق من رصيد الحساب أو أعد المحاولة لاحقاً.',
      ProviderErrorCategory.model => 'تأكد أن النموذج مدعوم لدى المزود الحالي.',
      ProviderErrorCategory.general => 'تحقق من العنوان والمفتاح والشبكة ثم أعد المحاولة.',
    };

    final detailParts = <String>[
      if (failureKind != null && failureKind.isNotEmpty) 'kind: $failureKind',
      if (resolvedCode != null) 'HTTP $resolvedCode',
      if (errorCode != null && errorCode.isNotEmpty) 'code: $errorCode',
    ];
    final technicalDetail = detailParts.isEmpty ? null : detailParts.join(' · ');

    return ProviderErrorDiagnosis(
      category: category,
      categoryLabel: categoryLabel,
      summary: formattedSummary,
      hint: hint,
      technicalDetail: technicalDetail,
    );
  }
}

/// Returns true when a profile is the untouched initial placeholder created on
/// a clean install (`profile-1` / `Provider 1` with no URL, key, headers, or models).
bool isUntouchedPlaceholderProfile(
  ModelProviderProfileSummary profile, {
  List<String> manualModelIds = const [],
}) {
  return (profile.id == 'profile-1' || profile.id == 'provider-1') &&
      profile.name.trim() == 'Provider 1' &&
      profile.baseUrl.trim().isEmpty &&
      !profile.hasApiKey &&
      profile.apiKey.trim().isEmpty &&
      !profile.hasCustomHeaders &&
      profile.customHeaders.isEmpty &&
      profile.sourceType == BuiltinOfficialProviderCatalog.customKey &&
      manualModelIds.isEmpty;
}

/// Checks if a profile/draft is missing required connection fields and returns
/// a concise human-readable description of what is missing, or null if complete.
String? describeMissingConfigItem({
  required String sourceType,
  required String baseUrl,
  required bool hasApiKey,
  required bool hasCustomHeaders,
  required bool chatGptReady,
  String? customHeadersError,
  required bool english,
}) {
  if (sourceType == ChatGptOAuthService.sourceType) {
    if (!chatGptReady) {
      return 'يلزم تسجيل الدخول إلى حساب ChatGPT';
    }
    return null;
  }

  final trimmedUrl = baseUrl.trim();
  if (trimmedUrl.isEmpty) {
    return 'عنوان API مفقود';
  }
  if (!ModelProviderConfigService.isValidApiBase(trimmedUrl)) {
    return 'صيغة عنوان API غير صالحة (يجب أن تبدأ بـ http:// أو https://)';
  }
  if (customHeadersError != null && customHeadersError.isNotEmpty) {
    return customHeadersError;
  }

  final requiresKey = const <String>{
    'deepseek',
    'mimo',
    'moonshot',
    'minimax',
    'bailian',
  }.contains(sourceType);
  if (requiresKey && !hasApiKey && !hasCustomHeaders) {
    return 'مفتاح API مفقود';
  }
  return null;
}

bool isProfileConnectionComplete(ModelProviderProfileSummary profile) {
  return describeMissingConfigItem(
        sourceType: profile.sourceType,
        baseUrl: profile.baseUrl,
        hasApiKey: profile.hasApiKey || profile.apiKey.trim().isNotEmpty,
        hasCustomHeaders:
            profile.hasCustomHeaders || profile.customHeaders.isNotEmpty,
        chatGptReady: profile.ready,
        english: false,
      ) ==
      null;
}

String? shortHostFromBaseUrl(String baseUrl) {
  final normalized = ModelProviderConfigService.normalizeApiBase(baseUrl);
  if (normalized == null) return null;
  final clean = normalized.endsWith('#')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  final uri = Uri.tryParse(clean);
  final host = uri?.host.trim() ?? '';
  if (host.isEmpty) return null;
  return uri != null && uri.hasPort ? '$host:${uri.port}' : host;
}

String? buildRequestEndpointPreview({
  required String rawBaseUrl,
  required String protocolType,
  required String wireApi,
}) {
  final input = rawBaseUrl.trim();
  if (input.isEmpty) {
    return null;
  }
  if (protocolType == 'gemini_interactions') {
    return ModelProviderConfigService.buildGeminiInteractionsRequestUrl(input);
  }
  if (protocolType == 'anthropic') {
    return ModelProviderConfigService.buildAnthropicMessagesRequestUrl(input);
  }
  if (protocolType == 'openai_compatible' && wireApi == 'responses') {
    return ModelProviderConfigService.buildResponsesRequestUrl(input);
  }
  return ModelProviderConfigService.buildChatCompletionsRequestUrl(input);
}

String formatCompactTokenLimit(int? value) {
  if (value == null || value <= 0) {
    return '--';
  }
  if (value >= 1000000) {
    final formatted = value % 1000000 == 0
        ? '${value ~/ 1000000}'
        : (value / 1000000).toStringAsFixed(1);
    return '${formatted}M';
  }
  if (value >= 1000) {
    final formatted = value % 1000 == 0
        ? '${value ~/ 1000}'
        : (value / 1000).toStringAsFixed(1);
    return '${formatted}K';
  }
  return value.toString();
}

ModelVendorInfo? resolveVendorForProfile(ModelProviderProfileSummary profile) {
  final preset = resolvePresetForValues(
    sourceType: profile.sourceType,
    protocolType: profile.protocolType,
    wireApi: profile.wireApi,
    baseUrl: profile.baseUrl,
  );
  if (preset.vendorKey != null) {
    final byKey = ModelVendorCatalog.byKey(preset.vendorKey);
    if (byKey != null) return byKey;
  }
  return ModelVendorCatalog.resolve(
    profile.name,
    providerId: profile.sourceType,
    providerName: profile.name,
  );
}

String buildProviderRowSubtitle(
  ModelProviderProfileSummary profile, {
  required int totalModelCount,
  required int visibleChatModelCount,
  required bool english,
}) {
  final parts = <String>[];
  final preset = resolvePresetForValues(
    sourceType: profile.sourceType,
    protocolType: profile.protocolType,
    wireApi: profile.wireApi,
    baseUrl: profile.baseUrl,
  );
  final protocolLabel = profile.sourceType == ChatGptOAuthService.sourceType
      ? 'حساب ChatGPT'
      : preset.wireProtocol.shortLabel;
  final presetLabel = preset.displayLabel(english: english);

  if (profile.name.trim().toLowerCase() != presetLabel.toLowerCase() &&
      !preset.isCustom) {
    parts.add(presetLabel);
  } else {
    parts.add(protocolLabel);
  }

  if (profile.sourceType != ChatGptOAuthService.sourceType) {
    final host = shortHostFromBaseUrl(profile.baseUrl);
    if (host != null && host.isNotEmpty) {
      parts.add(host);
    }
  }

  final missingItem = describeMissingConfigItem(
    sourceType: profile.sourceType,
    baseUrl: profile.baseUrl,
    hasApiKey: profile.hasApiKey || profile.apiKey.trim().isNotEmpty,
    hasCustomHeaders:
        profile.hasCustomHeaders || profile.customHeaders.isNotEmpty,
    chatGptReady: profile.ready,
    english: english,
  );
  if (missingItem != null) {
    parts.add(missingItem);
  } else if (totalModelCount > 0) {
    parts.add('$totalModelCount من النماذج');
  } else {
    parts.add('لا توجد نماذج بعد');
  }

  return parts.join(' · ');
}

String sceneDisplayNameForId(String sceneId, {required bool english}) {
  return switch (sceneId) {
    'scene.dispatch.model' => 'الوكيل',
    'scene.voice' => 'تركيب الصوت',
    'scene.vlm.operation.primary' => 'GUI',
    'scene.compactor.context.chat' => 'ضاغط المحادثة',
    'scene.memory.embedding' => 'تضمين الذاكرة',
    'scene.memory.rollup' => 'تلخيص الذاكرة',
    _ => sceneId,
  };
}
