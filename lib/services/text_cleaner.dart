class TextCleaner {
  static final RegExp _controlChars = RegExp(r'[\u0000-\u001F\u007F]');
  static final RegExp _cjkChars = RegExp(
    r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]',
  );

  static String clean(String text, {bool disallowCjk = false}) {
    var cleaned = text.replaceAll('\uFFFD', ' ');
    cleaned = cleaned.replaceAll(_controlChars, ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (disallowCjk) {
      cleaned = cleaned.replaceAll(_cjkChars, '').trim();
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    }

    return cleaned;
  }
}
