import 'package:super_clipboard/super_clipboard.dart';

void main() async {
  ClipboardEvents.instance?.registerPasteEventListener((event) async {
    final reader = await event.getClipboardReader();
    for (final item in reader.items) {
      if (item.canProvide(Formats.png)) {
        // Let's see the signature of getFile by trying to assign it
        Object? progress = item.getFile(Formats.png, (progress) {});
      }
    }
  });
}
