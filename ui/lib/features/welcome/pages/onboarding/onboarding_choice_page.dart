import 'package:ui/widgets/navigation/page_route.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/constants/storage_keys.dart';
import 'package:ui/core/router/go_router_manager.dart';
import 'package:ui/features/home/pages/chat/chat_page.dart';
import 'package:ui/services/special_permission.dart';
import 'package:ui/services/storage_service.dart';
import 'package:ui/theme/theme_context.dart';

import 'onboarding_definitions.dart';
import 'onboarding_flow_controller.dart';
import 'onboarding_l10n.dart';
import 'onboarding_permission_controller.dart';
import 'onboarding_provider_controller.dart';
import 'pages/completion_page.dart';
import 'pages/model_inventory_page.dart';
import 'pages/permissions_page.dart';
import 'pages/provider_connection_page.dart';
import 'pages/provider_page.dart';
import 'pages/provider_selection_page.dart';
import 'pages/scene_models_page.dart';
import 'widgets/onboarding_common.dart';
import 'widgets/onboarding_footer.dart';

/// First-use tutorial: permissions, account access, model roles, and chat.
///
/// This widget is a thin orchestration layer — page content lives in
/// `pages/`, reusable UI in `widgets/`, and state in the controllers.
class OnboardingChoicePage extends StatefulWidget {
  const OnboardingChoicePage({super.key, this.allowExit = false});

  final bool allowExit;

  @override
  State<OnboardingChoicePage> createState() => _OnboardingChoicePageState();
}

class _OnboardingChoicePageState extends State<OnboardingChoicePage> {
  final ScrollController _scrollController = ScrollController();
  final OnboardingFlowController _flow = OnboardingFlowController();
  final OnboardingProviderController _provider = OnboardingProviderController();
  final OnboardingPermissionController _permission =
      OnboardingPermissionController();

  bool _isReplay = false;
  bool _isCompletingTutorial = false;
  double _horizontalDragDistance = 0;

  String _t(String zh, String en) => onbTr(context, zh, en);

  @override
  void initState() {
    super.initState();
    _isReplay =
        widget.allowExit ||
        (StorageService.getBool(
              StorageKeys.welcomeCompleted,
              defaultValue: false,
            ) ??
            false);
    _flow.addListener(_onControllerChanged);
    _provider.addListener(_onControllerChanged);
    _permission.addListener(_onControllerChanged);
    _permission.init();
  }

  @override
  void dispose() {
    _flow.removeListener(_onControllerChanged);
    _provider.removeListener(_onControllerChanged);
    _permission.removeListener(_onControllerChanged);
    _flow.dispose();
    _provider.dispose();
    _permission.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  void _goToPage(TutorialPage page) {
    if (_flow.page == page) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _flow.goTo(page);
    _afterPageChange(page);
  }

  void _jumpToVisitedTutorialPage(TutorialPage page) {
    if (page == _flow.page || !_flow.isVisited(page)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _flow.jumpToVisited(page);
    _afterPageChange(page);
  }

  void _afterPageChange(TutorialPage page) {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (page == TutorialPage.providerSelection) {
      unawaited(_provider.loadData(t: _t));
    }
    if (page == TutorialPage.permissions) {
      unawaited(_permission.refresh());
    }
  }

  void _handleBack() {
    if (_provider.busy || _provider.sceneModelsSaving) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_flow.goBack()) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }
    if (_isReplay) {
      Navigator.of(context).maybePop();
    }
  }

  bool get _showBottomBack => _flow.hasHistory || _isReplay;

  VoidCallback? get _tutorialNextAction {
    return switch (_flow.page) {
      TutorialPage.permissions => () => _goToPage(TutorialPage.provider),
      TutorialPage.provider => () => unawaited(_openChatTour()),
      TutorialPage.providerSelection when !_provider.loading => () => _goToPage(
        TutorialPage.providerConnection,
      ),
      TutorialPage.providerConnection when _provider.connected =>
        () => _goToPage(TutorialPage.modelInventory),
      TutorialPage.modelInventory when _provider.modelOptions.isNotEmpty =>
        () => _goToPage(TutorialPage.primaryScenes),
      TutorialPage.primaryScenes when _provider.modelOptions.isNotEmpty =>
        () => _goToPage(TutorialPage.memoryScenes),
      _ => null,
    };
  }

  String get _tutorialNextTooltip {
    return switch (_flow.page) {
      TutorialPage.provider => 'تعرّف على واجهة المحادثة أولًا',
      _ =>
        _tutorialNextAction == null
            ? 'أكمل هذه الصفحة أولًا'
            : 'التالي',
    };
  }

  Key get _tutorialNextKey {
    return switch (_flow.page) {
      TutorialPage.permissions => const ValueKey('tutorial-permissions-next'),
      TutorialPage.provider => const ValueKey('tutorial-skip-models'),
      TutorialPage.providerSelection => const ValueKey(
        'tutorial-provider-selection-next',
      ),
      TutorialPage.modelInventory => const ValueKey('tutorial-models-next'),
      TutorialPage.primaryScenes => const ValueKey(
        'tutorial-primary-scenes-next',
      ),
      _ => const ValueKey('tutorial-page-next'),
    };
  }

  void _goToNextTutorialPage() {
    _tutorialNextAction?.call();
  }

  // -------------------------------------------------------------------------
  // Swipe navigation
  // -------------------------------------------------------------------------

  void _handleTutorialDragStart(DragStartDetails details) {
    _horizontalDragDistance = 0;
  }

  void _handleTutorialDragUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.primaryDelta ?? 0;
  }

  void _handleTutorialDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final direction = _horizontalDragDistance.abs() >= 64
        ? _horizontalDragDistance
        : velocity.abs() >= 260
        ? velocity
        : 0;
    _horizontalDragDistance = 0;
    if (direction < 0) {
      _goToNextTutorialPage();
    } else if (direction > 0 && _showBottomBack) {
      _handleBack();
    }
  }

  // -------------------------------------------------------------------------
  // Flow orchestration
  // -------------------------------------------------------------------------

  Future<void> _configureProvider() async {
    final success = await _provider.configure(t: _t);
    if (success && mounted) {
      _goToPage(TutorialPage.modelInventory);
    }
  }

  Future<void> _requestShizuku() async {
    if (!mounted) return;
    await ensureShizukuPermission(context);
    if (mounted) {
      await _permission.refresh();
    }
  }

  Future<void> _saveSceneModels() async {
    final saved = await _provider.saveSceneModels(t: _t);
    if (saved && mounted) {
      await _openChatTour();
    }
  }

  Future<void> _openChatTour() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final tourCompleted = await Navigator.of(context).push<bool>(
      OmniPageRoute<bool>(
        builder: (_) => const ChatPage(showFirstUseTour: true),
        settings: const RouteSettings(name: 'first-use-chat-spotlight-tour'),
      ),
    );
    if (tourCompleted == true && mounted) {
      _goToPage(TutorialPage.completion);
    }
  }

  Future<void> _startExploring() async {
    if (_isCompletingTutorial) return;
    setState(() => _isCompletingTutorial = true);
    await StorageService.setBool(StorageKeys.welcomeCompleted, true);
    if (!mounted) return;
    setState(() => _isCompletingTutorial = false);
    GoRouterManager.clearAndNavigateTo(GoRouterManager.homeRoute);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final canPop = !_flow.hasHistory && _isReplay;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && (_flow.hasHistory || _isReplay)) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: palette.pageBackground,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('tutorial-page-swipe-surface'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart:
                      _flow.isOnNavigationPage &&
                          _flow.page != TutorialPage.provider
                      ? _handleTutorialDragStart
                      : null,
                  onHorizontalDragUpdate:
                      _flow.isOnNavigationPage &&
                          _flow.page != TutorialPage.provider
                      ? _handleTutorialDragUpdate
                      : null,
                  onHorizontalDragEnd:
                      _flow.isOnNavigationPage &&
                          _flow.page != TutorialPage.provider
                      ? _handleTutorialDragEnd
                      : null,
                  child: IndexedStack(
                    sizing: StackFit.expand,
                    index: _flow.page == TutorialPage.provider ? 0 : 1,
                    children: [
                      // Keep in-progress sign-in/registration (including the
                      // verification request) alive while exploring model setup.
                      TickerMode(
                        enabled: _flow.page == TutorialPage.provider,
                        child: _flow.isVisited(TutorialPage.provider)
                            ? const OnboardingProviderPage()
                            : const SizedBox.shrink(),
                      ),
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide =
                              Tween<Offset>(
                                begin: Offset(
                                  0.06 * _flow.transitionDirection,
                                  0,
                                ),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              );
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey<TutorialPage>(_flow.page),
                          child: _buildCurrentPage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_flow.isOnNavigationPage) _buildTutorialFooter(),
              if (_flow.page == TutorialPage.completion)
                _buildCompletionFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    return switch (_flow.page) {
      TutorialPage.permissions => OnboardingPermissionsPage(
        controller: _permission,
        scrollController: _scrollController,
        onRequestShizuku: _requestShizuku,
      ),
      TutorialPage.provider => const SizedBox.shrink(),
      TutorialPage.providerSelection => OnboardingProviderSelectionPage(
        controller: _provider,
        scrollController: _scrollController,
        onSelectProvider: () => _goToPage(TutorialPage.providerConnection),
      ),
      TutorialPage.providerConnection => OnboardingProviderConnectionPage(
        controller: _provider,
        scrollController: _scrollController,
        onConnect: _configureProvider,
      ),
      TutorialPage.modelInventory => OnboardingModelInventoryPage(
        controller: _provider,
        scrollController: _scrollController,
        onAddManualModel: () => _provider.addManualModel(t: _t),
      ),
      TutorialPage.primaryScenes => OnboardingSceneModelsPage(
        controller: _provider,
        scrollController: _scrollController,
        icon: LucideIcons.workflow,
        title: 'تكوين نماذج المحادثة والوكيل',
        description: 'لا مشكلة في استخدام نموذج عام واحد الآن، ويمكنك ضبط هذه الأدوار لاحقًا من إعدادات نماذج السيناريوهات.',
        scenes: sceneDefinitions
            .where((scene) => !scene.id.startsWith('scene.memory.'))
            .toList(growable: false),
      ),
      TutorialPage.memoryScenes => OnboardingSceneModelsPage(
        controller: _provider,
        scrollController: _scrollController,
        icon: LucideIcons.database,
        title: 'تكوين نماذج الذاكرة',
        description: 'نموذج التضمين مسؤول عن الاسترجاع، ونموذج التلخيص مسؤول عن تجميع الذاكرة طويلة المدى.',
        scenes: sceneDefinitions
            .where((scene) => scene.id.startsWith('scene.memory.'))
            .toList(growable: false),
        showError: true,
      ),
      TutorialPage.completion => const OnboardingCompletionPage(),
    };
  }

  Widget _buildTutorialFooter() {
    return OnboardingFooter(
      currentPage: _flow.page,
      isVisited: _flow.isVisited,
      canGoBack: _showBottomBack,
      onBack: _handleBack,
      nextKey: _tutorialNextKey,
      nextTooltip: _tutorialNextTooltip,
      onNext: _tutorialNextAction == null ? null : _goToNextTutorialPage,
      onJumpToPage: _jumpToVisitedTutorialPage,
      primaryAction:
          MediaQuery.viewInsetsOf(context).bottom > 0 &&
              _flow.page == TutorialPage.provider
          ? null
          : _buildTutorialPrimaryAction(),
    );
  }

  Widget? _buildTutorialPrimaryAction() {
    return switch (_flow.page) {
      TutorialPage.provider => TextButton.icon(
        key: const ValueKey('tutorial-provider-next'),
        onPressed: () => _goToPage(TutorialPage.providerSelection),
        icon: const Icon(LucideIcons.settings2, size: 17),
        label: Text('اختياري: تكوين نموذجك الخاص'),
      ),
      TutorialPage.providerConnection => OnboardingPrimaryButton(
        buttonKey: const ValueKey('tutorial-provider-connect'),
        label: _provider.busy
            ? 'جارٍ الاتصال وجلب النماذج…'
            : _provider.connected
            ? 'إعادة الاتصال وجلب النماذج'
            : 'الاتصال وجلب النماذج',
        icon: _provider.connected ? LucideIcons.refreshCw : LucideIcons.plugZap,
        onPressed: _provider.busy ? null : _configureProvider,
      ),
      TutorialPage.memoryScenes => OnboardingPrimaryButton(
        buttonKey: const ValueKey('tutorial-save-scenes'),
        label: _provider.sceneModelsSaving
            ? 'جارٍ حفظ تكوين السيناريوهات…'
            : 'احفظ وتعرّف على واجهة المحادثة',
        icon: LucideIcons.arrowRight,
        onPressed:
            _provider.sceneModelsSaving ||
                _provider.activeProfile == null ||
                _provider.modelOptions.isEmpty
            ? null
            : _saveSceneModels,
      ),
      _ => null,
    };
  }

  Widget _buildCompletionFooter() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: SizedBox(
            key: const ValueKey('tutorial-completion-footer'),
            height: 58,
            child: Row(
              children: [
                OnboardingArrowButton(
                  buttonKey: const ValueKey('tutorial-bottom-back'),
                  icon: LucideIcons.arrowLeft,
                  tooltip: 'رجوع',
                  onPressed: _isCompletingTutorial ? null : _handleBack,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OnboardingPrimaryButton(
                    buttonKey: const ValueKey('tutorial-start-exploring'),
                    label: _isCompletingTutorial
                        ? 'جارٍ الدخول…'
                        : 'ابدأ الاستكشاف',
                    icon: LucideIcons.rocket,
                    onPressed: _isCompletingTutorial ? null : _startExploring,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
