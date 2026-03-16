import 'package:url_launcher/url_launcher.dart';

Future<void> downloadFromUrl(String url, {String? fileName}) async {
  final launched = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    throw Exception('Unable to open download link.');
  }
}