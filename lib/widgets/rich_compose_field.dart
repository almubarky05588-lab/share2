import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// متحكّم نصّي يلوّن المنشن والهاشتاق أثناء الكتابة
class RichComposeController extends TextEditingController {
  RichComposeController({super.text});

  static final _token = RegExp(r'([@#][\w\u0600-\u06FF._]+)');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <InlineSpan>[];
    var last = 0;

    for (final m in _token.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }

      spans.add(TextSpan(
        text: m.group(0),
        style: (style ?? const TextStyle()).copyWith(
          color: AppColors.brand,
          fontWeight: FontWeight.w600,
        ),
      ));

      last = m.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return TextSpan(style: style, children: spans);
  }

  /// الكلمة الجارية عند المؤشّر إن كانت منشنًا
  String? get activeMentionQuery {
    final sel = selection.baseOffset;
    if (sel < 0 || sel > text.length) return null;

    final before = text.substring(0, sel);
    final at = before.lastIndexOf('@');
    if (at < 0) return null;

    // لا مسافة بين @ والمؤشّر
    final chunk = before.substring(at);
    if (chunk.contains(' ') || chunk.contains('\n')) return null;

    return chunk.substring(1);
  }

  /// يستبدل المنشن الجاري بالمعرّف المختار
  void completeMention(String handle) {
    final sel = selection.baseOffset;
    if (sel < 0) return;

    final before = text.substring(0, sel);
    final at = before.lastIndexOf('@');
    if (at < 0) return;

    final after = text.substring(sel);
    final next = '${text.substring(0, at)}@$handle $after';

    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + handle.length + 2),
    );
  }
}
