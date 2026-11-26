import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/services/web_tools_config_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/flclash/page_activity.dart';
import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/widgets/settings_section_title.dart';
import 'package:ui/widgets/settings_ui.dart';

class WebToolsSettingPage extends StatefulWidget {
  const WebToolsSettingPage({super.key});

  @override
  State<WebToolsSettingPage> createState() => _WebToolsSettingPageState();
}

class _WebToolsSettingPageState extends State<WebToolsSettingPage>
    with FlClashPageLoadMixin {
  bool _loading = true;
  bool _saving = false;
  bool _hasProviderDeepSeekKey = false;
  String _providerDeepSeekBaseUrl = '';

  WebToolBackend _searchBackend = WebToolBackend.builtin;
  WebToolBackend _fetchBackend = WebToolBackend.builtin;
  WebHttpMethod _customSearchMethod = WebHttpMethod.post;
  WebHttpMethod _customFetchMethod = WebHttpMethod.post;

  bool _obscureDeepSeekKey = true;
  bool _obscureCustomSearchKey = true;
  bool _obscureCustomFetchKey = true;
  bool _showCustomSearchAdvanced = false;
  bool _showCustomFetchAdvanced = false;

  final _deepSeekBaseUrlController = TextEditingController(
    text: WebToolsConfig.defaultDeepSeekBaseUrl,
  );
  final _deepSeekApiKeyController = TextEditingController();

  final _customSearchUrlController = TextEditingController();
  final _customSearchApiKeyController = TextEditingController();
  final _customSearchBodyController = TextEditingController(
    text: CustomWebSearchConfig.defaultBodyTemplate,
  );
  final _customSearchResultsPathController = TextEditingController(
    text: CustomWebSearchConfig.defaultResultsPath,
  );
  final _customSearchTitleFieldController = TextEditingController(
    text: CustomWebSearchConfig.defaultTitleField,
  );
  final _customSearchUrlFieldController = TextEditingController(
    text: CustomWebSearchConfig.defaultUrlField,
  );
  final _customSearchSnippetFieldController = TextEditingController(
    text: CustomWebSearchConfig.defaultSnippetField,
  );
  final _customSearchHeadersController = TextEditingController();

  final _customFetchUrlController = TextEditingController();
  final _customFetchApiKeyController = TextEditingController();
  final _customFetchBodyController = TextEditingController(
    text: CustomWebFetchConfig.defaultBodyTemplate,
  );
  final _customFetchContentFieldController = TextEditingController(
    text: CustomWebFetchConfig.defaultContentField,
  );
  final _customFetchTitleFieldController = TextEditingController(
    text: CustomWebFetchConfig.defaultTitleField,
  );
  final _customFetchHeadersController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deepSeekBaseUrlController.dispose();
    _deepSeekApiKeyController.dispose();
    _customSearchUrlController.dispose();
    _customSearchApiKeyController.dispose();
    _customSearchBodyController.dispose();
    _customSearchResultsPathController.dispose();
    _customSearchTitleFieldController.dispose();
    _customSearchUrlFieldController.dispose();
    _customSearchSnippetFieldController.dispose();
    _customSearchHeadersController.dispose();
    _customFetchUrlController.dispose();
    _customFetchApiKeyController.dispose();
    _customFetchBodyController.dispose();
    _customFetchContentFieldController.dispose();
    _customFetchTitleFieldController.dispose();
    _customFetchHeadersController.dispose();
    super.dispose();
  }

  Future<void> _load() => runPageLoad(#webToolsLoad, () async {
    if (!await waitForPageReady() || !mounted) return;
    setState(() => _loading = true);
    try {
      final config = await WebToolsConfigService.getConfig();
      if (!await waitForPageReady() ||
          !mounted ||
          !pageLoadIsCurrent(#webToolsLoad)) {
        return;
      }
      _applyConfig(config);
    } catch (_) {
      if (mounted) {
        showToast(
          'تعذّر تحميل إعدادات أدوات الويب',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  });

  void _applyConfig(WebToolsConfig config) {
    setState(() {
      _searchBackend = config.searchBackend;
      _fetchBackend = config.fetchBackend;
      _hasProviderDeepSeekKey = config.hasProviderDeepSeekKey;
      _providerDeepSeekBaseUrl = config.providerDeepSeekBaseUrl;
      _deepSeekBaseUrlController.text = config.deepSeekBaseUrl;
      _deepSeekApiKeyController.text = config.deepSeekApiKey;

      _customSearchMethod = config.customSearch.method;
      _customSearchUrlController.text = config.customSearch.url;
      _customSearchApiKeyController.text = config.customSearch.apiKey;
      _customSearchBodyController.text = config.customSearch.bodyTemplate;
      _customSearchResultsPathController.text = config.customSearch.resultsPath;
      _customSearchTitleFieldController.text = config.customSearch.titleField;
      _customSearchUrlFieldController.text = config.customSearch.urlField;
      _customSearchSnippetFieldController.text =
          config.customSearch.snippetField;
      _customSearchHeadersController.text = config.customSearch.headersText;

      _customFetchMethod = config.customFetch.method;
      _customFetchUrlController.text = config.customFetch.url;
      _customFetchApiKeyController.text = config.customFetch.apiKey;
      _customFetchBodyController.text = config.customFetch.bodyTemplate;
      _customFetchContentFieldController.text = config.customFetch.contentField;
      _customFetchTitleFieldController.text = config.customFetch.titleField;
      _customFetchHeadersController.text = config.customFetch.headersText;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final next = WebToolsConfig(
        searchBackend: _searchBackend,
        fetchBackend: _fetchBackend,
        deepSeekBaseUrl: _deepSeekBaseUrlController.text.trim(),
        deepSeekApiKey: _deepSeekApiKeyController.text.trim(),
        customSearch: CustomWebSearchConfig(
          method: _customSearchMethod,
          url: _customSearchUrlController.text.trim(),
          headersText: _customSearchHeadersController.text.trim(),
          bodyTemplate: _customSearchBodyController.text.trim(),
          resultsPath: _customSearchResultsPathController.text.trim(),
          titleField: _customSearchTitleFieldController.text.trim(),
          urlField: _customSearchUrlFieldController.text.trim(),
          snippetField: _customSearchSnippetFieldController.text.trim(),
          apiKey: _customSearchApiKeyController.text.trim(),
        ),
        customFetch: CustomWebFetchConfig(
          method: _customFetchMethod,
          url: _customFetchUrlController.text.trim(),
          headersText: _customFetchHeadersController.text.trim(),
          bodyTemplate: _customFetchBodyController.text.trim(),
          contentField: _customFetchContentFieldController.text.trim(),
          titleField: _customFetchTitleFieldController.text.trim(),
          apiKey: _customFetchApiKeyController.text.trim(),
        ),
      );
      final saved = await WebToolsConfigService.saveConfig(next);
      if (!mounted) return;
      _applyConfig(saved);
      showToast('تم الحفظ', type: ToastType.success);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = e.message?.trim();
      showToast(
        (message != null && message.isNotEmpty)
            ? message
            : 'فشل الحفظ',
        type: ToastType.error,
      );
    } catch (_) {
      if (!mounted) return;
      showToast('فشل الحفظ', type: ToastType.error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _searchBackendLabel(WebToolBackend backend) => switch (backend) {
    WebToolBackend.builtin => 'مدمج (DuckDuckGo)',
    WebToolBackend.deepseek => 'DeepSeek',
    WebToolBackend.custom => 'واجهة مخصصة',
  };

  String _fetchBackendLabel(WebToolBackend backend) => switch (backend) {
    WebToolBackend.builtin => 'مدمج (ثابت)',
    WebToolBackend.deepseek => 'DeepSeek',
    WebToolBackend.custom => 'واجهة مخصصة',
  };

  List<OmniSettingsOption<WebToolBackend>> _backendOptions({
    required bool isSearch,
  }) => [
    for (final b in WebToolBackend.values)
      OmniSettingsOption(
        value: b,
        label: isSearch ? _searchBackendLabel(b) : _fetchBackendLabel(b),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final usesDeepSeek =
        _searchBackend == WebToolBackend.deepseek ||
        _fetchBackend == WebToolBackend.deepseek;
    final usesRemote =
        _searchBackend != WebToolBackend.builtin ||
        _fetchBackend != WebToolBackend.builtin;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: CommonAppBar(
        title: 'بحث الويب والقراءة',
        primary: true,
      ),
      body: OmniContentWidth(
        child: SafeArea(
          top: false,
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: edgeToEdgeScrollPadding(
                    context,
                    const EdgeInsets.fromLTRB(22, 12, 22, 32),
                  ),
                  children: [
                    OmniSettingsGroup(
                      title: 'الخدمات',
                      translateTitle: false,
                      dividerIndent: 18,
                      footer: Text(
                        usesRemote
                            ? 'عند الفشل يعود الجلب عن بُعد تلقائياً إلى الجلب الثابت المحلي. ويعيد ترقيم الصفحات استخدام لقطة التشغيل الحالية.'
                            : 'الوضع المدمج يعمل مباشرة دون إعداد. بدّل إلى DeepSeek أو نقطة نهاية مخصصة لجودة بحث أفضل واستخراج Markdown.',
                      ),
                      children: [
                        OmniSettingsTile(
                          icon: LucideIcons.search,
                          title: 'بحث الويب (web_search)',
                          translateText: false,
                          trailing: OmniSettingsDropdown<WebToolBackend>(
                            dropdownKey: const Key('web-tools-search-backend'),
                            value: _searchBackend,
                            selectedLabel: _searchBackendLabel(_searchBackend),
                            options: _backendOptions(isSearch: true),
                            maxWidth: 180,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _searchBackend = value);
                              }
                            },
                          ),
                        ),
                        OmniSettingsTile(
                          icon: LucideIcons.fileText,
                          title: 'قراءة الويب (web_fetch)',
                          translateText: false,
                          trailing: OmniSettingsDropdown<WebToolBackend>(
                            dropdownKey: const Key('web-tools-fetch-backend'),
                            value: _fetchBackend,
                            selectedLabel: _fetchBackendLabel(_fetchBackend),
                            options: _backendOptions(isSearch: false),
                            maxWidth: 180,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _fetchBackend = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (usesDeepSeek) ...[
                      const SizedBox(height: 22),
                      _buildDeepSeekSection(context),
                    ],
                    if (_searchBackend == WebToolBackend.custom) ...[
                      const SizedBox(height: 22),
                      _buildCustomSearchSection(context),
                    ],
                    if (_fetchBackend == WebToolBackend.custom) ...[
                      const SizedBox(height: 22),
                      _buildCustomFetchSection(context),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('web-tools-save-button'),
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accentPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('حفظ'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDeepSeekSection(BuildContext context) {
    final palette = context.omniPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(
          label: 'DeepSeek',
          subtitle: _hasProviderDeepSeekKey
              ? 'مرتبط تلقائياً بمفتاح DeepSeek API في «مزودي النماذج»؛ ويمكنك تجاوزه هنا.'
              : 'يستدعي /v1/tools/search و /v1/tools/fetch من DeepSeek. اترك مفتاح API فارغاً لإعادة استخدام مفتاح مزود DeepSeek.',
        ),
        OmniSettingsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasProviderDeepSeekKey) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OmniSettingsStatusBadge(
                    label: _providerDeepSeekBaseUrl.isNotEmpty
                        ? 'مرتبط بمزود DeepSeek ($_providerDeepSeekBaseUrl)'
                        : 'مرتبط بمزود نماذج DeepSeek',
                    color: const Color(0xFF2F8F4E),
                  ),
                ),
              ],
              TextField(
                key: const Key('web-tools-deepseek-base-url'),
                controller: _deepSeekBaseUrlController,
                keyboardType: TextInputType.url,
                style: context.omniInputTextStyle,
                decoration: omniSettingsInputDecoration(
                  context,
                  labelText: 'عنوان الواجهة (Base URL)',
                  hintText: WebToolsConfig.defaultDeepSeekBaseUrl,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('web-tools-deepseek-api-key'),
                controller: _deepSeekApiKeyController,
                obscureText: _obscureDeepSeekKey,
                style: context.omniInputTextStyle,
                decoration: omniSettingsInputDecoration(
                  context,
                  labelText: 'مفتاح API (اختياري)',
                  hintText: _hasProviderDeepSeekKey
                      ? 'اتركه فارغاً لإعادة استخدام مفتاح المزود'
                      : 'sk-xxxx',
                  suffixIcon: IconButton(
                    splashRadius: 18,
                    onPressed: () => setState(
                      () => _obscureDeepSeekKey = !_obscureDeepSeekKey,
                    ),
                    icon: Icon(
                      _obscureDeepSeekKey
                          ? LucideIcons.eyeOff
                          : LucideIcons.eye,
                      color: palette.textTertiary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomSearchSection(BuildContext context) {
    final palette = context.omniPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(
          label: 'بحث مخصص',
          subtitle: 'يدعم العناصر النائبة {{query}} و{{query_json}} و{{count}}. يرسل ترويسة Bearer Auth عند توفير مفتاح API.',
        ),
        OmniSettingsGroup(
          dividerIndent: 18,
          children: [
            OmniSettingsTile(
              title: 'طريقة HTTP',
              translateText: false,
              trailing: OmniSettingsDropdown<WebHttpMethod>(
                value: _customSearchMethod,
                selectedLabel: _customSearchMethod.wireName,
                options: const [
                  OmniSettingsOption(value: WebHttpMethod.post, label: 'POST'),
                  OmniSettingsOption(value: WebHttpMethod.get, label: 'GET'),
                ],
                onChanged: (method) {
                  if (method != null) {
                    setState(() => _customSearchMethod = method);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OmniSettingsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _customSearchUrlController,
                keyboardType: TextInputType.url,
                style: context.omniInputTextStyle,
                decoration: omniSettingsInputDecoration(
                  context,
                  labelText: 'رابط نقطة النهاية',
                  hintText: 'https://api.example.com/search',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customSearchApiKeyController,
                obscureText: _obscureCustomSearchKey,
                style: context.omniInputTextStyle,
                decoration: omniSettingsInputDecoration(
                  context,
                  labelText: 'مفتاح API (اختياري)',
                  suffixIcon: IconButton(
                    splashRadius: 18,
                    onPressed: () => setState(
                      () => _obscureCustomSearchKey = !_obscureCustomSearchKey,
                    ),
                    icon: Icon(
                      _obscureCustomSearchKey
                          ? LucideIcons.eyeOff
                          : LucideIcons.eye,
                      color: palette.textTertiary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(
                  () => _showCustomSearchAdvanced = !_showCustomSearchAdvanced,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'قالب الطلب وربط الحقول',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: palette.accentPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        _showCustomSearchAdvanced
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 16,
                        color: palette.accentPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showCustomSearchAdvanced) ...[
                const SizedBox(height: 10),
                if (_customSearchMethod == WebHttpMethod.post) ...[
                  TextField(
                    controller: _customSearchBodyController,
                    maxLines: 3,
                    minLines: 2,
                    style: context.omniInputTextStyle,
                    decoration: omniSettingsInputDecoration(
                      context,
                      labelText: 'قالب جسم الطلب (JSON)',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _customSearchResultsPathController,
                  style: context.omniInputTextStyle,
                  decoration: omniSettingsInputDecoration(
                    context,
                    labelText: 'مسار مصفوفة النتائج',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customSearchTitleFieldController,
                  style: context.omniInputTextStyle,
                  decoration: omniSettingsInputDecoration(
                    context,
                    labelText: 'حقل العنوان',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customSearchUrlFieldController,
                  style: context.omniInputTextStyle,
                  decoration: omniSettingsInputDecoration(
                    context,
                    labelText: 'حقل الرابط',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customSearchSnippetFieldController,
                  style: context.omniInputTextStyle,
                  decoration: omniSettingsInputDecoration(
                    context,
                    labelText: 'حقل المقتطف',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customSearchHeadersController,
                  maxLines: 4,
                  minLines: 2,
                  style: context.omniInputTextStyle,
                  decoration: omniSettingsInputDecoration(
                    context,
                    labelText: 'ترويسات مخصصة (اختياري، ترويسة: قيمة في كل سطر)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFetchSection(BuildContext context) {
    final palette = context.omniPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(
          label: 'قراءة مخصصة',
          subtitle: 'يدعم العناصر النائبة {{url}} و{{raw_url}} و{{url_json}}. يعود إلى الجلب الثابت عند الفشل.',
        ),
        OmniSettingsGroup(
          dividerIndent: 18,
          children: [
            OmniSettingsTile(
              title: 'طريقة HTTP',
              translateText: false,
              trailing: OmniSettingsDropdown<WebHttpMethod>(
                value: _customFetchMethod,
                selectedLabel: _customFetchMethod.wireName,
                options: const [
                  OmniSettingsOption(value: WebHttpMethod.post, label: 'POST'),
                  OmniSettingsOption(value: WebHttpMethod.get, label: 'GET'),
                ],
                onChanged: (method) {
                  if (method != null) {
                    setState(() => _customFetchMethod = method);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OmniSettingsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _customFetchUrlController,
                keyboardType: TextInputType.url,
                style: context.omniInputTextStyle,
                decoration: omniSettingsInputDecoration(
                  context,
                  labelText: 'رابط نقطة النهاية',
                  hintText: 'https://api.example.com/fetch',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customFetchApiKeyController,
                obscureText: _obscureCustomFetchKey,
                style: context.omniInputTextStyle,
                decoration: omniSettingsInputDecoration(
                  context,
                  labelText: 'مفتاح API (اختياري)',
                  suffixIcon: IconButton(
                    splashRadius: 18,
                    onPressed: () => setState(
                      () => _obscureCustomFetchKey = !_obscureCustomFetchKey,
                    ),
                    icon: Icon(
                      _obscureCustomFetchKey
                          ? LucideIcons.eyeOff
                          : LucideIcons.eye,
                      color: palette.textTertiary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(
                  () => _showCustomFetchAdvanced = !_showCustomFetchAdvanced,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'قالب الطلب وربط الحقول',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: palette.accentPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        _showCustomFetchAdvanced
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 16,
                        color: palette.accentPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showCustomFetchAdvanced) ...[
                const SizedBox(height: 10),
                if (_customFetchMethod == WebHttpMethod.post) ...[
                  TextField(
                    controller: _customFetchBodyController,
                    maxLines: 3,
                    minLines: 2,
                    style: context.omniInputTextStyle,
                    decoration: omniSettingsInputDecoration(
                      context,
                      labelText: 'قالب جسم الطلب (JSON)',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _customFetchContentFieldController,
                  style: context.omniInputTextStyle,
                  decoration: omniSettingsInputDecoration(
                    context,
                    labelText: 'مسار حقل المحتوى (فارغ = نص الاستجابة الخام)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customFetchTitleFieldController,
                  style: context.omniInputTextStyle,
                  decoration: omniSettingsInputDecoration(
                    context,
                    labelText: 'حقل العنوان',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customFetchHeadersController,
                  maxLines: 4,
                  minLines: 2,
                  style: context.omniInputTextStyle,
                  decoration: omniSettingsInputDecoration(
                    context,
                    labelText: 'ترويسات مخصصة (اختياري، ترويسة: قيمة في كل سطر)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
