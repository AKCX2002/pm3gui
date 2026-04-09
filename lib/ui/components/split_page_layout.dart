/// Shared split layout: left action pane + right content pane.
library;

import 'package:flutter/material.dart';

class SplitPageLayout extends StatelessWidget {
  final Widget side;
  final Widget main;
  final double sideWidth;
  final EdgeInsetsGeometry sidePadding;
  final EdgeInsetsGeometry mainPadding;
  final bool sideScrollable;
  final bool showDivider;

  const SplitPageLayout({
    super.key,
    required this.side,
    required this.main,
    this.sideWidth = 260,
    this.sidePadding = const EdgeInsets.all(12),
    this.mainPadding = const EdgeInsets.all(8),
    this.sideScrollable = true,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: sideWidth,
          child: sideScrollable
              ? SingleChildScrollView(
                  padding: sidePadding,
                  child: side,
                )
              : Padding(
                  padding: sidePadding,
                  child: side,
                ),
        ),
        if (showDivider)
          VerticalDivider(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
        Expanded(
          child: Padding(
            padding: mainPadding,
            child: main,
          ),
        ),
      ],
    );
  }
}
