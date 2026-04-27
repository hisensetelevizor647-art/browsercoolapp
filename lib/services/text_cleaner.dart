class TextCleaner {
  static final RegExp _controlChars = RegExp(r'[\u0000-\u001F\u007F]');

  static String clean(String text, {bool disallowCjk = false}) {
    var cleaned = text.replaceAll('\uFFFD', ' ');
    cleaned = cleaned.replaceAll(_controlChars, ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }
}
