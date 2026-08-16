/// تنسيق المعرّف ليظهر @ قبل الاسم دائمًا داخل النص العربي
/// يستخدم عزل الاتجاه (LRI…PDI) وهو الأسلوب الوحيد المضمون
String atHandle(String handle) {
  final clean = handle.replaceAll('@', '');
  return '\u2066@$clean\u2069';
}
