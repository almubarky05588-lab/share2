import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// متحكّم نصّي يلوّن المنشن والهاشتاق أثناء الكتابة
class RichComposeController extends TextEditingController {
  RichComposeController({super.text});

  static final _token = RegExp(r'([@#][\w\u0600-\u06FF._]+)');

  /// رموز عزل الاتجاه — تُدرج حول المنشن أثناء الكتابة
  /// حتى لا تنقلب @ داخل النص العربي، وتُنزع عند النشر.
  static const lri = '\u2066';
  static const pdi = '\u2069';

  /// النص النظيف للنشر — بدون رموز العزل
  String get cleanText =>
      text.replaceAll(lri, '').replaceAll(pdi, '');

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

    // لا مسافة ولا عزل بين @ والمؤشّر (العزل يعني منشنًا مكتملًا)
    final chunk = before.substring(at);
    if (chunk.contains(' ') ||
        chunk.contains('\n') ||
        chunk.contains(pdi)) {
      return null;
    }

    return chunk.substring(1);
  }

  /// يستبدل المنشن الجاري بالمعرّف المختار — معزول الاتجاه
  void completeMention(String handle) {
    final sel = selection.baseOffset;
    if (sel < 0) return;

    final before = text.substring(0, sel);
    final at = before.lastIndexOf('@');
    if (at < 0) return;

    final after = text.substring(sel);
    final inserted = '$lri@$handle$pdi ';
    final next = '${text.substring(0, at)}$inserted$after';

    value = TextEditingValue(
      text: next,
      selection:
          TextSelection.collapsed(offset: at + inserted.length),
    );
  }
}
