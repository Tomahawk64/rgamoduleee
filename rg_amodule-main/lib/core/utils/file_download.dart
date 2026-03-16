import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    if (dart.library.io) 'file_download_io.dart' as impl;

Future<void> downloadFromUrl(String url, {String? fileName}) {
  return impl.downloadFromUrl(url, fileName: fileName);
}