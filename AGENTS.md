# AI Agent Guide for ToDo Tree

Welcome, AI Agent! This guide will help you understand the architecture and conventions of the ToDo Tree project.

## Project Overview
ToDo Tree is a Flutter application for managing tasks in a nested, unlimited tree structure. It supports Android, iOS, Linux, and Web.

## Core Architecture
The project uses a custom dependency injection pattern and the `provider` package for state management.

### Dependency Injection
- **`lib/app/factory.dart`**: The central `AppFactory` creates and wires up all major services and controllers. It acts as a singleton container.
- Most components receive their dependencies through constructors.

### Data Model
- **`lib/node_model/tree_node.dart`**: The core data structure. A `TreeNode` can be a text node, a link to another node, or a remote node.
- The tree is recursive: each `TreeNode` has a list of `children`.

### State & Logic
- **`lib/services/tree_traverser.dart`**: Manages the in-memory tree, the current navigation path, and selection state.
- **`lib/tree_browser/browser_controller.dart`**: Handles user interactions in the main tree view.
- **`lib/editor/editor_controller.dart`**: Handles node content editing.
- **`State` classes** (e.g., `BrowserState`, `HomeState`): `ChangeNotifier` objects that hold UI-related state and notify listeners.

### Persistence
- The tree is saved as a YAML document (`todo.yaml`).
- **`lib/database/tree_storage.dart`**: Manages reading/writing the tree to the local filesystem or IndexedDB (on Web).
- **`lib/database/yaml_tree_serializer.dart`** and **`yaml_tree_deserializer.dart`**: Handle conversion between `TreeNode` objects and YAML strings.

## Platform Support
- **Native**: Uses standard file I/O for storage.
- **Web**: Uses `idb_shim` for IndexedDB storage. Platform-specific startup logic is in `lib/app/starter_web.dart` and `lib/app/starter_native.dart`.

## Common Tasks & Commands
Use the `Makefile` for common operations:
- `make run-linux`: Run the desktop app.
- `make build-web`: Build the web version.
- `make build-apk`: Build the Android APK.
- `flutter analyze`: Run static analysis.

## Conventions
- **Controllers & States**: Keep business logic in Controllers and UI state in State classes.
- **Dialogs**: Use `AlertDialog` with `scrollable: true` if the content (or title) can be long.
- **Manual DI**: Prefer passing dependencies via `AppFactory` rather than using global singletons.
