import 'package:flutter/material.dart';
import 'package:todotree/services/info_service.dart';
import 'package:todotree/util/errors.dart';

class TextFieldDialog {
  static void show(
    String title,
    String initialValue,
    void Function(String) onConfirm,
  ) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        final TextEditingController controller = TextEditingController();
        controller.text = initialValue;
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Value',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                safeExecute(() {
                  onConfirm(controller.text);
                });
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static Future<String?> inputText(String title) async {
    final String? result = await showDialog<String>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        final TextEditingController controller = TextEditingController();
        controller.text = '';
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Value',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
    return result;
  }
}
