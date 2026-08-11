import 'dart:html' as html;
import 'package:http/http.dart' as http;

Future<void> downloadFileDirectly(String url, String fileName) async {
  try {
    // Attempt to fetch as blob to force download instead of open
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final blob = html.Blob([response.bodyBytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: blobUrl)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(blobUrl);
    } else {
      // Fallback to opening in new tab
      html.window.open(url, '_blank');
    }
  } catch (e) {
    // If CORS prevents fetch, fallback to standard anchor download attempt
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..target = 'blank';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }
}
