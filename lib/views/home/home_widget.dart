import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:todotree/views/editor/editor_widget.dart';
import 'package:todotree/views/home/home_state.dart';
import 'package:todotree/views/home/title_bar.dart';
import 'package:todotree/views/tree_browser/browser_widget.dart';

class HomeWidget extends StatelessWidget {
  const HomeWidget({super.key});

  @override
  Widget build(BuildContext context) {

    final homeState = context.watch<HomeState>();
    Widget bodyContent;
    if (homeState.pageView == HomePageView.treeBrowser) {
      bodyContent = BrowserWidget();
    } else {
      bodyContent = EditorWidget();
    }

    final scaffold = Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TitleBar(),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.onSecondary,
                  child: bodyContent,
                ),
              ),
            ],
          );
        }
      ),
    );
    final statusBarColor = Theme.of(context).colorScheme.inversePrimary;
    
    return SafeArea(
      child: AnnotatedRegion(
        value: SystemUiOverlayStyle(
          statusBarColor: statusBarColor,
          statusBarIconBrightness: Brightness.light,
        ),
        child: scaffold,
      ),
    );
  }
}