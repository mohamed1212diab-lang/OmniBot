import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/settings_ui.dart';

import '../onboarding_permission_controller.dart';
import '../widgets/onboarding_page_scaffold.dart';

/// Grant the app permissions that power floating reminders,
/// background execution, and app detection.
class OnboardingPermissionsPage extends StatelessWidget {
  const OnboardingPermissionsPage({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.onRequestShizuku,
  });

  final OnboardingPermissionController controller;
  final ScrollController scrollController;
  final FutureOr<void> Function() onRequestShizuku;

  @override
  Widget build(BuildContext context) {
    return OnboardingPageScaffold(
      icon: LucideIcons.shieldCheck,
      title: 'أذونات التطبيق',
      description: 'هذه الأذونات تشغّل التذكيرات والعمل في الخلفية. يمكنك تغييرها لاحقًا من الإعدادات.',
      scrollController: scrollController,
      children: [
        _CoreProgressOverview(controller: controller),
        const SizedBox(height: 26),
        _SectionLabel(label: 'الأذونات الأساسية'),
        const SizedBox(height: 6),
        _PermissionRow(
          tapKey: const ValueKey('tutorial-permission-battery'),
          icon: LucideIcons.batteryCharging,
          title: 'التشغيل في الخلفية',
          subtitle: 'يمنع النظام من إيقاف التطبيق، فتستمر رسائلك ومهامك في الخلفية.',
          granted: controller.backgroundRunning,
          actionLabel: 'تفعيل',
          onTap: controller.openBatterySettings,
        ),
        _PermissionRow(
          tapKey: const ValueKey('tutorial-permission-overlay'),
          icon: LucideIcons.pictureInPicture2,
          title: 'النافذة العائمة',
          subtitle: 'اسمح لـ Doser AI بعرض نافذة المحادثة والتذكيرات فوق التطبيقات الأخرى.',
          granted: controller.overlay,
          actionLabel: 'تفعيل',
          onTap: controller.openOverlaySettings,
        ),
        _PermissionRow(
          tapKey: const ValueKey('tutorial-permission-apps'),
          icon: LucideIcons.layoutGrid,
          title: 'معرفة التطبيقات المثبّتة',
          subtitle: 'لمعرفة التطبيقات المثبّتة على جهازك.',
          granted: controller.installedApps,
          actionLabel: 'تفعيل',
          onTap: controller.openInstalledAppsSettings,
        ),
        const SizedBox(height: 26),
        _SectionLabel(label: 'أذونات إضافية'),
        const SizedBox(height: 6),
        _PermissionRow(
          tapKey: const ValueKey('tutorial-permission-storage'),
          icon: LucideIcons.folderOpen,
          title: 'الوصول إلى الملفات',
          subtitle: 'اسمح لـ Doser AI بقراءة ملفات جهازك وإدارتها.',
          granted: controller.publicStorage,
          actionLabel: 'تفعيل',
          onTap: controller.openStorageSettings,
        ),
        _PermissionRow(
          tapKey: const ValueKey('tutorial-permission-shizuku'),
          icon: LucideIcons.shieldPlus,
          title: 'إذن Shizuku',
          subtitle: controller.shizukuStatus.localizedGuide,
          granted: controller.shizukuStatus.isGranted,
          actionLabel: controller.shizukuStatus.localizedStatusLabel,
          onTap: onRequestShizuku,
        ),
        const SizedBox(height: 26),
        _SectionLabel(label: 'الإشعارات'),
        const SizedBox(height: 6),
        _NotificationRow(controller: controller),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.omniPalette.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Slim readiness meter for the three core permissions.
class _CoreProgressOverview extends StatelessWidget {
  const _CoreProgressOverview({required this.controller});

  final OnboardingPermissionController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final ready = controller.coreReadyCount;
    const total = OnboardingPermissionController.coreTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          child: Text(
            '$ready من $total أذونات جاهزة',
            key: ValueKey<int>(ready),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 6,
              decoration: BoxDecoration(
                color: palette.borderSubtle.withValues(
                  alpha: context.isDarkTheme ? 0.9 : 0.72,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * controller.coreProgress,
                  decoration: BoxDecoration(
                    color: palette.accentPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Flat permission row: leading icon, title/subtitle, and an animated
/// granted-check or an action label with a chevron.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.tapKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.actionLabel,
    required this.onTap,
  });

  final Key tapKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final String actionLabel;
  final FutureOr<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tapKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: palette.accentPrimary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: palette.accentPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: granted
                    ? Container(
                        key: const ValueKey('granted'),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: palette.accentPrimary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.check,
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Row(
                        key: const ValueKey('pending'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: palette.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: palette.textTertiary,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notification preference row with the same switch used in settings.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.controller});

  final OnboardingPermissionController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('tutorial-permission-notification'),
        onTap: () =>
            controller.setNotificationEnabled(!controller.notificationEnabled),
        borderRadius: BorderRadius.circular(14),
        splashColor: palette.accentPrimary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.bell,
                  size: 18,
                  color: palette.accentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إشعارات الرسائل',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ستصلك إشعارات عند تقدّم مهامك وانتهائها.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OmniSettingsSwitch(
                value: controller.notificationEnabled,
                onToggle: controller.setNotificationEnabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
