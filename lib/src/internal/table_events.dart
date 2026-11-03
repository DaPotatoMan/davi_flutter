import 'dart:math' as math;

import 'package:davi/davi.dart';
import 'package:davi/src/internal/davi_context.dart';
import 'package:davi/src/internal/theme_metrics/theme_metrics.dart';
import 'package:davi/src/internal/viewport_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

@internal
class TableEvents<DATA> extends StatefulWidget {
  const TableEvents(
      {super.key,
      required this.daviContext,
      required this.child,
      required this.rowRegions,
      required this.unpinnedAreaBounds,
      required this.rowTheme});

  final Widget child;
  final DaviContext<DATA> daviContext;

  final RowRegionCache rowRegions;

  /// The horizontal extent of the unpinned table area.
  final Rect unpinnedAreaBounds;

  final RowThemeData rowTheme;

  @override
  State<TableEvents<DATA>> createState() => _TableEventsState<DATA>();
}

class _TableEventsState<DATA> extends State<TableEvents<DATA>> {
  final _ScrollDragHandler _verticalScroller = _ScrollDragHandler();
  final _ScrollDragHandler _horizontalScroller = _ScrollDragHandler();
  Offset? _tapPosition;

  @override
  void dispose() {
    _verticalScroller.dispose();
    _horizontalScroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DaviThemeData theme = DaviTheme.of(context);

    Widget widget = this.widget.child;

    if (this.widget.daviContext.model.isRowsNotEmpty) {
      // Updates logical row status on hover
      widget = MouseRegion(
          onEnter: _onEnter, onHover: _onHover, onExit: _onExit, child: widget);

      widget = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: daviContext.hasCallback ? _onTapDown : null,
          onTap: _buildOnTap(),
          onDoubleTapDown: daviContext.hasCallback ? _onDoubleTapDown : null,
          onDoubleTap: _buildOnDoubleTap(),
          onSecondaryTap: _buildOnSecondaryTap(),
          onSecondaryTapUp: _buildOnSecondaryTapUp(),
          onVerticalDragStart: (details) =>
              _verticalScroller.start(verticalScroll, details),
          onVerticalDragUpdate: _verticalScroller.update,
          onVerticalDragEnd: _verticalScroller.end,
          onVerticalDragCancel: _verticalScroller.cancel,
          onHorizontalDragStart: (details) =>
              _horizontalScroller.start(_horizontalScrollAt(details), details),
          onHorizontalDragUpdate: _horizontalScroller.update,
          onHorizontalDragEnd: _horizontalScroller.end,
          onHorizontalDragCancel: _horizontalScroller.cancel,
          child: widget);

      widget = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: _onPointerSignal,
          onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
          child: widget);

      if (daviContext.focusable) {
        final TableThemeMetrics themeMetrics = TableThemeMetrics(theme);

        widget = Focus(
            focusNode: daviContext.focusNode,
            onKeyEvent: (node, event) =>
                _handleKeyPress(node, event, themeMetrics.row.height),
            child: widget);
      }
    }
    return widget;
  }

  DaviContext<DATA> get daviContext => widget.daviContext;

  RowRegionCache get rowRegions => widget.rowRegions;

  RowThemeData get rowTheme => widget.rowTheme;

  ScrollController get verticalScroll => daviContext.scrollControllers.vertical;

  ScrollController _horizontalScrollAt(DragStartDetails details) {
    final double horizontalPosition = details.localPosition.dx;
    if (horizontalPosition >= widget.unpinnedAreaBounds.left &&
        horizontalPosition <= widget.unpinnedAreaBounds.right) {
      return daviContext.scrollControllers.unpinnedHorizontal;
    }
    return daviContext.scrollControllers.leftPinnedHorizontal;
  }

  void _onEnter(PointerEnterEvent event) {
    _updateHover(event.localPosition);
  }

  void _onHover(PointerHoverEvent event) {
    _updateHover(event.localPosition);
  }

  void _onExit(PointerExitEvent event) {
    _updateHover(null);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent &&
        verticalScroll.hasClients &&
        event.scrollDelta.dy != 0) {
      verticalScroll.position.pointerScroll(event.scrollDelta.dy);
    }
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    // trackpad on macOS
    if (verticalScroll.hasClients && event.panDelta.dy != 0) {
      verticalScroll.position.pointerScroll(-event.panDelta.dy);
    }
  }

  void _updateHover(Offset? position) {
    if (daviContext.model.isRowsNotEmpty) {
      int? rowIndex;
      if (position != null) {
        rowIndex = rowRegions.boundsIndex(position);
      }
      DATA? data;
      if (rowIndex != null && rowIndex < daviContext.model.rowsLength) {
        data = daviContext.model.rowAt(rowIndex);
      }
      if (data != null) {
        daviContext.hoverNotifier.cursor = _buildCursor(
            data: data,
            index: rowIndex!,
            hovered: daviContext.hoverNotifier.index == rowIndex);
      } else {
        // hover over visual row without value
        rowIndex = null;
      }
      daviContext.hoverNotifier.index = rowIndex;
    }
  }

  MouseCursor _buildCursor(
      {required DATA data, required int index, required bool hovered}) {
    MouseCursor? mouseCursor;
    if (daviContext.rowCursorBuilder != null) {
      CursorBuilderParams<DATA> params =
          CursorBuilderParams(data: data, rowIndex: index, hovered: hovered);
      mouseCursor = daviContext.rowCursorBuilder!(params);
    }
    if (mouseCursor == null && daviContext.hasCallback) {
      mouseCursor = rowTheme.callbackCursor;
    }
    return mouseCursor ?? MouseCursor.defer;
  }

  DATA? _dataAt(Offset position) {
    final int? rowIndex = rowRegions.boundsIndex(position);
    if (rowIndex != null && rowIndex < daviContext.model.rowsLength) {
      return daviContext.model.rowAt(rowIndex);
    }
    return null;
  }

  DATA? get _hoverData {
    DATA? data;
    if (daviContext.hoverNotifier.index != null) {
      if (daviContext.hoverNotifier.index! < daviContext.model.rowsLength) {
        data = daviContext.model.rowAt(daviContext.hoverNotifier.index!);
      }
    }
    return data;
  }

  GestureTapCallback? _buildOnTap() {
    if (daviContext.onRowTap != null) {
      return () {
        final Offset? position = _tapPosition;
        DATA? data = position == null ? null : _dataAt(position);
        if (data != null) {
          daviContext.onRowTap!(data);
        }
      };
    }
    return null;
  }

  void _onTapDown(TapDownDetails details) {
    _tapPosition = details.localPosition;
  }

  GestureTapCallback? _buildOnDoubleTap() {
    if (daviContext.onRowDoubleTap != null) {
      return () {
        final Offset? position = _tapPosition;
        DATA? data = position == null ? null : _dataAt(position);
        if (data != null) {
          daviContext.onRowDoubleTap!(data);
        }
      };
    }
    return null;
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _tapPosition = details.localPosition;
  }

  GestureTapCallback? _buildOnSecondaryTap() {
    if (daviContext.onRowSecondaryTap != null) {
      return () {
        DATA? data = _hoverData;
        if (data != null) {
          daviContext.onRowSecondaryTap!(data);
        }
      };
    }
    return null;
  }

  GestureTapUpCallback? _buildOnSecondaryTapUp() {
    if (daviContext.onRowSecondaryTapUp != null) {
      return (detail) {
        DATA? data = _hoverData;
        if (data != null) {
          daviContext.onRowSecondaryTapUp!(data, detail);
        }
      };
    }
    return null;
  }

  KeyEventResult _handleKeyPress(
      FocusNode node, KeyEvent event, double rowHeight) {
    if (event is KeyUpEvent) {
      if (verticalScroll.hasClients) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          double target = math.min(verticalScroll.position.pixels + rowHeight,
              verticalScroll.position.maxScrollExtent);
          verticalScroll.animateTo(target,
              duration: const Duration(milliseconds: 30), curve: Curves.ease);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          double target =
              math.max(verticalScroll.position.pixels - rowHeight, 0);
          verticalScroll.animateTo(target,
              duration: const Duration(milliseconds: 30), curve: Curves.ease);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
          double target = math.min(
              verticalScroll.position.pixels +
                  verticalScroll.position.viewportDimension,
              verticalScroll.position.maxScrollExtent);
          verticalScroll.animateTo(target,
              duration: const Duration(milliseconds: 30), curve: Curves.ease);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
          double target = math.max(
              verticalScroll.position.pixels -
                  verticalScroll.position.viewportDimension,
              0);
          verticalScroll.animateTo(target,
              duration: const Duration(milliseconds: 30), curve: Curves.ease);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }
}

class _ScrollDragHandler {
  Drag? _drag;

  void start(ScrollController controller, DragStartDetails details) {
    cancel();
    if (controller.hasClients) {
      _drag = controller.position.drag(details, _clearDrag);
    }
  }

  void update(DragUpdateDetails details) => _drag?.update(details);

  void end(DragEndDetails details) {
    final Drag? drag = _drag;
    _drag = null;
    drag?.end(details);
  }

  void cancel() {
    final Drag? drag = _drag;
    _drag = null;
    drag?.cancel();
  }

  void dispose() => cancel();

  void _clearDrag() {
    _drag = null;
  }
}
