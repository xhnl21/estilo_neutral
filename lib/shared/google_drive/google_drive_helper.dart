import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utilidades de integración con Google Drive para almacenamiento y renderizado de imágenes.
/// Carpeta oficial asignada: https://drive.google.com/drive/folders/1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD?usp=sharing
class GoogleDriveHelper {
  static const String folderId = '1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD';
  static const String folderUrl = 'https://drive.google.com/drive/folders/1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD?usp=sharing';

  /// Extrae el ID de archivo de Google Drive desde cualquier formato común de enlace
  /// (enlaces de compartir /d/{id}/view, enlaces abiertos ?id={id}, o ID directo).
  static String? extractFileId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Si ya es un ID directo sin barras ni dominios
    if (!trimmed.contains('/') && !trimmed.contains('.')) {
      return trimmed;
    }

    // Patrón 1: /d/{ID} o /file/d/{ID}
    final dMatch = RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(trimmed);
    if (dMatch != null) return dMatch.group(1);

    // Patrón 2: id={ID}
    final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(trimmed);
    if (idMatch != null) return idMatch.group(1);

    return null;
  }

  /// Convierte cualquier enlace o ID de Google Drive a la URL directa de alta velocidad
  /// compatible con Flutter Image.network y con la fórmula =IMAGE(...) de Google Sheets.
  static String formatDirectImageUrl(String input) {
    final fileId = extractFileId(input);
    if (fileId != null) {
      return 'https://lh3.googleusercontent.com/d/$fileId';
    }
    return input.trim();
  }

  /// Abre la carpeta de Google Drive en el navegador web o app oficial
  static Future<bool> openFolder() async {
    final uri = Uri.parse(folderUrl);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Copia el enlace oficial de la carpeta al portapapeles
  static Future<void> copyFolderUrl() async {
    await Clipboard.setData(const ClipboardData(text: folderUrl));
  }
}
