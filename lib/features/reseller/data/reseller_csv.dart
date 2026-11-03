import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [content] as a UTF-8 (BOM) CSV in the temp directory and opens the
/// native share sheet (React downloads the same file). Falls back to copying
/// the CSV to the clipboard when file sharing is unavailable.
///
/// Returns the file path, or null when the clipboard fallback was used.
Future<String?> shareCsvFile(String content, String filename) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsString('\uFEFF$content', flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: filename,
        title: filename,
      ),
    );
    return file.path;
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: content));
    return null;
  }
}
