library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Cross-platform file dialog helper.
///
/// - Desktop (Linux/Windows/macOS): uses `file_selector` (no zenity dependency)
/// - Mobile (Android/iOS): uses `file_picker`
class FileDialogService {
  static bool get _isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  static Future<String?> pickSingleFilePath({
    List<fs.XTypeGroup>? desktopTypeGroups,
  }) async {
    if (_isDesktop) {
      final file = await fs.openFile(
        acceptedTypeGroups: desktopTypeGroups ?? const [],
      );
      return file?.path;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  /// Save file path chooser.
  ///
  /// On mobile, if no save dialog is available, falls back to app documents dir.
  static Future<String?> pickSaveFilePath({
    required String suggestedName,
    String? dialogTitle,
  }) async {
    if (_isDesktop) {
      final saveLocation = await fs.getSaveLocation(
        suggestedName: suggestedName,
      );
      return saveLocation?.path;
    }

    if (_isMobile) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedName,
      );
      if (path != null) return path;

      // Fallback: app documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      return p.join(docsDir.path, suggestedName);
    }

    // Fallback for other platforms
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedName,
    );
    return path;
  }
}
