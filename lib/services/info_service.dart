import 'package:flutter/material.dart';

import 'package:todotree/util/logger.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

class InfoService {
  static void info(String message) {
    logger.info('UI: $message');
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    scaffoldMessengerKey.currentState?.clearSnackBars();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        showCloseIcon: true,
        dismissDirection: DismissDirection.horizontal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void snackbarAction(String message, String actionLabel, VoidCallback action) {
    logger.info('UI: $message');
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    scaffoldMessengerKey.currentState?.clearSnackBars();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        showCloseIcon: false,
        dismissDirection: DismissDirection.horizontal,
        duration: const Duration(seconds: 10),
        persist: false,
        action: SnackBarAction(
          label: actionLabel,
          onPressed: action,
        ),
      ),
    );
  }

  static void error(Object error, [String? contextMessage]) {
    final String fullMessage;
    if (contextMessage != null) {
      fullMessage = '$contextMessage: $error';
    } else {
      fullMessage = error.toString();
    }
    logger.error(fullMessage);
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    scaffoldMessengerKey.currentState?.clearSnackBars();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(fullMessage),
        showCloseIcon: false,
        dismissDirection: DismissDirection.horizontal,
        duration: const Duration(seconds: 10),
        persist: false,
        action: SnackBarAction(
          label: 'DETAILS',
          onPressed: () {
            showDialog(
              context: navigatorKey.currentContext!,
              builder: (BuildContext context) {
                return AlertDialog(
                  scrollable: true,
                  title: Text('Error Details'),
                  content: Text(fullMessage),
                  actions: <Widget>[
                    TextButton(
                      child: Text('CLOSE'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
