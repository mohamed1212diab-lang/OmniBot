import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/theme/theme_context.dart';

import '../widgets/onboarding_entrance.dart';
import '../widgets/onboarding_page_scaffold.dart';

/// Final page: celebrate completion and lead into the app.
class OnboardingCompletionPage extends StatelessWidget {
  const OnboardingCompletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return LayoutBuilder(
      key: const ValueKey('tutorial-completion-page'),
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final heroSize = compact ? 82.0 : 104.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                children: [
                  OnboardingPageHeading(
                    icon: LucideIcons.rocket,
                    title: 'ابدأ الاستكشاف',
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 620),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value.clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                width: heroSize,
                                height: heroSize,
                                decoration: BoxDecoration(
                                  color: palette.accentPrimary,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  LucideIcons.check,
                                  size: compact ? 30 : 38,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 16 : 22),
                            OnboardingEntrance(
                              index: 1,
                              child: Text(
                                'اكتمل الدليل',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OnboardingEntrance(
                              index: 2,
                              child: Text(
                                'يمكنك البدء الآن. سيُجهَّز النظام والأدوات الأساسية لـ Doser AI تلقائيًا في الخلفية.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: palette.textSecondary,
                                      height: 1.6,
                                    ),
                              ),
                            ),
                            SizedBox(height: compact ? 18 : 26),
                            OnboardingEntrance(
                              index: 3,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _Capability(
                                      icon: LucideIcons.squareTerminal,
                                      label: 'الإعداد في الخلفية',
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: _Capability(
                                      icon: LucideIcons.brainCircuit,
                                      label: 'النماذج',
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: _Capability(
                                      icon: LucideIcons.messageCircle,
                                      label: 'المحادثة',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Flat icon-over-label capability hint — no bordered box.
class _Capability extends StatelessWidget {
  const _Capability({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: palette.accentPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: palette.accentPrimary),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
