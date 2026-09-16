import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/upload_part.dart';
import '../../domain/entities/user.dart';

class TaskFormResult {
  final String description;
  final String priority;
  final String status;
  final String? expectedFinish;
  final String? startDate;
  final bool approved;
  final bool pending;
  final List<int> assigneeIds;
  final List<UploadPart> files;

  TaskFormResult({
    required this.description,
    required this.priority,
    required this.status,
    this.expectedFinish,
    this.startDate,
    required this.approved,
    required this.pending,
    required this.assigneeIds,
    required this.files,
  });
}

/// Shared "add task" form, used from client_detail, task_board and
/// pending_board (they all hit the same create-task endpoints).
Future<TaskFormResult?> showTaskFormDialog(
  BuildContext context, {
  required List<UserRef> users,
  bool initialPending = false,
}) {
  return showDialog<TaskFormResult>(
    context: context,
    builder: (_) => _TaskFormDialog(users: users, initialPending: initialPending),
  );
}

class _TaskFormDialog extends StatefulWidget {
  final List<UserRef> users;
  final bool initialPending;
  const _TaskFormDialog({required this.users, required this.initialPending});

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  String _priority = 'A';
  String _status = 'not_started';
  bool _approved = false;
  late bool _pending;
  final Set<int> _assignees = {};
  final List<PlatformFile> _files = [];
  bool _pickingFiles = false;

  @override
  void initState() {
    super.initState();
    _pending = widget.initialPending;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _expectedCtrl.dispose();
    _startCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    setState(() => _pickingFiles = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final List<PlatformFile> loaded = [];
        for (final f in result.files) {
          Uint8List? bytes = f.bytes;
          if ((bytes == null || bytes.isEmpty) && !kIsWeb && f.path != null) {
            try {
              final file = File(f.path!);
              if (file.existsSync()) {
                bytes = await file.readAsBytes();
              }
            } catch (e) {
              debugPrint('Error reading file bytes: $e');
            }
          }
          loaded.add(PlatformFile(
            name: f.name,
            size: f.size > 0 ? f.size : (bytes?.length ?? 0),
            bytes: bytes,
            path: f.path,
          ));
        }
        setState(() => _files.addAll(loaded));
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingFiles = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return Icons.image_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_pending ? 'Add pending task' : 'Add task'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: [
                          for (final p in kPriorities) DropdownMenuItem(value: p, child: Text(p))
                        ],
                        onChanged: (v) => setState(() => _priority = v ?? _priority),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final s in kAllTaskStatuses)
                            DropdownMenuItem(value: s, child: Text(taskStatusLabel(s)))
                        ],
                        onChanged: (v) => setState(() => _status = v ?? _status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expectedCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Expected finish'),
                        onTap: () => _pickDate(_expectedCtrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _startCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Start date'),
                        onTap: () => _pickDate(_startCtrl),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _approved,
                  title: const Text('Approved'),
                  onChanged: (v) => setState(() => _approved = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _pending,
                  title: const Text('Pending (not scheduled for today)'),
                  onChanged: (v) => setState(() => _pending = v ?? false),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Assignees', style: theme.textTheme.labelLarge),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final u in widget.users)
                      FilterChip(
                        label: Text(u.name),
                        selected: _assignees.contains(u.id),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _assignees.add(u.id);
                          } else {
                            _assignees.remove(u.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Attached Files Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Attachments', style: theme.textTheme.labelLarge),
                    if (_files.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _files.clear()),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Colors.red.shade700,
                        ),
                        child: const Text('Clear all', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _pickingFiles ? null : _pickFiles,
                  icon: _pickingFiles
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file_rounded),
                  label: Text(_pickingFiles ? 'Reading files...' : 'Attach files'),
                ),
                if (_files.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _files.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                Icon(_getFileIcon(_files[i].name), size: 20, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _files[i].name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _formatFileSize(_files[i].size),
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  tooltip: 'Remove',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  onPressed: () => setState(() => _files.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(TaskFormResult(
              description: _descCtrl.text.trim(),
              priority: _priority,
              status: _status,
              expectedFinish: _expectedCtrl.text.isEmpty ? null : _expectedCtrl.text,
              startDate: _startCtrl.text.isEmpty ? null : _startCtrl.text,
              approved: _approved,
              pending: _pending,
              assigneeIds: _assignees.toList(),
              files: [
                for (final f in _files)
                  UploadPart(field: 'task_files', filename: f.name, bytes: f.bytes ?? []),
              ],
            ));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
