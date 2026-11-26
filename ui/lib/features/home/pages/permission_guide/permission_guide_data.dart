import 'package:ui/services/device_service.dart';

class PermissionGuideStep {
  final String title;
  final String description;
  final String? imageAssetPath;

  const PermissionGuideStep({
    required this.title,
    required this.description,
    this.imageAssetPath,
  });
}

class PermissionGuideBrandInfo {
  final String id;
  final String name;
  final String osLabel;
  final List<String> aliases;

  const PermissionGuideBrandInfo({
    required this.id,
    required this.name,
    required this.osLabel,
    required this.aliases,
  });
}

class PermissionGuideTopicInfo {
  final String id;
  final String title;
  final String subtitle;
  final String iconPath;
  final String openMethod;
  final Set<String>? supportedBrands;
  final Map<String, List<PermissionGuideStep>> brandSteps;

  const PermissionGuideTopicInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.openMethod,
    required this.brandSteps,
    this.supportedBrands,
  });

  bool supportsBrand(String brandId) {
    return supportedBrands == null || supportedBrands!.contains(brandId);
  }

  List<PermissionGuideStep> stepsFor(String brandId) {
    return brandSteps[brandId] ?? brandSteps['other'] ?? const [];
  }
}

class PermissionGuideRepository {
  PermissionGuideRepository._();

  static const List<PermissionGuideBrandInfo> brands = [
    PermissionGuideBrandInfo(
      id: 'huawei',
      name: 'Huawei',
      osLabel: 'HarmonyOS 4.0',
      aliases: ['huawei'],
    ),
    PermissionGuideBrandInfo(
      id: 'honor',
      name: 'Honor',
      osLabel: 'MagicOS 8.0',
      aliases: ['honor', 'honour'],
    ),
    PermissionGuideBrandInfo(
      id: 'xiaomi',
      name: 'Xiaomi',
      osLabel: 'HyperOS 2.0',
      aliases: ['xiaomi', 'redmi'],
    ),
    PermissionGuideBrandInfo(
      id: 'oppo',
      name: 'OPPO / OnePlus / realme',
      osLabel: 'ColorOS 16',
      aliases: ['oppo', 'oneplus', 'realme'],
    ),
    PermissionGuideBrandInfo(
      id: 'vivo',
      name: 'vivo / iQOO',
      osLabel: 'OriginOS 4',
      aliases: ['vivo', 'iqoo'],
    ),
    PermissionGuideBrandInfo(
      id: 'meizu',
      name: 'Meizu',
      osLabel: 'Flyme 10',
      aliases: ['meizu', '魅族'],
    ),
    PermissionGuideBrandInfo(
      id: 'other',
      name: 'علامات تجارية أخرى',
      osLabel: 'Android',
      aliases: [],
    ),
  ];

  static const List<PermissionGuideTopicInfo> _topics = [
    PermissionGuideTopicInfo(
      id: 'overlay',
      title: 'إذن النوافذ العائمة',
      subtitle: 'السماح لـ Doser AI بالظهور فوق التطبيقات الأخرى، لاستدعائه في أي وقت.',
      iconPath: 'assets/welcome/permission_overlay.svg',
      openMethod: 'openOverlaySettings',
      brandSteps: {
        'oppo': [
          PermissionGuideStep(
            title: 'انقر على «إذن النوافذ العائمة»',
            description: 'في صفحة إرشادات الأذونات في Doser AI، انقر على هذا الإذن وسيتم نقلك إلى صفحة الإعدادات المقابلة.',
          ),
          PermissionGuideStep(
            title: 'اختر «Doser AI»',
            description: 'في قائمة «العرض فوق التطبيقات الأخرى»، ابحث عن Doser AI وانقر عليه.',
          ),
          PermissionGuideStep(
            title: 'فعّل مفتاح «العرض فوق التطبيقات الأخرى»',
            description: 'بعد التفعيل، يمكن لـ Doser AI الظهور في المقدمة بثبات.',
          ),
        ],
        'huawei': [
          PermissionGuideStep(
            title: 'انقر على «إذن النوافذ العائمة»',
            description: 'في صفحة إرشادات الأذونات في Doser AI، انقر على هذا الإذن وسيتم نقلك إلى صفحة الإعدادات المقابلة.',
          ),
          PermissionGuideStep(
            title: 'ابحث عن «Doser AI»',
            description: 'في قائمة إدارة النوافذ العائمة، ابحث عن Doser AI وفعّل الإذن.',
          ),
        ],
        'honor': [
          PermissionGuideStep(
            title: 'انقر على «إذن النوافذ العائمة»',
            description: 'في صفحة إرشادات الأذونات في Doser AI، انقر على هذا الإذن وسيتم نقلك إلى صفحة الإعدادات.',
          ),
          PermissionGuideStep(title: 'تفعيل إذن النوافذ العائمة', description: 'ابحث عن Doser AI وفعّل مفتاح النافذة العائمة。'),
        ],
        'xiaomi': [
          PermissionGuideStep(
            title: 'انقر على «إذن النوافذ العائمة»',
            description: 'في صفحة إرشادات الأذونات في Doser AI، انقر على هذا الإذن وسيتم نقلك إلى صفحة الإعدادات.',
          ),
          PermissionGuideStep(
            title: 'تفعيل إذن النوافذ العائمة',
            description: 'ابحث عن Doser AI وفعّل مفتاح «إظهار النافذة العائمة».',
          ),
        ],
        'vivo': [
          PermissionGuideStep(
            title: 'انقر على «إذن النوافذ العائمة»',
            description: 'في صفحة إرشادات الأذونات في Doser AI، انقر على هذا الإذن وسيتم نقلك إلى صفحة الإعدادات.',
          ),
          PermissionGuideStep(
            title: 'السماح بالعرض فوق التطبيقات الأخرى',
            description: 'ابحث عن Doser AI وفعّل إذن النوافذ العائمة.',
          ),
        ],
        'other': [
          PermissionGuideStep(title: 'افتح إعدادات النظام', description: 'ادخل إلى تطبيق «الإعدادات» في الهاتف.'),
          PermissionGuideStep(title: 'الدخول إلى إدارة التطبيقات', description: 'ابحث عن مدخل «التطبيقات» أو «إدارة التطبيقات».'),
          PermissionGuideStep(
            title: 'تفعيل إذن النوافذ العائمة',
            description: 'ابحث عن Doser AI، وفعّل في إعدادات الأذونات «النافذة العائمة» أو «العرض فوق التطبيقات الأخرى».',
          ),
        ],
      },
    ),
    PermissionGuideTopicInfo(
      id: 'battery',
      title: 'التشغيل في الخلفية / تحسين البطارية',
      subtitle: 'منع النظام من إيقاف Doser AI مبكرًا، لضمان استقرار التشغيل في الخلفية والاستدعاء.',
      iconPath: 'assets/welcome/permission_battery.svg',
      openMethod: 'openBatteryOptimizationSettings',
      supportedBrands: {'oppo', 'xiaomi', 'vivo', 'meizu', 'other'},
      brandSteps: {
        'oppo': [
          PermissionGuideStep(title: 'افتح الإعدادات', description: 'ادخل إلى تطبيق «الإعدادات» في الهاتف.'),
          PermissionGuideStep(
            title: 'الدخول إلى إعدادات «البطارية»',
            description: 'في صفحة الإعدادات، ابحث عن خيار «البطارية» وانقر عليه.',
          ),
          PermissionGuideStep(
            title: 'انقر على «مزيد من إعدادات البطارية»',
            description: 'مرّر للأسفل وابحث عن خيار «مزيد من إعدادات البطارية».',
          ),
          PermissionGuideStep(
            title: 'الدخول إلى «تحسين استهلاك بطارية التطبيقات»',
            description: 'انقر على «تحسين استهلاك بطارية التطبيقات» للدخول إلى قائمة التطبيقات.',
          ),
          PermissionGuideStep(
            title: 'اضبط Doser AI على «بدون تحسين»',
            description: 'ابحث عن Doser AI واضبطه على «بدون تحسين»، فلن يقيّد النظام تشغيله في الخلفية بسهولة.',
          ),
        ],
        'xiaomi': [
          PermissionGuideStep(title: 'افتح الإعدادات', description: 'ادخل إلى تطبيق «الإعدادات» في الهاتف.'),
          PermissionGuideStep(
            title: 'الدخول إلى «إعدادات التطبيقات»',
            description: 'انقر على «إعدادات التطبيقات» ثم واصل إلى «إدارة التطبيقات».',
          ),
          PermissionGuideStep(title: 'ابحث عن Doser AI', description: 'في قائمة التطبيقات، ابحث عن Doser AI وانقر عليه.'),
          PermissionGuideStep(
            title: 'اضبط «سياسة توفير الطاقة»',
            description: 'انقر على «سياسة توفير الطاقة» واختر «بدون قيود».',
          ),
        ],
        'vivo': [
          PermissionGuideStep(title: 'افتح الإعدادات', description: 'ادخل إلى تطبيق «الإعدادات» في الهاتف.'),
          PermissionGuideStep(
            title: 'الدخول إلى إعدادات «البطارية»',
            description: 'انقر على «البطارية» ثم ادخل إلى «إدارة استهلاك البطارية في الخلفية».',
          ),
          PermissionGuideStep(
            title: 'اضبط Doser AI على «السماح باستهلاك عالٍ للبطارية»',
            description: 'ابحث عن Doser AI واختر «السماح بالتشغيل في الخلفية مع استهلاك عالٍ للبطارية».',
          ),
        ],
        'other': [
          PermissionGuideStep(title: 'افتح إعدادات النظام', description: 'ادخل إلى تطبيق «الإعدادات» في الهاتف.'),
          PermissionGuideStep(
            title: 'ابحث عن البطارية أو إدارة الطاقة',
            description: 'ابحث عن «البطارية» أو «إدارة الطاقة» أو «الإدارة في الخلفية».',
          ),
          PermissionGuideStep(
            title: 'السماح بالتشغيل في الخلفية',
            description: 'ابحث عن Doser AI واضبطه على السماح بالتشغيل في الخلفية وبدون تحسين أو بدون قيود، ويُنصح بالتحقق من إذن التشغيل التلقائي أيضًا.',
          ),
        ],
      },
    ),
    PermissionGuideTopicInfo(
      id: 'appLaunch',
      title: 'إدارة تشغيل التطبيقات',
      subtitle: 'إعداد إضافي شائع للحفاظ على التشغيل في أجهزة Huawei / Honor، ويُنصح بمراجعته مع إذن التشغيل في الخلفية.',
      iconPath: 'assets/welcome/permission_autostart.svg',
      openMethod: 'openAutoStartSettings',
      supportedBrands: {'huawei', 'honor'},
      brandSteps: {
        'huawei': [
          PermissionGuideStep(
            title: 'افتح الإعدادات',
            description: 'ادخل إلى تطبيق «الإعدادات» في الهاتف.',
            imageAssetPath: 'assets/welcome/auto_start_guide_1.png',
          ),
          PermissionGuideStep(
            title: 'ابحث عن «إدارة تشغيل التطبيقات»',
            description: 'عبر البحث أو في «التطبيقات والخدمات»، ابحث عن «إدارة تشغيل التطبيقات».',
            imageAssetPath: 'assets/welcome/auto_start_guide_2.png',
          ),
          PermissionGuideStep(
            title: 'اضبط Doser AI على الإدارة اليدوية',
            description: 'أوقف الإدارة التلقائية، وفعّل السماح بالتشغيل التلقائي والتشغيل المرتبط والنشاط في الخلفية.',
            imageAssetPath: 'assets/welcome/auto_start_guide_3.png',
          ),
        ],
        'honor': [
          PermissionGuideStep(
            title: 'افتح الإعدادات',
            description: 'ادخل إلى تطبيق «الإعدادات» في الهاتف.',
            imageAssetPath: 'assets/welcome/auto_start_guide_1.png',
          ),
          PermissionGuideStep(
            title: 'ابحث عن «إدارة تشغيل التطبيقات»',
            description: 'عبر البحث أو من مدخل إدارة النظام، ابحث عن «إدارة تشغيل التطبيقات».',
            imageAssetPath: 'assets/welcome/auto_start_guide_2.png',
          ),
          PermissionGuideStep(
            title: 'أوقف الإدارة التلقائية واسمح بكل شيء',
            description: 'بعد العثور على Doser AI، أوقف الإدارة التلقائية وتأكد من تفعيل جميع مفاتيح النشاط في الخلفية.',
            imageAssetPath: 'assets/welcome/auto_start_guide_3.png',
          ),
        ],
      },
    ),
  ];

  static PermissionGuideBrandInfo brandInfo(String brandId) {
    final normalized = normalizeBrandId(brandId);
    for (final brand in brands) {
      if (brand.id == normalized) {
        return brand;
      }
    }
    return brands.last;
  }

  static List<PermissionGuideBrandInfo> selectableBrands() {
    return brands;
  }

  static String normalizeBrandId(String? rawBrand) {
    final raw = (rawBrand ?? '').trim().toLowerCase();
    if (raw.isEmpty) {
      return 'other';
    }

    for (final brand in brands) {
      if (brand.id == raw) {
        return brand.id;
      }
      for (final alias in brand.aliases) {
        if (raw.contains(alias)) {
          return brand.id;
        }
      }
    }
    return 'other';
  }

  static String normalizeDeviceBrand(Map<String, dynamic>? deviceInfo) {
    if (deviceInfo == null) {
      return 'other';
    }
    final joined = [
      deviceInfo['manufacturer'],
      deviceInfo['brand'],
      deviceInfo['model'],
    ].whereType<String>().join(' ').toLowerCase();
    return normalizeBrandId(joined);
  }

  static Future<String> detectCurrentBrand() async {
    try {
      final info = await DeviceService.getDeviceInfo();
      return normalizeDeviceBrand(info);
    } catch (_) {
      return 'other';
    }
  }

  static List<PermissionGuideTopicInfo> topicsForBrand(String brandId) {
    final normalized = normalizeBrandId(brandId);
    final topics = <PermissionGuideTopicInfo>[];
    for (final topic in _topics) {
      if (topic.supportsBrand(normalized)) {
        topics.add(topic);
      }
    }
    return topics;
  }

  static PermissionGuideTopicInfo? topicById(String topicId) {
    for (final topic in _topics) {
      if (topic.id == topicId) {
        return topic;
      }
    }
    return null;
  }
}
