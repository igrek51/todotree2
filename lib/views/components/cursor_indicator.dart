import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:todotree/model/tree_node.dart';
import 'package:todotree/util/errors.dart';
import 'package:todotree/util/logger.dart';
import 'package:todotree/util/numbers.dart';
import 'package:todotree/views/components/ripple_indicator.dart';
import 'package:todotree/views/tree_browser/browser_controller.dart';
import 'package:todotree/views/tree_browser/browser_state.dart';

class CursorIndicator extends StatefulWidget {
  CursorIndicator({
    super.key,
    required this.rippleIndicatorKey,
    required this.browserController,
    required this.browserState,
  });

  final GlobalKey<RippleIndicatorState> rippleIndicatorKey;
  final BrowserController browserController;
  final BrowserState browserState;

  @override
  State<CursorIndicator> createState() => CursorIndicatorState();
}

const double cursrorDiameter = 20;
const double brakeFactor = 0.99;
const double alignFactor = 1.1;
const double velocityTransmission = 1.1;
const double dragTransmission = 1.4;
const double overscrollTransmission = 4;
const double swipeDistanceThreshold = 90.0;
const double swipeAngleThreshold = 30;
const double overscrollArea = 100;
const double touchpadHeight = 200;

class CursorIndicatorState extends State<CursorIndicator> with TickerProviderStateMixin {
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
    lowerBound: 0.0,
  );
  Offset _velocity = Offset.zero;
  GlobalKey _boxKey = GlobalKey();
  int lastTickTimestampUs = 0;
  bool dragging = false;
  Offset dragStartPos = Offset.zero;
  Offset dragDelta = Offset.zero;
  double w = 0;
  double h = 0;

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void frameTick(BuildContext context) {
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    if (lastTickTimestampUs == 0) {
      lastTickTimestampUs = nowUs;
    }
    final durationUs = nowUs - lastTickTimestampUs;
    double timeScale = durationUs / 1000000.0;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (w == 0 && widget.browserController.cursorIndicatorX == 0) {
      w = renderBox?.size.width ?? 0;
      widget.browserController.cursorIndicatorX = w / 2;
      widget.browserController.cursorIndicatorY = -cursrorDiameter;
    }
    w = renderBox?.size.width ?? 0;
    h = ((renderBox?.size.height ?? 0) - touchpadHeight).clampMin(0);

    if (w > 0) {
      final browserState = Provider.of<BrowserState>(context, listen: false);

      if (!dragging) {
        double offsetX =
            (widget.browserController.cursorIndicatorX + _velocity.dx * velocityTransmission * timeScale).clamp(0, w);
        double offsetY =
            (widget.browserController.cursorIndicatorY + _velocity.dy * velocityTransmission * timeScale).clamp(0, h);
        double velocityX = _velocity.dx * pow(1 - brakeFactor, timeScale);
        double velocityY = _velocity.dy * pow(1 - brakeFactor, timeScale);
        offsetX += (w / 2 - offsetX) * alignFactor * timeScale;

        widget.browserController.cursorIndicatorX = offsetX;
        widget.browserController.cursorIndicatorY = offsetY;
        _velocity = Offset(velocityX, velocityY);
      }

      if (browserState.scrollController.hasClients) {
        double scroll = browserState.scrollController.offset;

        final overscrollUp = overscrollArea - widget.browserController.cursorIndicatorY;
        if (overscrollUp > 0 && scroll > 0) {
          browserState.scrollController.jumpTo(
            scroll - overscrollUp * overscrollTransmission * timeScale,
          );
        }
        final overscrollDown = widget.browserController.cursorIndicatorY + overscrollArea - h;
        if (overscrollDown > 0) {
          browserState.scrollController.jumpTo(
            scroll + overscrollDown * overscrollTransmission * timeScale,
          );
        }
      }
    }

    lastTickTimestampUs = nowUs;
  }

  void onTap() {
    dragging = false;
    if (_velocity.distance > 50.0) {
      logger.debug('Gesture: TAP - stop velocity');
      _velocity = Offset.zero;
      return;
    }

    _velocity = Offset.zero;
    final (itemIndex, treeItem) = findHoveredItem();
    logger.debug('Gesture: TAP - click item: $itemIndex');
    final dx = widget.browserController.cursorIndicatorX;
    final dy = widget.browserController.cursorIndicatorY;
    widget.rippleIndicatorKey.currentState?.animateLocal(dx, dy);
    if (treeItem != null && itemIndex != null) {
      safeExecute(() async {
        await widget.browserController.handleNodeTap(treeItem, itemIndex);
      });
    }
  }

  void onDragStart(DragStartDetails details) {
    dragging = true;
    dragStartPos = details.globalPosition;
  }

  void onDragUpdate(DragUpdateDetails details) {
    var dx = details.delta.dx;
    var dy = details.delta.dy;

    widget.browserController.cursorIndicatorX += dx * dragTransmission;
    widget.browserController.cursorIndicatorY += dy * dragTransmission;
    _velocity = Offset.zero;

    dragDelta = details.globalPosition - dragStartPos;

    lastTickTimestampUs = DateTime.now().microsecondsSinceEpoch;
    _animController.forward(from: 0);
  }

  void onDragEnd(DragEndDetails details) {
    dragging = false;

    _velocity = details.velocity.pixelsPerSecond;

    if (dragDelta.distance >= swipeDistanceThreshold) {
      final angle = dragDelta.direction * 180.0 / pi; // [0; 180] on top, [0; -180] on bottom

      if (angle >= 180 - swipeAngleThreshold || angle <= -180 + swipeAngleThreshold) {
        logger.debug('Gesture: Swipe left');
        _velocity = Offset.zero;
        widget.browserController.goBack();
      } else if (angle <= swipeAngleThreshold && angle >= -swipeAngleThreshold) {
        final (itemIndex, treeItem) = findHoveredItem();
        if (itemIndex != null && treeItem != null) {
          _velocity = Offset.zero;
          logger.debug('Gesture: Swipe right on item: $itemIndex');
          final dx = widget.browserController.cursorIndicatorX;
          final dy = widget.browserController.cursorIndicatorY;
          widget.rippleIndicatorKey.currentState?.animateLocal(dx, dy);
          safeExecute(() async {
            await widget.browserController.goIntoNode(treeItem);
          });
        }
      }
    }
  }

  void goIntoHoveredItem() {
    final (itemIndex, treeItem) = findHoveredItem();
    if (itemIndex != null && treeItem != null) {
      safeExecute(() async {
        await widget.browserController.goIntoNode(treeItem);
      });
    }
  }

  void addAboveHoveredItem() {
    final (itemIndex, treeItem) = findHoveredItem();
    if (itemIndex != null && treeItem != null) {
      safeExecute(() {
        widget.browserController.addNodeAt(itemIndex);
      });
    } else {
      safeExecute(() {
        widget.browserController.addNodeToTheEnd();
      });
    }
  }

  void moreOptionsOnHoveredItem() {
    final (itemIndex, treeItem) = findHoveredItem();
    if (itemIndex != null && treeItem != null) {
      safeExecute(() {
        widget.browserController.showItemOptionsDialog(treeItem, itemIndex);
      });
    } else {
      safeExecute(() {
        widget.browserController.showPlusOptionsDialog();
      });
    }
  }

  (int?, TreeNode?) findHoveredItem() {
    double scroll = 0;
    final browserController = widget.browserController;
    final browserState = widget.browserState;
    if (browserState.scrollController.hasClients) {
      scroll = browserState.scrollController.offset;
    }
    int itemsCount = browserState.items.length;
    var itemIndex = findItemIndexByOffset(
        widget.browserController.cursorIndicatorY + scroll, itemsCount, browserController.itemHeights);

    if (itemIndex == null) {
      return (null, null);
    }

    var treeItem = browserState.items[itemIndex];
    return (itemIndex, treeItem);
  }

  int? findItemIndexByOffset(double y, int itemsCount, Map<int, double> itemHeights) {
    double bufferY = y;
    for (var i = 0; i < itemsCount; i++) {
      var itemHeight = itemHeights[i] ?? 0;
      if (bufferY < itemHeight) {
        return i;
      }
      bufferY -= itemHeight;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _animController, curve: Curves.linear),
      builder: (context, child) {
        frameTick(context);
        return Stack(
          key: _boxKey,
          children: [
            Positioned(
              left: widget.browserController.cursorIndicatorX - cursrorDiameter / 2,
              top: widget.browserController.cursorIndicatorY - cursrorDiameter / 2,
              child: Container(
                width: cursrorDiameter,
                height: cursrorDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromARGB(255, 241, 165, 77).withOpacity(0.6 * (1 - _animController.value) + 0.1),
                ),
              ),
            )
          ],
        );
      },
    );
  }
}
