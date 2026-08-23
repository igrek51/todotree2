import 'dart:math';

import 'package:flutter/material.dart';

import 'package:todotree/node_model/tree_node.dart';
import 'package:todotree/services/clipboard_manager.dart';
import 'package:todotree/services/info_service.dart';
import 'package:todotree/services/remote_service.dart';
import 'package:todotree/util/numbers.dart';
import 'package:todotree/components/confirmation_dialog.dart';
import 'package:todotree/editor/editor_state.dart';
import 'package:todotree/services/tree_traverser.dart';
import 'package:todotree/home/home_state.dart';
import 'package:todotree/tree_browser/browser_controller.dart';

class EditorController {
  HomeState homeState;
  EditorState editorState;

  late BrowserController browserController;

  ClipboardManager clipboardManager;
  TreeTraverser treeTraverser;
  RemoteService remoteService;

  EditorController(this.homeState, this.editorState, this.treeTraverser, this.clipboardManager, this.remoteService);

  void addNodeAt(int position) {
    position = position.clampMax(treeTraverser.currentParent.size);
    editorState.newItemPosition = position;
    editorState.editedNode = null;
    editorState.numericKeyboard = false;
    editorState.editTextController.text = '';
    homeState.pageView = HomePageView.itemEditor;
    editorState.notify();
    homeState.notify();
    Future.microtask(() {
      editorState.textEditFocus.requestFocus();
    });
  }

  void editNode(TreeNode node) {
    editorState.newItemPosition = null;
    editorState.editedNode = node;
    editorState.numericKeyboard = false;
    editorState.editTextController.text = node.name;
    homeState.pageView = HomePageView.itemEditor;
    editorState.notify();
    homeState.notify();
    Future.microtask(() {
      editorState.textEditFocus.requestFocus();
    });
  }

  void saveNode() {
    if (editorState.editedNode != null) {
      saveEditedNode();
    } else if (editorState.newItemPosition != null) {
      saveNewNode();
    }
    treeTraverser.unsavedChanges = true;
    remoteService.checkUnsavedRemoteChanges();
  }

  void saveEditedNode() {
    final newName = editorState.editTextController.text.trim();
    if (editorState.editedNode == null) return;
    if (newName.isEmpty) {
      browserController.removeOneNode(editorState.editedNode!);
      cancelEdit();
      return InfoService.info('Blank node has been deleted.');
    }
    editorState.editedNode?.name = newName;
    treeTraverser.focusNode = editorState.editedNode;
    browserController.renderItems();
    homeState.pageView = HomePageView.treeBrowser;
    homeState.notify();
    editorState.editTextController.clear();
    editorState.notify();
    browserController.restoreScrollOffset();
    InfoService.info('Saved: $newName', truncate: true);
  }

  void saveNewNode() {
    final newName = editorState.editTextController.text.trim();
    if (newName.isEmpty) {
      cancelEdit();
      return InfoService.info('Blank node has been dropped.');
    }
    final newNode = TreeNode.textNode(newName);
    treeTraverser.addChildToCurrent(newNode, position: editorState.newItemPosition);
    browserController.renderItems();
    homeState.pageView = HomePageView.treeBrowser;
    homeState.notify();
    editorState.editTextController.clear();
    editorState.notify();
    browserController.restoreScrollOffset();
    InfoService.info('Added: $newName', truncate: true);
  }

  void saveAndAddNext() {
    final newName = editorState.editTextController.text.trim();
    if (newName.isEmpty) {
      editorState.editTextController.clear();
      editorState.textEditFocus.requestFocus();
      editorState.notify();
      return InfoService.info('Can\'t save a blank node');
    }

    int nextPosition = 0;
    if (editorState.editedNode != null) {
      editorState.editedNode?.name = newName;
      treeTraverser.focusNode = editorState.editedNode;
      nextPosition = (treeTraverser.getChildIndex(editorState.editedNode!) ?? 0) + 1;
      InfoService.info('Saved: $newName', truncate: true);
    } else if (editorState.newItemPosition != null) {
      final newNode = TreeNode.textNode(newName);
      treeTraverser.addChildToCurrent(newNode, position: editorState.newItemPosition);
      nextPosition = (editorState.newItemPosition ?? 0) + 1;
      browserController.renderAll();
      InfoService.info('Added: $newName', truncate: true);
    }

    editorState.newItemPosition = nextPosition;
    editorState.editedNode = null;
    editorState.editTextController.clear();
    editorState.textEditFocus.requestFocus();
    editorState.notify();
    remoteService.checkUnsavedRemoteChanges();
  }

  void saveAndEnter() {
    final newName = editorState.editTextController.text.trim();
    if (newName.isEmpty) {
      editorState.editTextController.clear();
      editorState.textEditFocus.requestFocus();
      editorState.notify();
      return InfoService.info('Can\'t save a blank node');
    }

    TreeNode? newParent;
    if (editorState.editedNode != null) {
      editorState.editedNode?.name = newName;
      treeTraverser.focusNode = editorState.editedNode;
      newParent = editorState.editedNode;
      InfoService.info('Saved: $newName', truncate: true);
    } else if (editorState.newItemPosition != null) {
      final newNode = TreeNode.textNode(newName);
      treeTraverser.addChildToCurrent(newNode, position: editorState.newItemPosition);
      newParent = newNode;
      InfoService.info('Added: $newName', truncate: true);
    }

    if (newParent != null) {
      treeTraverser.goTo(newParent);
      browserController.renderAll();
    }
    editorState.newItemPosition = 0;
    editorState.editedNode = null;
    editorState.editTextController.clear();
    editorState.textEditFocus.requestFocus();
    editorState.notify();
    remoteService.checkUnsavedRemoteChanges();
  }

  void cancelEdit() {
    if (hasUnsavedChanges()) {
      InfoService.info('Changes discarded');
    }
    treeTraverser.focusNode = editorState.editedNode;
    browserController.renderItems();
    homeState.pageView = HomePageView.treeBrowser;
    homeState.notify();
    editorState.editTextController.clear();
    editorState.notify();
    browserController.restoreScrollOffset();
  }

  Future<void> quitEditor() async {
    if (hasUnsavedChanges()) {
      int result = await ConfirmationDialog.ask(
        title: 'Unsaved changes',
        content: 'You have unsaved changes, would you like to save them?',
        confirmActionLabel: 'Save',
        altActionLabel: 'Discard',
      );
      switch (result) {
        case 1:
          saveNode();
        case 2:
          cancelEdit();
        default:
          return;
      }
    } else {
      cancelEdit();
    }
  }

  bool hasUnsavedChanges() {
    final content = editorState.editTextController.text;
    if (editorState.editedNode != null) {
      return editorState.editedNode?.name != content;
    } else {
      return content.isNotEmpty;
    }
  }

  int get minSelection =>
      min(editorState.editTextController.selection.baseOffset, editorState.editTextController.selection.extentOffset);
  int get maxSelection =>
      max(editorState.editTextController.selection.baseOffset, editorState.editTextController.selection.extentOffset);

  void jumpCursorToStart() {
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: 0),
    );
    Future.microtask(() {
      editorState.textEditFocus.requestFocus();
    });
  }

  void jumpCursorToEnd() {
    if (maxSelection == editorState.editTextController.text.length &&
        minSelection == maxSelection &&
        maxSelection > 0) {
      // move forcefully, if already at the end
      editorState.editTextController.selection = TextSelection.fromPosition(
        TextPosition(offset: editorState.editTextController.text.length - 1),
      );
    }
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: editorState.editTextController.text.length),
    );
    Future.microtask(() {
      editorState.textEditFocus.requestFocus();
    });
  }

  void moveCursorLeft() {
    final newPos = (minSelection - 1).clampMin(0);
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: newPos),
    );
    Future.microtask(() {
      editorState.textEditFocus.requestFocus();
    });
  }

  void moveCursorRight() {
    final newPos = (maxSelection + 1).clampMax(editorState.editTextController.text.length);
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: newPos),
    );
    Future.microtask(() {
      editorState.textEditFocus.requestFocus();
    });
  }

  void selectAll() {
    var len = editorState.editTextController.text.length;
    if (minSelection == 0 && maxSelection == len) {
      // already selected all
      editorState.editTextController.selection = TextSelection.fromPosition(
        TextPosition(offset: editorState.editTextController.text.length),
      );
    } else {
      editorState.editTextController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: len,
      );
    }
    Future.microtask(() {
      editorState.textEditFocus.requestFocus();
    });
  }

  void copyToClipboard() {
    if (minSelection == maxSelection) {
      return InfoService.info('No selection to copy.');
    }
    final selectedText = editorState.editTextController.text.substring(minSelection, maxSelection);
    clipboardManager.copyAsText(selectedText);
  }

  Future<void> pasteFromClipboard() async {
    final clipboardText = await clipboardManager.readSystemClipboard();
    if (clipboardText == null) {
      return InfoService.info('Clipboard is empty.');
    }
    final textBefore = editorState.editTextController.text.substring(0, minSelection);
    final textAfter = editorState.editTextController.text.substring(maxSelection);
    final finalText = textBefore + clipboardText + textAfter;
    editorState.editTextController.text = finalText;
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: textBefore.length + clipboardText.length),
    );
    editorState.textEditFocus.requestFocus();
    InfoService.info('Clipboard pasted.');
  }

  void keyBackspace() {
    final textBefore = editorState.editTextController.text.substring(0, minSelection);
    final textAfter = editorState.editTextController.text.substring(maxSelection);
    String finalText;
    if (minSelection == maxSelection) {
      finalText = textBefore.substring(0, (minSelection - 1).clampMin(0)) + textAfter;
    } else {
      finalText = textBefore + textAfter;
    }
    editorState.editTextController.text = finalText;
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: finalText.length - textAfter.length),
    );
    editorState.textEditFocus.requestFocus();
  }

  void keyDelete() {
    final textBefore = editorState.editTextController.text.substring(0, minSelection);
    final textAfter = editorState.editTextController.text.substring(maxSelection);
    String finalText;
    if (minSelection == maxSelection && textAfter.isNotEmpty) {
      finalText = textBefore + textAfter.substring(1);
    } else {
      finalText = textBefore + textAfter;
    }
    editorState.editTextController.text = finalText;
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: textBefore.length),
    );
    editorState.textEditFocus.requestFocus();
  }

  void toggleNumericKeyboard(BuildContext context) {
    editorState.textEditFocus.unfocus();
    editorState.numericKeyboard = !editorState.numericKeyboard;
    editorState.notify();
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(editorState.textEditFocus);
      editorState.notify();
    });
  }

  void disableNumericKeyboard() {
    editorState.textEditFocus.unfocus();
    editorState.numericKeyboard = false;
    editorState.notify();
    Future.delayed(const Duration(milliseconds: 100), () {
      editorState.textEditFocus.requestFocus();
      editorState.notify();
    });
  }

  void insertDash() {
    final textBefore = editorState.editTextController.text.substring(0, minSelection);
    final textAfter = editorState.editTextController.text.substring(maxSelection);
    var appendText = '-';
    if (!textBefore.endsWith(' ')) appendText = ' $appendText';
    if (!textAfter.startsWith(' ')) appendText = '$appendText ';
    editorState.editTextController.text = textBefore + appendText + textAfter;
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: textBefore.length + appendText.length),
    );
    editorState.textEditFocus.requestFocus();
  }

  void insertColon() {
    var textBefore = editorState.editTextController.text.substring(0, minSelection);
    final textAfter = editorState.editTextController.text.substring(maxSelection);
    var appendText = ':';
    if (!editorState.numericKeyboard) {
      if (textBefore.endsWith(' ')) textBefore = textBefore.substring(0, textBefore.length - 1);
      if (!textAfter.startsWith(' ')) appendText = '$appendText ';
    }
    editorState.editTextController.text = textBefore + appendText + textAfter;
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: textBefore.length + appendText.length),
    );
    editorState.textEditFocus.requestFocus();
  }

  void insertDot() {
    final textBefore = editorState.editTextController.text.substring(0, minSelection);
    final textAfter = editorState.editTextController.text.substring(maxSelection);
    var appendText = '.';
    editorState.editTextController.text = textBefore + appendText + textAfter;
    editorState.editTextController.selection = TextSelection.fromPosition(
      TextPosition(offset: textBefore.length + appendText.length),
    );
    editorState.textEditFocus.requestFocus();
  }

  void concludeNumericInput() {
    disableNumericKeyboard();
  }
}
