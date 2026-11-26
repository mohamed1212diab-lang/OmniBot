import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';

typedef PetAtlasInspector = Future<PetAtlasInfo> Function(Uint8List bytes);

class PetAtlasInfo {
  final int width;
  final int height;

  const PetAtlasInfo({required this.width, required this.height});
}

class PetPackageInstallResult {
  final String id;
  final String displayName;
  final String description;
  final int spriteVersionNumber;
  final int animationRowCount;
  final Directory packageDirectory;
  final File spritesheetFile;

  const PetPackageInstallResult({
    required this.id,
    required this.displayName,
    required this.description,
    required this.spriteVersionNumber,
    required this.animationRowCount,
    required this.packageDirectory,
    required this.spritesheetFile,
  });
}

class PetPackageException implements Exception {
  final String message;

  const PetPackageException(this.message);

  @override
  String toString() => message;
}

class PetPackageInstaller {
  static const int _maxArchiveBytes = 32 * 1024 * 1024;
  static const int _maxExtractedBytes = 64 * 1024 * 1024;
  static const int _maxEntries = 64;
  static final RegExp _petIdPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  final PetAtlasInspector inspectAtlas;

  const PetPackageInstaller({this.inspectAtlas = inspectCodexPetAtlas});

  Future<PetPackageInstallResult> installArchiveFile({
    required File archiveFile,
    required String petsRootPath,
  }) async {
    if (!await archiveFile.exists()) {
      throw const PetPackageException('حزمة الحيوان الأليف غير موجودة');
    }
    final archiveLength = await archiveFile.length();
    if (archiveLength <= 0 || archiveLength > _maxArchiveBytes) {
      throw const PetPackageException('حزمة الحيوان الأليف فارغة أو تتجاوز 32 MB');
    }
    return installArchiveBytes(
      archiveBytes: await archiveFile.readAsBytes(),
      petsRootPath: petsRootPath,
    );
  }

  Future<PetPackageInstallResult> installArchiveBytes({
    required Uint8List archiveBytes,
    required String petsRootPath,
  }) async {
    if (archiveBytes.isEmpty || archiveBytes.length > _maxArchiveBytes) {
      throw const PetPackageException('حزمة الحيوان الأليف فارغة أو تتجاوز 32 MB');
    }
    final rootPath = petsRootPath.trim();
    if (rootPath.isEmpty) {
      throw const PetPackageException('لم تتم تهيئة دليل الحيوانات الأليفة بعد');
    }

    final archive = _decodeArchive(archiveBytes);
    final files = _validatedFiles(archive);
    final manifestEntries = files.entries
        .where((entry) => _baseName(entry.key) == 'pet.json')
        .toList(growable: false);
    if (manifestEntries.length != 1) {
      throw const PetPackageException('يجب أن تحتوي الحزمة على ملف pet.json واحد فقط');
    }

    final manifestEntry = manifestEntries.single;
    final manifestBytes = manifestEntry.value.readBytes();
    if (manifestBytes == null || manifestBytes.isEmpty) {
      throw const PetPackageException('ملف pet.json فارغ');
    }
    final manifest = _decodeManifest(manifestBytes);
    final petId = (manifest['id'] ?? '').toString().trim();
    if (!_petIdPattern.hasMatch(petId)) {
      throw const PetPackageException(
        'يجب أن يكون id في pet.json اسمًا بأحرف صغيرة وشرطات مثل claude-pixel',
      );
    }

    final displayName = (manifest['displayName'] ?? manifest['name'] ?? petId)
        .toString()
        .trim();
    if (displayName.isEmpty) {
      throw const PetPackageException('يفتقد ملف pet.json إلى displayName');
    }
    final description = (manifest['description'] ?? '').toString().trim();
    final spritesheetPath = (manifest['spritesheetPath'] ?? '')
        .toString()
        .trim();
    if (!_isSafeRelativeFileName(spritesheetPath) ||
        !_isSupportedSpritesheetName(spritesheetPath)) {
      throw const PetPackageException(
        'يجب أن يشير spritesheetPath في pet.json إلى أطلس صور WebP أو PNG',
      );
    }

    final manifestDirectory = _directoryName(manifestEntry.key);
    final spritesheetArchivePath = manifestDirectory.isEmpty
        ? spritesheetPath
        : '$manifestDirectory/$spritesheetPath';
    final spritesheetEntry = files[spritesheetArchivePath];
    if (spritesheetEntry == null) {
      throw PetPackageException('الحزمة لا تحتوي على $spritesheetPath');
    }
    final spritesheetBytes = spritesheetEntry.readBytes();
    if (spritesheetBytes == null || spritesheetBytes.isEmpty) {
      throw const PetPackageException('أطلس صور الحيوان الأليف فارغ');
    }
    _validateImageHeader(spritesheetPath, spritesheetBytes);

    final atlasInfo = await inspectAtlas(spritesheetBytes);
    final spriteVersionNumber = _parseSpriteVersion(
      manifest['spriteVersionNumber'],
    );
    final animationRowCount = _validateAtlasContract(
      atlasInfo,
      spriteVersionNumber,
    );
    final normalizedVersion = animationRowCount == 11 ? 2 : 1;

    final petsRoot = Directory(rootPath);
    await petsRoot.create(recursive: true);
    final packageDirectory = Directory(
      '${petsRoot.path}${Platform.pathSeparator}$petId',
    );
    await packageDirectory.create(recursive: true);
    final spritesheetFile = File(
      '${packageDirectory.path}${Platform.pathSeparator}$spritesheetPath',
    );
    await spritesheetFile.writeAsBytes(spritesheetBytes, flush: true);

    manifest['id'] = petId;
    manifest['displayName'] = displayName;
    manifest['description'] = description;
    manifest['spritesheetPath'] = spritesheetPath;
    if (normalizedVersion == 2) {
      manifest['spriteVersionNumber'] = 2;
    } else if (manifest['spriteVersionNumber'] != null) {
      manifest['spriteVersionNumber'] = 1;
    }
    final manifestFile = File(
      '${packageDirectory.path}${Platform.pathSeparator}pet.json',
    );
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );

    return PetPackageInstallResult(
      id: petId,
      displayName: displayName,
      description: description,
      spriteVersionNumber: normalizedVersion,
      animationRowCount: animationRowCount,
      packageDirectory: packageDirectory,
      spritesheetFile: spritesheetFile,
    );
  }

  Archive _decodeArchive(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const PetPackageException('تعذّرت قراءة حزمة الحيوان الأليف، تأكد من أنها ملف ZIP صالح');
    }
  }

  Map<String, ArchiveFile> _validatedFiles(Archive archive) {
    if (archive.isEmpty || archive.length > _maxEntries) {
      throw const PetPackageException('حزمة الحيوان الأليف فارغة أو تحتوي على ملفات كثيرة جدًا');
    }
    final files = <String, ArchiveFile>{};
    var extractedBytes = 0;
    for (final entry in archive) {
      if (entry.isSymbolicLink) {
        throw const PetPackageException('لا يمكن أن تحتوي حزمة الحيوان الأليف على روابط رمزية');
      }
      final entryName = entry.isFile
          ? entry.name
          : entry.name.replaceFirst(RegExp(r'/+$'), '');
      final normalizedName = _normalizeArchiveEntryName(entryName);
      if (!entry.isFile) {
        continue;
      }
      extractedBytes += entry.size;
      if (extractedBytes > _maxExtractedBytes) {
        throw const PetPackageException('تتجاوز حزمة الحيوان الأليف 64 MB بعد فك الضغط');
      }
      files[normalizedName] = entry;
    }
    return files;
  }

  String _normalizeArchiveEntryName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty ||
        name.startsWith('/') ||
        name.contains(r'\') ||
        name.contains(':')) {
      throw const PetPackageException('تحتوي حزمة الحيوان الأليف على مسار ملف غير آمن');
    }
    final segments = name.split('/');
    if (segments.any((segment) => segment == '..' || segment.isEmpty)) {
      throw const PetPackageException('تحتوي حزمة الحيوان الأليف على مسار ملف غير آمن');
    }
    return segments.where((segment) => segment != '.').join('/');
  }

  Map<String, dynamic> _decodeManifest(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException();
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      throw const PetPackageException('ملف pet.json ليس كائن JSON صالحًا');
    }
  }

  int _parseSpriteVersion(Object? rawValue) {
    if (rawValue == null) return 1;
    final parsed = rawValue is num
        ? rawValue.toInt()
        : int.tryParse(rawValue.toString().trim());
    if (parsed != 1 && parsed != 2) {
      throw const PetPackageException('يدعم spriteVersionNumber القيمتين 1 أو 2 فقط');
    }
    return parsed!;
  }

  int _validateAtlasContract(PetAtlasInfo info, int spriteVersionNumber) {
    if (info.width != 1536) {
      throw const PetPackageException('يجب أن يكون عرض أطلس صور الحيوان الأليف 1536 بكسل');
    }
    if (info.height == 1872 && spriteVersionNumber == 1) {
      return 9;
    }
    if (info.height == 2288 && spriteVersionNumber == 2) {
      return 11;
    }
    if (info.height == 2288) {
      throw const PetPackageException(
        'يجب الإعلان عن spriteVersionNumber: 2 في pet.json لأطلس الصور ذي 11 صفًا',
      );
    }
    if (spriteVersionNumber == 2) {
      throw const PetPackageException('يجب أن تكون أبعاد أطلس صور الحيوان الأليف v2 1536×2288');
    }
    throw const PetPackageException('يجب أن تكون أبعاد أطلس صور الحيوان الأليف v1 1536×1872');
  }

  void _validateImageHeader(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    final isWebp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    if ((lower.endsWith('.webp') && !isWebp) ||
        (lower.endsWith('.png') && !isPng)) {
      throw const PetPackageException('تنسيق أطلس صور الحيوان الأليف لا يطابق امتداد الملف');
    }
  }

  bool _isSafeRelativeFileName(String value) {
    return value.isNotEmpty &&
        !value.startsWith('/') &&
        !value.contains('/') &&
        !value.contains(r'\') &&
        !value.contains(':') &&
        value != '.' &&
        value != '..';
  }

  bool _isSupportedSpritesheetName(String value) {
    final lower = value.toLowerCase();
    return lower.endsWith('.webp') || lower.endsWith('.png');
  }

  String _baseName(String path) {
    final segments = path.split('/');
    return segments.isEmpty ? path : segments.last.toLowerCase();
  }

  String _directoryName(String path) {
    final separatorIndex = path.lastIndexOf('/');
    return separatorIndex < 0 ? '' : path.substring(0, separatorIndex);
  }
}

Future<PetAtlasInfo> inspectCodexPetAtlas(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final info = PetAtlasInfo(width: image.width, height: image.height);
    image.dispose();
    codec.dispose();
    return info;
  } catch (_) {
    throw const PetPackageException('تعذّر فك ترميز أطلس صور الحيوان الأليف');
  }
}
