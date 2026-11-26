import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui/l10n/legacy_text_localizer.dart';
import 'package:ui/utils/ui.dart';

// The channel name must match the one in MainActivity.kt
const spePermission = MethodChannel(
  'cn.com.omnimind.bot/SpecialPermissionEvent',
);
const _specialPermissionEvents = EventChannel(
  'cn.com.omnimind.bot/SpecialPermissionEvents',
);

enum EmbeddedTerminalDistribution {
  alpine('alpine'),
  ubuntu('ubuntu');

  const EmbeddedTerminalDistribution(this.id);

  final String id;

  static EmbeddedTerminalDistribution fromId(String? id) {
    return values.firstWhere(
      (distribution) => distribution.id == id?.trim().toLowerCase(),
      orElse: () => alpine,
    );
  }
}

class EmbeddedTerminalInitProgress {
  const EmbeddedTerminalInitProgress({
    required this.kind,
    required this.message,
    required this.timestamp,
    required this.phase,
    required this.distribution,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.error,
  });

  final String kind;
  final String message;
  final DateTime timestamp;
  final String? phase;
  final EmbeddedTerminalDistribution? distribution;
  final int downloadedBytes;
  final int totalBytes;
  final double? progress;
  final String? error;

  factory EmbeddedTerminalInitProgress.fromMap(Map<dynamic, dynamic> map) {
    final timestampValue = map['timestamp'];
    final millis = timestampValue is num
        ? timestampValue.toInt()
        : DateTime.now().millisecondsSinceEpoch;
    return EmbeddedTerminalInitProgress(
      kind: (map['kind'] as String? ?? 'status').trim(),
      message: (map['message'] as String? ?? '').trimRight(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
      phase: (map['phase'] as String?)?.trim(),
      distribution: (map['distribution'] as String?)?.trim().isNotEmpty == true
          ? EmbeddedTerminalDistribution.fromId(map['distribution'] as String?)
          : null,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      progress: map['progress'] is num
          ? (map['progress'] as num).toDouble().clamp(0.0, 1.0).toDouble()
          : null,
      error: (map['error'] as String?)?.trim(),
    );
  }
}

class EmbeddedTerminalInitSnapshot {
  const EmbeddedTerminalInitSnapshot({
    required this.running,
    required this.completed,
    required this.success,
    required this.progress,
    required this.stage,
    required this.logLines,
    required this.startedAt,
    required this.completedAt,
    required this.phase,
    required this.distribution,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.error,
  });

  final bool running;
  final bool completed;
  final bool? success;
  final double progress;
  final String stage;
  final List<String> logLines;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? phase;
  final EmbeddedTerminalDistribution? distribution;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  factory EmbeddedTerminalInitSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final rawLogLines = map['logLines'];
    return EmbeddedTerminalInitSnapshot(
      running: map['running'] == true,
      completed: map['completed'] == true,
      success: map['success'] as bool?,
      progress: ((map['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
      stage: (map['stage'] as String? ?? '').trim(),
      logLines: rawLogLines is List
          ? rawLogLines.map((line) => line.toString()).toList(growable: false)
          : const <String>[],
      startedAt: _parseEmbeddedTerminalInitTimestamp(map['startedAt']),
      completedAt: _parseEmbeddedTerminalInitTimestamp(map['completedAt']),
      phase: (map['phase'] as String?)?.trim(),
      distribution: (map['distribution'] as String?)?.trim().isNotEmpty == true
          ? EmbeddedTerminalDistribution.fromId(map['distribution'] as String?)
          : null,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      error: (map['error'] as String?)?.trim(),
    );
  }
}

DateTime? _parseEmbeddedTerminalInitTimestamp(dynamic rawValue) {
  if (rawValue is! num) {
    return null;
  }
  final millis = rawValue.toInt();
  if (millis <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

class EmbeddedTerminalRuntimeStatus {
  const EmbeddedTerminalRuntimeStatus({
    required this.supported,
    required this.runtimeReady,
    required this.basePackagesReady,
    required this.allReady,
    required this.missingCommands,
    required this.message,
    required this.nodeReady,
    required this.nodeVersion,
    required this.nodeMinMajor,
    required this.pnpmReady,
    required this.pnpmVersion,
    required this.workspaceAccessGranted,
  });

  final bool supported;
  final bool runtimeReady;
  final bool basePackagesReady;
  final bool allReady;
  final List<String> missingCommands;
  final String message;
  final bool nodeReady;
  final String? nodeVersion;
  final int nodeMinMajor;
  final bool pnpmReady;
  final String? pnpmVersion;
  final bool workspaceAccessGranted;

  factory EmbeddedTerminalRuntimeStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawMissing = map['missingCommands'];
    return EmbeddedTerminalRuntimeStatus(
      supported: map['supported'] == true,
      runtimeReady: map['runtimeReady'] == true,
      basePackagesReady: map['basePackagesReady'] == true,
      allReady: map['allReady'] == true,
      missingCommands: rawMissing is List
          ? rawMissing.map((it) => it.toString()).toList(growable: false)
          : const <String>[],
      message: (map['message'] as String? ?? '').trim(),
      nodeReady: map['nodeReady'] == true,
      nodeVersion: (map['nodeVersion'] as String?)?.trim(),
      nodeMinMajor: (map['nodeMinMajor'] as num?)?.toInt() ?? 22,
      pnpmReady: map['pnpmReady'] == true,
      pnpmVersion: (map['pnpmVersion'] as String?)?.trim(),
      workspaceAccessGranted: map['workspaceAccessGranted'] == true,
    );
  }
}

class EmbeddedTerminalSetupStatus {
  const EmbeddedTerminalSetupStatus({required this.packages});

  final Map<String, bool> packages;

  factory EmbeddedTerminalSetupStatus.fromMap(Map<dynamic, dynamic>? map) {
    final rawPackages = map?['packages'];
    final packages = <String, bool>{};
    if (rawPackages is Map) {
      for (final entry in rawPackages.entries) {
        packages[entry.key.toString()] = entry.value == true;
      }
    }
    return EmbeddedTerminalSetupStatus(packages: packages);
  }
}

class EmbeddedTerminalSetupInventoryItem {
  const EmbeddedTerminalSetupInventoryItem({
    required this.ready,
    required this.version,
  });

  final bool? ready;
  final String? version;

  factory EmbeddedTerminalSetupInventoryItem.fromMap(
    Map<dynamic, dynamic>? map,
  ) {
    return EmbeddedTerminalSetupInventoryItem(
      ready: map?['ready'] is bool ? map!['ready'] as bool : null,
      version: (map?['version'] as String?)?.trim(),
    );
  }
}

class EmbeddedTerminalSetupInventory {
  const EmbeddedTerminalSetupInventory({required this.packages});

  final Map<String, EmbeddedTerminalSetupInventoryItem> packages;

  factory EmbeddedTerminalSetupInventory.fromMap(Map<dynamic, dynamic>? map) {
    final rawPackages = map?['packages'];
    final packages = <String, EmbeddedTerminalSetupInventoryItem>{};
    if (rawPackages is Map) {
      for (final entry in rawPackages.entries) {
        packages[entry.key
            .toString()] = EmbeddedTerminalSetupInventoryItem.fromMap(
          entry.value is Map
              ? Map<dynamic, dynamic>.from(entry.value as Map)
              : const <dynamic, dynamic>{},
        );
      }
    }
    return EmbeddedTerminalSetupInventory(packages: packages);
  }
}

class EmbeddedTerminalSetupResult {
  const EmbeddedTerminalSetupResult({
    required this.success,
    required this.message,
    required this.output,
  });

  final bool success;
  final String message;
  final String output;

  factory EmbeddedTerminalSetupResult.fromMap(Map<dynamic, dynamic>? map) {
    return EmbeddedTerminalSetupResult(
      success: map?['success'] == true,
      message: (map?['message'] as String? ?? '').trim(),
      output: (map?['output'] as String? ?? '').trim(),
    );
  }
}

class EmbeddedTerminalSetupSessionSnapshot {
  const EmbeddedTerminalSetupSessionSnapshot({
    required this.sessionId,
    required this.running,
    required this.completed,
    required this.success,
    required this.message,
    required this.selectedPackageIds,
  });

  final String? sessionId;
  final bool running;
  final bool completed;
  final bool? success;
  final String message;
  final List<String> selectedPackageIds;

  bool get hasSession => (sessionId ?? '').trim().isNotEmpty;

  factory EmbeddedTerminalSetupSessionSnapshot.fromMap(
    Map<dynamic, dynamic>? map,
  ) {
    final rawSelectedPackageIds = map?['selectedPackageIds'];
    return EmbeddedTerminalSetupSessionSnapshot(
      sessionId: (map?['sessionId'] as String?)?.trim(),
      running: map?['running'] == true,
      completed: map?['completed'] == true,
      success: map?['success'] as bool?,
      message: (map?['message'] as String? ?? '').trim(),
      selectedPackageIds: rawSelectedPackageIds is List
          ? rawSelectedPackageIds
                .map((item) => item.toString())
                .where((item) => item.trim().isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }
}

class EmbeddedTerminalAutoStartTask {
  const EmbeddedTerminalAutoStartTask({
    required this.id,
    required this.name,
    required this.command,
    required this.workingDirectory,
    required this.enabled,
    required this.running,
    required this.sessionId,
  });

  final String id;
  final String name;
  final String command;
  final String? workingDirectory;
  final bool enabled;
  final bool running;
  final String sessionId;

  factory EmbeddedTerminalAutoStartTask.fromMap(Map<dynamic, dynamic>? map) {
    return EmbeddedTerminalAutoStartTask(
      id: (map?['id'] as String? ?? '').trim(),
      name: (map?['name'] as String? ?? '').trim(),
      command: (map?['command'] as String? ?? '').trim(),
      workingDirectory: (map?['workingDirectory'] as String?)?.trim(),
      enabled: map?['enabled'] != false,
      running: map?['running'] == true,
      sessionId: (map?['sessionId'] as String? ?? '').trim(),
    );
  }
}

class EmbeddedTerminalAutoStartTaskList {
  const EmbeddedTerminalAutoStartTaskList({required this.tasks});

  final List<EmbeddedTerminalAutoStartTask> tasks;

  factory EmbeddedTerminalAutoStartTaskList.fromMap(
    Map<dynamic, dynamic>? map,
  ) {
    final rawTasks = map?['tasks'];
    return EmbeddedTerminalAutoStartTaskList(
      tasks: rawTasks is List
          ? rawTasks
                .map(
                  (item) => EmbeddedTerminalAutoStartTask.fromMap(
                    item is Map
                        ? Map<dynamic, dynamic>.from(item)
                        : const <dynamic, dynamic>{},
                  ),
                )
                .toList(growable: false)
          : const <EmbeddedTerminalAutoStartTask>[],
    );
  }
}

class EmbeddedTerminalAutoStartTaskRunResult {
  const EmbeddedTerminalAutoStartTaskRunResult({
    required this.taskId,
    required this.started,
    required this.alreadyRunning,
    required this.message,
    required this.sessionId,
  });

  final String taskId;
  final bool started;
  final bool alreadyRunning;
  final String message;
  final String sessionId;

  factory EmbeddedTerminalAutoStartTaskRunResult.fromMap(
    Map<dynamic, dynamic>? map,
  ) {
    return EmbeddedTerminalAutoStartTaskRunResult(
      taskId: (map?['taskId'] as String? ?? '').trim(),
      started: map?['started'] == true,
      alreadyRunning: map?['alreadyRunning'] == true,
      message: (map?['message'] as String? ?? '').trim(),
      sessionId: (map?['sessionId'] as String? ?? '').trim(),
    );
  }
}

Stream<EmbeddedTerminalInitProgress> get embeddedTerminalInitProgressStream {
  return _specialPermissionEvents.receiveBroadcastStream().map((event) {
    final payload = event is Map
        ? Map<dynamic, dynamic>.from(event)
        : const <dynamic, dynamic>{};
    return EmbeddedTerminalInitProgress.fromMap(payload);
  });
}

Future<EmbeddedTerminalInitSnapshot> getEmbeddedTerminalInitSnapshot() async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'getEmbeddedTerminalInitSnapshot',
  );
  return EmbeddedTerminalInitSnapshot.fromMap(result ?? const {});
}

Future<bool> cancelEmbeddedTerminalInit() async {
  return await spePermission.invokeMethod<bool>('cancelEmbeddedTerminalInit') ??
      false;
}

Future<Map<String, dynamic>> retryEmbeddedTerminalInit() async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'retryEmbeddedTerminalInit',
  );
  return Map<String, dynamic>.from(result ?? const {});
}

Future<EmbeddedTerminalRuntimeStatus> getEmbeddedTerminalRuntimeStatus() async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'getEmbeddedTerminalRuntimeStatus',
  );
  return EmbeddedTerminalRuntimeStatus.fromMap(result ?? const {});
}

Future<EmbeddedTerminalSetupStatus> getEmbeddedTerminalSetupStatus() async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'getEmbeddedTerminalSetupStatus',
  );
  return EmbeddedTerminalSetupStatus.fromMap(result ?? const {});
}

Future<EmbeddedTerminalSetupInventory>
getEmbeddedTerminalSetupInventory() async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'getEmbeddedTerminalSetupInventory',
  );
  return EmbeddedTerminalSetupInventory.fromMap(result ?? const {});
}

Future<EmbeddedTerminalDistribution> getEmbeddedTerminalDistribution() async {
  final result = await spePermission.invokeMethod<String>(
    'getEmbeddedTerminalDistribution',
  );
  return EmbeddedTerminalDistribution.fromId(result);
}

Future<EmbeddedTerminalDistribution> setEmbeddedTerminalDistribution(
  EmbeddedTerminalDistribution distribution,
) async {
  final result = await spePermission.invokeMethod<String>(
    'setEmbeddedTerminalDistribution',
    <String, dynamic>{'distribution': distribution.id},
  );
  return EmbeddedTerminalDistribution.fromId(result);
}

Future<EmbeddedTerminalDistribution> switchEmbeddedTerminalDistribution(
  EmbeddedTerminalDistribution distribution,
) async {
  final result = await spePermission.invokeMethod<String>(
    'switchEmbeddedTerminalDistribution',
    <String, dynamic>{'distribution': distribution.id},
  );
  return EmbeddedTerminalDistribution.fromId(result);
}

Future<EmbeddedTerminalSetupSessionSnapshot>
getEmbeddedTerminalSetupSessionSnapshot() async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'getEmbeddedTerminalSetupSessionSnapshot',
  );
  return EmbeddedTerminalSetupSessionSnapshot.fromMap(result ?? const {});
}

Future<EmbeddedTerminalSetupResult> installEmbeddedTerminalPackages(
  List<String> packageIds,
) async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'installEmbeddedTerminalPackages',
    {'packageIds': packageIds},
  );
  return EmbeddedTerminalSetupResult.fromMap(result ?? const {});
}

Future<EmbeddedTerminalSetupSessionSnapshot> startEmbeddedTerminalSetupSession(
  List<String> packageIds,
) async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'startEmbeddedTerminalSetupSession',
    {'packageIds': packageIds},
  );
  return EmbeddedTerminalSetupSessionSnapshot.fromMap(result ?? const {});
}

Future<void> dismissEmbeddedTerminalSetupSession() async {
  await spePermission.invokeMethod<void>('dismissEmbeddedTerminalSetupSession');
}

Future<EmbeddedTerminalAutoStartTaskList>
getEmbeddedTerminalAutoStartTasks() async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'getEmbeddedTerminalAutoStartTasks',
  );
  return EmbeddedTerminalAutoStartTaskList.fromMap(result ?? const {});
}

Future<EmbeddedTerminalAutoStartTask> saveEmbeddedTerminalAutoStartTask({
  String? id,
  required String name,
  required String command,
  String? workingDirectory,
  required bool enabled,
}) async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'saveEmbeddedTerminalAutoStartTask',
    <String, dynamic>{
      'id': id,
      'name': name,
      'command': command,
      'workingDirectory': workingDirectory,
      'enabled': enabled,
    },
  );
  return EmbeddedTerminalAutoStartTask.fromMap(result ?? const {});
}

Future<void> deleteEmbeddedTerminalAutoStartTask(String id) async {
  await spePermission.invokeMethod<void>(
    'deleteEmbeddedTerminalAutoStartTask',
    {'id': id},
  );
}

Future<EmbeddedTerminalAutoStartTaskRunResult> runEmbeddedTerminalAutoStartTask(
  String id,
) async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'runEmbeddedTerminalAutoStartTask',
    <String, dynamic>{'id': id},
  );
  return EmbeddedTerminalAutoStartTaskRunResult.fromMap(result ?? const {});
}

Future<void> openNativeTerminal({
  bool openSetup = false,
  List<String> setupPackageIds = const <String>[],
}) async {
  await spePermission.invokeMethod<void>('openNativeTerminal', {
    'openSetup': openSetup,
    'setupPackageIds': setupPackageIds,
  });
}

class ShizukuStatusSnapshot {
  const ShizukuStatusSnapshot({
    required this.status,
    required this.backend,
    required this.installed,
    required this.running,
    required this.permissionGranted,
    required this.binderReady,
    required this.serviceBound,
    required this.availableActions,
    required this.message,
    this.uid,
    this.version,
  });

  final String status;
  final String backend;
  final bool installed;
  final bool running;
  final bool permissionGranted;
  final bool binderReady;
  final bool serviceBound;
  final List<String> availableActions;
  final String message;
  final int? uid;
  final int? version;

  bool get isGranted => status == 'GRANTED_ADB' || status == 'GRANTED_ROOT';
  bool get isRootBackend => backend == 'ROOT';

  factory ShizukuStatusSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    final rawActions = map?['availableActions'];
    return ShizukuStatusSnapshot(
      status: (map?['status'] as String? ?? 'NOT_INSTALLED').trim(),
      backend: (map?['backend'] as String? ?? 'NONE').trim(),
      installed: map?['installed'] == true,
      running: map?['running'] == true,
      permissionGranted: map?['permissionGranted'] == true,
      binderReady: map?['binderReady'] == true,
      serviceBound: map?['serviceBound'] == true,
      availableActions: rawActions is List
          ? rawActions.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      message: (map?['message'] as String? ?? '').trim(),
      uid: (map?['uid'] as num?)?.toInt(),
      version: (map?['version'] as num?)?.toInt(),
    );
  }

  factory ShizukuStatusSnapshot.fallback() {
    return const ShizukuStatusSnapshot(
      status: 'NOT_INSTALLED',
      backend: 'NONE',
      installed: false,
      running: false,
      permissionGranted: false,
      binderReady: false,
      serviceBound: false,
      availableActions: <String>[],
      message: '',
    );
  }

  String get localizedStatusLabel {
    switch (status) {
      case 'GRANTED_ROOT':
        return 'ممنوح (root)';
      case 'GRANTED_ADB':
        return 'ممنوح (adb)';
      case 'PERMISSION_DENIED':
        return 'قيد التشغيل، ولم يُمنح الإذن بعد';
      case 'NOT_RUNNING':
        return 'مثبّت، وغير قيد التشغيل';
      case 'BINDER_DEAD':
        return 'انقطع الاتصال، ويلزم إعادة التشغيل';
      default:
        return 'غير مثبّت';
    }
  }

  String get localizedGuide {
    switch (status) {
      case 'GRANTED_ROOT':
        return 'Shizuku جاهز عبر root/Sui. أدوات الوكيل ذات الصلاحيات العالية مفعّلة، بما فيها أوامر shell العشوائية وجلسات shell الدائمة. وما زال كل أمر shell خام وأمر جلسة ذات صلاحيات عالية يتطلب تأكيداً.';
      case 'GRANTED_ADB':
        return 'Shizuku جاهز عبر adb shell. أدوات الوكيل ذات الصلاحيات العالية مفعّلة، بما فيها أوامر shell العشوائية وجلسات shell الدائمة. وما زالت الأوامر خاضعة لحدود إمكانيات adb shell، وكل أمر shell خام وأمر جلسة ذات صلاحيات عالية يتطلب تأكيداً.';
      case 'PERMISSION_DENIED':
        return 'افتح Shizuku وامنح Omnibot الإذن.';
      case 'NOT_RUNNING':
        return 'افتح Shizuku وشغّله. في Android 11+، تُشغَّل الأجهزة غير المروّتة عادةً من تصحيح الأخطاء اللاسلكي، وتحتاج إلى إعادة تشغيل Shizuku بعد كل إعادة تشغيل للجهاز.';
      case 'BINDER_DEAD':
        return 'أُعيد تشغيل Shizuku أو انقطع اتصاله. افتحه مجدداً لإعادة الاتصال.';
      default:
        return 'ثبّت Shizuku أولاً، ثم شغّله وامنح Omnibot الإذن.';
    }
  }
}

class ShizukuHealthCheckSnapshot {
  const ShizukuHealthCheckSnapshot({
    required this.status,
    required this.probeSuccess,
    required this.probeMessage,
    required this.rawShellProbeSuccess,
    required this.rawShellProbeMessage,
    required this.sessionProbeSuccess,
    required this.sessionProbeMessage,
  });

  final ShizukuStatusSnapshot status;
  final bool probeSuccess;
  final String probeMessage;
  final bool rawShellProbeSuccess;
  final String rawShellProbeMessage;
  final bool sessionProbeSuccess;
  final String sessionProbeMessage;

  factory ShizukuHealthCheckSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    final probe = map?['probe'];
    final probeMap = probe is Map ? Map<dynamic, dynamic>.from(probe) : null;
    final rawShellProbe = map?['rawShellProbe'];
    final rawShellProbeMap = rawShellProbe is Map
        ? Map<dynamic, dynamic>.from(rawShellProbe)
        : null;
    final sessionProbe = map?['sessionProbe'];
    final sessionProbeMap = sessionProbe is Map
        ? Map<dynamic, dynamic>.from(sessionProbe)
        : null;
    final sessionStart = _asNestedMap(sessionProbeMap?['start']);
    final sessionExec = _asNestedMap(sessionProbeMap?['exec']);
    final sessionRead = _asNestedMap(sessionProbeMap?['read']);
    final sessionStop = _asNestedMap(sessionProbeMap?['stop']);
    final sessionStages = [
      if (sessionStart != null) sessionStart,
      if (sessionExec != null) sessionExec,
      if (sessionRead != null) sessionRead,
      if (sessionStop != null) sessionStop,
    ];
    return ShizukuHealthCheckSnapshot(
      status: ShizukuStatusSnapshot.fromMap(map),
      probeSuccess: probeMap?['success'] == true,
      probeMessage: (probeMap?['message'] as String? ?? '').trim(),
      rawShellProbeSuccess: rawShellProbeMap?['success'] == true,
      rawShellProbeMessage: (rawShellProbeMap?['message'] as String? ?? '')
          .trim(),
      sessionProbeSuccess:
          sessionStages.isNotEmpty &&
          sessionStages.every((stage) => stage['success'] == true),
      sessionProbeMessage:
          ((sessionExec ?? sessionStart)?['message'] as String? ??
                  (sessionStop?['message'] as String? ?? ''))
              .trim(),
    );
  }
}

Map<dynamic, dynamic>? _asNestedMap(dynamic raw) {
  return raw is Map ? Map<dynamic, dynamic>.from(raw) : null;
}

Future<bool> isShizukuInstalled() async {
  try {
    return await spePermission.invokeMethod<bool>('isShizukuInstalled') ??
        false;
  } catch (e) {
    debugPrint('检查 Shizuku 安装状态失败: $e');
    return false;
  }
}

Future<bool> isShizukuRunning() async {
  try {
    return await spePermission.invokeMethod<bool>('isShizukuRunning') ?? false;
  } catch (e) {
    debugPrint('检查 Shizuku 运行状态失败: $e');
    return false;
  }
}

Future<void> openShizukuDownloadOrApp() async {
  await spePermission.invokeMethod<void>('openShizukuDownloadOrApp');
}

Future<ShizukuStatusSnapshot> getShizukuStatus() async {
  try {
    final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
      'getShizukuStatus',
    );
    return ShizukuStatusSnapshot.fromMap(result);
  } catch (e) {
    debugPrint('读取 Shizuku 状态失败: $e');
    return ShizukuStatusSnapshot.fallback();
  }
}

Future<bool> requestShizukuPermission() async {
  try {
    final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
      'requestShizukuPermission',
    );
    return ShizukuStatusSnapshot.fromMap(result).isGranted;
  } catch (e) {
    debugPrint('请求 Shizuku 权限失败: $e');
    return false;
  }
}

Future<ShizukuHealthCheckSnapshot> runShizukuHealthCheck() async {
  try {
    final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
      'runShizukuHealthCheck',
    );
    return ShizukuHealthCheckSnapshot.fromMap(result);
  } catch (e) {
    debugPrint('执行 Shizuku 健康检查失败: $e');
    return ShizukuHealthCheckSnapshot(
      status: ShizukuStatusSnapshot.fallback(),
      probeSuccess: false,
      probeMessage: '',
      rawShellProbeSuccess: false,
      rawShellProbeMessage: '',
      sessionProbeSuccess: false,
      sessionProbeMessage: '',
    );
  }
}

Future<bool> ensureShizukuPermission(BuildContext context) async {
  final status = await getShizukuStatus();
  if (status.isGranted) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final confirmed = await AppDialog.confirm(
    context,
    title: 'إذن Shizuku',
    content: status.localizedGuide,
    cancelText: 'إلغاء',
    confirmText: status.installed ? 'افتح Shizuku' : 'ثبّت Shizuku',
  );
  if (confirmed != true) {
    return false;
  }
  await openShizukuDownloadOrApp();
  if (!status.installed || !status.running) {
    return false;
  }
  return requestShizukuPermission();
}

Future<bool> requestPermission(List<String> permissions) async {
  try {
    final hasPermission = await spePermission.invokeMethod(
      'requestPermissions',
      {'permissions': permissions},
    );
    return hasPermission == "Success";
  } catch (e) {
    debugPrint('请求权限失败: $e');
    return false;
  }
}

Future<bool> isTermuxInstalled() async {
  try {
    return await spePermission.invokeMethod<bool>('isTermuxInstalled') ?? false;
  } catch (e) {
    debugPrint('检查 Termux 安装状态失败: $e');
    return false;
  }
}

Future<bool> openTermuxApp() async {
  try {
    return await spePermission.invokeMethod<bool>('openTermuxApp') ?? false;
  } catch (e) {
    debugPrint('打开 Termux 失败: $e');
    return false;
  }
}

Future<bool> isTermuxRunCommandPermissionGranted() async {
  try {
    return await spePermission.invokeMethod<bool>(
          'isTermuxRunCommandPermissionGranted',
        ) ??
        false;
  } catch (e) {
    debugPrint('检查 Termux RUN_COMMAND 权限失败: $e');
    return false;
  }
}

Future<bool> requestTermuxRunCommandPermission() async {
  try {
    return await spePermission.invokeMethod<bool>(
          'requestTermuxRunCommandPermission',
        ) ??
        false;
  } catch (e) {
    debugPrint('请求 Termux RUN_COMMAND 权限失败: $e');
    return false;
  }
}

Future<bool> ensureInstalledAppsPermission() async {
  try {
    final hasPermission =
        await spePermission.invokeMethod<bool>(
          'isInstalledAppsPermissionGranted',
        ) ??
        false;
    if (hasPermission) {
      return true;
    }
    await openInstalledAppsSettings();
  } catch (e) {
    debugPrint('检查应用列表读取权限失败: $e');
  }
  return false;
}

Future<void> openInstalledAppsSettings() async {
  await spePermission.invokeMethod('openInstalledAppsSettings');
}

Future<void> openAppDetailsSettings() async {
  await spePermission.invokeMethod('openAppDetailsSettings');
}

Future<bool> isNotificationPermissionGranted() async {
  try {
    return await spePermission.invokeMethod<bool>(
          'isNotificationPermissionGranted',
        ) ??
        false;
  } catch (e) {
    debugPrint('检查通知权限失败: $e');
    return false;
  }
}

Future<bool> requestNotificationPermission() async {
  try {
    return await spePermission.invokeMethod<bool>(
          'requestNotificationPermission',
        ) ??
        false;
  } catch (e) {
    debugPrint('请求通知权限失败: $e');
    return false;
  }
}

Future<bool> ensureNotificationPermission() async {
  if (await isNotificationPermissionGranted()) {
    return true;
  }
  return requestNotificationPermission();
}

Future<void> openNotificationSettings() async {
  await spePermission.invokeMethod<void>('openNotificationSettings');
}

Future<bool> isWorkspaceStorageAccessGranted() async {
  try {
    return await spePermission.invokeMethod<bool>(
          'isWorkspaceStorageAccessGranted',
        ) ??
        false;
  } catch (e) {
    debugPrint('检查内置 workspace 状态失败: $e');
    return false;
  }
}

Future<void> openWorkspaceStorageSettings() async {
  await spePermission.invokeMethod('openWorkspaceStorageSettings');
}

Future<bool> isPublicStorageAccessGranted() async {
  try {
    return await spePermission.invokeMethod<bool>(
          'isPublicStorageAccessGranted',
        ) ??
        false;
  } catch (e) {
    debugPrint('检查公共文件访问权限失败: $e');
    return false;
  }
}

Future<void> openPublicStorageSettings() async {
  await spePermission.invokeMethod('openPublicStorageSettings');
}

Future<Map<String, dynamic>> prepareTermuxLiveWrapper({
  List<String>? packageIds,
}) async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'prepareTermuxLiveWrapper',
    <String, dynamic>{if (packageIds != null) 'packageIds': packageIds},
  );
  return Map<String, dynamic>.from(result ?? const {});
}

Future<bool> isUnknownAppInstallAllowed() async {
  try {
    return await spePermission.invokeMethod<bool>(
          'isUnknownAppInstallAllowed',
        ) ??
        false;
  } catch (e) {
    debugPrint('检查未知应用安装权限失败: $e');
    return false;
  }
}

Future<void> openUnknownAppInstallSettings() async {
  await spePermission.invokeMethod('openUnknownAppInstallSettings');
}

Future<Map<String, dynamic>> downloadAndInstallTermuxApk(
  String downloadUrl,
) async {
  final result = await spePermission.invokeMethod<Map<dynamic, dynamic>>(
    'downloadAndInstallTermuxApk',
    {'downloadUrl': downloadUrl},
  );
  return Map<String, dynamic>.from(result ?? const {});
}

Future<bool> isBackgroundRunAllowed() async {
  try {
    return await spePermission.invokeMethod<bool>('isBackgroundRunAllowed') ??
        false;
  } catch (e) {
    debugPrint('检查后台运行权限失败: $e');
    return false;
  }
}
