import '../../core/upload_part.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/enums.dart';
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
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result != null) {
      setState(() => _files.addAll(result.files));
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
    return AlertDialog(
      title: Text(_pending ? 'Add pending task' : 'Add task'),
      content: SizedBox(
        width: 480,
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
                Align(alignment: Alignment.centerLeft, child: Text('Assignees', style: Theme.of(context).textTheme.labelLarge)),
                Wrap(
                  spacing: 6,
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
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: Text('Attach files (${_files.length})'),
                ),
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
