import 'package:flutter/services.dart';

class OmnibotOfficePreviewData {
  final String kindLabel;
  final String summary;
  final List<OmnibotOfficePreviewSection> sections;
  final bool truncated;

  const OmnibotOfficePreviewData({
    required this.kindLabel,
    required this.summary,
    required this.sections,
    this.truncated = false,
  });
}

class OmnibotOfficePreviewSection {
  final String title;
  final String? subtitle;
  final List<String> lines;
  final List<List<String>> tableRows;

  const OmnibotOfficePreviewSection({
    required this.title,
    this.subtitle,
    this.lines = const <String>[],
    this.tableRows = const <List<String>>[],
  });

  bool get hasTable => tableRows.isNotEmpty;
}

/// The host reads ZIP/XML data; Flutter only maps it to the existing preview UI.
class OmnibotOfficePreviewService {
  static const MethodChannel _channel = MethodChannel(
    'cn.com.omnimind.bot/file_save',
  );

  static Future<OmnibotOfficePreviewData> loadPreview({
    required String path,
    required String previewKind,
  }) async {
    try {
      final payload = await _channel.invokeMapMethod<String, dynamic>(
        'loadOfficePreview',
        {'path': path, 'previewKind': previewKind},
      );
      if (payload == null) {
        throw StateError('فشلت معاينة ملف Office');
      }
      final sections = (payload['sections'] as List).cast<Map>();
      return switch (previewKind) {
        'office_word' => OmnibotOfficePreviewData(
          kindLabel: 'معاينة Word',
          summary: 'تم استخراج ${(sections.single['lines'] as List).length} فقرة في المجموع',
          sections: [
            OmnibotOfficePreviewSection(
              title: 'النص',
              subtitle: 'مرّر لعرض محتوى المستند المستخرج',
              lines: _lines(sections.single),
            ),
          ],
        ),
        'office_sheet' => OmnibotOfficePreviewData(
          kindLabel: 'معاينة Excel',
          summary: 'تم استخراج ${sections.length} ورقة عمل في المجموع',
          sections: [
            for (var index = 0; index < sections.length; index++)
              _sheetSection(sections[index], index),
          ],
        ),
        'office_slide' => OmnibotOfficePreviewData(
          kindLabel: 'معاينة PowerPoint',
          summary: 'تم استخراج ${sections.length} شريحة في المجموع',
          sections: [
            for (var index = 0; index < sections.length; index++)
              OmnibotOfficePreviewSection(
                title: 'الشريحة ${index + 1}',
                lines: _lines(sections[index]).isEmpty
                    ? ['لا يوجد نص قابل للاستخراج في هذه الشريحة']
                    : _lines(sections[index]),
              ),
          ],
        ),
        _ => throw StateError(
          'نوع ملف Office هذا غير مدعوم',
        ),
      };
    } on PlatformException catch (error) {
      final detail = error.message ?? '';
      throw StateError(switch (error.code) {
        'OFFICE_UNSUPPORTED' => 'نوع ملف Office هذا غير مدعوم',
        'OFFICE_MISSING_ENTRY' => 'الملف ناقص: $detail',
        'OFFICE_EMPTY_WORD' => 'لم يتم العثور على نص Word قابل للمعاينة',
        'OFFICE_EMPTY_SHEETS' => 'لم يتم العثور على ورقة عمل Excel قابلة للمعاينة',
        'OFFICE_EMPTY_SLIDES' => 'لم يتم العثور على شرائح PowerPoint قابلة للمعاينة',
        'OFFICE_XML_ERROR' => 'فشل تحليل بنية ملف Office: $detail',
        _ => 'فشلت معاينة ملف Office: $detail',
      });
    }
  }

  static OmnibotOfficePreviewSection _sheetSection(Map section, int index) {
    final title = section['title'] as String? ?? '';
    final rows = (section['tableRows'] as List)
        .map((row) => (row as List).cast<String>())
        .toList(growable: false);
    return OmnibotOfficePreviewSection(
      title: title.isEmpty
          ? 'ورقة العمل ${index + 1}'
          : title,
      subtitle: rows.isEmpty
          ? 'لم يتم استخراج محتوى أي خلية'
          : 'تم استخراج ${rows.length} صفاً في المجموع',
      lines: rows.isEmpty
          ? ['لا يوجد نص قابل للمعاينة في ورقة العمل هذه']
          : const [],
      tableRows: rows,
    );
  }

  static List<String> _lines(Map section) =>
      (section['lines'] as List).cast<String>();
}
