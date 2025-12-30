import 'package:flutter/material.dart';

/// Safe Text widget that prevents overflow by default
/// Automatically handles text overflow with ellipsis and optional maxLines
class SafeText extends StatelessWidget {

  const SafeText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.textAlign,
    this.overflow,
    this.softWrap = true,
    this.textDirection,
  });
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final bool softWrap;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines ?? 1,
      textAlign: textAlign,
      overflow: overflow ?? TextOverflow.ellipsis,
      softWrap: softWrap,
      textDirection: textDirection,
    );
  }
}

/// Safe Text widget for multi-line content with automatic overflow handling
class SafeTextMultiLine extends StatelessWidget {

  const SafeTextMultiLine(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 3,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
  });
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;
  final TextOverflow overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
















