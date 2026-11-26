import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/l10n/app_language_mode.dart';
import 'package:ui/l10n/legacy_text_localizer.dart';

void main() {
  tearDown(LegacyTextLocalizer.clearResolvedLocale);

  test('uses active locale override for legacy translations', () {
    LegacyTextLocalizer.setResolvedLocale(const Locale('zh'));
    expect(LegacyTextLocalizer.localize('设置'), '设置');

    LegacyTextLocalizer.setResolvedLocale(const Locale('en'));
    expect(LegacyTextLocalizer.localize('设置'), 'Settings');

    LegacyTextLocalizer.setResolvedLocale(const Locale('ar'));
    expect(LegacyTextLocalizer.localize('设置'), 'الإعدادات');
    expect(
      LegacyTextLocalizer.localize('另一个终端环境准备任务正在运行，请稍后再试。'),
      'Another terminal environment setup task is already running. Please try again later.',
    );
    expect(
      LegacyTextLocalizer.localize(
        '环境检测失败，无法确认组件状态：Failed to extract alpine rootfs.',
      ),
      'Environment check failed; unable to confirm component status: Failed to extract alpine rootfs.',
    );
    expect(
      LegacyTextLocalizer.localize('正在下载 Ubuntu 运行资源 12.0 MB / 28.5 MB'),
      'Downloading Ubuntu runtime 12.0 MB / 28.5 MB',
    );
  });

  test('supports ar locale resolution, translations, and Arabic fallback', () {
    final autoAr = resolveAppLocale(
      mode: AppLanguageMode.system,
      systemLocale: const Locale('ar'),
    );
    expect(autoAr.locale, const Locale('ar'));
    expect(autoAr.isArabic, isTrue);
    expect(autoAr.brandName, 'Doser AI');

    final explicitAr = resolveAppLocale(
      mode: AppLanguageMode.ar,
      systemLocale: const Locale('zh', 'CN'),
    );
    expect(explicitAr.locale, const Locale('ar'));

    // Non-Arabic system locales also resolve to Arabic (Arabic-only app).
    final foreignAr = resolveAppLocale(
      mode: AppLanguageMode.system,
      systemLocale: const Locale('en', 'US'),
    );
    expect(foreignAr.locale, const Locale('ar'));

    expect(
      LegacyTextLocalizer.localize(
        '另一个终端环境准备任务正在运行，请稍后再试。',
        locale: const Locale('pt', 'BR'),
      ),
      'Outra tarefa de preparação do terminal já está em execução. Tente novamente em instantes.',
    );
    expect(
      LegacyTextLocalizer.localize(
        '小万正在思考...',
        locale: const Locale('pt', 'BR'),
      ),
      'Omnibot is thinking...',
    );
    expect(
      LegacyTextLocalizer.localize(
        '小万正在思考...',
        locale: const Locale('ar'),
      ),
      'Doser AI يفكّر...',
    );
    expect(
      LegacyTextLocalizer.localize(
        '内嵌终端环境已初始化，但基础 Agent CLI 包安装失败：403 Forbidden',
        locale: const Locale('en'),
      ),
      'Embedded terminal initialized, but installing base Agent CLI packages failed: 403 Forbidden',
    );
    expect(
      LegacyTextLocalizer.localize(
        '内嵌终端环境已初始化，但基础 Agent CLI 包安装失败：403 Forbidden',
        locale: const Locale('pt', 'BR'),
      ),
      'Terminal integrado inicializado, mas falhou ao instalar pacotes base de CLI: 403 Forbidden',
    );
  });
}
