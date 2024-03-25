import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../model/tree_node.dart';
import 'logger.dart';

class TreeStorage {

  Future<String> get _localPath async {
    final Directory directory = await getApplicationSupportDirectory();
    logger.debug('local directory: ${directory.absolute.path}');
    return directory.path;
  }

  Future<File> get localDbFile async {
    final String path = await _localPath;
    return File('$path/todo.yaml');
  }

  Future<File> writeDbString(String content) async {
    final file = await localDbFile;
    return file.writeAsString(content);
  }

  Future<String> readDbString() async {
    try {
      final file = await localDbFile;
      if (!file.existsSync()) {
        logger.warning('database file $file does not exist, loading empty');
        return '';
      }
      return await file.readAsString();
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }

  Future<TreeNode> readDbTree() async {
    final String content = await readDbString();
    final node = TreeNode.rootNode();
    sleep(Duration(seconds:1));
    node.add(TreeNode.textNode("dupa"));
    return node;
  }

  Future<void> writeDbTree(TreeNode root) async {
    final String content = '';
    await writeDbString(content);
    logger.debug('local database saved');
  }
}