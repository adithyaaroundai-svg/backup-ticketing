import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/crm_storage_service.dart';
import '../../core/enums.dart';
import '../../core/upload_part.dart';
import '../../domain/entities/user.dart';
import 'attachment_picker_section.dart';

typedef TaskFormSubmitCallback = Future<void> Function(
  TaskFormResult result,
  CrmBatchUploadProgress onUploadProgress,
);

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
  TaskFormSubmitCallback? onSubmit,
}) {
  return showDialog<TaskFormResult>(
    context: context,
    barrierDismissible: onSubmit == null,
    builder: (_) => _TaskFormDialog(
      users: users,
      initialPending: initialPending,
      onSubmit: onSubmit,
    ),
  );
}

class _TaskFormDialog extends StatefulWidget {
  final List<UserRef> users;
  final bool initialPending;
  final TaskFormSubmitCallback? onSubmit;
  const _TaskFormDialog({
    required this.users,
    required this.initialPending,
    this.onSubmit,
  });

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
  final Map<PlatformFile, UploadPart> _partCache = {};
  bool _pickingFiles = false;
  bool _submitting = false;
  String? _submitError;
  String? _progressLabel;
  double? _progressValue;

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

  UploadPart _partFor(PlatformFile file) => _partCache.putIfAbsent(
        file,
        () => UploadPart.fromPlatformFile(file, field: 'task_files'),
      );

  Future<void> _pickFiles() async {
    setState(() => _pickingFiles = true);
    try {
      final picked = await pickCrmUploadFiles();
      if (picked.isNotEmpty) {
        setState(() {
          _files.addAll(picked);
          _submitError = null;
        });
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (hasInvalidCrmAttachments(_files)) {
      setState(() {
        _submitError = 'Remove empty or unreadable (0 B) files before creating the task.';
      });
      return;
    }

    final result = TaskFormResult(
      description: _descCtrl.text.trim(),
      priority: _priority,
      status: _status,
      expectedFinish: _expectedCtrl.text.isEmpty ? null : _expectedCtrl.text,
      startDate: _startCtrl.text.isEmpty ? null : _startCtrl.text,
      approved: _approved,
      pending: _pending,
      assigneeIds: _assignees.toList(),
      files: [for (final f in _files) _partFor(f)],
    );

    if (widget.onSubmit == null) {
      Navigator.of(context).pop(result);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
      _progressLabel = _files.isEmpty ? 'Creating task...' : 'Preparing upload...';
      _progressValue = _files.isEmpty ? null : 0.0;
    });

    try {
      await widget.onSubmit!(result, (index, total, fileProgress, filename) {
        if (!mounted) return;
        setState(() {
          _progressLabel = formatCrmUploadProgressLabel(
            index,
            total,
            fileProgress,
            filename,
          );
          _progressValue = total <= 1 ? fileProgress : (index + fileProgress) / total;
        });
      });
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _progressLabel = null;
        _progressValue = null;
        _submitError = e.toString();
      });
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
                if (_submitError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _submitError!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: [
                          for (final p in kPriorities) DropdownMenuItem(value: p, child: Text(p))
                        ],
                        onChanged: (v) => setState(() => _priority = v ?? _priority),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final s in kAllTaskStatuses)
                            DropdownMenuItem(
                              value: s,
                              child: Text(
                                taskStatusLabel(s),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
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
                Text('Attachments', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: (_pickingFiles || _submitting) ? null : _pickFiles,
                  icon: _pickingFiles
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file_rounded),
                  label: Text(_pickingFiles ? 'Reading files...' : 'Attach files'),
                ),
                PendingAttachmentList(
                  files: _files,
                  enabled: !_submitting,
                  padding: const EdgeInsets.only(top: 6),
                  onRemove: (i) => setState(() {
                    _partCache.remove(_files[i]);
                    _files.removeAt(i);
                    _submitError = null;
                  }),
                  onClearAll: () => setState(() {
                    _partCache.clear();
                    _files.clear();
                    _submitError = null;
                  }),
                ),
                if (_submitting && _progressLabel != null) ...[
                  const SizedBox(height: 12),
                  CrmUploadProgressBanner(
                    label: _progressLabel!,
                    progress: _progressValue,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _handleSubmit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
