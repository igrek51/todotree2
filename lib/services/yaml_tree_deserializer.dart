import 'package:yaml/yaml.dart';

import '../model/tree_node.dart';

class YamlTreeDeserializer {

  TreeNode deserializeTree(String data) {
    final YamlMap yamlDoc = loadYaml(data) as YamlMap;
    // throw Exception('Root node is not a map');
    return mapNodeToTreeItem(yamlDoc);
  }

  TreeNode mapNodeToTreeItem(YamlMap node) {
    final type = node['type'] as String? ?? 'text';

    TreeNode treeItem;
    switch (type) {
      case '/':
        treeItem = TreeNode.rootNode();
      case 'text':
        final name = node['name'] as String;
        treeItem = TreeNode.textNode(name);
      case 'remote':
        final name = node['name'] as String;
        treeItem = TreeNode.textNode(name);
      case 'link':
        final name = node['name'] as String? ?? '';
        final target = node['target'] as String;
        treeItem = TreeNode.linkNode(target, name);
      default:
        throw Exception('Unknown item type: $type');
    }

    if (node['items'] != null) {
      final List<YamlMap> items = node['items'] as List<YamlMap>;
      for (var child in items) {
        treeItem.add(mapNodeToTreeItem(child));
      }
    }
    return treeItem;
  }
}
