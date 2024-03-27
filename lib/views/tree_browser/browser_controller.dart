import 'package:collection/collection.dart';
import 'package:todotree/services/clipboard_manager.dart';
import 'package:todotree/services/error_handler.dart';
import 'package:todotree/services/info_service.dart';
import 'package:todotree/services/logger.dart';
import 'package:todotree/util/collections.dart';
import 'package:todotree/views/editor/editor_controller.dart';
import 'package:todotree/views/editor/editor_state.dart';
import 'package:todotree/services/tree_traverser.dart';
import 'package:todotree/model/tree_node.dart';
import 'package:todotree/util/strings.dart';
import 'package:todotree/views/home/home_state.dart';
import 'package:todotree/views/tree_browser/browser_state.dart';

class BrowserController {
  HomeState homeState;
  BrowserState browserState;
  EditorState editorState;

  late EditorController editorController;

  TreeTraverser treeTraverser;
  ClipboardManager clipboardManager;
  Map<TreeNode, double> scrollCache = {};

  BrowserController(this.homeState, this.browserState, this.editorState,
      this.treeTraverser, this.clipboardManager);

  void init() {
    renderAll();
  }

  void renderAll() {
    renderItems();
    renderTitle();
  }

  void renderTitle() {
    browserState.title = treeTraverser.currentParent.name;
    browserState.notify();
  }

  void renderItems() {
    browserState.items = treeTraverser.currentParent.children.toList();
    browserState.selectedIndexes = treeTraverser.selectedIndexes.toSet();
    browserState.notify();
  }

  void populateItems() {
    for (int i = 0; i < 10; i++) {
      final name = '$i. ${randomName()}';
      treeTraverser.addChildToCurrent(TreeNode.textNode(name));
    }
    renderItems();
  }

  void editNode(TreeNode node) {
    ensureNoSelectionMode();
    editorState.newItemPosition = null;
    editorState.editedNode = node;
    editorState.editTextController.text = node.name;
    editorState.notify();
    homeState.pageView = HomePageView.itemEditor;
    homeState.notify();
  }

  bool goBack() {
    ensureNoSelectionMode();
    try {
      treeTraverser.goBack();
      restoreScrollOffset();
      renderAll();
      return true;
    } on NoSuperItemException {
      return false; // Can't go any higher
    }
  }

  bool goStepUp() {
    ensureNoSelectionMode();
    try {
      treeTraverser.goUp();
      restoreScrollOffset();
      renderAll();
      return true;
    } on NoSuperItemException {
      return false;
    }
  }

  void restoreScrollOffset() {
    if (scrollCache.containsKey(treeTraverser.currentParent)) {
      browserState.scrollController
          .jumpTo(scrollCache[treeTraverser.currentParent]!);
      scrollCache.remove(treeTraverser.currentParent);
    }
  }

  void goIntoNode(TreeNode node) {
    rememberScrollOffset();
    ensureNoSelectionMode();
    if (node.type == TreeNodeType.link) {
      treeTraverser.goToLinkTarget(node);
    } else {
      treeTraverser.goTo(node);
    }
    renderAll();
  }

  void ensureNoSelectionMode() {
    if (treeTraverser.selectionMode) {
      treeTraverser.cancelSelection();
      renderItems();
    }
  }

  void addNodeAt(int position) {
    ensureNoSelectionMode();
    if (position < 0) position = treeTraverser.currentParent.size; // last
    if (position > treeTraverser.currentParent.size) {
      position = treeTraverser.currentParent.size;
    }
    editorState.newItemPosition = position;
    editorState.editedNode = null;
    editorState.editTextController.text = '';
    editorState.notify();
    homeState.pageView = HomePageView.itemEditor;
    homeState.notify();
  }

  void addNodeToTheEnd() {
    addNodeAt(treeTraverser.currentParent.size);
  }

  void reorderNodes(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final newList = treeTraverser.currentParent.children.toList();
    if (newIndex >= newList.length) newIndex = newList.length - 1;
    if (newIndex == oldIndex) return;
    if (newIndex < oldIndex) {
      final node = newList.removeAt(oldIndex);
      newList.insert(newIndex, node);
    } else {
      final node = newList.removeAt(oldIndex);
      newList.insert(newIndex, node);
    }
    treeTraverser.currentParent.children = newList;
    treeTraverser.unsavedChanges = true;
    renderItems();
    logger.debug('Reordered nodes: $oldIndex -> $newIndex');
  }

  void removeNode(TreeNode node) {
    treeTraverser.removeFromCurrent(node);
    renderItems();
    InfoService.info('Node removed: ${node.name}');
  }

  void removeNodesAt(int position) {
    if (treeTraverser.selectionMode) {
      List<int> sortedPositions = treeTraverser.selectedIndexes.toList()
        ..sort();
      List<Pair<int, TreeNode>> originalNodePositions = sortedPositions
          .map((index) => Pair(index, treeTraverser.getChild(index)))
          .toList();
      for (final pair in originalNodePositions) {
        treeTraverser.removeFromCurrent(pair.second);
      }
      treeTraverser.cancelSelection();
      renderItems();
      InfoService.snackbarAction('Nodes removed: ${sortedPositions.length}', 'UNDO',
          () {
        for (final pair in originalNodePositions) {
          treeTraverser.addChildToCurrent(pair.second, position: pair.first);
        }
        renderItems();
        InfoService.info('Nodes restored: ${originalNodePositions.length}');
      });
    } else {
      final node = treeTraverser.getChild(position);
      removeNode(node);
    }
  }

  void removeLinkAndTarget(TreeNode node) {
    treeTraverser.removeLinkAndTarget(node);
    renderItems();
    InfoService.info('Link & target removed: ${node.name}');
  }

  void runNodeMenuAction(String action, {TreeNode? node, int? position}) {
    handleError(() {
      if (action == 'remove-nodes' && position != null) {
        removeNodesAt(position);
      } else if (action == 'edit-node' && node != null) {
        editNode(node);
      } else if (action == 'add-above' && position != null) {
        addNodeAt(position);
      } else if (action == 'select-node' && position != null) {
        selectNodeAt(position);
      } else if (action == 'select-all') {
        selectAll();
      } else if (action == 'remove-remote-node' && node != null) {
      } else if (action == 'remove-link-and-target' && node != null) {
        removeLinkAndTarget(node);
      } else if (action == 'add-above' && position != null) {
        addNodeAt(position);
      } else if (action == 'cut' && position != null) {
        cutItemsAt(position);
      } else if (action == 'copy' && position != null) {
        copyItemsAt(position);
      } else if (action == 'paste-above' && position != null) {
        pasteAbove(position);
      } else if (action == 'paste-as-link' && position != null) {
        pasteAboveAsLink(position);
      } else if (action == 'split' && node != null) {
        InfoService.error('Not implemented yet');
      } else if (action == 'push-to-remote' && node != null) {
      } else {
        logger.error('Unknown action: $action');
      }
    });
  }

  Future<void> saveAndExit() async {
    treeTraverser.goToRoot();
    renderAll();
    await treeTraverser.saveAndExit();
  }

  void onToggleSelectedNode(int position) {
    treeTraverser.toggleItemSelected(position);
    renderItems();
  }

  void selectAll() {
    treeTraverser.selectAll();
    renderItems();
  }

  void selectNodeAt(int position) {
    treeTraverser.setItemSelected(position, true);
    renderItems();
  }

  void cutItemsAt(int position) {
    final positions = treeTraverser.selectedIndexes.toSet();
    if (positions.isEmpty) {
      positions.add(position); // if nothing selected - include current item
    }
    clipboardManager.cutItems(treeTraverser, positions);
    renderItems();
  }

  void copyItemsAt(int position) {
    final positions = treeTraverser.selectedIndexes.toSet();
    if (positions.isEmpty) {
      positions.add(position); // if nothing selected - include current item
    }
    clipboardManager.copyItems(treeTraverser, positions, info: true);
    renderItems();
  }

  void pasteAbove(int position) async {
    handleError(() async {
      await clipboardManager.pasteItems(treeTraverser, position);
      renderItems();
    });
  }

  void pasteAboveAsLink(int position) {
    clipboardManager.pasteItemsAsLink(treeTraverser, position);
    renderItems();
  }

  void handleNodeTap(TreeNode node, int index) {
    if (treeTraverser.selectionMode) {
      onToggleSelectedNode(index);
    } else if (node.isLink) {
      goIntoNode(node);
    } else if (node.isLeaf) {
      editNode(node);
    } else {
      goIntoNode(node);
    }
  }

  void rememberScrollOffset() {
    scrollCache[treeTraverser.currentParent] =
        browserState.scrollController.offset;
  }
}
