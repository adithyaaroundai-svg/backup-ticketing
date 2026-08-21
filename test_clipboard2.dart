import 'package:super_clipboard/super_clipboard.dart';
void main() {
  int x = ClipboardEvents.instance!.registerPasteEventListener((event) async {});
}
