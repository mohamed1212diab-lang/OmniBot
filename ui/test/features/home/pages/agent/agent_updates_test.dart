import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/features/home/pages/agent/agent_mode_setting_page.dart';
import 'package:ui/l10n/generated/app_localizations.dart';
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
  });

  Widget page() => MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AgentModeSettingPage(),
  );

  Map<String, dynamic> agent(
    String id, {
    bool checked = false,
    bool updated = false,
    bool missing = false,
    String? error,
  }) => {
    'id': id,
    'name': id == 'opencode-acp' ? 'OpenCode' : id,
    'command': id,
    'enabled': true,
    'builtIn': true,
    'managedAdapter': true,
    'installed': !missing,
    'status': missing ? 'missing' : 'online',
    if (checked)
      'packageVersion': {
        'installedVersion': missing
            ? null
            : updated
            ? '2.0.32'
            : '1.18.29',
        'latestVersion': error == null ? '2.0.32' : null,
        'targetVersion': error == null ? '2.0.32' : null,
        'checkedAt': 1792467900000,
        'error': error,
        'updateAvailable': !updated && !missing && error == null,
      },
  };

  for (final initializationOk in [true, false]) {
    testWidgets(
      'single update reports installed version with initialization success=$initializationOk',
      (tester) async {
        var updated = false;
        final calls = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'agent/prepare') {
            expect(call.arguments, {
              'agentId': 'opencode-acp',
              'force': true,
            });
            updated = true;
            return {
              'ok': initializationOk,
              if (!initializationOk)
                'error': 'Provider credentials are missing',
              'agent': agent('opencode-acp', checked: true, updated: true),
            };
          }
          if (call.method == 'agent/list') {
            // No distribution id, so no auto-install fires for this fixture.
            return {
              'agents': [
                agent('opencode-acp', checked: true, updated: updated),
              ],
            };
          }
          return null;
        });
        tester.view.physicalSize = const Size(390, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(find.text('1.18.29 · يتوفر تحديث 2.0.32'), findsOneWidget);
        expect(find.text('تحديث'), findsOneWidget);
        expect(
          calls.where((call) => call == 'agent/prepare'),
          isEmpty,
        );
        await tester.tap(find.byKey(const Key('agent-check-opencode-acp')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            initializationOk ? 'تم تحديث المساعد' : 'تم التحديث، لكن تعذّر بدء المساعد',
          ),
          findsOneWidget,
        );
        if (initializationOk) {
          expect(find.textContaining('تم تثبيت 2.0.32'), findsOneWidget);
        } else {
          expect(
            find.text(
              'تعذّر بدء المساعد. حاول مجدداً، أو أعد التثبيت إذا استمرت المشكلة.',
            ),
            findsOneWidget,
          );
        }
        expect(
          calls.where((call) => call == 'agent/prepare'),
          hasLength(1),
        );
        // Healthy agent: reinstall is a quiet icon button (tooltip only).
        expect(
          find.byKey(const Key('agent-check-opencode-acp')),
          findsOneWidget,
        );
        expect(find.byTooltip('إعادة التثبيت'), findsOneWidget);
        expect(find.text('تحديث'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'up-to-date OpenCode offers reinstall instead of an update',
    (tester) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'agent/list') {
          return {
            'agents': [agent('opencode-acp', checked: true, updated: true)],
          };
        }
        return null;
      });
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('OpenCode'), findsOneWidget);
      expect(find.text('تحديث'), findsNothing);
      // Healthy agent: reinstall is a quiet icon button (tooltip only).
      expect(
        find.byKey(const Key('agent-check-opencode-acp')),
        findsOneWidget,
      );
      expect(find.byTooltip('إعادة التثبيت'), findsOneWidget);
      expect(find.text('لا توجد تحديثات'), findsNothing);
      expect(find.textContaining('يتوفر تحديث'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offline update check shows a readable error without an update', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'agent/list') {
        return {
          'agents': [
            agent('opencode-acp', checked: true, error: 'registry_unavailable'),
          ],
        };
      }
      return null;
    });
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(
      find.text('1.18.29 · فشل التحقق من التحديثات؛ حاول مجدداً'),
      findsOneWidget,
    );
    expect(find.textContaining('لا توجد تحديثات'), findsNothing);
    expect(find.text('تحديث'), findsNothing);
    expect(find.text('إعادة التثبيت'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
