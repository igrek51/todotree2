import 'package:todotree/node_model/tree_node.dart';
import 'package:todotree/services/info_service.dart';
import 'package:todotree/util/collections.dart';
import 'package:todotree/tree_browser/browser_controller.dart';

class NodeTrash {
  List<Pair<int, TreeNode>> trashedNodes = [];
  TreeNode parent = cRootNode;
  TreeNode? linkTarget;
  int? originalTargetPosition;
  TreeNode? linkTargetParent;

  NodeTrash();

  void emptyBin({TreeNode? parent}) {
    trashedNodes.clear();
    this.parent = parent ?? cRootNode;
    linkTarget = null;
    originalTargetPosition = null;
    linkTargetParent = null;
  }

  void putToTrash(TreeNode node, int position, TreeNode parent) {
    trashedNodes.clear();
    trashedNodes.add(Pair(position, node));
    this.parent = parent;
  }

  void putLinkAndTarget(TreeNode link, int linkPosition, TreeNode linkParent, TreeNode? linkTarget,
      int? originalTargetPosition, TreeNode? linkTargetParent) {
    trashedNodes.clear();
    trashedNodes.add(Pair(linkPosition, link));
    parent = linkParent;
    this.linkTarget = linkTarget;
    this.originalTargetPosition = originalTargetPosition;
    this.linkTargetParent = linkTargetParent;
  }

  void addToTrash(TreeNode node, int position) {
    trashedNodes.add(Pair(position, node));
  }

  bool isNotEmpty() {
    return trashedNodes.isNotEmpty || linkTarget != null;
  }

  void restore(BrowserController browserController) {
    if (!isNotEmpty()) {
      return InfoService.info('Nothing to restore from trash bin');
    }

    if (linkTarget != null) {
      // restore link
      for (final pair in trashedNodes) {
        browserController.treeTraverser.addChildToNode(parent, pair.second, position: pair.first);
      }
      // restore target
      final nnlinkTarget = linkTarget;
      final nnoriginalTargetPosition = originalTargetPosition;
      final nnlinkTargetParent = linkTargetParent;
      if (nnlinkTarget != null && nnlinkTargetParent != null && nnoriginalTargetPosition != null) {
        nnlinkTargetParent.insertAt(nnoriginalTargetPosition, nnlinkTarget);
      }
      browserController.remoteService.checkUnsavedRemoteChanges();
      InfoService.info('Link & target restored: ${trashedNodes.first.second.name}', truncate: true);
    } else if (trashedNodes.length == 1) {
      final pair = trashedNodes.first;
      final originalPosition = pair.first;
      final node = pair.second;
      browserController.treeTraverser.addChildToNode(parent, node, position: originalPosition);
      browserController.remoteService.checkUnsavedRemoteChanges();
      InfoService.info('Node restored: ${node.name}', truncate: true);
    } else {
      for (final pair in trashedNodes) {
        browserController.treeTraverser.addChildToNode(parent, pair.second, position: pair.first);
      }
      browserController.remoteService.checkUnsavedRemoteChanges();
      InfoService.info('Nodes restored: ${trashedNodes.length}');
    }

    emptyBin();
  }
}
