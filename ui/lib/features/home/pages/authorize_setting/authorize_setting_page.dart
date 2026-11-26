import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/widgets/glass_popup.dart';
import 'package:ui/widgets/flclash/popup.dart';
import 'package:ui/widgets/flclash/page_activity.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/features/home/pages/authorize/accessibility_permission_prompt.dart';
import 'package:ui/l10n/l10n.dart';
import 'package:ui/services/special_permission.dart';
import 'package:ui/services/personal_context_service.dart';
import 'package:ui/features/home/pages/authorize_setting/personal_context_labels.dart';
import 'package:ui/features/home/pages/authorize_setting/root_access_setting.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/omni_menu.dart';
import 'package:ui/utils/cache_util.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/settings_ui.dart';

/// 应用权限授权页面
class AuthorizeSettingPage extends StatefulWidget {
  const AuthorizeSettingPage({super.key});

  @override
  State<AuthorizeSettingPage> createState() => _AuthorizeSettingPageState();
}

class _AuthorizeSettingPageState extends State<AuthorizeSettingPage>
    with WidgetsBindingObserver, FlClashPageLoadMixin {
  bool notificationEnabled = true; // 接收消息通知

  // 权限状态
  bool _backgroundRunning = false;
  bool _accessibilityReady = false;
  bool _overlayPermission = false;
  bool _installedAppsPermission = false;
  bool _publicStoragePermission = false;
  bool _localNetworkPermissionRequired = false;
  bool _localNetworkPermissionGranted = false;
  ShizukuStatusSnapshot _shizukuStatus = ShizukuStatusSnapshot.fallback();
  Map<String, PersonalContextCapability> _personalContext = {};
  bool _personalContextLoaded = false;
  bool _personalContextFailed = false;

  Color get _pageBackground => context.omniPalette.pageBackground;
  Color get _titleColor => context.omniPalette.textPrimary;
  Color get _subtitleColor => context.omniPalette.textSecondary;
  Color get _tertiaryTextColor => context.omniPalette.textTertiary;
  Color get _accentColor => context.omniPalette.accentPrimary;
  int get _corePermissionCount => 4;
  int get _readyCorePermissionCount => <bool>[
    _backgroundRunning,
    _accessibilityReady,
    _overlayPermission,
    _installedAppsPermission,
  ].where((value) => value).length;
  bool get _allCorePermissionsEnabled =>
      _readyCorePermissionCount == _corePermissionCount;
  double get _corePermissionProgress =>
      _readyCorePermissionCount / _corePermissionCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _loadSettings() async {
    if (!await waitForPageReady() || !mounted) return;
    try {
      final notification = await CacheUtil.getBool("notification_enabled");
      if (!await waitForPageReady() || !mounted) return;
      setState(() {
        notificationEnabled = notification;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _toggleNotification(bool value) async {
    await CacheUtil.cacheBool("notification_enabled", value);
    if (!mounted) return;
    setState(() {
      notificationEnabled = value;
    });
  }

  List<_AuthorizeSettingSection> _buildSections() {
    return [
      _AuthorizeSettingSection(
        label: 'الإشعارات',
        subtitle: 'تحكم في طريقة استلام تحديثات تقدم المهام والتذكيرات.',
        items: [
          _AuthorizeSettingItem(
            icon: LucideIcons.bell,
            title: context.l10n.authorizeReceiveNotifications,
            subtitle: context.l10n.authorizeNotificationsDesc,
            trailing: _buildSwitchTrailing(
              value: notificationEnabled,
              onToggle: _toggleNotification,
            ),
            onTap: () {
              _toggleNotification(!notificationEnabled);
            },
          ),
        ],
      ),
      _AuthorizeSettingSection(
        label: 'الأذونات الأساسية',
        subtitle: 'تدعم هذه الأذونات التحكم في الواجهة، والعرض العائم، والتشغيل في الخلفية، واكتشاف التطبيقات المثبتة.',
        items: [
          _AuthorizeSettingItem(
            icon: LucideIcons.accessibility,
            title: 'إذن الوصول',
            subtitle: 'لقراءة الشاشة وتنفيذ النقر والتمرير والإدخال. فعّلها من «إمكانية الوصول» في إعدادات النظام.',
            trailing: _buildPermissionTrailing(
              label: context.trLegacy(_accessibilityReady ? '已开启' : '去开启'),
              color: _accessibilityReady ? _tertiaryTextColor : _accentColor,
            ),
            onTap: () async {
              await showAccessibilityPermissionPrompt(context);
              if (mounted) await _checkPermissions();
            },
          ),
          _AuthorizeSettingItem(
            icon: LucideIcons.batteryCharging,
            title: context.trLegacy('后台运行权限'),
            subtitle: 'قلّل من إيقاف النظام للخدمات حتى تستمر الرسائل والمهام المجدولة والخدمات المحلية بثبات.',
            trailing: _buildPermissionTrailing(
              label: context.trLegacy(_backgroundRunning ? '已开启' : '去开启'),
              color: _backgroundRunning ? _tertiaryTextColor : _accentColor,
            ),
            onTap: () {
              spePermission.invokeMethod('openBatteryOptimizationSettings');
            },
          ),
          _AuthorizeSettingItem(
            icon: LucideIcons.pictureInPicture2,
            title: context.trLegacy('悬浮窗权限'),
            subtitle: 'اسمح لـ Doser AI بعرض الحيوان الأليف والدردشة بنصف الشاشة وتذكيرات المهام فوق التطبيقات الأخرى.',
            trailing: _buildPermissionTrailing(
              label: context.trLegacy(_overlayPermission ? '已开启' : '去开启'),
              color: _overlayPermission ? _tertiaryTextColor : _accentColor,
            ),
            onTap: () {
              spePermission.invokeMethod('openOverlaySettings');
            },
          ),
          _AuthorizeSettingItem(
            icon: LucideIcons.layoutGrid,
            title: context.trLegacy('应用列表读取'),
            subtitle: 'تُستخدم للتعرف على التطبيقات المثبتة وتوفير سياق التطبيقات.',
            trailing: _buildPermissionTrailing(
              label: context.trLegacy(_installedAppsPermission ? '已开启' : '去开启'),
              color: _installedAppsPermission
                  ? _tertiaryTextColor
                  : _accentColor,
            ),
            onTap: () {
              spePermission.invokeMethod('openInstalledAppsSettings');
            },
          ),
        ],
      ),
      _AuthorizeSettingSection(
        label: 'الوصول المتقدم',
        footer: const RootAccessSetting(),
        subtitle: 'فعّلها عند الحاجة للحصول على قدرات أوسع على مستوى النظام وتوافق أفضل.',
        items: [
          if (_localNetworkPermissionRequired)
            _AuthorizeSettingItem(
              icon: LucideIcons.wifi,
              title: 'الشبكة المحلية',
              subtitle: 'اتصل بالحواسيب ومزودي النماذج وخدمات MCP على شبكتك، أو اسمح للحاسوب بالوصول إلى Doser AI.',
              trailing: _buildPermissionTrailing(
                label: context.trLegacy(
                  _localNetworkPermissionGranted ? 'مفعّلة' : 'تفعيل',
                ),
                color: _localNetworkPermissionGranted
                    ? _tertiaryTextColor
                    : _accentColor,
              ),
              onTap: _requestLocalNetworkAccess,
            ),
          _AuthorizeSettingItem(
            icon: LucideIcons.folderOpen,
            title: 'الوصول إلى كل الملفات',
            subtitle: 'اسمح لـ Doser AI بقراءة وإدارة الملفات في التخزين المشترك للجهاز لمهام الملفات والتنزيلات.',
            trailing: _buildPermissionTrailing(
              label: context.trLegacy(_publicStoragePermission ? '已开启' : '去开启'),
              color: _publicStoragePermission
                  ? _tertiaryTextColor
                  : _accentColor,
            ),
            onTap: () {
              openPublicStorageSettings();
            },
          ),
          _AuthorizeSettingItem(
            icon: LucideIcons.usb,
            title: context.trLegacy('Shizuku 权限'),
            subtitle: _shizukuStatus.localizedGuide,
            trailing: _buildPermissionTrailing(
              label: _shizukuStatus.localizedStatusLabel,
              color: _shizukuStatus.isGranted
                  ? _tertiaryTextColor
                  : _accentColor,
            ),
            onTap: () async {
              await ensureShizukuPermission(context);
              if (mounted) {
                await _checkPermissions();
              }
            },
          ),
        ],
      ),
      _buildPersonalContextSection(),
    ];
  }

  _AuthorizeSettingSection _buildPersonalContextSection() {
    return _AuthorizeSettingSection(
      label: 'السياق الشخصي',
      subtitle: 'اختر المعلومات التي تريد مشاركتها. يستعلم الذكاء الاصطناعي عن البيانات عند الحاجة وقد يرسل النتائج إلى النموذج الذي كوّنته. لا تُحفظ البيانات تلقائياً كذاكرة طويلة المدى.',
      items: [
        for (final item in personalContextLabels)
          _AuthorizeSettingItem(
            icon: item.icon,
            title: item.ar,
            subtitle: item.arDetail,
            trailing: _buildPermissionTrailing(
              label: _personalContextStatus(item.id),
              color:
                  _personalContext[item.id]?.status ==
                      PersonalContextAccessStatus.granted
                  ? _tertiaryTextColor
                  : _accentColor,
            ),
            onTap: item.id == 'documents'
                ? null
                : () => _openPersonalContext(item.id),
            onMenuTap: item.id == 'documents'
                ? (anchorContext) => _openPersonalContext(
                    item.id,
                    anchorContext: anchorContext,
                  )
                : null,
          ),
        _AuthorizeSettingItem(
          icon: LucideIcons.trash2,
          title: 'مسح سجل الإشعارات',
          subtitle: 'احذف ذاكرة الإشعارات المحلية المؤقتة. ستبقى إشعارات النظام والمحادثات.',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _personalContextAction(
            PersonalContextService.clearNotifications,
            'تم مسح سجل الإشعارات',
          ),
        ),
      ],
    );
  }

  String _personalContextStatus(String id) {
    if (!_personalContextLoaded) return 'جارٍ الفحص';
    if (_personalContextFailed) return 'انقر لإعادة المحاولة';
    final status =
        _personalContext[id]?.status ?? PersonalContextAccessStatus.unavailable;
    return switch (status) {
      PersonalContextAccessStatus.granted =>
          id == 'environment' ? 'متاح' : 'مفعّل',
      PersonalContextAccessStatus.partial =>
          id == 'location' ? 'موقع تقريبي' : 'وصول جزئي',
      PersonalContextAccessStatus.denied =>
          id == 'documents' ? 'اختيار' : 'تفعيل',
      PersonalContextAccessStatus.restricted => 'مقيّد',
      PersonalContextAccessStatus.disconnected => 'غير متصل',
      PersonalContextAccessStatus.unavailable => 'غير متاح',
    };
  }

  Future<void> _refreshPersonalContext() async {
    if (!await waitForPageReady() || !mounted) return;
    try {
      final capabilities = await PersonalContextService.capabilities();
      if (await waitForPageReady() && mounted) {
        setState(() {
          _personalContext = capabilities;
          _personalContextLoaded = true;
          _personalContextFailed = false;
        });
      }
    } catch (_) {
      if (await waitForPageReady() && mounted) {
        setState(() {
          _personalContextLoaded = true;
          _personalContextFailed = true;
        });
      }
    }
  }

  Future<void> _personalContextAction(
    Future<void> Function() action, [
    String? message,
  ]) async {
    try {
      await action();
      await _refreshPersonalContext();
      if (mounted && message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر إكمال هذا الإجراء. تحقق من إعدادات النظام وحاول مجدداً.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openPersonalContext(
    String id, {
    BuildContext? anchorContext,
  }) async {
    if (_personalContextFailed || !_personalContextLoaded) {
      await _refreshPersonalContext();
      return;
    }
    if (id == 'environment' ||
        _personalContext[id]?.status ==
            PersonalContextAccessStatus.unavailable) {
      return;
    }
    if (id == 'background_location' &&
        ![
          PersonalContextAccessStatus.granted,
          PersonalContextAccessStatus.partial,
        ].contains(_personalContext['location']?.status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فعّل الوصول إلى الموقع أعلاه أولاً.',
          ),
        ),
      );
      return;
    }
    if (id == 'documents') {
      if (anchorContext == null) return;
      final anchor = glassPopupAnchorFromContext(anchorContext);
      if (anchor == null) return;
      final action = await showOmniMenu<String>(
        context: context,
        sourceContext: anchorContext,
        anchor: anchor,
        width: 300,
        items: [
          OmniPopupMenuItem(
            value: 'files',
            child: Text('اختيار ملفات'),
          ),
          OmniPopupMenuItem(
            value: 'directory',
            child: Text('اختيار مجلد'),
          ),
          OmniPopupMenuItem(
            value: 'revoke',
            child: Text(
              'إزالة الوصول إلى الملفات والمجلدات المحددة',
            ),
          ),
        ],
      );
      if (action == null || !mounted) return;
      if (action == 'revoke') {
        await _personalContextAction(PersonalContextService.revokeDocuments);
        return;
      }
      await _personalContextAction(
        () => PersonalContextService.request(
          id,
          directory: action == 'directory',
        ),
      );
      return;
    }
    await _personalContextAction(() => PersonalContextService.request(id));
  }

  Future<void> _checkPermissions() async {
    if (!await waitForPageReady() || !mounted) return;
    await _refreshPersonalContext();
    if (!await waitForPageReady() || !mounted) return;
    try {
      final backgroundRunning = await isBackgroundRunAllowed();
      final accessibilityReady =
          await spePermission.invokeMethod<bool>(
            'isAndroidGuiAccessibilityReady',
          ) ??
          false;
      final overlayPermission =
          await spePermission.invokeMethod('isOverlayPermission') ?? false;
      final installedAppsPermission =
          await spePermission.invokeMethod(
            'isInstalledAppsPermissionGranted',
          ) ??
          false;
      final publicStoragePermission = await isPublicStorageAccessGranted();
      final localNetworkStatus = await spePermission
          .invokeMapMethod<String, dynamic>('getLocalNetworkPermissionStatus');
      final shizukuStatus = await getShizukuStatus();

      if (await waitForPageReady() && mounted) {
        setState(() {
          _backgroundRunning = backgroundRunning;
          _accessibilityReady = accessibilityReady;
          _overlayPermission = overlayPermission;
          _installedAppsPermission = installedAppsPermission;
          _publicStoragePermission = publicStoragePermission;
          _localNetworkPermissionRequired =
              localNetworkStatus?['required'] == true;
          _localNetworkPermissionGranted =
              localNetworkStatus?['granted'] == true;
          _shizukuStatus = shizukuStatus;
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<void> _requestLocalNetworkAccess() async {
    try {
      if (_localNetworkPermissionGranted) {
        await spePermission.invokeMethod('openAppDetailsSettings');
        return;
      }
      final granted = await spePermission.invokeMethod<bool>(
        'requestLocalNetworkPermission',
      );
      if (!mounted) return;
      if (granted != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم رفض الوصول إلى الشبكة المحلية. اسمح بـ«الأجهزة القريبة» في أذونات التطبيق في إعدادات النظام.',
            ),
            action: SnackBarAction(
              label: 'فتح الإعدادات',
              onPressed: () =>
                  spePermission.invokeMethod('openAppDetailsSettings'),
            ),
          ),
        );
      }
      await _checkPermissions();
    } catch (error) {
      if (mounted) {
        showToast(
          'تعذّر طلب الوصول إلى الشبكة المحلية. فعّله في أذونات التطبيق في إعدادات النظام.',
          type: ToastType.warning,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections();

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: CommonAppBar(
        title: context.l10n.authorizePageTitle,
        primary: true,
      ),
      body: OmniContentWidth(
        child: SafeArea(
          top: false,
          bottom: false,
          child: ListView.separated(
            padding: edgeToEdgeScrollPadding(
              context,
              const EdgeInsets.fromLTRB(22, 12, 22, 32),
            ),
            itemCount: sections.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 22),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildOverview();
              }
              return _buildSettingsSection(sections[index - 1]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    final palette = context.omniPalette;
    final progress = _corePermissionProgress.clamp(0.0, 1.0);

    return OmniSettingsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              '$_readyCorePermissionCount من أصل $_corePermissionCount من الأذونات الأساسية جاهزة',
              key: ValueKey<int>(_readyCorePermissionCount),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _titleColor,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'فعّل أولاً الأذونات الضرورية لتنفيذ المهام. قد يؤدي نقص الأذونات إلى مقاطعة المساعد العائم والمهام الخلفية.',
            style: TextStyle(fontSize: 12, height: 1.5, color: _subtitleColor),
          ),
          const SizedBox(height: 14),
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
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      color: palette.accentPrimary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              _allCorePermissionsEnabled
                  ? 'الأذونات الأساسية جاهزة. يمكنك تكوين الوصول المتقدم عند الحاجة.'
                  : 'أكمل الأذونات الأساسية أولاً قبل تشغيل المهام التي تحتاج إلى تفاعل عائم أو تنفيذ في الخلفية.',
              key: ValueKey<bool>(_allCorePermissionsEnabled),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _allCorePermissionsEnabled
                    ? _accentColor
                    : _subtitleColor,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(_AuthorizeSettingSection section) {
    return OmniSettingsGroup(
      title: section.label,
      subtitle: section.subtitle,
      translateTitle: false,
      children: [
        for (final item in section.items)
          if (item.onMenuTap != null)
            FlClashPopupSource(
              glass: false,
              color: Colors.transparent,
              shape: const RoundedRectangleBorder(),
              builder: (anchorContext) => OmniSettingsTile(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                trailing: item.trailing,
                onTap: () => item.onMenuTap!(anchorContext),
                translateText: false,
              ),
            )
          else
            OmniSettingsTile(
              icon: item.icon,
              title: item.title,
              subtitle: item.subtitle,
              trailing: item.trailing,
              onTap: item.onTap,
              translateText: false,
            ),
        if (section.footer != null) section.footer!,
      ],
    );
  }

  Widget _buildPermissionTrailing({
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Icon(LucideIcons.chevronRight, size: 16, color: _tertiaryTextColor),
      ],
    );
  }

  Widget _buildSwitchTrailing({
    required bool value,
    required ValueChanged<bool> onToggle,
  }) {
    return OmniSettingsSwitch(value: value, onToggle: onToggle);
  }
}

class _AuthorizeSettingSection {
  final String label;
  final String? subtitle;
  final List<_AuthorizeSettingItem> items;
  final Widget? footer;

  const _AuthorizeSettingSection({
    required this.label,
    this.subtitle,
    required this.items,
    this.footer,
  });
}

class _AuthorizeSettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final ValueChanged<BuildContext>? onMenuTap;

  const _AuthorizeSettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onMenuTap,
  });
}
