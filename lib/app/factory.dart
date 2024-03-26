import 'package:todotree/views/editor/editor_controller.dart';
import 'package:todotree/services/clipboard_manager.dart';
import 'package:todotree/services/lifecycle.dart';
import 'package:todotree/services/logger.dart';
import 'package:todotree/services/main_menu_runner.dart';
import 'package:todotree/services/tree_storage.dart';
import 'package:todotree/services/tree_traverser.dart';
import 'package:todotree/services/yaml_tree_deserializer.dart';
import 'package:todotree/services/yaml_tree_serializer.dart';
import 'package:todotree/views/home/home_state.dart';
import 'package:todotree/views/tree_browser/browser_controller.dart';
import 'package:todotree/views/tree_browser/browser_state.dart';
import 'package:todotree/views/home/home_controller.dart';
import 'package:todotree/views/editor/editor_state.dart';

class AppFactory {
  late final HomeState homeState;
  late final BrowserState browserState;
  late final EditorState editorState;

  late final HomeController homeController;
  late final BrowserController browserController;
  late final EditorController editorController;

  late final TreeTraverser treeTraverser;
  late final YamlTreeSerializer yamlTreeSerializer;
  late final YamlTreeDeserializer yamlTreeDeserializer;
  late final TreeStorage treeStorage;
  late final AppLifecycle appLifecycle;
  late final ClipboardManager clipboardManager;
  late final MainMenuRunner mainMenuRunner;

  AppFactory() {
    homeState = HomeState();
    browserState = BrowserState();
    editorState = EditorState();
    yamlTreeSerializer = YamlTreeSerializer();
    yamlTreeDeserializer = YamlTreeDeserializer();
    treeStorage = TreeStorage();
    clipboardManager = ClipboardManager();
    treeTraverser = TreeTraverser(treeStorage);
    appLifecycle = AppLifecycle(treeStorage, treeTraverser);
    browserController = BrowserController(homeState, browserState, editorState, treeTraverser, clipboardManager);
    editorController = EditorController(homeState, editorState, treeTraverser);
    browserController.editorController = editorController;
    editorController.browserController = browserController;
    homeController = HomeController(homeState, treeTraverser, browserController, editorController);
    mainMenuRunner = MainMenuRunner(browserController, treeTraverser);
    logger.debug('AppFactory created');
  }
}
