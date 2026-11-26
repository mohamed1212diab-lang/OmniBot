import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui/services/agent_runtime_service.dart';

typedef NaLocalTimeResolver = Future<Map<String, dynamic>> Function({
  String? localTime,
  String? at,
  required String timezone,
});

const _weekdays = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const _modes = {
  'once': 'تشغيل مرة واحدة فقط',
  'interval': 'حسب الفاصل الزمني',
  'daily': 'يوميًا',
  'weekly': 'أسبوعيًا',
  'monthly': 'شهريًا',
  'event': 'حدث تطبيق',
  'cron': 'Cron (متقدم)',
};
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// Form draft only. Execution, scheduling and permissions stay server-owned.
class NaRoutineDraft {
  NaRoutineDraft({this.original, required String timezone}) {
    final routine = original ?? {};
    final schedule = _map(routine['schedule']);
    this.timezone = schedule['timezone']?.toString() ?? timezone;
    title = routine['title']?.toString() ?? '';
    prompt = routine['prompt']?.toString() ?? '';
    continuity = routine['continuity'] as bool? ?? (original == null);
    deliver = routine['deliver']?.toString() ?? 'chat';
    maxRunsPerDay = (routine['maxRunsPerDay'] ?? 24).toString();
    checks = List<String>.from(routine['checks'] as List? ?? []);
    mode = routine['trigger'] == 'event' ? 'event' : 'once';
    interval = (schedule['everyMinutes'] ?? routine['intervalMinutes'] ?? 60)
        .toString();
    if (routine['trigger'] != 'event') {
      if (schedule['type'] == 'interval' ||
          routine['intervalMinutes'] != null) {
        mode = 'interval';
      }
      if (schedule['type'] == 'interval') {
        weekdays = List<int>.from(schedule['weekdays'] as List? ?? []);
        final window = _map(schedule['window']);
        windowStart = window['start']?.toString() ?? '';
        windowEnd = window['end']?.toString() ?? '';
      }
      if (schedule['time'] is String) {
        mode = schedule['weekday'] == null ? 'daily' : 'weekly';
        time = schedule['time'] as String;
        weekday = [
          'Sun',
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
        ].indexOf(schedule['weekday']?.toString() ?? 'Mon');
      }
      if (schedule['type'] == 'cron') {
        mode = 'cron';
        cron = schedule['expression']?.toString() ?? '';
        final parts = cron.trim().split(RegExp(r'\s+'));
        if (parts.length == 5) {
          final minute = int.tryParse(parts[0]), hour = int.tryParse(parts[1]);
          if (minute != null &&
              minute >= 0 &&
              minute < 60 &&
              hour != null &&
              hour >= 0 &&
              hour < 24 &&
              parts[3] == '*') {
            time = '${_pad(hour)}:${_pad(minute)}';
            if (parts[2] == '*' && parts[4] == '*') {
              mode = 'daily';
            } else if (parts[2] == '*' &&
                RegExp(r'^[0-6]$').hasMatch(parts[4])) {
              mode = 'weekly';
              weekday = int.parse(parts[4]);
            } else if (parts[4] == '*' &&
                (int.tryParse(parts[2]) ?? 0) >= 1 &&
                (int.tryParse(parts[2]) ?? 32) <= 31) {
              mode = 'monthly';
              monthDay = parts[2];
            }
          }
        }
      }
    }
  }

  final Map<String, dynamic>? original;
  late String title, prompt, timezone, mode, interval, maxRunsPerDay, deliver;
  late bool continuity;
  late List<String> checks;
  String localTime = '', explicitAt = '', time = '09:00';
  String monthDay = '1', cron = '0 9 * * *', windowStart = '', windowEnd = '';
  int weekday = 1;
  List<int> weekdays = [];
  String? _initialTiming;

  String get initialAt {
    final schedule = _map(original?['schedule']);
    return (schedule['type'] == 'once'
                ? schedule['at']
                : original?['nextRunAt'])
            ?.toString() ??
        DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
  }

  void acceptInitialLocalTime(String value) {
    localTime = value;
    _initialTiming = _timingKey;
  }

  String get _timingKey => jsonEncode({
    'mode': mode,
    'timezone': timezone,
    'localTime': localTime,
    'explicitAt': explicitAt,
    'time': time,
    'weekday': weekday,
    'monthDay': monthDay,
    'interval': interval,
    'cron': cron,
    'weekdays': [...weekdays]..sort(),
    'windowStart': windowStart,
    'windowEnd': windowEnd,
  });

  Future<Map<String, dynamic>> payload(NaLocalTimeResolver resolve) async {
    if (title.trim().isEmpty || prompt.trim().isEmpty) {
      throw const FormatException('يُرجى إدخال اسم المهمة ومحتوى الفحص.');
    }
    final max = int.tryParse(maxRunsPerDay);
    if (max == null || max < 1 || max > 1440) {
      throw const FormatException('يجب أن يكون الحد اليومي بين 1 و 1440 مرة.');
    }
    final body = <String, dynamic>{
      'title': title.trim(),
      'prompt': prompt.trim(),
    };
    if (original == null || _timingKey != _initialTiming) {
      if (mode == 'event') {
        body['trigger'] = 'event';
      } else {
        body['trigger'] = 'schedule';
        if (mode == 'once') {
          String at;
          if (explicitAt.trim().isNotEmpty) {
            final explicit = explicitAt.trim();
            final match = RegExp(
              r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(Z|[+-]\d{2}:\d{2})$',
            ).firstMatch(explicit);
            final parsed = DateTime.tryParse(explicit);
            if (match == null || parsed == null) {
              throw const FormatException('يجب أن يتضمن الوقت المتقدم Z أو إزاحة منطقة زمنية صريحة.');
            }
            final offset = match.group(7)!;
            if (offset != 'Z' &&
                (int.parse(offset.substring(1, 3)) > 23 ||
                    int.parse(offset.substring(4)) > 59)) {
              throw const FormatException('إزاحة المنطقة الزمنية غير صالحة.');
            }
            final parts = [
              for (var i = 1; i <= 6; i++) int.parse(match.group(i) ?? '0'),
            ];
            final calendar = DateTime.utc(
              parts[0],
              parts[1],
              parts[2],
              parts[3],
              parts[4],
              parts[5],
            );
            if (calendar.year != parts[0] ||
                calendar.month != parts[1] ||
                calendar.day != parts[2] ||
                calendar.hour != parts[3] ||
                calendar.minute != parts[4] ||
                calendar.second != parts[5]) {
              throw const FormatException('التاريخ أو الوقت غير صالح.');
            }
            at = parsed.toUtc().toIso8601String();
          } else {
            at =
                (await resolve(localTime: localTime, timezone: timezone))['at']
                    as String;
          }
          body['schedule'] = {'type': 'once', 'at': at};
        } else if (mode == 'interval') {
          final every = num.tryParse(interval);
          if (every == null || !every.isFinite || every < 1 || every > 525600) {
            throw const FormatException('يجب أن يكون الفاصل بين 1 و 525600 دقيقة.');
          }
          Map<String, String>? window;
          if (windowStart.isNotEmpty || windowEnd.isNotEmpty) {
            if (!_validTime(windowStart) ||
                !_validTime(windowEnd) ||
                windowStart.compareTo(windowEnd) >= 0) {
              throw const FormatException('يجب إدخال فترة التنفيذ كاملة، وأن يكون وقت الانتهاء بعد وقت البدء.');
            }
            window = {'start': windowStart, 'end': windowEnd};
          }
          body['schedule'] = {
            'type': 'interval',
            'everyMinutes': every,
            'timezone': timezone,
            if (weekdays.isNotEmpty) 'weekdays': [...weekdays]..sort(),
            'window': ?window,
          };
        } else {
          if (mode != 'cron' && !_validTime(time)) {
            throw const FormatException('يُرجى اختيار وقت تنفيذ صالح.');
          }
          final parts = time.split(':');
          final day = int.tryParse(monthDay);
          if (mode == 'monthly' && (day == null || day < 1 || day > 31)) {
            throw const FormatException('يجب أن يكون يوم الشهر بين 1 و 31.');
          }
          final expression = mode == 'cron'
              ? cron.trim()
              : '${int.parse(parts[1])} ${int.parse(parts[0])} ${mode == 'monthly' ? day : '*'} * ${mode == 'weekly' ? weekday : '*'}';
          if (expression.split(RegExp(r'\s+')).length != 5 ||
              RegExp(r'[@?]').hasMatch(expression) ||
              expression.length > 200) {
            throw const FormatException('يجب أن يتكون تعبير Cron من خمسة حقول: الدقيقة، الساعة، اليوم، الشهر، يوم الأسبوع.');
          }
          body['schedule'] = {
            'type': 'cron',
            'expression': expression,
            'timezone': timezone,
          };
        }
      }
    }
    final values = <String, dynamic>{
      'continuity': continuity,
      'deliver': deliver,
      'maxRunsPerDay': max,
      'checks': [...checks]..sort(),
    };
    final previous = {
      'continuity': original?['continuity'] ?? false,
      'deliver': original?['deliver'] ?? 'chat',
      'maxRunsPerDay': original?['maxRunsPerDay'] ?? 24,
      'checks': List<String>.from(original?['checks'] as List? ?? [])..sort(),
    };
    for (final entry in values.entries) {
      if (original == null ||
          jsonEncode(entry.value) != jsonEncode(previous[entry.key])) {
        body[entry.key] = entry.value;
      }
    }
    return body;
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');
bool _validTime(String value) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

String naRoutineStatus(Map<String, dynamic> routine) {
  if (routine['enabled'] != true) return 'متوقف مؤقتًا';
  if (routine['waitingReview'] != null || routine['heldReason'] == 'review') {
    return 'بانتظار مراجعتك لعملية التطبيق';
  }
  if (routine['heldReason'] == 'daily_cap') return 'تم بلوغ الحد اليومي للتشغيل';
  if (routine['lastCheckFailureCause'] != null) return 'لم تكتمل قراءة التطبيق، وهذا لا يعني عدم وجود محتوى جديد';
  if (routine['heldReason'] == 'check_unavailable') return 'بانتظار نتيجة فحص متاحة أو إذن قراءة';
  if (routine['heldReason'] == 'boot_hold') return 'بانتظار أول فحص بعد التشغيل';
  if (routine['heldReason'] != null) return 'تم الإيقاف مؤقتًا: ${routine['heldReason']}';
  if (routine['nextAllowedAt'] != null ||
      routine['nextCheckAllowedAt'] != null) {
    return 'متوقف مؤقتًا، بانتظار المحاولة التالية';
  }
  if (routine['scheduleDone'] == true) return 'اكتملت هذه الخطة';
  return routine['trigger'] == 'event' ? 'بانتظار حدث تطبيق' : 'الخطة مفعّلة';
}

Future<Map<String, dynamic>?> showNaRoutineEditor(
  BuildContext context, {
  Map<String, dynamic>? routine,
  required String timezone,
  NaLocalTimeResolver resolveLocalTime = AgentRuntimeService.requestNaLocalTime,
  bool Function()? isCurrent,
}) async {
  final draft = NaRoutineDraft(original: routine, timezone: timezone);
  final local = await resolveLocalTime(
    at: draft.initialAt,
    timezone: draft.timezone,
  );
  draft.acceptInitialLocalTime(local['localTime'] as String);
  if (!context.mounted || isCurrent?.call() == false) return null;
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) =>
        NaRoutineEditor(draft: draft, resolveLocalTime: resolveLocalTime),
  );
}

class NaRoutineEditor extends StatefulWidget {
  const NaRoutineEditor({
    super.key,
    required this.draft,
    required this.resolveLocalTime,
    this.isCurrent,
  });
  final NaRoutineDraft draft;
  final NaLocalTimeResolver resolveLocalTime;
  final bool Function()? isCurrent;

  @override
  State<NaRoutineEditor> createState() => _NaRoutineEditorState();
}

class _NaRoutineEditorState extends State<NaRoutineEditor> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  NaRoutineDraft get draft => widget.draft;

  Future<void> _save() async {
    if (_saving) return;
    if (widget.isCurrent?.call() == false) {
      Navigator.of(context).pop();
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    _form.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await draft.payload(widget.resolveLocalTime);
      if (mounted) {
        Navigator.of(context)
            .pop(widget.isCurrent?.call() == false ? null : result);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is FormatException
              ? error.message
              : error is PlatformException
              ? (error.message ?? 'التاريخ أو المنطقة الزمنية غير صالحة.')
              : 'التاريخ أو المنطقة الزمنية غير صالحة، يُرجى التحقق وإعادة المحاولة.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _text(
    String label,
    String value,
    ValueChanged<String> change, {
    int lines = 1,
    bool required = false,
    TextInputType? keyboard,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey(label),
      initialValue: value,
      maxLines: lines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 4,
      ),
      onChanged: change,
      onSaved: (value) => change(value ?? ''),
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? 'يُرجى إدخال $label' : null
          : null,
    ),
  );

  Widget _select<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<T>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: _saving
          ? null
          : (value) {
              if (value != null) setState(() => change(value));
            },
    ),
  );

  Future<void> _pickTime(String current, ValueChanged<String> change) async {
    final parts = current.split(':');
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      ),
    );
    if (result != null && mounted) {
      setState(() => change('${_pad(result.hour)}:${_pad(result.minute)}'));
    }
  }

  Widget _timeButton(
    String label,
    String current,
    ValueChanged<String> change,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: TextButton(
      onPressed: _saving ? null : () => _pickTime(current, change),
      child: Text(current.isEmpty ? 'اختر الوقت' : current),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final local = DateTime.tryParse(draft.localTime);
    return AlertDialog(
      title: Text(draft.original == null ? 'إضافة مهمة جديدة' : 'تعديل المهمة'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(
                  'اسم المهمة',
                  draft.title,
                  (v) => draft.title = v,
                  required: true,
                ),
                _text(
                  'محتوى الفحص وشروط التنبيه',
                  draft.prompt,
                  (v) => draft.prompt = v,
                  lines: 3,
                  required: true,
                ),
                _select(
                  'طريقة التنفيذ',
                  draft.mode,
                  _modes.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  (v) => draft.mode = v,
                ),
                if (draft.mode != 'event')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('المنطقة الزمنية للخطة: ${draft.timezone}'),
                  ),
                if (draft.mode == 'once') ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ التنفيذ'),
                    trailing: TextButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              final result = await showDatePicker(
                                context: context,
                                initialDate: local ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2200),
                              );
                              if (result != null && mounted) {
                                setState(() {
                                  draft.localTime =
                                      '${result.year}-${_pad(result.month)}-${_pad(result.day)}T${draft.localTime.split('T').last}';
                                });
                              }
                            },
                      child: Text(draft.localTime.split('T').first),
                    ),
                  ),
                  _timeButton(
                    'وقت التنفيذ',
                    draft.localTime.split('T').last,
                    (v) => draft.localTime =
                        '${draft.localTime.split('T').first}T$v',
                  ),
                ],
                if (draft.mode == 'interval')
                  _text(
                    'فاصل التكرار (بالدقائق)',
                    draft.interval,
                    (v) => draft.interval = v,
                    keyboard: TextInputType.number,
                  ),
                if (['daily', 'weekly', 'monthly'].contains(draft.mode))
                  _timeButton('وقت التنفيذ', draft.time, (v) => draft.time = v),
                if (draft.mode == 'weekly')
                  _select(
                    'يوم الأسبوع',
                    draft.weekday,
                    List.generate(
                      7,
                      (i) =>
                          DropdownMenuItem(value: i, child: Text(_weekdays[i])),
                    ),
                    (v) => draft.weekday = v,
                  ),
                if (draft.mode == 'monthly')
                  _text(
                    'يوم الشهر',
                    draft.monthDay,
                    (v) => draft.monthDay = v,
                    keyboard: TextInputType.number,
                    hint: 'إذا لم يكن التاريخ المحدد موجودًا في ذلك الشهر، يتم تخطيه.',
                  ),
                if (draft.mode == 'cron')
                  _text(
                    'تعبير Cron',
                    draft.cron,
                    (v) => draft.cron = v,
                    hint: 'خمسة حقول: الدقيقة الساعة اليوم الشهر يوم الأسبوع، مثال: 0 9 * * 1-5.',
                  ),
                if (draft.mode == 'event')
                  const Text('بعد الحفظ، اربط هذه المهمة بحدث تطبيق في «ربط التطبيقات»؛ ويتم التفعيل فقط عند استلام حدث مطابق.'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('متابعة مستمرة'),
                  subtitle: const Text('عند وجود تغييرات جديدة تتم المتابعة، وعند عدم وجودها يبقى صامتًا.'),
                  value: draft.continuity,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => draft.continuity = v),
                ),
                _select('تسليم النتيجة', draft.deliver, const [
                  DropdownMenuItem(value: 'chat', child: Text('المحادثة الأصلية')),
                  DropdownMenuItem(value: 'brief', child: Text('الملخص اليومي')),
                ], (v) => draft.deliver = v),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('الإعدادات المتقدمة'),
                  children: [
                    _text(
                      'المنطقة الزمنية للخطة',
                      draft.timezone,
                      (v) => draft.timezone = v,
                      hint: 'يُستخدم افتراضيًا توقيت IANA من بيانات خدمة Na.',
                    ),
                    _text(
                      'أقصى عدد تشغيل يوميًا',
                      draft.maxRunsPerDay,
                      (v) => draft.maxRunsPerDay = v,
                      keyboard: TextInputType.number,
                    ),
                    if (draft.mode == 'once')
                      _text(
                        'وقت تنفيذ بإزاحة صريحة (اختياري)',
                        draft.explicitAt,
                        (v) => draft.explicitAt = v,
                        hint: 'عند تداخل التوقيت الصيفي يمكن إدخال 2026-11-01T01:30:00-05:00؛ ويُستخدم أولًا بعد إدخاله.',
                      ),
                    if (draft.mode == 'interval') ...[
                      const Text('التنفيذ في هذه الأيام فقط (إذا لم تختر شيئًا، يتم التنفيذ يوميًا)'),
                      Wrap(
                        spacing: 6,
                        children: List.generate(
                          7,
                          (i) => FilterChip(
                            label: Text(_weekdays[i]),
                            selected: draft.weekdays.contains(i),
                            onSelected: (v) => setState(() {
                              v
                                  ? draft.weekdays.add(i)
                                  : draft.weekdays.remove(i);
                            }),
                          ),
                        ),
                      ),
                      _timeButton(
                        'وقت البدء اليومي (اختياري)',
                        draft.windowStart,
                        (v) => draft.windowStart = v,
                      ),
                      _timeButton(
                        'وقت الانتهاء اليومي (اختياري)',
                        draft.windowEnd,
                        (v) => draft.windowEnd = v,
                      ),
                      if (draft.windowStart.isNotEmpty ||
                          draft.windowEnd.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() {
                            draft.windowStart = '';
                            draft.windowEnd = '';
                          }),
                          child: const Text('مسح فترة التنفيذ'),
                        ),
                    ],
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('افحص التغييرات أولًا، ثم قرر ما إذا كان يلزم متابعة من الذكاء الاصطناعي'),
                    ),
                    for (final check in {
                      'mail': 'البريد الإلكتروني',
                      'calendar': 'التقويم',
                      'runs': 'تقدّم المهام',
                    }.entries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(check.value),
                        value: draft.checks.contains(check.key),
                        onChanged: (v) => setState(() {
                          v == true
                              ? draft.checks.add(check.key)
                              : draft.checks.remove(check.key);
                        }),
                      ),
                    const Text(
                      'يجب تشغيل البريد الإلكتروني والتقويم يدويًا مرة أولًا، ثم حفظ إذن متكرر لعملية القراءة المقابلة. وفي حال عدم الحصول على الإذن أو فشل القراءة، ستظهر حالة انتظار أو فشل، ولن يُعتبر ذلك «لا يوجد محتوى جديد».',
                    ),
                  ],
                ),
                if (draft.original != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('تعديل المهمة أو الخطة يُبطل الإذن المتكرر الأصلي، ويلزم إعادة المراجعة ثم حفظ الإذن.'),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ المهمة'),
        ),
      ],
    );
  }
}
