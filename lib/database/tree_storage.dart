import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:todotree/app/factory.dart';

import 'package:todotree/database/backup_manager.dart';
import 'package:todotree/database/local_storage.dart';
import 'package:todotree/database/saf_helper.dart';
import 'package:todotree/database/yaml_tree_deserializer.dart';
import 'package:todotree/database/yaml_tree_serializer.dart';
import 'package:todotree/node_model/tree_node.dart';
import 'package:todotree/services/info_service.dart';
import 'package:todotree/settings/settings_provider.dart';
import 'package:todotree/util/logger.dart';
import 'package:todotree/util/errors.dart';

class TreeStorage {
  BackupManager backupManager;
  SettingsProvider settingsProvider;

  TreeStorage(this.backupManager, this.settingsProvider);

  SafHelper safHelper = SafHelper();
  LocalStorage localStorage = LocalStorage.instance;

  Future<TreeNode> readDbTree({File? file}) async {
    final String content = await readDbString();
    if (content.isEmpty) {
      InfoService.info('No database file, initializing with a default tree.');
      return createDefaultRootNode();
    }
    final node = YamlTreeDeserializer().deserializeTree(content);
    return node;
  }

  Future<void> writeDbTree(TreeNode root) async {
    logger.debug('saving local database...');
    final String content = YamlTreeSerializer().serializeTree(root);
    await writeDbString(content);
    logger.info('local database saved');
    
    // Skip backups on web
    if (!localStorage.isWeb) {
      await backupManager.saveLocalBackup(await _localDbFile);
      saveExternalBackups(settingsProvider.externalBackupLocation, await _localDbFile, content).catchError((e) {
        if (e != null) {
          InfoService.error(e, 'Failed to save external backup');
        }
      });
    }
  }

  Future<void> saveExternalBackups(String locationString, File dbFile, String content) async {
    final backupLocations = splitLocationPaths(locationString);
    if (backupLocations.isNotEmpty) {
      final stopwatch = Stopwatch()..start();
      for (final backupLocation in backupLocations) {
        await backupManager.saveExternalBackup(dbFile, content, backupLocation, safHelper);
      }
      logger.debug('External backups saved in ${stopwatch.elapsed}');
    }
  }

  Future<String> get _localPath async {
    if (localStorage.isWeb) {
      return 'web';
    }
    final Directory directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  Future<File> get _localDbFile async {
    final String path = await _localPath;
    return File('$path/todo.yaml');
  }

  Future<String> readDbString() async {
    if (localStorage.isWeb) {
      return await localStorage.readFileContent('todo.yaml');
    }
    final file = await _localDbFile;
    return await _readDbString(file);
  }

  Future<void> writeDbString(String content) async {
    try {
      if (localStorage.isWeb) {
        await localStorage.writeFileContent('todo.yaml', content);
        return;
      }
      final file = await _localDbFile;
      await file.writeAsString(content, flush: true);
    } catch (e) {
      logger.error('Failed to write database: $e');
      rethrow;
    }
  }

  Future<String> _readDbString(File file) async {
    try {
      if (!file.existsSync()) {
        logger.warning('database file $file does not exist, loading default tree');
        return '';
      }
      logger.debug('reading local database from ${file.absolute.path}');
      return await file.readAsString();
    } catch (error, stack) {
      throw ContextError('Failed to read file', error, stackTrace: stack);
    }
  }

  Future<void> importDatabaseUi(AppFactory app) async {
    FilePickerResult? fpickResult = await FilePicker.pickFiles(
      dialogTitle: 'Import database file',
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml'],
    );
    if (fpickResult == null) {
      return logger.info('file picker canceled');
    }
    final path = fpickResult.files.single.path;
    if (path == null) {
      if (kIsWeb) {
        final bytes = fpickResult.files.single.bytes;
        if (bytes != null) {
          final content = String.fromCharCodes(bytes);
          await app.treeTraverser.loadFromString(content);
          app.browserController.renderAll();
          InfoService.info('Tree loaded from uploaded file');
          return;
        }
      }
      return logger.warning('no file path or bytes available');
    }
    File file = File(path);
    await app.treeTraverser.loadFromFile(file);
    app.browserController.renderAll();
    InfoService.info('Tree loaded from ${file.absolute.path}');
  }

  Future<String> grantBackupLocationUri(String locationsString) async {
    List<String> locations = splitLocationPaths(locationsString);

    final String? grantedUriStr = await safHelper.grantFolderAccess();
    if (grantedUriStr == null) {
      InfoService.info('Cancelled storage permission');
      return locationsString;
    }
    if (!locations.contains(grantedUriStr)){
      locations.add(grantedUriStr);
    }
    final newLocationString = locations.join(',\n');

    InfoService.info('Storage permission granted to: $grantedUriStr');
    return newLocationString;
  }

  List<String> splitLocationPaths(String locationString) {
    return locationString.split(RegExp(r'[\n,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
