// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unnecessary_null_comparison
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

bool _globalDragDropGuardsInstalled = false;

/// Ensures browser window never opens dropped files as URLs/new tabs.
void _ensureGlobalDragDropGuards() {
  if (_globalDragDropGuardsInstalled) return;
  _globalDragDropGuardsInstalled = true;

  void prevent(html.Event e) {
    e.preventDefault();
    if (e is html.MouseEvent) {
      e.dataTransfer.dropEffect = 'copy';
    }
  }

  html.window.addEventListener('dragover', prevent, true);
  html.window.addEventListener('dragenter', prevent, true);
  html.document.addEventListener('dragover', prevent, true);
  html.document.addEventListener('dragenter', prevent, true);
  html.document.body?.addEventListener('dragover', prevent, true);
  html.document.body?.addEventListener('dragenter', prevent, true);
}

class ChatDragDropPasteSubscription {
  final List<VoidCallback> _cancelCallbacks = [];

  void add(VoidCallback cancelFn) {
    _cancelCallbacks.add(cancelFn);
  }

  void cancel() {
    for (final cancelFn in _cancelCallbacks) {
      try {
        cancelFn();
      } catch (e) {
        debugPrint('Error cancelling drag-drop listener: $e');
      }
    }
    _cancelCallbacks.clear();
  }
}

void _processBlobFile(html.File file, String? typeHint, void Function(PlatformFile) onFileReceived) {
  try {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        if (result != null) {
          final Uint8List bytes = result is Uint8List
              ? result
              : Uint8List.fromList(result as List<int>);

          final rawType = typeHint ?? file.type;
          final ext = rawType.contains('/')
              ? rawType.split('/').last.split('+').first
              : 'png';
          final safeExt = (ext == 'jpeg' || ext.isEmpty) ? 'jpg' : ext;
          final name = file.name.isNotEmpty && file.name != 'image.png'
              ? file.name
              : 'screenshot_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

          final platformFile = PlatformFile(
            name: name,
            size: bytes.length,
            bytes: bytes,
          );

          onFileReceived(platformFile);
        }
      } catch (e) {
        debugPrint('Error reading blob array buffer: $e');
      }
    });
  } catch (e) {
    debugPrint('Error processing blob file: $e');
  }
}

ChatDragDropPasteSubscription registerChatDragDropAndPaste({
  required void Function(PlatformFile file) onFileReceived,
  required void Function(bool isDragging) onDragStateChanged,
}) {
  final subTracker = ChatDragDropPasteSubscription();

  try {
    _ensureGlobalDragDropGuards();

    // 1. Handle Paste via ClipboardEvent (Ctrl+V / Cmd+V)
    void handlePaste(html.Event event) {
      if (event is! html.ClipboardEvent) return;
      final clipboardData = event.clipboardData;
      if (clipboardData == null) return;

      // Check 1: clipboardData.items (standard screenshot copy in Chrome/Edge/Firefox)
      final items = clipboardData.items;
      if (items != null && (items.length ?? 0) > 0) {
        for (int i = 0; i < (items.length ?? 0); i++) {
          final item = items[i];
          final type = item.type;

          if (type != null && type.startsWith('image/')) {
            final file = item.getAsFile();
            if (file != null) {
              event.preventDefault();
              event.stopPropagation();
              _processBlobFile(file, type, onFileReceived);
              return;
            }
          }
        }
      }

      // Check 2: clipboardData.files
      final files = clipboardData.files;
      if (files != null && files.isNotEmpty) {
        for (final file in files) {
          if (file.type.startsWith('image/') || file.name.toLowerCase().endsWith('.png') || file.name.toLowerCase().endsWith('.jpg')) {
            event.preventDefault();
            event.stopPropagation();
            _processBlobFile(file, file.type, onFileReceived);
            return;
          }
        }
      }
    }

    // Attach capture-phase paste listener to window, document, and document.body
    html.window.addEventListener('paste', handlePaste, true);
    subTracker.add(() => html.window.removeEventListener('paste', handlePaste, true));

    html.document.addEventListener('paste', handlePaste, true);
    subTracker.add(() => html.document.removeEventListener('paste', handlePaste, true));

    html.document.body?.addEventListener('paste', handlePaste, true);
    subTracker.add(() => html.document.body?.removeEventListener('paste', handlePaste, true));

    // 2. Handle Drag and Drop
    int dragCounter = 0;

    void handleDragEnter(html.Event event) {
      event.preventDefault();
      event.stopPropagation();
      dragCounter++;
      onDragStateChanged(true);
    }

    void handleDragOver(html.Event event) {
      event.preventDefault();
      event.stopPropagation();
      if (event is html.MouseEvent) {
        event.dataTransfer.dropEffect = 'copy';
      }
      onDragStateChanged(true);
    }

    void handleDragLeave(html.Event event) {
      event.preventDefault();
      event.stopPropagation();
      dragCounter--;
      if (dragCounter <= 0) {
        dragCounter = 0;
        onDragStateChanged(false);
      }
    }

    void handleDrop(html.Event event) {
      event.preventDefault();
      event.stopPropagation();
      dragCounter = 0;
      onDragStateChanged(false);

      dynamic dataTransfer;
      if (event is html.MouseEvent) {
        dataTransfer = event.dataTransfer;
      }

      final files = dataTransfer?.files;
      if (files != null && (files.length ?? 0) > 0) {
        final file = files[0];
        _processBlobFile(file, file.type, onFileReceived);
      }
    }

    // Attach capture-phase event listeners to window and document
    html.window.addEventListener('dragenter', handleDragEnter, true);
    html.window.addEventListener('dragover', handleDragOver, true);
    html.window.addEventListener('dragleave', handleDragLeave, true);
    html.window.addEventListener('drop', handleDrop, true);

    subTracker.add(() {
      html.window.removeEventListener('dragenter', handleDragEnter, true);
      html.window.removeEventListener('dragover', handleDragOver, true);
      html.window.removeEventListener('dragleave', handleDragLeave, true);
      html.window.removeEventListener('drop', handleDrop, true);
    });

    html.document.addEventListener('dragenter', handleDragEnter, true);
    html.document.addEventListener('dragover', handleDragOver, true);
    html.document.addEventListener('dragleave', handleDragLeave, true);
    html.document.addEventListener('drop', handleDrop, true);

    subTracker.add(() {
      html.document.removeEventListener('dragenter', handleDragEnter, true);
      html.document.removeEventListener('dragover', handleDragOver, true);
      html.document.removeEventListener('dragleave', handleDragLeave, true);
      html.document.removeEventListener('drop', handleDrop, true);
    });
  } catch (e) {
    debugPrint('Error registering chat drag-drop & paste listeners: $e');
  }

  return subTracker;
}
