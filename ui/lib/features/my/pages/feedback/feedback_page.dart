import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/services/device_service.dart';
import 'package:ui/services/feedback_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/settings_ui.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, this.service});
  final FeedbackService? service;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _contact = TextEditingController();
  final _cancel = CancelToken();
  late final FeedbackService _service = widget.service ?? FeedbackService();
  List<FeedbackAttachment> _attachments = [];
  Map<String, dynamic>? _version;
  String _accountEmail = '';
  String? _reference;
  FeedbackFailure? _error;
  bool _loading = true;
  bool _picking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final email = FeedbackService.loadAccountEmail();
    final version = await DeviceService.getAppVersion().timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
    final address = await email;
    if (!mounted) return;
    setState(() {
      _version = version;
      _accountEmail = address;
      _loading = false;
      if (_contact.text.isEmpty) _contact.text = address;
    });
  }

  @override
  void dispose() {
    _cancel.cancel();
    _service.close();
    _title.dispose();
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    if (_picking || _sending) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await _service.pickAttachments();
      if (!mounted) return;
      final combined = [..._attachments];
      for (final file in picked) {
        if (!combined.any((item) => item.identifier == file.identifier)) {
          combined.add(file);
        }
      }
      FeedbackService.validateAttachments(combined);
      setState(() => _attachments = combined);
    } on FeedbackException catch (error) {
      if (mounted) setState(() => _error = error.reason);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_loading || _sending || _picking || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final reference = await _service.submit(
        title: _title.text,
        description: _description.text,
        contact: _contact.text,
        accountEmail: _accountEmail,
        languageCode: Localizations.localeOf(context).languageCode,
        versionInfo: _version,
        attachments: _attachments,
        cancelToken: _cancel,
      );
      if (mounted) setState(() => _reference = reference);
    } on FeedbackException catch (error) {
      if (mounted) setState(() => _error = error.reason);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _errorMessage(FeedbackFailure reason) => switch (reason) {
    FeedbackFailure.invalidFields => 'يُرجى إدخال عنوان المشكلة ووصفها، والتحقق من أطوال النصوص.',
    FeedbackFailure.fileCount => 'يمكن إضافة 5 مرفقات كحد أقصى.',
    FeedbackFailure.fileSize => 'يجب ألا يتجاوز كل مرفق 10 ميغابايت.',
    FeedbackFailure.totalSize => 'يجب ألا يتجاوز مجموع المرفقات 25 ميغابايت.',
    FeedbackFailure.unreadableFile => 'تعذّرت قراءة المرفق. يُرجى اختياره مجددًا.',
    FeedbackFailure.rateLimited => 'عدد الإرسالات كبير جدًا. يُرجى إعادة المحاولة لاحقًا.',
    FeedbackFailure.network => 'فشل الإرسال. يُرجى التحقق من الاتصال وإعادة المحاولة. تم الاحتفاظ بما أدخلته.',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: CommonAppBar(
        title: 'أريد إرسال ملاحظات',
        primary: true,
      ),
      body: OmniContentWidth(
        child: SafeArea(
          top: false,
          child: _reference != null
              ? _success()
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'واجهت مشكلة أو لديك اقتراح تحسين؟ أخبرنا.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      OmniSettingsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              key: const ValueKey('feedback-title'),
                              controller: _title,
                              enabled: !_sending,
                              maxLength: 200,
                              textInputAction: TextInputAction.next,
                              decoration: omniSettingsInputDecoration(
                                context,
                                labelText: 'عنوان المشكلة',
                                hintText: 'صِف باختصار المشكلة التي واجهتها',
                              ),
                              validator: (value) =>
                                  value?.trim().isEmpty ?? true
                                  ? 'يُرجى إدخال عنوان المشكلة'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('feedback-description'),
                              controller: _description,
                              enabled: !_sending,
                              maxLength: 10000,
                              minLines: 5,
                              maxLines: 9,
                              decoration: omniSettingsInputDecoration(
                                context,
                                labelText: 'الوصف التفصيلي',
                                hintText: 'ماذا فعلت، وماذا حدث، وماذا توقعت؟',
                              ),
                              validator: (value) =>
                                  value?.trim().isEmpty ?? true
                                  ? 'يُرجى إدخال الوصف التفصيلي'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('feedback-contact'),
                              controller: _contact,
                              enabled: !_sending,
                              maxLength: 300,
                              keyboardType: TextInputType.emailAddress,
                              decoration: omniSettingsInputDecoration(
                                context,
                                labelText: 'بيانات التواصل (اختياري)',
                                hintText: 'البريد الإلكتروني أو أي وسيلة تواصل أخرى',
                              ),
                            ),
                            if (_loading) ...[
                              const SizedBox(height: 8),
                              Text(
                                'جارٍ قراءة معلومات الحساب…',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ] else if (_accountEmail.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'سيُرفق مع الملاحظات بريد حسابك $_accountEmail، ويمكن تعديل بيانات التواصل.',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      OmniSettingsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'المرفقات (اختياري)',
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  key: const ValueKey(
                                    'feedback-add-attachment',
                                  ),
                                  onPressed: _sending || _picking
                                      ? null
                                      : _pickAttachments,
                                  icon: const Icon(
                                    LucideIcons.paperclip,
                                    size: 16,
                                  ),
                                  label: Text('إضافة مرفقات'),
                                ),
                              ],
                            ),
                            Text(
                              'يمكن إضافة لقطات شاشة أو تسجيلات أو سجلات: حتى 5 ملفات، و10 ميغابايت لكل ملف، و25 ميغابايت في المجموع.',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            for (final file in _attachments)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(LucideIcons.file, size: 20),
                                title: Text(
                                  file.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${(file.size / 1024).ceil()} KB',
                                ),
                                trailing: IconButton(
                                  tooltip: 'إزالة المرفق',
                                  onPressed: _sending
                                      ? null
                                      : () => setState(
                                          () => _attachments.remove(file),
                                        ),
                                  icon: const Icon(LucideIcons.x, size: 18),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _errorMessage(_error!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            semanticsLabel: _errorMessage(_error!),
                          ),
                        ),
                      const SizedBox(height: 22),
                      FilledButton(
                        key: const ValueKey('feedback-submit'),
                        onPressed: _loading || _sending || _picking
                            ? null
                            : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accentPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('إرسال الملاحظات'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _success() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.circleCheck,
            color: context.omniPalette.accentPrimary,
            size: 44,
          ),
          const SizedBox(height: 20),
          Text(
            'تم استلام ملاحظاتك',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'شكرًا لك. احفظ الرقم المرجعي للتواصل لاحقًا.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SelectableText(
            _reference!,
            key: const ValueKey('feedback-reference'),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => setState(() {
              _reference = null;
              _title.clear();
              _description.clear();
              _contact.text = _accountEmail;
              _attachments = [];
              _error = null;
            }),
            child: Text('إرسال ملاحظات أخرى'),
          ),
        ],
      ),
    ),
  );
}
