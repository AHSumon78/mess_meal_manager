// lib/services/drive_service.dart
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'auth_client.dart';

class DriveService {
  final _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ], // Use driveFileScope for broader access
  );

  Future<GoogleSignInAccount?> signIn() async {
    return await _googleSignIn.signIn();
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    return await _googleSignIn.signInSilently();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<void> backupDatabase(File dbFile, Function(String) onProgress) async {
    final account = await _googleSignIn.currentUser;
    if (account == null) {
      onProgress('Sign-in required to backup.');
      return;
    }

    onProgress('Authenticating...');
    final authClient = await AuthClient.fromGoogleSignInAccount(account);
    final driveApi = drive.DriveApi(authClient);
    final appDataFolderId = await _getOrCreateAppFolderId(driveApi);

    if (appDataFolderId == null) {
      onProgress('Could not create or find app folder.');
      return;
    }

    onProgress('Uploading backup...');
    final fileName = 'meal_manager_backup.db';

    // Check if a backup file already exists
    final existingFiles = await driveApi.files.list(
      q: "name='$fileName' and '$appDataFolderId' in parents and trashed = false",
      $fields: "files(id)",
    );

    var fileMetadata = drive.File()..name = fileName;
    final media = drive.Media(dbFile.openRead(), await dbFile.length());

    if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
      // Update the existing file
      final fileId = existingFiles.files!.first.id!;
      await driveApi.files.update(fileMetadata, fileId, uploadMedia: media);
      onProgress('Backup updated successfully!');
    } else {
      // Create a new file in the app folder
      fileMetadata.parents = [appDataFolderId];
      await driveApi.files.create(fileMetadata, uploadMedia: media);
      onProgress('Backup created successfully!');
    }
  }

  Future<File?> restoreDatabase(
    String dbPath,
    Function(String) onProgress,
  ) async {
    final account = await _googleSignIn.currentUser;
    if (account == null) {
      onProgress('Sign-in required to restore.');
      return null;
    }

    onProgress('Authenticating...');
    final authClient = await AuthClient.fromGoogleSignInAccount(account);
    final driveApi = drive.DriveApi(authClient);
    final appDataFolderId = await _getOrCreateAppFolderId(driveApi);

    onProgress('Searching for backup file...');
    final fileName = 'meal_manager_backup.db';
    final fileList = await driveApi.files.list(
      q: "name='$fileName' and '$appDataFolderId' in parents and trashed = false",
      $fields: 'files(id, name)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      onProgress('No backup file found.');
      return null;
    }

    final fileId = fileList.files!.first.id!;
    onProgress('Downloading backup...');
    final media =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final dbFile = File(dbPath);
    await dbFile.create(recursive: true);

    final fileStream = dbFile.openWrite();
    await media.stream.pipe(fileStream);

    onProgress('Database restored! Please restart the app.');
    return dbFile;
  }

  // This function finds or creates a dedicated folder for the app in Google Drive
  Future<String?> _getOrCreateAppFolderId(drive.DriveApi driveApi) async {
    const folderName = 'MessMealManagerApp';
    final search = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed = false",
      $fields: "files(id)",
    );

    if (search.files != null && search.files!.isNotEmpty) {
      return search.files!.first.id;
    } else {
      final folderMeta = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final folder = await driveApi.files.create(folderMeta);
      return folder.id;
    }
  }
}
