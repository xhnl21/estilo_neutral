import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/shared/google_drive/google_drive_helper.dart';

void main() {
  group('GoogleDriveHelper Tests', () {
    const expectedFolderId = '1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD';

    test('Folder ID and URL match user specified Google Drive folder', () {
      expect(GoogleDriveHelper.folderId, expectedFolderId);
      expect(
        GoogleDriveHelper.folderUrl,
        'https://drive.google.com/drive/folders/$expectedFolderId?usp=sharing',
      );
    });

    test('extractFileId parses various Google Drive URL formats and direct IDs', () {
      // Direct ID
      expect(GoogleDriveHelper.extractFileId('1A2b3C4d5E6f7G'), '1A2b3C4d5E6f7G');

      // Sharing URL (/d/{ID}/view)
      expect(
        GoogleDriveHelper.extractFileId('https://drive.google.com/file/d/1A2b3C4d5E6f7G/view?usp=sharing'),
        '1A2b3C4d5E6f7G',
      );

      // Open URL (?id={ID})
      expect(
        GoogleDriveHelper.extractFileId('https://drive.google.com/open?id=1A2b3C4d5E6f7G'),
        '1A2b3C4d5E6f7G',
      );

      // Empty string
      expect(GoogleDriveHelper.extractFileId('   '), isNull);
    });

    test('formatDirectImageUrl formats directly accessible image URL for Flutter and Sheets', () {
      const fileId = '1A2b3C4d5E6f7G';
      final formattedFromUrl = GoogleDriveHelper.formatDirectImageUrl(
        'https://drive.google.com/file/d/$fileId/view?usp=sharing',
      );
      expect(formattedFromUrl, 'https://lh3.googleusercontent.com/d/$fileId');

      final formattedFromId = GoogleDriveHelper.formatDirectImageUrl(fileId);
      expect(formattedFromId, 'https://lh3.googleusercontent.com/d/$fileId');

      // Standard non-drive image URL remains unaltered
      expect(
        GoogleDriveHelper.formatDirectImageUrl('https://images.unsplash.com/photo-12345'),
        'https://images.unsplash.com/photo-12345',
      );
    });
  });
}
