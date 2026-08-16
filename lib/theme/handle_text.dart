/// تنسيق المعرّف ليظهر @ قبل الاسم دائمًا داخل النص العربي
/// يستخدم عزل الاتجاه (LRI…PDI) وهو الأسلوب الوحيد المضمون
String atHandle(String handle) {
  final clean = handle.replaceAll('@', '');
  return '\u2066@$clean\u2069';
}

/// يعالج نصًا كاملًا: يعزل كل معرّف @فلان داخله
/// حتى لا تنقلب @ لنهاية الكلمة في السياق العربي.
/// يستخدم لنصوص المنشورات والمعاينات التي قد تحتوي منشنات.
String bidiSafeMentions(String text) {
  return text.replaceAllMapped(
    RegExp(r'@[A-Za-z0-9_\u0621-\u064A]+'),
    (m) => '\u2066${m[0]}\u2069',
  );
}
