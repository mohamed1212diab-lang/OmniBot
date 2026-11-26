import 'package:flutter/material.dart';
import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/widgets/omni_segmented_slider.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/features/my/pages/account/account_lifecycle_sheets.dart';
import 'package:ui/services/account_service.dart';
import 'package:ui/services/app_update_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/app_update_dialog.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/settings_detail_sheet.dart';
import 'package:ui/widgets/settings_section_title.dart';
import 'package:ui/widgets/settings_ui.dart';

String formatWeeklyQuotaResetCountdown(DateTime now, {required bool english}) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final nextMonday = startOfToday.add(Duration(days: 8 - now.weekday));
  final remaining = nextMonday.difference(now);
  final totalHours = (remaining.inMinutes / Duration.minutesPerHour).ceil();
  final days = totalHours ~/ Duration.hoursPerDay;
  final hours = totalHours % Duration.hoursPerDay;
  return '$days يوم $hours ساعة';
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key})
    : authOnly = false,
      onAuthenticated = null,
      showAuthHeading = true,
      fitAuthContent = false;

  const AccountPage.authOnly({
    super.key,
    this.onAuthenticated,
    this.showAuthHeading = true,
    this.fitAuthContent = false,
  }) : authOnly = true;

  final bool authOnly;
  final VoidCallback? onAuthenticated;
  final bool showAuthHeading;

  /// Lets an enclosing sheet size to the active form. The sheet owns safe-area
  /// and keyboard insets; full-page destinations keep their paged layout.
  final bool fitAuthContent;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _authPageController = PageController();
  final _registerPasswordFocusNode = FocusNode();
  final _emailController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _registerMode = false;
  bool _showPassword = false;
  bool _passwordResetDialogOpen = false;
  int? _authSwipePointer;
  Offset _authSwipeDelta = Offset.zero;
  AccountSessionState? _session;
  AccountOverview? _overview;
  RegistrationCodeRequest? _codeRequest;
  String? _codeRequestEmail;
  String? _error;

  bool get _english => Localizations.localeOf(context).languageCode != 'zh';

  @override
  void initState() {
    super.initState();
    _registerPasswordFocusNode.addListener(_onRegisterPasswordFocusChanged);
    _loadAccount();
  }

  @override
  void dispose() {
    _authPageController.dispose();
    _registerPasswordFocusNode.removeListener(_onRegisterPasswordFocusChanged);
    _registerPasswordFocusNode.dispose();
    _emailController.dispose();
    _registerEmailController.dispose();
    _passwordController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      var session = await AccountService.getSessionState();
      if (session.configured && !session.cloudServicePolicyKnown) {
        try {
          await AppUpdateService.checkNow();
          session = await AccountService.getSessionState();
        } catch (_) {
          // The native account guard remains fail-closed. Keep the policy
          // unavailable state so the page can offer an explicit retry.
        }
      }
      if (!mounted) return;
      // Local credentials remain authoritative when the account server is
      // unavailable. Keep sign-out reachable without retaining a stale overview.
      setState(() {
        _session = session;
        _overview = null;
      });
      AccountOverview? overview;
      if (session.configured &&
          session.signedIn &&
          session.cloudServiceAccessAllowed) {
        overview = await AccountService.getOverview();
      }
      if (!mounted) return;
      setState(() {
        _overview = overview;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      if (error.code == 'NOT_AUTHENTICATED' ||
          error.code == 'invalid_refresh_token') {
        setState(() {
          _session = const AccountSessionState(
            configured: true,
            signedIn: false,
          );
          _overview = null;
        });
      } else {
        setState(() => _error = _messageFor(error));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'الحساب غير متاح مؤقتًا';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendVerificationCode() async {
    final email = _registerEmailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _error = 'أدخل بريدًا إلكترونيًا صحيحًا أولًا');
      return;
    }
    await _withBusy(() async {
      final request = await AccountService.requestRegistrationCode(email);
      if (!mounted) return;
      setState(() {
        _codeRequest = request;
        _codeRequestEmail = email;
        _error = null;
      });
      _showSuccessToast(
        'تم إرسال الرمز، وهو صالح لمدة ${request.expiresInSeconds ~/ 60} دقيقة',
      );
    });
  }

  Future<void> _submitAuth() async {
    final creatingAccount = _registerMode;
    final formKey = creatingAccount ? _registerFormKey : _formKey;
    if (!(formKey.currentState?.validate() ?? false)) return;
    final email = creatingAccount
        ? _registerEmailController.text.trim()
        : _emailController.text.trim();
    final password = creatingAccount
        ? _registerPasswordController.text
        : _passwordController.text;
    await _withBusy(() async {
      if (creatingAccount) {
        final request = _codeRequest;
        if (request == null || _codeRequestEmail != email) {
          throw PlatformException(
            code: 'CODE_NOT_REQUESTED',
            message: 'اطلب رمز تحقق لهذا البريد الإلكتروني أولًا',
          );
        }
        await AccountService.register(
          email: email,
          password: password,
          verificationRequestId: request.requestId,
          verificationCode: _verificationCodeController.text.trim(),
        );
      }
      try {
        await AccountService.login(email: email, password: password);
      } catch (_) {
        if (creatingAccount && mounted) {
          _selectAuthMode(false);
        }
        rethrow;
      }
      _passwordController.clear();
      _registerPasswordController.clear();
      _confirmPasswordController.clear();
      _verificationCodeController.clear();
      _codeRequest = null;
      _codeRequestEmail = null;
      if (mounted) _selectAuthMode(false);
      await _loadAccount();
      if (mounted) {
        _showSuccessToast(
          creatingAccount
              ? 'تم إنشاء الحساب وتسجيل الدخول'
              : 'تم تسجيل الدخول',
        );
        widget.onAuthenticated?.call();
      }
    });
  }

  Future<void> _logout() async {
    final confirmed = await showSettingsDetailSheet<bool>(
      context: context,
      builder: (sheetContext) => SettingsDetailSheet(
        key: const ValueKey('sign-out-sheet'),
        title: 'تسجيل الخروج',
        body: Text(
          'سيتم تسجيل الخروج من هذا الجهاز فقط.',
        ),
        actions: [
          TextButton(
            style: settingsDetailSheetActionStyle(sheetContext),
            onPressed: () => Navigator.pop(sheetContext, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            style: settingsDetailSheetActionStyle(
              sheetContext,
              foregroundColor: Theme.of(sheetContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(sheetContext, true),
            child: Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _withBusy(() async {
      try {
        await AccountService.logout();
      } finally {
        if (mounted) {
          setState(() {
            _session = const AccountSessionState(
              configured: true,
              signedIn: false,
            );
            _overview = null;
          });
        }
      }
    });
  }

  Future<void> _showPasswordResetDialog() async {
    if (_passwordResetDialogOpen) return;
    setState(() => _passwordResetDialogOpen = true);
    final formKey = GlobalKey<FormState>();
    var emailValue = _emailController.text;
    var passwordValue = '';
    var confirmValue = '';
    var codeValue = '';
    RegistrationCodeRequest? request;
    String? requestEmail;
    String? dialogError;
    var submitting = false;
    var sendingCode = false;
    var showPassword = false;

    try {
      final reset = await showSettingsDetailSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setDialogState) => PopScope(
            canPop: !submitting && !sendingCode,
            child: SettingsDetailSheet(
              key: const ValueKey('reset-password-sheet'),
              title: 'إعادة تعيين كلمة المرور',
              subtitle: 'سيتم إرسال رمز إلى بريدك الإلكتروني المسجّل. ويجب إعادة تسجيل الدخول على الأجهزة الأخرى بعد إعادة التعيين.',
              avoidKeyboard: true,
              body: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const ValueKey('auth-email-field'),
                      initialValue: emailValue,
                      onChanged: (value) => emailValue = value,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        suffixIcon: TextButton(
                          onPressed: submitting || sendingCode
                              ? null
                              : () async {
                                  final email = emailValue.trim();
                                  if (!_looksLikeEmail(email)) {
                                    setDialogState(() {
                                      dialogError = 'أدخل بريدًا إلكترونيًا صحيحًا';
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    sendingCode = true;
                                    dialogError = null;
                                  });
                                  try {
                                    final result =
                                        await AccountService.requestPasswordResetCode(
                                          email,
                                        );
                                    if (!sheetContext.mounted) return;
                                    setDialogState(() {
                                      request = result;
                                      requestEmail = email;
                                      sendingCode = false;
                                    });
                                  } on PlatformException catch (error) {
                                    if (!sheetContext.mounted) return;
                                    setDialogState(() {
                                      sendingCode = false;
                                      dialogError = _messageFor(error);
                                    });
                                  } catch (_) {
                                    if (!sheetContext.mounted) return;
                                    setDialogState(() {
                                      sendingCode = false;
                                      dialogError = 'تعذّر إرسال الرمز. حاول مرة أخرى لاحقًا.';
                                    });
                                  }
                                },
                          child: sendingCode
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  request == null
                                      ? 'إرسال'
                                      : 'إعادة الإرسال',
                                ),
                        ),
                      ),
                      validator: (value) => _looksLikeEmail(value?.trim() ?? '')
                          ? null
                          : 'أدخل بريدًا إلكترونيًا صحيحًا',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('auth-password-field'),
                      onChanged: (value) => passwordValue = value,
                      obscureText: !showPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        helperText: 'من 8 إلى 16 حرفًا',
                      ),
                      validator: _passwordValidationMessage,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('auth-confirm-password-field'),
                      onChanged: (value) => confirmValue = value,
                      obscureText: !showPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور الجديدة',
                      ),
                      validator: (_) => confirmValue == passwordValue
                          ? null
                          : 'كلمتا المرور غير متطابقتين',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('auth-verification-code-field'),
                      onChanged: (value) => codeValue = value,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'رمز التحقق من البريد الإلكتروني',
                        counterText: '',
                      ),
                      validator: (value) => (value ?? '').trim().length == 6
                          ? null
                          : 'أدخل الرمز المكوّن من 6 أرقام',
                    ),
                    CheckboxListTile(
                      value: showPassword,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: submitting
                          ? null
                          : (value) => setDialogState(
                              () => showPassword = value ?? false,
                            ),
                      title: Text('إظهار كلمات المرور'),
                    ),
                    if (dialogError != null) _errorBanner(dialogError!),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: settingsDetailSheetActionStyle(sheetContext),
                  onPressed: submitting || sendingCode
                      ? null
                      : () => Navigator.pop(sheetContext, false),
                  child: Text('إلغاء'),
                ),
                TextButton(
                  key: const ValueKey('submit-auth'),
                  style: settingsDetailSheetActionStyle(sheetContext),
                  onPressed: submitting || sendingCode
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final email = emailValue.trim();
                          if (request == null || requestEmail != email) {
                            setDialogState(() {
                              dialogError = 'أرسل رمزًا إلى هذا البريد الإلكتروني أولًا.';
                            });
                            return;
                          }
                          setDialogState(() {
                            submitting = true;
                            dialogError = null;
                          });
                          try {
                            await AccountService.resetPassword(
                              email: email,
                              newPassword: passwordValue,
                              verificationRequestId: request!.requestId,
                              verificationCode: codeValue.trim(),
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext, true);
                            }
                          } on PlatformException catch (error) {
                            if (!sheetContext.mounted) return;
                            setDialogState(() {
                              submitting = false;
                              dialogError = _messageFor(error);
                            });
                          } catch (_) {
                            if (!sheetContext.mounted) return;
                            setDialogState(() {
                              submitting = false;
                              dialogError = 'تعذّرت إعادة تعيين كلمة المرور. حاول مرة أخرى لاحقًا.';
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('تأكيد إعادة التعيين'),
                ),
              ],
            ),
          ),
        ),
      );
      if (reset == true && mounted) {
        _passwordController.clear();
        _showSuccessToast(
          'تمت إعادة تعيين كلمة المرور. سجّل الدخول مجددًا.',
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _passwordResetDialogOpen = false);
    }
  }

  Future<void> _showPlatformUsage() => showSettingsDetailSheet<void>(
    context: context,
    builder: (context) =>
        PlatformUsageSheet(english: _english, errorMessage: _messageFor),
  );

  Future<void> _showSessions() => showSettingsDetailSheet<void>(
    context: context,
    builder: (context) =>
        SessionsSheet(english: _english, errorMessage: _messageFor),
  );

  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    var currentPassword = '';
    var newPassword = '';
    var confirmedPassword = '';
    var submitting = false;
    var showPasswords = false;
    String? dialogError;
    final changed = await showSettingsDetailSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !submitting,
          child: SettingsDetailSheet(
            key: const ValueKey('change-password-sheet'),
            title: 'تغيير كلمة المرور',
            subtitle: 'سيتم تسجيل الخروج من الأجهزة الأخرى. ويبقى هذا الجهاز مسجّلًا.',
            avoidKeyboard: true,
            body: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('current-password-field'),
                    obscureText: !showPasswords,
                    onChanged: (value) => currentPassword = value,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                    ),
                    validator: (value) => (value ?? '').isEmpty
                        ? 'أدخل كلمة المرور الحالية'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('new-password-field'),
                    obscureText: !showPasswords,
                    onChanged: (value) => newPassword = value,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      helperText: 'من 8 إلى 16 حرفًا',
                    ),
                    validator: _passwordValidationMessage,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('confirm-new-password-field'),
                    obscureText: !showPasswords,
                    onChanged: (value) => confirmedPassword = value,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور الجديدة',
                    ),
                    validator: (_) => confirmedPassword == newPassword
                        ? null
                        : 'كلمتا المرور غير متطابقتين',
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    _errorBanner(dialogError!),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          key: const ValueKey('show-change-passwords'),
                          value: showPasswords,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: submitting
                              ? null
                              : (value) => setDialogState(
                                  () => showPasswords = value ?? false,
                                ),
                          title: Text('إظهار كلمات المرور'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        key: const ValueKey('confirm-change-password'),
                        onPressed: submitting
                            ? null
                            : () async {
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                setDialogState(() {
                                  submitting = true;
                                  dialogError = null;
                                });
                                try {
                                  await AccountService.changePassword(
                                    currentPassword: currentPassword,
                                    newPassword: newPassword,
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext, true);
                                  }
                                } on PlatformException catch (error) {
                                  if (!dialogContext.mounted) return;
                                  setDialogState(() {
                                    submitting = false;
                                    dialogError = _messageFor(error);
                                  });
                                } catch (_) {
                                  if (!dialogContext.mounted) return;
                                  setDialogState(() {
                                    submitting = false;
                                    dialogError = 'تعذّر تغيير كلمة المرور. حاول مرة أخرى لاحقًا.';
                                  });
                                }
                              },
                        child: submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('تغيير كلمة المرور'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (changed == true && mounted) {
      _showSuccessToast('تم تغيير كلمة المرور');
    }
  }

  Future<void> _showDeleteAccountFlow() async {
    final overview = _overview;
    if (overview == null) return;
    final proceed = await showSettingsDetailSheet<bool>(
      context: context,
      builder: (sheetContext) => SettingsDetailSheet(
        key: const ValueKey('delete-account-warning-sheet'),
        title: 'حذف الحساب نهائيًا؟',
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 18,
              color: Theme.of(sheetContext).colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'سيتم حذف حسابك على الخادم وجلسات تسجيل الدخول ومعلومات حصة المنصة نهائيًا. ولن تُحذف المحادثات والملفات المحلية تلقائيًا.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: settingsDetailSheetActionStyle(sheetContext),
            onPressed: () => Navigator.pop(sheetContext, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            key: const ValueKey('continue-delete-account'),
            style: settingsDetailSheetActionStyle(
              sheetContext,
              foregroundColor: Theme.of(sheetContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(sheetContext, true),
            child: Text('متابعة'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final formKey = GlobalKey<FormState>();
    var confirmationEmail = '';
    var currentPassword = '';
    var submitting = false;
    String? dialogError;
    final deleted = await showSettingsDetailSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !submitting,
          child: SettingsDetailSheet(
            key: const ValueKey('delete-account-confirmation-sheet'),
            title: 'التأكيد النهائي',
            avoidKeyboard: true,
            body: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('delete-account-email-field'),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => confirmationEmail = value,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني للحساب',
                      hintText: overview.user.email,
                    ),
                    validator: (_) =>
                        confirmationEmail.trim().toLowerCase() ==
                            overview.user.email.trim().toLowerCase()
                        ? null
                        : 'أدخل البريد الإلكتروني الكامل لهذا الحساب.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('delete-account-password-field'),
                    obscureText: true,
                    onChanged: (value) => currentPassword = value,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                    ),
                    validator: (value) => (value ?? '').isEmpty
                        ? 'أدخل كلمة المرور الحالية'
                        : null,
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    _errorBanner(dialogError!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                style: settingsDetailSheetActionStyle(sheetContext),
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(sheetContext, false),
                child: Text('إلغاء'),
              ),
              TextButton(
                key: const ValueKey('confirm-delete-account'),
                style: settingsDetailSheetActionStyle(
                  sheetContext,
                  foregroundColor: Theme.of(sheetContext).colorScheme.error,
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() {
                          submitting = true;
                          dialogError = null;
                        });
                        try {
                          await AccountService.deleteAccount(currentPassword);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext, true);
                          }
                        } on PlatformException catch (error) {
                          if (!sheetContext.mounted) return;
                          setDialogState(() {
                            submitting = false;
                            dialogError = _messageFor(error);
                          });
                        } catch (_) {
                          if (!sheetContext.mounted) return;
                          setDialogState(() {
                            submitting = false;
                            dialogError = 'تعذّر حذف الحساب. حاول مرة أخرى لاحقًا.';
                          });
                        }
                      },
                child: submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('حذف نهائي'),
              ),
            ],
          ),
        ),
      ),
    );
    if (deleted == true && mounted) {
      setState(() {
        _session = const AccountSessionState(configured: true, signedIn: false);
        _overview = null;
        _error = null;
      });
      _showSuccessToast('تم حذف الحساب');
    }
  }

  String? _passwordValidationMessage(String? value) {
    final length = (value ?? '').characters.length;
    if (length < 8 || length > 16) {
      return 'استخدم من 8 إلى 16 حرفًا.';
    }
    return null;
  }

  Future<void> _withBusy(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'فشلت العملية. حاول مرة أخرى لاحقًا.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(PlatformException error) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'email_already_registered':
        return 'هذا البريد الإلكتروني مسجّل بالفعل';
      case 'invalid_email':
        return 'أدخل عنوان بريد إلكتروني صحيحًا';
      case 'invalid_password':
        return 'استخدم كلمة مرور من 8 إلى 16 حرفًا';
      case 'invalid_request':
        return 'الطلب غير صالح. تحقق من الحقول وحاول مرة أخرى';
      case 'invalid_verification_code':
        return 'الرمز غير صالح أو منتهي الصلاحية';
      case 'invalid_verification_request':
        return 'اطلب رمز تحقق جديدًا';
      case 'rate_limited':
        return 'محاولات كثيرة جدًا. حاول مرة أخرى لاحقًا.';
      case 'too_many_requests':
        return 'محاولات كثيرة جدًا. حاول مرة أخرى لاحقًا.';
      case 'verification_unavailable':
        return 'خدمة التحقق غير متاحة مؤقتًا.';
      case 'account_service_unavailable':
        return 'خدمة الحساب غير متاحة مؤقتًا.';
      case 'ACCOUNT_FEATURE_UNAVAILABLE':
        return 'خدمة الحساب هذه لا تدعم التسجيل بعد.';
      case 'current_password_invalid':
        return 'كلمة المرور الحالية غير صحيحة';
      case 'password_reuse':
        return 'اختر كلمة مرور مختلفة';
      case 'session_not_found':
        return 'تم تسجيل الخروج من ذلك الجهاز بالفعل';
      case 'cannot_revoke_current_session':
        return 'لا يمكن إلغاء تسجيل الجهاز الحالي من هنا';
      case 'invalid_verification_request':
        return 'اطلب رمز تحقق جديدًا';
      case 'ACCOUNT_NOT_CONFIGURED':
        return 'خدمة الحساب غير مُعدّة';
      case 'CLOUD_SERVICE_UPDATE_REQUIRED':
        return 'حدّث التطبيق قبل استخدام الحساب وخدمات السحابة الرسمية';
      case 'CLOUD_SERVICE_POLICY_UNAVAILABLE':
        return 'اتصل بالإنترنت وتحقق من وجود تحديثات قبل استخدام خدمات الحساب';
      default:
        return 'فشلت العملية. حاول مرة أخرى لاحقًا.';
    }
  }

  bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    return at > 0 && value.indexOf('.', at) > at + 1;
  }

  void _showSuccessToast(String message) {
    showToast(message, type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final content = Stack(
      children: [
        if (widget.fitAuthContent)
          _buildBody()
        else
          Positioned.fill(child: _buildBody()),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: palette.overlayScrim,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
    if (widget.authOnly) {
      return ColoredBox(
        key: const ValueKey('account-auth-only-surface'),
        color: Colors.transparent,
        child: content,
      );
    }
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: CommonAppBar(
        title: 'الحساب وخدمة الذكاء الاصطناعي',
        primary: true,
      ),
      body: OmniContentWidth(child: content),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return SizedBox(
        height: widget.fitAuthContent ? 280 : null,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final session = _session;
    if (session == null) return _buildErrorState();
    if (!session.configured) return _buildNotConfigured();
    if (!session.credentialStorageAvailable) {
      return _buildCredentialStorageUnavailable();
    }
    if (!session.cloudServiceAccessAllowed) {
      return _buildCloudServiceBlocked(session);
    }
    if (!session.signedIn) return _buildAuthForm();
    if (_overview == null) return _buildErrorState();
    if (widget.authOnly) return _buildAuthenticatedAuthState(_overview!);
    return _buildSignedIn(_overview!);
  }

  Widget _buildAuthenticatedAuthState(AccountOverview overview) {
    final palette = context.omniPalette;
    return Center(
      heightFactor: widget.fitAuthContent ? 1 : null,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.circleCheckBig,
              size: 42,
              color: palette.accentPrimary,
            ),
            const SizedBox(height: 14),
            Text(
              'أنت مسجّل الدخول',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              overview.user.email,
              style: TextStyle(color: palette.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (widget.onAuthenticated != null) ...[
              const SizedBox(height: 22),
              FilledButton(
                key: const ValueKey('account-auth-finish'),
                onPressed: widget.onAuthenticated,
                child: Text('تم'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      heightFactor: widget.fitAuthContent ? 1 : null,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'فشل التحميل'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadAccount,
              child: Text('إعادة المحاولة'),
            ),
            if (_session?.signedIn == true) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('account-error-logout-action'),
                onPressed: _busy ? null : _logout,
                icon: const Icon(LucideIcons.logOut, size: 18),
                label: Text('تسجيل الخروج من هذا الجهاز'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotConfigured() {
    return SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        shrinkWrap: widget.fitAuthContent,
        padding: edgeToEdgeScrollPadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 28),
        ),
        children: [
          SettingsSectionTitle(label: 'الحساب'),
          OmniSettingsCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.cloudOff,
                  size: 26,
                  color: context.omniPalette.textSecondary,
                ),
                const SizedBox(height: 14),
                Text(
                  'خدمة الحساب غير مُعدّة',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'هذا البناء لا يحتوي على OMNIBOT_BASE_URL. اضبط نطاق الخدمة العام وأعد البناء.',
                  style: TextStyle(
                    color: context.omniPalette.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialStorageUnavailable() {
    return SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        shrinkWrap: widget.fitAuthContent,
        padding: edgeToEdgeScrollPadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 28),
        ),
        children: [
          SettingsSectionTitle(label: 'الحساب'),
          OmniSettingsCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.lockKeyhole,
                  size: 26,
                  color: context.omniPalette.textSecondary,
                ),
                const SizedBox(height: 14),
                Text(
                  'بيانات تسجيل الدخول غير متاحة مؤقتًا',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'التخزين الآمن قيد الاستعادة. ولن يتم اعتبارك مسجّل خروج. حاول مرة أخرى قريبًا، أو أعد تشغيل التطبيق إذا لزم الأمر.',
                  style: TextStyle(
                    color: context.omniPalette.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey('account-credential-storage-retry'),
                  onPressed: _loading ? null : _loadAccount,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudServiceBlocked(AccountSessionState session) {
    final policyKnown = session.cloudServicePolicyKnown;
    final minimumVersion = session.minimumVersion;
    final currentVersion = session.currentVersion.isEmpty
        ? '-'
        : session.currentVersion;
    final reason =
        session.cloudServiceUnavailableReason ??
        (policyKnown
            ? 'هذا الإصدار قديم جدًا بالنسبة للحساب وخدمات السحابة الرسمية.'
            : 'لا تتوفر سياسة صالحة لإصدار خدمة السحابة. تحقق من وجود تحديثات أثناء الاتصال بالإنترنت.');
    return SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        key: const ValueKey('account-cloud-service-version-gate'),
        shrinkWrap: widget.fitAuthContent,
        padding: edgeToEdgeScrollPadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 28),
        ),
        children: [
          SettingsSectionTitle(
            label: policyKnown
                ? 'التحديث مطلوب'
                : 'يلزم التحقق من وجود تحديث',
          ),
          OmniSettingsCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.cloudOff,
                  size: 26,
                  color: context.omniPalette.textSecondary,
                ),
                const SizedBox(height: 14),
                Text(reason, style: Theme.of(context).textTheme.titleMedium),
                if (minimumVersion.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'الحالي v$currentVersion · الأدنى v$minimumVersion',
                    style: TextStyle(color: context.omniPalette.textSecondary),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'التسجيل في الحساب وتسجيل الدخول والذكاء الاصطناعي الرسمي معطّلة. يمكنك العودة ومواصلة استخدام مفتاح API الخاص بك (BYOK).',
                  style: TextStyle(
                    color: context.omniPalette.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey('account-required-update-action'),
                  onPressed: _busy ? null : _checkRequiredUpdate,
                  icon: Icon(
                    policyKnown ? LucideIcons.download : LucideIcons.refreshCw,
                    size: 18,
                  ),
                  label: Text(
                    policyKnown
                        ? 'حدّث الآن'
                        : 'تحقق من وجود تحديثات',
                  ),
                ),
                if (session.signedIn) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('account-gated-logout-action'),
                    onPressed: _busy ? null : _logout,
                    child: Text('تسجيل الخروج'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkRequiredUpdate() async {
    await _withBusy(() async {
      final status = await AppUpdateService.checkNow();
      final refreshedSession = await AccountService.getSessionState();
      if (!mounted) return;
      setState(() => _session = refreshedSession);
      if (refreshedSession.cloudServiceAccessAllowed) {
        await _loadAccount();
        return;
      }
      if (status?.hasUpdate == true) {
        await showAppUpdateDialog(context, status!);
        return;
      }
      showToast(
        'لا يتوفر تحديث قابل للتثبيت. حاول مرة أخرى لاحقًا.',
        type: ToastType.warning,
      );
    });
  }

  Widget _buildAuthForm() {
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        mainAxisSize: widget.fitAuthContent
            ? MainAxisSize.min
            : MainAxisSize.max,
        children: [
          Padding(
            padding: widget.fitAuthContent
                ? const EdgeInsets.fromLTRB(20, 12, 20, 0)
                : const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showAuthHeading)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: SettingsSectionTitle(
                      key: ValueKey(_registerMode),
                      label: _registerMode
                          ? 'أنشئ حسابك'
                          : 'تسجيل الدخول إلى OmniBot',
                      subtitle: 'يقوم حسابك بمزامنة الجلسات وحصة المنصة؛ ويصبح الذكاء الاصطناعي الرسمي مزوّدًا اختياريًا بعد تسجيل الدخول.',
                      bottomPadding: 16,
                    ),
                  ),
                _authModeSelector(),
              ],
            ),
          ),
          SizedBox(
            key: const Key('account-auth-content-gap'),
            height: widget.fitAuthContent ? 16 : 12,
          ),
          Flexible(
            fit: widget.fitAuthContent ? FlexFit.loose : FlexFit.tight,
            child: Listener(
              onPointerDown: _onAuthPointerDown,
              onPointerMove: _onAuthPointerMove,
              onPointerUp: _onAuthPointerUp,
              onPointerCancel: _onAuthPointerCancel,
              child: widget.fitAuthContent
                  ? _buildAuthPage(register: _registerMode)
                  : PageView(
                      key: const Key('account-auth-page-view'),
                      controller: _authPageController,
                      onPageChanged: _onAuthPageChanged,
                      children: [
                        _buildAuthPage(register: false),
                        _buildAuthPage(register: true),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPage({required bool register}) {
    final emailController = register
        ? _registerEmailController
        : _emailController;
    final passwordController = register
        ? _registerPasswordController
        : _passwordController;

    return Form(
      key: register ? _registerFormKey : _formKey,
      child: ListView(
        key: PageStorageKey(
          register ? 'account-register-page' : 'account-login-page',
        ),
        shrinkWrap: widget.fitAuthContent,
        padding: widget.fitAuthContent
            ? const EdgeInsets.fromLTRB(20, 0, 20, 16)
            : edgeToEdgeScrollPadding(
                context,
                const EdgeInsets.fromLTRB(18, 8, 18, 28),
              ),
        children: [
          TextFormField(
            key: ValueKey(
              register ? 'account-register-email' : 'account-login-email',
            ),
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: const Icon(LucideIcons.mail, size: 20),
            ),
            validator: (value) => _looksLikeEmail(value?.trim() ?? '')
                ? null
                : 'أدخل بريدًا إلكترونيًا صحيحًا',
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: ValueKey(
              register ? 'account-register-password' : 'account-login-password',
            ),
            controller: passwordController,
            focusNode: register ? _registerPasswordFocusNode : null,
            obscureText: !_showPassword,
            autofillHints: register
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              hintText: register && _registerPasswordFocusNode.hasFocus
                  ? 'من 8 إلى 16 حرفًا'
                  : null,
              prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 20),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 20,
                ),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return 'أدخل كلمة المرور';
              }
              if (register &&
                  (value!.characters.length < 8 ||
                      value.characters.length > 16)) {
                return 'استخدم من 8 إلى 16 حرفًا';
              }
              return null;
            },
          ),
          if (!register)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('forgot-password'),
                onPressed: _busy ? null : _showPasswordResetDialog,
                child: Text('هل نسيت كلمة المرور؟'),
              ),
            ),
          if (register) ...[
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('auth-confirm-password-field'),
              controller: _confirmPasswordController,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: const Icon(LucideIcons.rotateCcwKey, size: 20),
              ),
              validator: (value) => value == _registerPasswordController.text
                  ? null
                  : 'كلمتا المرور غير متطابقتين',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _verificationCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'رمز التحقق من البريد الإلكتروني',
                counterText: '',
                prefixIcon: const Icon(LucideIcons.mailCheck, size: 20),
                suffixIcon: TextButton(
                  onPressed: _busy ? null : _sendVerificationCode,
                  child: Text(
                    _codeRequest == null
                        ? 'إرسال'
                        : 'إعادة الإرسال',
                  ),
                ),
              ),
              validator: (value) => (value ?? '').trim().length == 6
                  ? null
                  : 'أدخل الرمز المكوّن من 6 أرقام',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBanner(_error!),
          ],
          SizedBox(height: widget.fitAuthContent ? 16 : 22),
          FilledButton(
            key: ValueKey(
              register
                  ? 'account-register-submit'
                  : _passwordResetDialogOpen
                  ? 'account-login-submit'
                  : 'submit-auth',
            ),
            onPressed: _busy ? null : _submitAuth,
            child: KeyedSubtree(
              key: ValueKey(register ? 'submit-auth' : 'account-login-submit'),
              child: Text(
                register
                    ? 'إنشاء الحساب وتسجيل الدخول'
                    : 'تسجيل الدخول',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onRegisterPasswordFocusChanged() {
    if (mounted) setState(() {});
  }

  void _selectAuthMode(bool register) {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final destinationEmail = register
        ? _registerEmailController
        : _emailController;
    final sourceEmail = register ? _emailController : _registerEmailController;
    if (destinationEmail.text.isEmpty && sourceEmail.text.isNotEmpty) {
      destinationEmail.text = sourceEmail.text;
    }
    if (_registerMode != register || _error != null) {
      setState(() {
        _registerMode = register;
        _error = null;
      });
    }
    if (_authPageController.hasClients) {
      _authPageController.animateToPage(
        register ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onAuthPageChanged(int page) {
    final register = page == 1;
    if (_registerMode == register) return;
    FocusScope.of(context).unfocus();
    final destinationEmail = register
        ? _registerEmailController
        : _emailController;
    final sourceEmail = register ? _emailController : _registerEmailController;
    if (destinationEmail.text.isEmpty && sourceEmail.text.isNotEmpty) {
      destinationEmail.text = sourceEmail.text;
    }
    setState(() {
      _registerMode = register;
      _error = null;
    });
  }

  void _onAuthPointerDown(PointerDownEvent event) {
    if (_authSwipePointer != null) return;
    _authSwipePointer = event.pointer;
    _authSwipeDelta = Offset.zero;
  }

  void _onAuthPointerMove(PointerMoveEvent event) {
    if (_authSwipePointer != event.pointer) return;
    _authSwipeDelta += event.delta;
  }

  void _onAuthPointerUp(PointerUpEvent event) {
    if (_authSwipePointer != event.pointer) return;
    final delta = _authSwipeDelta;
    _resetAuthSwipeTracking();
    if (delta.dx.abs() < 64 || delta.dx.abs() <= delta.dy.abs() * 1.2) {
      return;
    }
    _selectAuthMode(delta.dx < 0);
  }

  void _onAuthPointerCancel(PointerCancelEvent event) {
    if (_authSwipePointer == event.pointer) _resetAuthSwipeTracking();
  }

  void _resetAuthSwipeTracking() {
    _authSwipePointer = null;
    _authSwipeDelta = Offset.zero;
  }

  Widget _authModeSelector() => OmniSegmentedSlider<bool>(
    key: const Key('account-auth-mode-selector'),
    keyPrefix: 'account-auth-mode',
    value: _registerMode,
    options: [
      OmniSegmentedOption(
        value: false,
        label: 'تسجيل الدخول',
        id: 'login',
      ),
      OmniSegmentedOption(
        value: true,
        label: 'التسجيل',
        id: 'register',
      ),
    ],
    onChanged: _selectAuthMode,
  );

  Widget _buildSignedIn(AccountOverview overview) {
    final settings = overview.settings;
    final platformQuota = settings.platform;
    final String? quotaSubtitle = !settings.platformAvailable
        ? settings.platformUnavailableReason ?? 'منصة الذكاء الاصطناعي غير متاحة بعد؛ ويمكن استخدام الحصة بعد الإطلاق'
        : settings.platform.enabled
        ? platformQuota.weeklyLimit > 0
              ? 'إعادة التعيين بعد ${formatWeeklyQuotaResetCountdown(DateTime.now(), english: true)}'
              : null
        : 'حصة المنصة معطّلة حاليًا';
    return SafeArea(
      top: false,
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadAccount,
        child: ListView(
          padding: edgeToEdgeScrollPadding(
            context,
            const EdgeInsets.fromLTRB(16, 12, 16, 28),
          ),
          children: [
            OmniSettingsGroup(
              title: 'الحساب',
              translateTitle: false,
              dividerIndent: 46,
              children: [
                _summaryRow(
                  icon: LucideIcons.userRound,
                  title: overview.user.email,
                  subtitle: 'تم التحقق · مسجّل الدخول على هذا الجهاز',
                ),
                _summaryRow(
                  icon: LucideIcons.coins,
                  title: 'حصة المنصة',
                  subtitle: quotaSubtitle,
                  trailing: settings.platformAvailable
                      ? _platformQuotaValue(platformQuota)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 22),
            OmniSettingsGroup(
              title: 'إدارة الحساب',
              translateTitle: false,
              dividerIndent: 46,
              children: [
                _accountAction(
                  key: const ValueKey('account-usage-action'),
                  icon: LucideIcons.chartNoAxesColumnIncreasing,
                  title: 'استخدام المنصة الأخير',
                  onTap: _showPlatformUsage,
                ),
                _accountAction(
                  key: const ValueKey('account-sessions-action'),
                  icon: LucideIcons.smartphone,
                  title: 'الأجهزة المسجّل دخولها',
                  onTap: _showSessions,
                ),
                _accountAction(
                  key: const ValueKey('change-password-action'),
                  icon: LucideIcons.shieldCheck,
                  title: 'تغيير كلمة المرور',
                  onTap: _showChangePasswordDialog,
                ),
                _accountAction(
                  key: const ValueKey('delete-account-action'),
                  icon: LucideIcons.trash2,
                  title: 'حذف الحساب',
                  destructive: true,
                  onTap: _showDeleteAccountFlow,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _errorBanner(_error!),
            ],
            const SizedBox(height: 22),
            TextButton.icon(
              onPressed: _busy ? null : _logout,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(LucideIcons.logOut, size: 18),
              label: Text('تسجيل الخروج من هذا الجهاز'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformQuotaValue(PlatformQuota quota) {
    final palette = context.omniPalette;
    final limit = quota.weeklyLimit;
    if (limit <= 0) {
      return Text(
        '${quota.balance}',
        style: TextStyle(
          color: palette.accentPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final balance = quota.balance;
    final percentage = (balance / limit * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          key: const ValueKey('account-platform-quota-ratio'),
          text: TextSpan(
            children: [
              TextSpan(
                text: '$balance',
                style: TextStyle(
                  color: palette.accentPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: '/',
                style: TextStyle(
                  color: palette.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '$limit',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$percentage%',
          key: const ValueKey('account-platform-quota-percent'),
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String title,
    required String? subtitle,
    Widget? trailing,
  }) {
    final palette = context.omniPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 19,
            color: palette.textPrimary.withValues(alpha: 0.78),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                    height: 1.38,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2.5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ],
      ),
    );
  }

  Widget _accountAction({
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final palette = context.omniPalette;
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : palette.textPrimary;
    final iconColor = destructive
        ? Theme.of(context).colorScheme.error
        : palette.textPrimary.withValues(alpha: 0.78);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: _busy ? null : onTap,
        splashColor: palette.accentPrimary.withValues(alpha: 0.06),
        highlightColor: palette.accentPrimary.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: palette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.circleAlert,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
