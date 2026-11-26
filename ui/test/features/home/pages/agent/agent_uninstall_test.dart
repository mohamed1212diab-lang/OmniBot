import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/features/home/pages/agent/agent_mode_setting_page.dart';
import 'package:ui/l10n/generated/app_localizations.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/services/storage_service.dart';
import 'package:ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn.com.omnimind.bot/AgentRuntime');
  const plugins = MethodChannel('cn.com.omnimind.bot/PluginPlatform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    messenger.setMockMethodCallHandler(plugins, (_) async => <dynamic>[]);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(plugins, null);
    expect(AgentRuntimeService.agentPackageOperations, isEmpty);
  });

  Widget page({double textScale = 1}) => MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const AgentModeSettingPage(),
  );

  Map<String, dynamic> agent(
    String id, {
    String? name,
    bool? installed = true,
    bool uninstallable = true,
    bool managed = true,
    bool builtIn = true,
    bool enabled = true,
    bool? versionKnown,
  }) => {
    'id': id,
    'name': name ?? (id == 'opencode-acp' ? 'OpenCode' : id),
    'command': id,
    'enabled': enabled,
    'builtIn': builtIn,
    'managedAdapter': managed,
    'uninstallable': uninstallable,
    'installed': installed,
    'status': installed == false ? 'missing' : 'online',
    'packageVersion': {
      'installedVersion': (versionKnown ?? installed == true) ? '1.0.0' : null,
      'latestVersion': '2.0.0',
      'targetVersion': '2.0.0',
      'checkedAt': 1792467900000,
      'updateAvailable': installed == true,
    },
  };

  Map<String, dynamic> catalog(List<Map<String, dynamic>> agents) => {
    'distributionId': 'ubuntu',
    'agents': agents,
  };

  void size(WidgetTester tester, {double width = 390, double height = 950}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> confirmUninstall(WidgetTester tester, String id) async {
    final action = find.byKey(Key('agent-uninstall-$id'));
    // The page admits its catalog read after the landing frame. An unrelated
    // install keeps animating, so wait for the row instead of pumpAndSettle.
    for (var frame = 0; frame < 10 && action.evaluate().isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(Key('agent-uninstall-confirm-action-$id')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'installed OpenCode shows uninstall while other agents stay hidden',
    (tester) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'agent/list') {
          return catalog([
            agent('opencode-acp'),
            agent('pi-acp'),
            agent('codex-acp'),
            agent('claude-code-acp'),
            agent('kimi-code-acp'),
            agent('na-cloud', managed: false, uninstallable: false),
            agent('custom', managed: false, builtIn: false),
          ]);
        }
        return null;
      });
      size(tester);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('OpenCode'), findsOneWidget);
      expect(find.text('الوكيل'), findsNWidgets(2));
      expect(
        find.byKey(const Key('agent-config-opencode-acp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('agent-uninstall-opencode-acp')),
        findsOneWidget,
      );
      for (final id in [
        'pi-acp',
        'codex-acp',
        'claude-code-acp',
        'kimi-code-acp',
        'na-cloud',
        'custom',
      ]) {
        expect(find.byKey(Key('agent-config-$id')), findsNothing);
        expect(find.byKey(Key('agent-uninstall-$id')), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'OpenCode without an installed package shows install instead of uninstall',
    (tester) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'agent/list') {
          // No distribution id, so no auto-install fires for this fixture.
          return {
            'agents': [agent('opencode-acp', installed: false)],
          };
        }
        return null;
      });
      size(tester);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('OpenCode'), findsOneWidget);
      expect(find.text('غير مثبّت'), findsOneWidget);
      expect(find.text('تثبيت'), findsOneWidget);
      expect(find.text('جارٍ تثبيت OpenCode...'), findsNothing);
      expect(
        find.byKey(const Key('agent-uninstall-opencode-acp')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unmanaged or non-uninstallable OpenCode shows no uninstall action',
    (tester) async {
      var catalogAgents = [agent('opencode-acp', managed: false)];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'agent/list' || call.method == 'agent/refresh') {
          return catalog(catalogAgents);
        }
        return null;
      });
      size(tester);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      // Unmanaged: the tile offers a re-check, not uninstall.
      expect(
        find.byKey(const Key('agent-uninstall-opencode-acp')),
        findsNothing,
      );
      expect(find.text('تحقق مجدداً'), findsOneWidget);
      catalogAgents = [agent('opencode-acp', uninstallable: false)];
      await tester.tap(find.byKey(const Key('agent-refresh-button')));
      await tester.pumpAndSettle();
      // Not uninstallable: the update action stays, uninstall does not.
      expect(
        find.byKey(const Key('agent-uninstall-opencode-acp')),
        findsNothing,
      );
      expect(find.text('تحديث'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmation can cancel and successful uninstall restores install',
    (tester) async {
      var installed = true;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'agent/list') {
          return catalog([agent('opencode-acp', installed: installed)]);
        }
        if (call.method == 'agent/uninstall') {
          expect(call.arguments, {
            'agentId': 'opencode-acp',
            'distributionId': 'ubuntu',
          });
          installed = false;
          return {
            'ok': true,
            'agent': agent('opencode-acp', installed: false),
          };
        }
        return null;
      });
      size(tester);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-uninstall-opencode-acp')));
      await tester.pumpAndSettle();
      expect(find.text('إلغاء تثبيت OpenCode؟'), findsOneWidget);
      expect(
        find.text(
          'ألغِ تثبيت البرنامج من بيئة الطرفية الحالية. مع الاحتفاظ بالإعدادات ومعلومات تسجيل الدخول والسجل.',
        ),
        findsOneWidget,
      );
      expect(calls.where((call) => call.method == 'agent/uninstall'), isEmpty);
      await tester.tap(
        find.byKey(const Key('agent-uninstall-cancel-opencode-acp')),
      );
      await tester.pumpAndSettle();
      expect(calls.where((call) => call.method == 'agent/uninstall'), isEmpty);
      await confirmUninstall(tester, 'opencode-acp');
      await tester.pumpAndSettle();
      expect(find.text('تم إلغاء تثبيت المساعد'), findsOneWidget);
      expect(find.textContaining('تم الاحتفاظ بالإعدادات'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('agent-uninstall-result-close-opencode-acp')),
      );
      await tester.pumpAndSettle();
      expect(find.text('غير مثبّت'), findsOneWidget);
      expect(find.text('تثبيت'), findsOneWidget);
      expect(find.textContaining('1.0.0'), findsNothing);
      expect(
        find.byKey(const Key('agent-uninstall-opencode-acp')),
        findsNothing,
      );
      // The reload after uninstall auto-installs OpenCode once, silently.
      expect(
        calls.where((call) => call.method == 'agent/prepare'),
        hasLength(1),
      );
      expect(calls.where((call) => call.method == 'agent/delete'), isEmpty);
      expect(calls.where((call) => call.method == 'agent/select'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uninstall queues behind installation and survives leaving and returning',
    (tester) async {
      final installing = Completer<Map<String, dynamic>>();
      final uninstalling = Completer<Map<String, dynamic>>();
      var installed = true;
      var uninstallCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'agent/list') {
          return catalog([agent('opencode-acp', installed: installed)]);
        }
        if (call.method == 'agent/prepare') return installing.future;
        if (call.method == 'agent/uninstall') {
          uninstallCalls++;
          return uninstalling.future;
        }
        return null;
      });
      unawaited(
        AgentRuntimeService.prepareAgentInBackground(
          'other',
          distributionId: 'ubuntu',
        ),
      );
      addTearDown(() {
        if (!installing.isCompleted) installing.complete({'ok': false});
        if (!uninstalling.isCompleted) uninstalling.complete({'ok': false});
      });
      size(tester, height: 1100);
      await tester.pumpWidget(page());
      await tester.pump();
      await confirmUninstall(tester, 'opencode-acp');
      expect(find.text('بانتظار إلغاء التثبيت'), findsOneWidget);
      expect(uninstallCalls, 0);
      expect(
        find.byKey(const Key('agent-uninstall-opencode-acp')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('agent-check-opencode-acp')),
        findsNothing,
      );
      final navigation = tester.widget<IconButton>(
        find.byKey(const Key('agent-navigation-opencode-acp')),
      );
      expect(navigation.onPressed, isNull);
      final refresh = tester.widget<IconButton>(
        find.byKey(const Key('agent-refresh-button')),
      );
      expect(refresh.onPressed, isNull);

      installing.complete({'ok': true});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('جارٍ إلغاء التثبيت'), findsOneWidget);
      expect(uninstallCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page());
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('جارٍ إلغاء التثبيت'), findsOneWidget);
      expect(uninstallCalls, 1);
      installed = false;
      uninstalling.complete({
        'ok': true,
        'agent': agent('opencode-acp', installed: false),
      });
      await tester.pumpAndSettle();
      expect(find.text('غير مثبّت'), findsOneWidget);
      expect(
        find.byKey(const Key('agent-check-opencode-acp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('agent-uninstall-opencode-acp')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('agent-uninstall-result-opencode-acp')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final throws in [false, true]) {
    testWidgets(
      'failed uninstall remains retryable after partial removal, throws=$throws',
      (tester) async {
        var installed = true;
        var attempts = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'agent/list') {
            return catalog([agent('opencode-acp', installed: installed)]);
          }
          if (call.method == 'agent/uninstall') {
            expect(call.arguments, {
              'agentId': 'opencode-acp',
              'distributionId': 'ubuntu',
            });
            attempts++;
            installed = false;
            if (attempts == 1) {
              if (throws) {
                throw PlatformException(
                  code: 'uninstall_failed',
                  message: 'Permission denied',
                );
              }
              return {
                'ok': false,
                'error': 'Permission denied',
                'agent': agent('opencode-acp', installed: false),
              };
            }
            return {
              'ok': true,
              'agent': agent('opencode-acp', installed: false),
            };
          }
          return null;
        });
        size(tester);
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        await confirmUninstall(tester, 'opencode-acp');
        await tester.pumpAndSettle();
        expect(find.text('لم يكتمل إلغاء التثبيت'), findsOneWidget);
        expect(find.text('لم يكتمل إلغاء التثبيت. حاول مجدداً.'), findsOneWidget);
        expect(find.textContaining('Permission denied'), findsNothing);
        expect(
          find.byKey(const Key('agent-uninstall-opencode-acp')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const Key('agent-uninstall-retry-opencode-acp')),
        );
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.text('تم إلغاء تثبيت المساعد'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unknown distribution cannot start an uninstall', (tester) async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'agent/list') {
        return {
          'agents': [agent('opencode-acp')],
        };
      }
      return null;
    });
    size(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agent-uninstall-opencode-acp')));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر إلغاء التثبيت'), findsOneWidget);
    expect(find.text('حدّث قائمة الوكلاء وحاول مجدداً.'), findsOneWidget);
    expect(calls, isNot(contains('agent/uninstall')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'external installation is explained without claiming uninstall success',
    (tester) async {
      var attempts = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'agent/list') {
          return catalog([agent('opencode-acp')]);
        }
        if (call.method == 'agent/uninstall') {
          attempts++;
          return {
            'ok': false,
            'failureKind': 'agent_uninstall_external_installation',
            'error':
                'Another installation remains at /opt/external/pi (probe timeout)',
            'agent': agent('opencode-acp'),
          };
        }
        return null;
      });
      size(tester);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await confirmUninstall(tester, 'opencode-acp');
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(find.text('لم يكتمل إلغاء التثبيت'), findsOneWidget);
      expect(
        find.text(
          'ما زالت هناك نسخة أخرى مثبتة أو ملفات تعذّرت إزالتها بأمان. تحقق من مكان تثبيت المساعد في الطرفية.',
        ),
        findsOneWidget,
      );
      expect(find.text('تم إلغاء تثبيت المساعد'), findsNothing);
      expect(find.textContaining('انتهت مهلة'), findsNothing);
      expect(find.textContaining('/opt/external/pi'), findsNothing);
      expect(
        find.byKey(const Key('agent-uninstall-retry-opencode-acp')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inline actions fit a narrow layout with enlarged text', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'agent/list') {
        return catalog([
          agent('opencode-acp', name: 'OpenCode مساعد البرمجة'),
        ]);
      }
      return null;
    });
    size(tester, width: 320, height: 1100);
    await tester.pumpWidget(page(textScale: 1.3));
    await tester.pumpAndSettle();
    expect(find.text('إلغاء التثبيت'), findsOneWidget);
    expect(find.text('تحديث'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('agent-uninstall-opencode-acp')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('مع الاحتفاظ بالإعدادات'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
