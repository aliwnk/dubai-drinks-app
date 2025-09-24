import 'dart:io';
import 'package:flutter/material.dart';

// Рендер цены с символом тенге с явными fallback-шрифтами
Widget tengeText(String amount, TextStyle style) {
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '$amount ', style: style),
        TextSpan(
          text: '\u20B8',
          style: style.copyWith(
            // Жёстко укажем системные шрифты по платформе
            fontFamily: Platform.isAndroid ? 'Roboto' : null,
          ),
        ),
      ],
    ),
  );
}

