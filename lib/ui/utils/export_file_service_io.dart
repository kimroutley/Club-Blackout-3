import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportFileService {
  static String safeTimestampForFilename(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }

  static bool get supportsOpenFolder {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static Future<Directory> _getExportsDir({String subdirName = 'exports'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${dir.path}/$subdirName');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    return exportsDir;
  }

  static Future<File> saveText({
    required String fileName,
    required String content,
    String subdirName = 'exports',
  }) async {
    final exportsDir = await _getExportsDir(subdirName: subdirName);
    final file = File('${exportsDir.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  static Future<void> shareFile(File file, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
    );
  }

  static Future<void> openExportsFolder({String subdirName = 'exports'}) async {
    if (!supportsOpenFolder) {
      throw UnsupportedError('Open folder is only supported on desktop.');
    }

    final exportsDir = await _getExportsDir(subdirName: subdirName);

    if (Platform.isWindows) {
      await Process.run('explorer', [exportsDir.path]);
      return;
    }

    if (Platform.isMacOS) {
      await Process.run('open', [exportsDir.path]);
      return;
    }

    if (Platform.isLinux) {
      await Process.run('xdg-open', [exportsDir.path]);
      return;
    }
  }
}
