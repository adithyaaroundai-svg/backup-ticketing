import 'package:file_picker/file_picker.dart';

class ChatDragDropPasteSubscription {
  void cancel() {}
}

ChatDragDropPasteSubscription registerChatDragDropAndPaste({
  required void Function(PlatformFile file) onFileReceived,
  required void Function(bool isDragging) onDragStateChanged,
}) {
  return ChatDragDropPasteSubscription();
}
