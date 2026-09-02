import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/download.dart';
import '../../core/enums.dart';
import '../../core/money_utils.dart';
import '../../core/time_utils.dart';
import '../../domain/entities/advance.dart';
import '../providers/auth_provider.dart';
import '../providers/task_edit_provider.dart';
import '../widgets/common.dart';

class TaskEditScreen extends StatelessWidget {
  final int taskId;
  const TaskEditScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => TaskEditProvider(ctx.read<ApiClient>(), taskId)..load(),
      child: const _TaskEditBody(),
    );
  }
}

class _TaskEditBody extends StatefulWidget {
  const _TaskEditBody();

  @override
  State<_TaskEditBody> createState() => _TaskEditBodyState();
}

class _TaskEditBodyState extends State<_TaskEditBody> {
  final _descCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _cancelReasonCtrl = TextEditingController();
  final _billAmountCtrl = TextEditingController();
  final _statusMessageCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _advanceAmountCtrl = TextEditingController();
  final _advanceNoteCtrl = TextEditingController();

  String _priority = 'A';
  String _status = 'not_started';
  bool _approved = false;
  bool _billed = false;
  final Set<int> _assignees = {};
  final Set<int> _removeFileIds = {};
  final List<PlatformFile> _newFiles = [];

  bool _hydrated = false;
  bool _saving = false;
  bool _savingNote = false;
  bool _addingAdvance = false;
  String? _error;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _descCtrl.dispose();
    _expectedCtrl.dispose();
    _startCtrl.dispose();
    _cancelReasonCtrl.dispose();
    _billAmountCtrl.dispose();
    _statusMessageCtrl.dispose();
    _noteCtrl.dispose();
    _advanceAmountCtrl.dispose();
    _advanceNoteCtrl.dispose();
    super.dispose();
  }

  void _hydrate(TaskEditProvider prov) {
    final t = prov.task!;
    _descCtrl.text = t.description;
    _expectedCtrl.text = t.expectedFinish ?? '';
    _startCtrl.text = t.startDate ?? '';
    _cancelReasonCtrl.text = t.cancelReason ?? '';
    _billAmountCtrl.text = t.billAmount?.toString() ?? '';
    _priority = t.priority;
    _status = kFullEditTaskStatuses.contains(t.status) ? t.status : 'not_started';
    _approved = t.approved;
    _billed = t.billed;
    _assignees
      ..clear()
      ..addAll(t.assignees.map((a) => a.id));
    final todayNote = prov.notes.where((n) => n.noteDate == prov.today).toList();
    _noteCtrl.text = todayNote.isNotEmpty ? todayNote.first.body : '';
    _hydrated = true;
    _startTickerIfNeeded(t.status);
  }

  void _startTickerIfNeeded(String status) {
    _ticker?.cancel();
    if (status == 'working') {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
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

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result != null) setState(() => _newFiles.addAll(result.files));
  }

  Future<void> _save(TaskEditProvider prov, bool isManager) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await prov.saveFull(
        description: _descCtrl.text.trim(),
        priority: _priority,
        status: _status,
        approved: _approved,
        expectedFinish: _expectedCtrl.text.trim().isEmpty ? null : _expectedCtrl.text.trim(),
        billAmount: isManager ? _billAmountCtrl.text.trim() : null,
        billed: isManager ? _billed : null,
        cancelReason: _status == 'cancelled' ? _cancelReasonCtrl.text.trim() : null,
        statusMessage: _statusMessageCtrl.text.trim().isEmpty ? null : _statusMessageCtrl.text.trim(),
        startDate: _startCtrl.text.trim().isEmpty ? null : _startCtrl.text.trim(),
        assigneeIds: _assignees.toList(),
        removeFileIds: _removeFileIds.toList(),
        newFiles: [
          for (final f in _newFiles) UploadPart(field: 'task_files', filename: f.name, bytes: f.bytes ?? [])
        ],
      );
      _removeFileIds.clear();
      _newFiles.clear();
      _statusMessageCtrl.clear();
      _hydrated = false;
      if (mounted) showSavedSnack(context, message: 'Task saved \u2713');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TaskEditProvider>();
    final isManager = context.watch<AuthProvider>().user?.isManager ?? false;

    if (prov.loading && prov.task == null) {
      return Scaffold(appBar: AppBar(title: const Text('Task')), body: const CenterLoading());
    }
    if (prov.error != null && prov.task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task')),
        body: ErrorBanner(message: prov.error!, onRetry: prov.load),
      );
    }
    final task = prov.task!;
    if (!_hydrated) _hydrate(prov);

    return Scaffold(
      appBar: AppBar(
        title: Text('Task #${task.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/tasks'),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete task',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete task?'),
                  content: const Text('This permanently deletes the task and its files/notes/history.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed == true) {
                await prov.delete();
                if (context.mounted) context.go('/tasks');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_error!),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (task.client != null) Chip(label: Text(task.client!)),
            StatusChip(status: task.status),
            PriorityChip(priority: task.priority),
            Chip(label: Text('Time: ${fmtDuration(task.liveSeconds())}')),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [for (final p in kPriorities) DropdownMenuItem(value: p, child: Text(p))],
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in kFullEditTaskStatuses)
                    DropdownMenuItem(value: s, child: Text(taskStatusLabel(s)))
                ],
                onChanged: (v) => setState(() {
                  _status = v ?? _status;
                  _startTickerIfNeeded(_status);
                }),
              ),
            ),
          ]),
          if (_status == 'cancelled') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cancelReasonCtrl,
              decoration: const InputDecoration(labelText: 'Cancellation reason'),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _expectedCtrl,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Expected finish'),
                onTap: () => _pickDate(_expectedCtrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _startCtrl,
                readOnly: task.startDate != null && task.startDate!.isNotEmpty,
                decoration: InputDecoration(
                  labelText: 'Start date',
                  helperText: (task.startDate != null && task.startDate!.isNotEmpty)
                      ? 'Immutable once set'
                      : null,
                ),
                onTap: (task.startDate != null && task.startDate!.isNotEmpty)
                    ? null
                    : () => _pickDate(_startCtrl),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _approved,
            title: const Text('Approved'),
            onChanged: (v) => setState(() => _approved = v ?? false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _statusMessageCtrl,
            decoration: const InputDecoration(labelText: 'Status change message (optional)'),
          ),
          const SizedBox(height: 16),
          Text('Assignees', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 6,
            children: [
              for (final u in prov.users)
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
          Text('Files', style: Theme.of(context).textTheme.titleSmall),
          for (final f in task.files)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _removeFileIds.contains(f.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _removeFileIds.add(f.id);
                } else {
                  _removeFileIds.remove(f.id);
                }
              }),
              title: Text(f.filename),
              subtitle: const Text('Check to remove'),
              secondary: IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => openDownload(context, context.read<ApiClient>().taskFileDownloadUrl(f.storagePath ?? '')),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.attach_file),
            label: Text('Attach new files (${_newFiles.length})'),
          ),
          const SizedBox(height: 20),
          if (isManager) _BillingSection(
            billAmountCtrl: _billAmountCtrl,
            billed: _billed,
            onBilledChanged: (v) => setState(() => _billed = v ?? false),
            advances: prov.advances,
            advanceAmountCtrl: _advanceAmountCtrl,
            advanceNoteCtrl: _advanceNoteCtrl,
            addingAdvance: _addingAdvance,
            onRaiseAdvance: () async {
              final amount = num.tryParse(_advanceAmountCtrl.text.trim());
              if (amount == null || amount <= 0) {
                showSavedSnack(context, ok: false, message: 'Amount must be greater than zero.');
                return;
              }
              setState(() => _addingAdvance = true);
              try {
                await prov.addAdvance(amount, _advanceNoteCtrl.text.trim());
                _advanceAmountCtrl.clear();
                _advanceNoteCtrl.clear();
                if (mounted) showSavedSnack(context, message: 'Advance recorded \u2713');
              } catch (e) {
                if (mounted) showSavedSnack(context, ok: false, message: e.toString());
              } finally {
                if (mounted) setState(() => _addingAdvance = false);
              }
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : () => _save(prov, isManager),
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save task'),
          ),
          const SizedBox(height: 28),
          Text('Daily progress notes', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: "Today's note (${prov.today ?? ''})",
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _savingNote
                  ? null
                  : () async {
                      if (_noteCtrl.text.trim().isEmpty) return;
                      setState(() => _savingNote = true);
                      try {
                        await prov.addNote(_noteCtrl.text.trim());
                        if (mounted) showSavedSnack(context, message: 'Note saved \u2713');
                      } catch (e) {
                        if (mounted) showSavedSnack(context, ok: false, message: e.toString());
                      } finally {
                        if (mounted) setState(() => _savingNote = false);
                      }
                    },
              child: _savingNote
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save note'),
            ),
          ),
          const SizedBox(height: 12),
          for (final n in prov.notes.where((n) => n.noteDate != prov.today))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(n.body),
                subtitle: Text('${fmtDate(n.noteDate)} \u2022 ${n.authorName ?? ''} (locked)'),
              ),
            ),
          const SizedBox(height: 28),
          Text('Status change history', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: prov.statusHistory.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No status changes yet.', style: TextStyle(color: Colors.grey)),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('From')),
                        DataColumn(label: Text('To')),
                        DataColumn(label: Text('Message')),
                        DataColumn(label: Text('By')),
                        DataColumn(label: Text('When')),
                      ],
                      rows: [
                        for (final h in prov.statusHistory)
                          DataRow(cells: [
                            DataCell(Text(h.fromStatus == null ? '-' : taskStatusLabel(h.fromStatus!))),
                            DataCell(Text(taskStatusLabel(h.toStatus))),
                            DataCell(Text(h.message ?? '-')),
                            DataCell(Text(h.changedByName ?? '-')),
                            DataCell(Text(fmtDateTimeIst(h.changedAt))),
                          ]),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BillingSection extends StatelessWidget {
  final TextEditingController billAmountCtrl;
  final bool billed;
  final ValueChanged<bool?> onBilledChanged;
  final List<Advance> advances;
  final TextEditingController advanceAmountCtrl;
  final TextEditingController advanceNoteCtrl;
  final bool addingAdvance;
  final VoidCallback onRaiseAdvance;

  const _BillingSection({
    required this.billAmountCtrl,
    required this.billed,
    required this.onBilledChanged,
    required this.advances,
    required this.advanceAmountCtrl,
    required this.advanceNoteCtrl,
    required this.addingAdvance,
    required this.onRaiseAdvance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Billing (manager only)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: billAmountCtrl,
                  decoration: const InputDecoration(labelText: 'Bill amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Checkbox(value: billed, onChanged: onBilledChanged),
                  const Text('Billed'),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            Text('Advances', style: Theme.of(context).textTheme.labelLarge),
            for (final a in advances)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(fmtMoney(a.amount)),
                subtitle: Text('${a.note ?? ''} \u2022 ${a.createdByName ?? ''} \u2022 ${fmtDateTimeIst(a.createdAt)}'),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: advanceAmountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: advanceNoteCtrl,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: addingAdvance ? null : onRaiseAdvance,
                child: const Text('Raise advance'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
