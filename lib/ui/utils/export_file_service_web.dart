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

  static bool get supportsOpenFolder => false;

  static Future<dynamic> saveText({
    required String fileName,
    required String content,
    String subdirName = 'exports',
  }) {
    throw UnsupportedError('Saving exports is not supported on web.');
  }

  static Future<void> shareFile(dynamic file, {String? subject}) {
    throw UnsupportedError('Sharing exports is not supported on web.');
  }

  static Future<void> openExportsFolder({String subdirName = 'exports'}) {
    throw UnsupportedError('Open folder is not supported on web.');
  }
}
