import 'package:flutter/services.dart';

import 'package:todotree/services/info_service.dart';
import 'package:todotree/util/logger.dart';
import 'package:todotree/services/tree_traverser.dart';
import 'package:todotree/node_model/tree_node.dart';

class ClipboardManager {
  List<TreeNode> clipboardNodes = [];
  TreeNode? copiedFrom;
  bool markForCut = false;

  int get clipboardSize => clipboardNodes.length;
  bool get isClipboardEmpty => clipboardNodes.isEmpty;

  void clearClipboardNodes() {
    clipboardNodes.clear();
    copiedFrom = null;
    markForCut = false;
  }

  void addToClipboard(TreeNode node) {
    clipboardNodes.add(node);
  }

  void recopyClipboard() {
    final newClipboard = <TreeNode>[];
    for (var node in clipboardNodes) {
      newClipboard.add(node.clone());
    }
    clipboardNodes = newClipboard;
  }

  void copyToSystemClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  Future<String?> readSystemClipboard() async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    return clipData?.text;
  }

  void copySelectedItems(TreeTraverser treeTraverser) {
    if (!treeTraverser.selectionMode) {
      return InfoService.info('Nothing selected');
    }
    copyItems(treeTraverser, treeTraverser.selectedIndexes, info: true);
  }

  void copyItems(TreeTraverser treeTraverser, Set<int> itemPositions, {bool info = true, bool cut = false}) {
    if (itemPositions.isEmpty) {
      if (info) InfoService.info('Nothing selected');
      return;
    }
    clearClipboardNodes();
    final currentNode = treeTraverser.currentParent;
    copiedFrom = currentNode;
    markForCut = cut;
    for (var position in itemPositions.toList()..sort()) {
      final childNode = currentNode.getChild(position);
      addToClipboard(childNode);
    }

    if (!cut) {
      final copiedText = clipboardNodes.map((e) => e.displayName).join('\n');
      copyToSystemClipboard(copiedText);
    }

    if (info) {
      if (clipboardNodes.length == 1) {
        final item = clipboardNodes.first;
        InfoService.info('Item copied: ${item.displayName}', truncate: true);
      } else {
        InfoService.info('Items copied: ${clipboardNodes.length}');
      }
    }

    if (treeTraverser.selectionMode) {
      treeTraverser.cancelSelection();
    }
  }

  void cutSelectedItems(TreeTraverser treeTraverser) {
    if (!treeTraverser.selectionMode) {
      return InfoService.info('Nothing selected');
    }
    cutItems(treeTraverser, treeTraverser.selectedIndexes);
  }

  void cutItems(TreeTraverser treeTraverser, Set<int> itemPositions) {
    if (itemPositions.isEmpty) return;
    copyItems(treeTraverser, itemPositions, info: false, cut: true);
    InfoService.info('Marked for cut: ${itemPositions.length}');
  }

  Future<void> pasteItems(TreeTraverser treeTraverser, int atPosition) async {
    var position = atPosition;
    if (clipboardNodes.isEmpty) {
      // recover by taking text from system clipboard
      final systemClipboard = await readSystemClipboard();
      if (systemClipboard == null) {
        return InfoService.info('Clipboard is empty');
      }
      treeTraverser.addChildToCurrent(TreeNode.textNode(systemClipboard), position: position);
      InfoService.info('Pasted from system clipboard: $systemClipboard', truncate: true);
      return;
    }
    if (markForCut) {
      for (var clipboardNode in clipboardNodes) {
        final newItem = clipboardNode.clone();
        newItem.parent = treeTraverser.currentParent;
        treeTraverser.addChildToCurrent(newItem, position: position);
        position++;
      }
      for (var clipboardNode in clipboardNodes) {
        final oldParent = clipboardNode.parent;
        if (oldParent == null) {
          logger.warning('item $clipboardNode doesn\'t have a parent');
          continue;
        }
        treeTraverser.removeFromParent(clipboardNode, oldParent);
      }
      InfoService.info('Items moved: ${clipboardNodes.length}');
      markForCut = false;
      clearClipboardNodes();
    } else {
      for (var clipboardNode in clipboardNodes) {
        final newItem = clipboardNode.clone();
        newItem.parent = treeTraverser.currentParent;
        treeTraverser.addChildToCurrent(newItem, position: position);
        position++;
      }
      InfoService.info('Items pasted: ${clipboardNodes.length}');
      recopyClipboard();
    }
  }

  void copyAsText(String text) {
    copyToSystemClipboard(text);
    clearClipboardNodes();
    InfoService.info('Copied to clipboard: $text', truncate: true);
  }

  TreeNode buildLinkItem(TreeNode targetNode) {
    if (targetNode.isLink) {
      var clone = targetNode.clone(); // shorten link to a link
      clone.parent = null;
      return clone;
    }
    final link = TreeNode.linkNode('');
    link.setLinkTarget(targetNode);
    return link;
  }

  void pasteItemsAsLink(TreeTraverser treeTraverser, int atPosition) {
    var position = atPosition;
    if (clipboardNodes.isEmpty) {
      return InfoService.info('Clipboard is empty');
    }
    for (var clipboardNode in clipboardNodes) {
      final linkItem = buildLinkItem(clipboardNode);
      treeTraverser.addChildToCurrent(linkItem, position: position);
      position++;
    }
    markForCut = false;
    InfoService.info('Items pasted as links: ${clipboardNodes.length}');
  }
}
