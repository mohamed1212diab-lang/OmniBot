import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/theme/theme_context.dart';

import '../onboarding_provider_controller.dart';
import '../widgets/onboarding_common.dart';
import '../widgets/onboarding_page_scaffold.dart';

/// Enter the connection details for the chosen provider.
class OnboardingProviderConnectionPage extends StatelessWidget {
  const OnboardingProviderConnectionPage({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.onConnect,
  });

  final OnboardingProviderController controller;
  final ScrollController scrollController;
  final FutureOr<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final isCustom = controller.selectedProviderId == 'custom';
    return OnboardingPageScaffold(
      icon: LucideIcons.plugZap,
      title: 'اتصال ${controller.selectedProvider.label}',
      description:
          'تُحمَّل النماذج المتاحة بعد الاتصال، ويبقى مفتاحك محفوظاً على هذا الجهاز فقط.',
      scrollController: scrollController,
      children: [
        Row(
          children: [
            Icon(LucideIcons.keyRound, size: 19, color: palette.accentPrimary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'تفاصيل الاتصال',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OnboardingBadge(
              text: 'محفوظ على الجهاز فقط',
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('tutorial-provider-name'),
          controller: controller.nameController,
          enabled: !controller.busy,
          textInputAction: TextInputAction.next,
          decoration: onboardingInputDecoration(
            context,
            label: 'اسم مزود الخدمة',
            hint: 'مثال: بوابة نماذج الشركة',
            icon: LucideIcons.building2,
          ),
        ),
        const SizedBox(height: 13),
        TextField(
          key: const ValueKey('tutorial-provider-base-url'),
          controller: controller.baseUrlController,
          enabled: !controller.busy,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: onboardingInputDecoration(
            context,
            label: 'عنوان API الأساسي',
          hint: 'https://api.example.com/v1 أو http://192.168.1.10:8000/v1',
            icon: LucideIcons.globe2,
            helper: isCustom
                ? 'أدخل عنوان HTTP/HTTPS متوافقاً مع OpenAI أو Anthropic.'
                : 'تمت تعبئته مسبقاً لمزود الخدمة المحدد. غيّره فقط عند استخدام بوابة وسيطة.',
          ),
        ),
        const SizedBox(height: 13),
        TextField(
          key: const ValueKey('tutorial-provider-api-key'),
          controller: controller.apiKeyController,
          enabled: !controller.busy,
          obscureText: controller.obscureApiKey,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => onConnect(),
          decoration: onboardingInputDecoration(
            context,
            label: 'مفتاح API',
            hint: isCustom ? 'يمكن تركه فارغاً عند عدم وجود مصادقة' : 'sk-…',
            icon: LucideIcons.key,
            suffix: IconButton(
              onPressed: controller.toggleObscureApiKey,
              tooltip: controller.obscureApiKey ? 'إظهار المفتاح' : 'إخفاء المفتاح',
              icon: Icon(
                controller.obscureApiKey ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 19,
              ),
            ),
          ),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          OnboardingInlineError(message: controller.error!),
        ],
      ],
    );
  }
}
