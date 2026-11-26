import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/core/router/go_router_manager.dart';
import 'package:ui/features/home/pages/agent/agent_mode_setting_page.dart';
import 'package:ui/l10n/generated/app_localizations.dart';
import 'package:ui/services/storage_service.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/navigation/open_container.dart';
import 'package:ui/widgets/settings_detail_sheet.dart';
import 'package:ui/widgets/settings_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const agentRuntimeChannel = MethodChannel('cn.com.omnimind.bot/AgentRuntime');
  const pluginPlatformChannel = MethodChannel(
    'cn.com.omnimind.bot/PluginPlatform',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
          if (call.method != 'agent/list') return null;
          return <String, dynamic>{
            'agents': <Map<String, dynamic>>[
              _agent('codex-acp', 'Codex', 'codex-acp', 'online'),
              _agent(
                'claude-code-acp',
                'Claude Code',
                'claude-agent-acp',
                'missing',
              ),
              _agent(
                'opencode-acp',
                'OpenCode',
                'opencode',
                'offline',
                arguments: const ['acp'],
              ),
              _agent(
                'kimi-code-acp',
                'Kimi Code',
                'kimi',
                'unchecked',
                managedAdapter: true,
              ),
            ],
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginPlatformChannel, (call) async {
          if (call.method == 'listActions') return <dynamic>[];
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agentRuntimeChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginPlatformChannel, null);
  });

  testWidgets('shows only OpenCode from the managed catalog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: const AgentModeSettingPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OpenCode'), findsOneWidget);
    expect(find.text('Codex'), findsNothing);
    expect(find.text('Claude Code'), findsNothing);
    expect(find.text('Kimi Code'), findsNothing);
    expect(find.text('Agents'), findsNothing);
    // Toolbar title plus the single group title.
    expect(find.text('الوكيل'), findsNWidgets(2));
    expect(find.text('تعذّر البدء'), findsOneWidget);
    expect(find.text('جاهز'), findsNothing);
    expect(find.text('غير مثبّت'), findsNothing);
    // The unmanaged OpenCode row offers a re-check, not install actions.
    expect(find.text('تحقق مجدداً'), findsOneWidget);
    expect(find.text('إعادة التثبيت'), findsNothing);
    expect(find.text('تثبيت'), findsNothing);
    expect(find.text('تحديث'), findsNothing);
    expect(find.byKey(const Key('agent-refresh-button')), findsOneWidget);
    expect(find.byTooltip('تحديث'), findsOneWidget);
    expect(find.byKey(const Key('agent-search-button')), findsNothing);
    expect(find.byKey(const Key('agent-contact-search')), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(OmniSettingsGroup), findsOneWidget);
    expect(
      find.byKey(const Key('agent-navigation-opencode-acp')),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
    expect(find.text('Agent WebUI'), findsNothing);
    expect(find.text('صيانة'), findsNothing);
    expect(find.text('OpenCode غير متاح حالياً'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides every other agent in a full multi-agent catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
          if (call.method != 'agent/list') return null;
          return {
            'agents': [
              _agent('xiaowan-acp', '小万', 'xiaowan', 'online'),
              _agent('na-cloud', 'Na', 'na-cloud', 'offline'),
              _agent('claude-code-acp', 'Claude Code', 'claude', 'online'),
              _agent('codex-acp', 'Codex', 'codex', 'online'),
              _agent(
                'opencode-acp',
                'OpenCode',
                'opencode',
                'missing',
                managedAdapter: true,
              ),
              _agent('pi-acp', 'Pi', 'pi', 'online'),
              _agent('kimi-code-acp', 'Kimi Code', 'kimi', 'missing'),
              {
                ..._agent('custom-z', 'Z Agent', 'z', 'online'),
                'builtIn': false,
              },
              {
                ..._agent('custom-a', 'A Agent', 'a', 'online'),
                'builtIn': false,
              },
            ],
          };
        });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: const AgentModeSettingPage(embedded: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OpenCode'), findsOneWidget);
    for (final name in [
      '小万',
      'Na',
      'Claude Code',
      'Codex',
      'Pi',
      'Kimi Code',
      'Z Agent',
      'A Agent',
    ]) {
      expect(find.text(name), findsNothing);
    }
    expect(find.text('الوكيل'), findsNWidgets(2));
    expect(find.text('غير مثبّت'), findsOneWidget);
    expect(find.text('تثبيت'), findsOneWidget);
    expect(find.byKey(const Key('agent-refresh-button')), findsOneWidget);
    expect(find.byKey(const Key('agent-search-button')), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Agent WebUI'), findsNothing);
    expect(find.text('صيانة'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the OpenCode empty state when the catalog has no OpenCode', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
          if (call.method != 'agent/list') return null;
          return <String, dynamic>{
            'agents': <Map<String, dynamic>>[
              _agent('codex-acp', 'Codex', 'codex-acp', 'online'),
              _agent('claude-code-acp', 'Claude Code', 'claude', 'missing'),
              _agent('kimi-code-acp', 'Kimi Code', 'kimi', 'online'),
            ],
          };
        });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: const AgentModeSettingPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OpenCode غير متاح حالياً'), findsOneWidget);
    // Only the toolbar title remains; there is no group without the agent.
    expect(find.text('الوكيل'), findsOneWidget);
    expect(find.text('OpenCode'), findsNothing);
    expect(find.byType(OmniSettingsGroup), findsNothing);
    expect(
      find.byKey(const Key('agent-config-opencode-acp')),
      findsNothing,
    );
    expect(find.byKey(const Key('agent-refresh-button')), findsOneWidget);
    expect(find.byKey(const Key('agent-search-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh button and reactivation reload the OpenCode catalog', (
    tester,
  ) async {
    var catalogReads = 0;
    var refreshReads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
          if (call.method == 'agent/refresh') {
            refreshReads++;
            return {
              'agents': [
                _agent('opencode-acp', 'OpenCode', 'opencode', 'online'),
              ],
            };
          }
          if (call.method != 'agent/list') return null;
          catalogReads++;
          return {
            'agents': [
              _agent(
                'opencode-acp',
                'OpenCode',
                'opencode',
                catalogReads > 1 ? 'online' : 'offline',
              ),
            ],
          };
        });
    Widget page(bool active) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: AgentModeSettingPage(embedded: true, active: active),
    );
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(find.text('الوكيل'), findsNWidgets(2));
    expect(find.text('OpenCode'), findsOneWidget);
    expect(find.text('تعذّر البدء'), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevronLeft), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('agent-avatar-OpenCode'))),
      const Size(44, 44),
    );
    expect(find.byKey(const Key('agent-refresh-button')), findsOneWidget);
    expect(find.byTooltip('تحديث'), findsOneWidget);
    expect(find.byKey(const Key('agent-search-button')), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('agent-refresh-button')));
    await tester.pumpAndSettle();
    expect(refreshReads, 1);
    expect(catalogReads, 1);
    expect(find.text('جاهز'), findsOneWidget);
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    expect(catalogReads, 1);
    expect(
      ModalRoute.of(tester.element(find.byType(AgentModeSettingPage)))!
          .popDisposition,
      RoutePopDisposition.bubble,
    );
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(catalogReads, 2);
    expect(refreshReads, 1);
    expect(find.text('OpenCode'), findsOneWidget);
    expect(find.text('جاهز'), findsOneWidget);
    // The page no longer vetoes pops (no search to close on back).
    expect(
      ModalRoute.of(tester.element(find.byType(AgentModeSettingPage)))!
          .popDisposition,
      RoutePopDisposition.bubble,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'OpenCode row opens its config through GoRouter and refreshes on return',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var catalogReads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
            if (call.method != 'agent/list') return null;
            catalogReads++;
            return {
              'agents': [
                _agent('opencode-acp', 'OpenCode', 'opencode', 'online'),
              ],
            };
          });
      final admittedPaths = <String>[];
      Page<dynamic> destination(GoRouterState state) {
        admittedPaths.add(state.uri.path);
        final source = (state.extra! as Map)[omniContainerExtraKey];
        expect(source, isA<OmniContainerSource>());
        return (source as OmniContainerSource).createPage<dynamic>(
          key: state.pageKey,
          child: const Scaffold(
            key: Key('agent-row-destination'),
            body: Text('Agent destination'),
          ),
        );
      }

      final router = GoRouter(
        navigatorKey: GoRouterManager.rootNavigatorKey,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const AgentModeSettingPage(embedded: true),
          ),
          GoRoute(
            path: '/home/agent_config/:agentId',
            pageBuilder: (_, state) => destination(state),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      expect(catalogReads, 1);
      for (final scenario in [
        (result: false, reload: false),
        (result: true, reload: true),
      ]) {
        final row = find.byKey(const Key('agent-config-opencode-acp'));
        final source = find.ancestor(
          of: row,
          matching: find.byType(OmniOpenContainer),
        );
        final sourceRect = tester.getRect(source);
        final readsBeforeOpen = catalogReads;
        await tester.tap(row);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(admittedPaths.last, '/home/agent_config/opencode-acp');
        final detail = find.byKey(const Key('agent-row-destination'));
        expect(detail, findsOneWidget);
        final route = ModalRoute.of(tester.element(detail))!;
        expect(route.transitionDuration, const Duration(milliseconds: 300));
        expect(route.animation!.isAnimating, isTrue);
        final full = Offset.zero & tester.getSize(find.byType(MaterialApp));
        final opening = Rect.lerp(
          sourceRect,
          full,
          Curves.fastOutSlowIn.transform(route.animation!.value),
        )!;
        expect(tester.getTopLeft(detail).dx, closeTo(opening.left, 0.01));
        expect(tester.getTopLeft(detail).dy, closeTo(opening.top, 0.01));
        await tester.pumpAndSettle();
        expect(catalogReads, readsBeforeOpen);
        router.pop(scenario.result);
        await tester.pumpAndSettle();
        expect(detail, findsNothing);
        expect(router.canPop(), isFalse);
        expect(tester.getRect(source), sourceRect);
        expect(catalogReads, readsBeforeOpen + (scenario.reload ? 1 : 0));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'OpenCode row does not navigate when configuration is unavailable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var catalogReads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
            if (call.method != 'agent/list') return null;
            catalogReads++;
            return {
              'agents': [
                _agent(
                  'opencode-acp',
                  'OpenCode',
                  'opencode',
                  'online',
                  configurationAvailable: false,
                ),
              ],
            };
          });
      final admittedPaths = <String>[];
      Page<dynamic> destination(GoRouterState state) {
        admittedPaths.add(state.uri.path);
        final source = (state.extra! as Map)[omniContainerExtraKey];
        return (source as OmniContainerSource).createPage<dynamic>(
          key: state.pageKey,
          child: const Scaffold(
            key: Key('agent-row-destination'),
            body: Text('Agent destination'),
          ),
        );
      }

      final router = GoRouter(
        navigatorKey: GoRouterManager.rootNavigatorKey,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const AgentModeSettingPage(embedded: true),
          ),
          GoRoute(
            path: '/home/agent_config/:agentId',
            pageBuilder: (_, state) => destination(state),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      expect(catalogReads, 1);
      expect(
        find.byKey(const Key('agent-navigation-opencode-acp')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('agent-config-opencode-acp')));
      await tester.pumpAndSettle();
      expect(admittedPaths, isEmpty);
      expect(catalogReads, 1);
      expect(find.byKey(const Key('agent-row-destination')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scenario in [
    (width: 1100.0, scale: 1.0, inline: true),
    (width: 500.0, scale: 1.0, inline: false),
    (width: 1100.0, scale: 2.0, inline: false),
  ]) {
    testWidgets(
      'OpenCode maintenance adapts at ${scenario.width}dp and ${scenario.scale}x text',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scenario.scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
              calls.add(call);
              if (call.method != 'agent/list') return null;
              return {
                'distributionId': 'pad-layout-test',
                'agents': [
                  {
                    ..._agent(
                      'opencode-acp',
                      'OpenCode',
                      'opencode',
                      'online',
                      managedAdapter: true,
                      packageVersion: <String, dynamic>{
                        'installedVersion': '1.0.0',
                        'latestVersion': '2.0.0',
                        'targetVersion': '2.0.0',
                        'checkedAt': 1792467900000,
                        'updateAvailable': true,
                      },
                    ),
                    'uninstallable': true,
                  },
                ],
              };
            });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: const AgentModeSettingPage(embedded: true),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('agent-check-opencode-acp'));
        final uninstall = find.byKey(
          const Key('agent-uninstall-opencode-acp'),
        );
        final navigation = find.byKey(
          const Key('agent-navigation-opencode-acp'),
        );
        for (final control in [action, uninstall, navigation]) {
          expect(
            tester.getSize(control).shortestSide,
            greaterThanOrEqualTo(48),
          );
        }
        final actionBounds = tester.getRect(action);
        final navigationBounds = tester.getRect(navigation);
        if (scenario.inline) {
          expect(
            actionBounds.center.dy,
            closeTo(navigationBounds.center.dy, 1),
          );
          // RTL: the action sits to the left of the title.
          expect(
            actionBounds.right,
            lessThan(tester.getRect(find.text('OpenCode')).left),
          );
        } else {
          expect(
            actionBounds.top,
            greaterThanOrEqualTo(navigationBounds.bottom),
          );
        }
        expect(tester.widget<IconButton>(navigation).onPressed, isNotNull);
        // Reflowing a row must not remove the existing uninstall confirmation.
        await tester.tap(uninstall);
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey('agent-uninstall-confirm-opencode-acp'),
          ),
          findsOneWidget,
        );
        expect(
          calls.where((call) => call.method == 'agent/uninstall'),
          isEmpty,
        );
        await tester.tap(
          find.byKey(const Key('agent-uninstall-cancel-opencode-acp')),
        );
        await tester.pumpAndSettle();
        expect(
          calls.where((call) => call.method == 'agent/uninstall'),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'settings groups fit 320dp with $brightness and text scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(bottom: 24);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          var refreshReads = 0;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
                if (call.method == 'agent/refresh') {
                  refreshReads++;
                  return <String, dynamic>{
                    'agents': <Map<String, dynamic>>[
                      _agent(
                        'opencode-acp',
                        'OpenCode',
                        'opencode',
                        'offline',
                        arguments: const ['acp'],
                      ),
                    ],
                  };
                }
                if (call.method != 'agent/list') return null;
                return <String, dynamic>{
                  'agents': <Map<String, dynamic>>[
                    _agent(
                      'opencode-acp',
                      'OpenCode',
                      'opencode',
                      'offline',
                      arguments: const ['acp'],
                    ),
                  ],
                };
              });
          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('ar'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const AgentModeSettingPage(embedded: true),
            ),
          );
          await tester.pumpAndSettle();
          final row = find.byKey(const Key('agent-config-opencode-acp'));
          expect(tester.getRect(row).left, 22);
          expect(tester.getRect(row).right, 298);
          expect(
            tester.widget<Text>(find.text('OpenCode')).style?.fontSize,
            15,
          );
          expect(find.text('الوكيل'), findsNWidgets(2));
          expect(find.byKey(const Key('agent-refresh-button')), findsOneWidget);
          expect(find.byKey(const Key('agent-search-button')), findsNothing);
          expect(find.byType(TextField), findsNothing);
          expect(find.text('Agent WebUI'), findsNothing);
          expect(find.text('صيانة'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('agent-refresh-button')));
          await tester.pumpAndSettle();
          expect(refreshReads, 1);
          expect(find.text('OpenCode'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('installer exceptions remain in a readable result sheet', (
    tester,
  ) async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
          if (call.method == 'agent/list') {
            return {
              'agents': [
                _agent(
                  'opencode-acp',
                  'OpenCode',
                  'opencode',
                  'online',
                  managedAdapter: true,
                ),
              ],
            };
          }
          if (call.method == 'agent/prepare') {
            calls++;
            expect((call.arguments as Map)['force'], isTrue);
            throw PlatformException(
              code: 'INSTALL_FAILED',
              message: 'DEPTH_ZERO_SELF_SIGNED_CERT',
            );
          }
          return null;
        });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: const AgentModeSettingPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agent-check-opencode-acp')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(SettingsDetailSheet), findsOneWidget);
    expect(find.text('لم يكتمل التثبيت'), findsOneWidget);
    expect(find.textContaining('تتطلب تسجيل الدخول'), findsOneWidget);
    expect(find.textContaining('SELF_SIGNED_CERT'), findsNothing);
    expect(calls, 1);
  });

  for (final entry in <String, String>{
    'Dispatch Model Provider is not configured.':
        'اختر نموذجاً متاحاً من إعدادات النموذج، ثم ابدأ المساعد.',
    'Dispatch Model Provider has no usable credentials.':
        'تعذّر التحقق من اتصال النموذج. تحقق من العنوان والمفتاح في إعدادات النموذج.',
    'Claude Code requires an Anthropic-compatible Provider endpoint.':
        'اتصال النموذج هذا غير متوافق مع المساعد. اختر اتصالاً أو مساعداً آخر.',
    'Harness preparation is already running for codex-acp.':
        'يتم تثبيت مساعد آخر حالياً. حاول مجدداً عند اكتمال التثبيت.',
  }.entries) {
    testWidgets(
      'assistant error offers an action without internal details: ${entry.key}',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
              if (call.method != 'agent/list') return null;
              return <String, dynamic>{
                'agents': [
                  _agent(
                    'opencode-acp',
                    'OpenCode',
                    'opencode',
                    'offline',
                    lastCheckError: entry.key,
                  ),
                ],
              };
            });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: const AgentModeSettingPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.key), findsNothing);
        expect(find.text(entry.value), findsOneWidget);
      },
    );
  }

  testWidgets(
    'installed initialization errors are not mislabeled and retry runs again',
    (tester) async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
            if (call.method == 'agent/list') {
              return <String, dynamic>{
                'agents': [
                  _agent(
                    'opencode-acp',
                    'OpenCode',
                    'opencode',
                    'missing',
                    managedAdapter: true,
                  ),
                ],
              };
            }
            if (call.method == 'agent/prepare') {
              expect((call.arguments as Map)['force'], isTrue);
              attempts++;
              return <String, dynamic>{
                'ok': attempts > 1,
                'agent': {'installed': true},
                'error': 'ACP process exited unexpectedly',
                'capabilities': <String, dynamic>{},
              };
            }
            return null;
          });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: const AgentModeSettingPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-check-opencode-acp')));
      await tester.pumpAndSettle();
      expect(find.text('تم التثبيت، لكن تعذّر بدء المساعد'), findsOneWidget);
      expect(find.textContaining('Dispatch'), findsNothing);
      expect(find.text('ACP process exited unexpectedly'), findsNothing);
      expect(
        find.text('تعذّر بدء المساعد. حاول مجدداً، أو أعد التثبيت إذا استمرت المشكلة.'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-check-opencode-acp')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('تم تثبيت المساعد'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the OpenCode check result in the shared settings detail card',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
            switch (call.method) {
              case 'agent/list':
                return <String, dynamic>{
                  'agents': <Map<String, dynamic>>[
                    _agent('opencode-acp', 'OpenCode', 'opencode', 'online'),
                  ],
                };
              case 'agent/test':
                expect(
                  call.arguments,
                  <String, Object?>{'agentId': 'opencode-acp'},
                );
                return <String, dynamic>{
                  'ok': true,
                  'capabilities': <String, dynamic>{
                    'prompt': true,
                    'tools': <String>['read', 'edit'],
                  },
                };
            }
            return null;
          });
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: const AgentModeSettingPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-check-opencode-acp')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final resultSheet = find.byKey(
        const ValueKey('agent-check-result-opencode-acp'),
      );
      expect(resultSheet, findsOneWidget);
      expect(find.byType(SettingsDetailSheet), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is AlertDialog),
        findsNothing,
      );
      expect(find.text('المساعد جاهز'), findsOneWidget);
      expect(find.textContaining('prompt: true'), findsNothing);
      expect(find.text('المساعد جاهز للدردشة.'), findsOneWidget);
      expect(find.text('إغلاق'), findsNothing);
      expect(tester.getSize(resultSheet).width, 640);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(resultSheet, findsNothing);
    },
  );

  testWidgets(
    'OpenCode auto-installs once per page when the environment is ready',
    (tester) async {
      final preparation = Completer<Map<String, dynamic>>();
      var preparationCalls = 0;
      addTearDown(() {
        if (!preparation.isCompleted) {
          preparation.complete(<String, dynamic>{
            'ok': false,
            'error': 'test cleanup',
          });
        }
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(agentRuntimeChannel, (call) async {
            switch (call.method) {
              case 'agent/list':
                return <String, dynamic>{
                  'distributionId': 'ubuntu',
                  'agents': <Map<String, dynamic>>[
                    _agent(
                      'opencode-acp',
                      'OpenCode',
                      'opencode',
                      'missing',
                      managedAdapter: true,
                    ),
                  ],
                };
              case 'agent/prepare':
                preparationCalls += 1;
                expect(call.arguments, <String, Object?>{
                  'agentId': 'opencode-acp',
                  'force': true,
                  'distributionId': 'ubuntu',
                });
                return preparation.future;
            }
            return null;
          });
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget buildPage() => MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: const AgentModeSettingPage(),
      );

      Future<void> waitForInstalling() async {
        for (
          var frame = 0;
          frame < 20 &&
              find.text('جارٍ تثبيت OpenCode...').evaluate().isEmpty;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpWidget(buildPage());
      await waitForInstalling();
      expect(find.text('جارٍ تثبيت OpenCode...'), findsOneWidget);
      expect(preparationCalls, 1);
      expect(find.byKey(const Key('agent-check-opencode-acp')), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('agent-refresh-button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('agent-navigation-opencode-acp')),
            )
            .onPressed,
        isNull,
      );

      // Leaving and returning keeps the same in-flight install.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(buildPage());
      await waitForInstalling();
      expect(find.text('جارٍ تثبيت OpenCode...'), findsOneWidget);
      expect(preparationCalls, 1);

      // A failed install leaves the manual install button as the retry.
      // The rebuilt page auto-installs at most once more for its lifetime.
      preparation.complete(<String, dynamic>{
        'ok': false,
        'error': 'expected test completion',
      });
      await tester.pumpAndSettle();
      expect(preparationCalls, 2);
      expect(find.text('جارٍ تثبيت OpenCode...'), findsNothing);
      expect(find.text('تثبيت'), findsOneWidget);
      expect(
        find.byKey(const Key('agent-check-opencode-acp')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('agent-refresh-button')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, dynamic> _agent(
  String id,
  String name,
  String command,
  String status, {
  List<String> arguments = const [],
  bool managedAdapter = false,
  String? lastCheckError,
  Map<String, dynamic>? packageVersion,
  bool uninstallable = false,
  bool? configurationAvailable,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': '$name ACP Agent',
    'command': command,
    'arguments': arguments,
    'enabled': true,
    'builtIn': true,
    'source': 'official',
    'installed': status != 'missing',
    'status': status,
    'managedAdapter': managedAdapter,
    'uninstallable': uninstallable,
    'lastCheckError': ?lastCheckError,
    if (packageVersion != null) 'packageVersion': packageVersion,
    if (configurationAvailable != null)
      'configurationAvailable': configurationAvailable,
  };
}
