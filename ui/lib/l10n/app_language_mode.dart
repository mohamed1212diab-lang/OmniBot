import 'dart:ui';

enum AppLanguageMode {
  system('system'),
  ar('ar');

  const AppLanguageMode(this.storageValue);

  final String storageValue;

  static AppLanguageMode fromStorageValue(String? raw) {
    final normalized = raw?.trim();
    return AppLanguageMode.values.firstWhere(
      (mode) => mode.storageValue == normalized,
      orElse: () => AppLanguageMode.system,
    );
  }
}

class ResolvedAppLocale {
  const ResolvedAppLocale({
    required this.mode,
    required this.systemLocale,
    required this.locale,
  });

  final AppLanguageMode mode;
  final Locale systemLocale;
  final Locale locale;

  bool get isArabic => locale.languageCode == 'ar';
  String get brandName => 'Doser AI';
}

ResolvedAppLocale resolveAppLocale({
  required AppLanguageMode mode,
  required Locale systemLocale,
}) {
  final normalizedSystemLocale = _normalizeSupportedLocale(systemLocale);
  final resolvedLocale = switch (mode) {
    AppLanguageMode.system => normalizedSystemLocale,
    AppLanguageMode.ar => const Locale('ar'),
  };

  return ResolvedAppLocale(
    mode: mode,
    systemLocale: normalizedSystemLocale,
    locale: resolvedLocale,
  );
}

Locale _normalizeSupportedLocale(Locale _) {
  return const Locale('ar');
}
