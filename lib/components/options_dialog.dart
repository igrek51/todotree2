import 'package:flutter/material.dart';
import 'package:todotree/services/info_service.dart';
import 'package:todotree/util/errors.dart';

class OptionsDialog {
  static void show(
    String title,
    List<OptionItem> options,
  ) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          contentPadding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 16.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: buildOptionWidgets(options, context),
          ),
        );
      },
    ).then((value) {
      if (value != null) {
        final optionItem = options.firstWhere((element) => element.id == value);
        safeExecute(() {
          optionItem.action();
        });
      }
    });
  }

  static List<Widget> buildOptionWidgets(
      List<OptionItem> options, BuildContext context) {
    return options
        .map((option) => ListTile(
              title: Text(option.name),
              onTap: () {
                Navigator.pop(context, option.id);
              },
            ))
        .toList();
  }
}

class OptionItem {
  OptionItem({required this.id, required this.name, required this.action});

  String id;
  String name;
  VoidCallback action;
}
