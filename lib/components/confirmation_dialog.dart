import 'package:flutter/material.dart';
import 'package:todotree/services/info_service.dart';

class ConfirmationDialog {
  static Future<int> ask({
    String title = 'Are you sure?',
    required String content,
    String confirmActionLabel = 'Confirm',
    String? altActionLabel,
  }) async {
    final int? result = await showDialog<int>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        final actions = <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context, 0);
            },
            child: Text('Cancel'),
          ),
        ];
        if (altActionLabel != null) {
          actions.add(TextButton(
            onPressed: () {
              Navigator.pop(context, 2);
            },
            child: Text(altActionLabel),
          ));
        }
        actions.add(TextButton(
          onPressed: () {
            Navigator.pop(context, 1);
          },
          child: Text(confirmActionLabel),
        ));

        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(content),
          actions: actions,
        );
      },
    );
    return result ?? 0;
  }
}
