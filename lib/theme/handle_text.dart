/// تنسيق المعرّف ليظهر @ قبل الاسم دائمًا في السياق العربي
String atHandle(String handle) {
  final clean = handle.replaceAll('@', '');
  // RLM قبل وبعد يثبّت اتجاه العرض
  return '\u200F@$clean\u200F';
}
