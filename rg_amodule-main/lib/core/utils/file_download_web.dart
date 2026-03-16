import 'dart:html' as html;

Future<void> downloadFromUrl(String url, {String? fileName}) async {
  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..style.display = 'none';
  if (fileName != null && fileName.isNotEmpty) {
    anchor.download = fileName;
  }
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}