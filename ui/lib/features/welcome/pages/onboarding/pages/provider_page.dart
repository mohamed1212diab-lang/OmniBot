import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/features/my/pages/account/account_page.dart';
import 'package:ui/theme/theme_context.dart';

import '../widgets/onboarding_page_scaffold.dart';

/// Sign in or register directly inside the tutorial, using the shared auth form.
class OnboardingProviderPage extends StatelessWidget {
  const OnboardingProviderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!keyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OnboardingPageHeading(
                      icon: LucideIcons.logIn,
                      title: 'تسجيل الدخول أو إنشاء حساب',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'سجّل الدخول لاستخدام خدمة الذكاء الاصطناعي للمنصة وحصتها. يمكنك أيضاً تسجيل الدخول لاحقاً أو إعداد نموذجك الخاص.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.omniPalette.textSecondary,
                        height: 1.65,
                      ),
                    ),
                  ],
                ),
              ),
            const Expanded(
              child: AccountPage.authOnly(
                key: ValueKey('tutorial-inline-account-auth'),
                showAuthHeading: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
