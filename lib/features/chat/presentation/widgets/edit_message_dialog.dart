import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../widgets/markdown_text_editing_controller.dart';

class EditMessageDialog extends StatefulWidget {
  final String initialContent;
  final Future<void> Function(String newContent) onSave;

  const EditMessageDialog({
    super.key,
    required this.initialContent,
    required this.onSave,
  });

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late final MarkdownTextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownTextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newContent = _controller.text.trim();
    if (newContent.isEmpty || newContent == widget.initialContent.trim()) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(newContent);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to edit message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_note, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Text('Edit Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : AppColors.slate200,
                ),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 6,
                minLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Edit your message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Changes'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
