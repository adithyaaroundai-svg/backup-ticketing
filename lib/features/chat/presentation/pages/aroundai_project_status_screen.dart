import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design_system/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/aroundai_project_status.dart';
import '../providers/aroundai_project_status_provider.dart';

final aroundaiProjectStatusProvider = NotifierProvider<AroundaiProjectStatusNotifier, AroundaiProjectStatusState>(() {
  return AroundaiProjectStatusNotifier();
});

class AroundaiProjectStatusScreen extends ConsumerStatefulWidget {
  const AroundaiProjectStatusScreen({super.key});

  @override
  ConsumerState<AroundaiProjectStatusScreen> createState() => _AroundaiProjectStatusScreenState();
}

class _AroundaiProjectStatusScreenState extends ConsumerState<AroundaiProjectStatusScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aroundaiProjectStatusProvider.notifier).load();
    });
  }

  String _getLatestNoteText(String? notesJson) {
    if (notesJson == null || notesJson.isEmpty) return '';
    try {
      final List<dynamic> history = jsonDecode(notesJson);
      if (history.isNotEmpty) {
        return history.first['note']?.toString() ?? '';
      }
    } catch (_) {
      return notesJson; // fallback for plain text
    }
    return '';
  }

  List<Map<String, dynamic>> _getNotesHistoryList(String? notesJson) {
    if (notesJson == null || notesJson.isEmpty) return [];
    try {
      final List<dynamic> history = jsonDecode(notesJson);
      return List<Map<String, dynamic>>.from(history);
    } catch (_) {
      return [
        {
          'note': notesJson,
          'created_at': '',
        }
      ];
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showTaskDialog({AroundaiProjectStatus? task}) {
    final nameCtrl = TextEditingController(text: task?.taskName);
    final statusCtrl = TextEditingController(text: task?.taskStatus ?? 'not started');
    final latestNote = _getLatestNoteText(task?.notes);
    final notesCtrl = TextEditingController(text: latestNote);
    DateTime? selectedFollowUpDate = task?.followUpDate;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task == null ? 'Create New Task' : 'Edit Task',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task == null ? 'Add a new task to the project status.' : 'Update the details of the task.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        icon: const Icon(LucideIcons.x, size: 22, color: Colors.black54),
                        splashRadius: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Task Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'e.g., Integrate Supabase API',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.normal),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Current Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: statusCtrl.text,
                    icon: const Icon(LucideIcons.chevronDown, size: 16, color: Colors.black54),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                    items: [
                      _buildDropdownItem('not started', 'Not Started', Colors.grey.shade600, Colors.grey.shade200),
                      _buildDropdownItem('working', 'Presently Working', Colors.orange.shade800, Colors.orange.shade100),
                      _buildDropdownItem('completed', 'Completed', Colors.green.shade700, Colors.green.shade100),
                      _buildDropdownItem('paused', 'Paused', Colors.red.shade700, Colors.red.shade50),
                      _buildDropdownItem('trial', 'Trial', Colors.blue.shade700, Colors.blue.shade50),
                    ],
                    onChanged: (v) {
                      if (v != null) statusCtrl.text = v;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Follow-up Date (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final dt = await showDatePicker(
                        context: context,
                        initialDate: selectedFollowUpDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (dt != null) {
                        setState(() => selectedFollowUpDate = dt);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedFollowUpDate == null ? 'Select Date' : '${selectedFollowUpDate!.toLocal()}'.split(' ')[0],
                            style: TextStyle(
                              fontSize: 14,
                              color: selectedFollowUpDate == null ? Colors.grey.shade400 : AppColors.textPrimary,
                              fontWeight: selectedFollowUpDate == null ? FontWeight.normal : FontWeight.w500,
                            ),
                          ),
                          if (selectedFollowUpDate != null)
                            InkWell(
                              onTap: () => setState(() => selectedFollowUpDate = null),
                              child: const Icon(LucideIcons.x, size: 16, color: Colors.black54),
                            )
                          else
                            const Icon(LucideIcons.calendar, size: 16, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Additional Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: notesCtrl,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Any extra details...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                if (nameCtrl.text.trim().isEmpty) return;
                                setState(() => saving = true);
                                final prov = ref.read(aroundaiProjectStatusProvider.notifier);
                                final currentUserId = ref.read(authProvider)?.id;
                                try {
                                  if (task == null) {
                                    await prov.createTask(
                                      nameCtrl.text.trim(),
                                      statusCtrl.text,
                                      notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                      selectedFollowUpDate,
                                      currentUserId,
                                    );
                                  } else {
                                    await prov.updateTask(
                                      task.id,
                                      nameCtrl.text.trim(),
                                      statusCtrl.text,
                                      notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                      task.notes,
                                      selectedFollowUpDate,
                                      currentUserId,
                                    );
                                  }
                                  if (mounted) Navigator.pop(dialogCtx);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                } finally {
                                  if (mounted) setState(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                task == null ? 'Create Task' : 'Save Changes',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String value, String label, Color textColor, Color bgColor) {
    return DropdownMenuItem(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
        child: Text(
          label,
          style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _confirmDelete(AroundaiProjectStatus task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${task.taskName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600, elevation: 0),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(aroundaiProjectStatusProvider.notifier).deleteTask(task.id);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showNotesHistory(AroundaiProjectStatus task) {
    final history = _getNotesHistoryList(task.notes);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Notes History - ${task.taskName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: 500,
          height: 400,
          child: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.history, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No note history found for this task.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final record = history[index];
                    String dateStr = record['created_at']?.toString() ?? '';
                    if (dateStr.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(dateStr).toLocal();
                        dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      } catch (_) {}
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr.isNotEmpty ? dateStr : 'Unknown Time',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record['note']?.toString() ?? '',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupMenuItemChild(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AroundaiProjectStatus task, AroundaiProjectStatusNotifier prov) {
    Color textColor;
    Color bgColor;
    String label;

    if (task.taskStatus == 'completed') {
      textColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
      label = 'Completed';
    } else if (task.taskStatus == 'working') {
      textColor = Colors.orange.shade800;
      bgColor = Colors.orange.shade50;
      label = 'Presently Working';
    } else if (task.taskStatus == 'paused') {
      textColor = Colors.red.shade700;
      bgColor = Colors.red.shade50;
      label = 'Paused';
    } else if (task.taskStatus == 'trial') {
      textColor = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
      label = 'Trial';
    } else {
      textColor = Colors.grey.shade700;
      bgColor = Colors.grey.shade100;
      label = 'Yet to Start';
    }

    return Transform.translate(
      offset: const Offset(-8, 0),
      child: PopupMenuButton<String>(
        tooltip: 'Change Status',
        padding: EdgeInsets.zero,
      initialValue: task.taskStatus,
      onSelected: (String newStatus) async {
        if (newStatus == task.taskStatus) return;
        final currentUserId = ref.read(authProvider)?.id;
        final latestNote = _getLatestNoteText(task.notes);
        try {
          await prov.updateTask(task.id, task.taskName, newStatus, latestNote, task.notes, task.followUpDate, currentUserId);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'not started',
          child: _buildPopupMenuItemChild('Yet to Start', Colors.grey.shade700, Colors.grey.shade100),
        ),
        PopupMenuItem<String>(
          value: 'working',
          child: _buildPopupMenuItemChild('Presently Working', Colors.orange.shade800, Colors.orange.shade50),
        ),
        PopupMenuItem<String>(
          value: 'completed',
          child: _buildPopupMenuItemChild('Completed', Colors.green.shade700, Colors.green.shade50),
        ),
        PopupMenuItem<String>(
          value: 'paused',
          child: _buildPopupMenuItemChild('Paused', Colors.red.shade700, Colors.red.shade50),
        ),
        PopupMenuItem<String>(
          value: 'trial',
          child: _buildPopupMenuItemChild('Trial', Colors.blue.shade700, Colors.blue.shade50),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.3),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 14, color: textColor),
          ],
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aroundaiProjectStatusProvider);
    final prov = ref.read(aroundaiProjectStatusProvider.notifier);

    final filteredTasks = state.tasks.where((t) {
      if (_selectedFilter == 'all') return true;
      return t.taskStatus == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate-100
      appBar: AppBar(
        title: const Text('Project Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        centerTitle: true,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () => _showTaskDialog(),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('New Task', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white10, height: 1),
        ),
      ),
      body: state.loading && state.tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.alertTriangle, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('Failed to load data', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(state.error ?? '', style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(elevation: 0),
                        onPressed: () => prov.load(),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : state.tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                            child: Icon(LucideIcons.table, size: 48, color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 24),
                          const Text('No tasks found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          const Text('Click the "New Task" button to add a task.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => await prov.load(),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFilterTabs(),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.grey.shade200),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.02),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    minWidth: math.max(1150.0, constraints.maxWidth),
                                                  ),
                                                  child: DataTable(
                                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                      dataRowMaxHeight: 70,
                                      dataRowMinHeight: 60,
                                      horizontalMargin: 24,
                                      columnSpacing: 16,
                                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13),
                                      dividerThickness: 1,
                                      columns: const [
                                        DataColumn(label: Text('Task Name')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Notes')),
                                        DataColumn(label: Text('Follow Up')),
                                        DataColumn(label: Text('Created At')),
                                        DataColumn(label: Text('Updated At')),
                                        DataColumn(label: Text('Actions'), numeric: true),
                                      ],
                                      rows: filteredTasks.map((task) {
                                        Color baseRowColor;
                                        if (task.taskStatus == 'completed') {
                                          baseRowColor = Colors.green.shade50.withOpacity(0.3);
                                        } else if (task.taskStatus == 'working') {
                                          baseRowColor = Colors.orange.shade50.withOpacity(0.3);
                                        } else if (task.taskStatus == 'paused') {
                                          baseRowColor = Colors.red.shade50.withOpacity(0.3);
                                        } else if (task.taskStatus == 'trial') {
                                          baseRowColor = Colors.blue.shade50.withOpacity(0.3);
                                        } else {
                                          baseRowColor = Colors.white;
                                        }

                                        return DataRow(
                                          color: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                                            if (states.contains(MaterialState.hovered)) {
                                              return Colors.indigo.shade50.withOpacity(0.5);
                                            }
                                            return baseRowColor;
                                          }),
                                          cells: [
                                            DataCell(
                                              SizedBox(
                                                width: 250,
                                                child: Tooltip(
                                                  message: task.taskName,
                                                  waitDuration: const Duration(milliseconds: 500),
                                                  child: Text(
                                                    task.taskName,
                                                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo.shade800, fontSize: 15),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(_buildStatusBadge(task, prov)),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ConstrainedBox(
                                                    constraints: const BoxConstraints(maxWidth: 300),
                                                    child: Tooltip(
                                                      message: _getLatestNoteText(task.notes).isNotEmpty ? _getLatestNoteText(task.notes) : '-',
                                                      waitDuration: const Duration(milliseconds: 500),
                                                      child: Text(
                                                        _getLatestNoteText(task.notes).isNotEmpty ? _getLatestNoteText(task.notes) : '-',
                                                        style: TextStyle(color: _getLatestNoteText(task.notes).isNotEmpty ? Colors.black87 : Colors.grey.shade400, fontSize: 13),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: Icon(LucideIcons.history, size: 16, color: Colors.indigo.shade400),
                                                    splashRadius: 20,
                                                    tooltip: 'Notes History',
                                                    onPressed: () => _showNotesHistory(task),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                task.followUpDate != null ? '${task.followUpDate!.toLocal()}'.split(' ')[0] : '-',
                                                style: TextStyle(
                                                  color: task.followUpDate != null && task.followUpDate!.isBefore(DateTime.now()) 
                                                    ? Colors.red.shade600 
                                                    : Colors.grey.shade600, 
                                                  fontSize: 13,
                                                  fontWeight: task.followUpDate != null && task.followUpDate!.isBefore(DateTime.now()) 
                                                    ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _formatDate(task.createdAt),
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _formatDate(task.updatedAt),
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(LucideIcons.edit2, size: 16),
                                                    color: Colors.blue.shade600,
                                                    splashRadius: 20,
                                                    onPressed: () => _showTaskDialog(task: task),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(LucideIcons.trash2, size: 16),
                                                    color: Colors.red.shade500,
                                                    splashRadius: 20,
                                                    onPressed: () => _confirmDelete(task),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 250,
                    child: _buildSidebar(state.tasks),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'label': 'All Tasks', 'value': 'all'},
      {'label': 'Yet to Start', 'value': 'not started'},
      {'label': 'Presently Working', 'value': 'working'},
      {'label': 'Paused', 'value': 'paused'},
      {'label': 'Trial', 'value': 'trial'},
      {'label': 'Completed', 'value': 'completed'},
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['value'];
          return ChoiceChip(
            label: Text(f['label']!),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedFilter = f['value']!;
                });
              }
            },
            selectedColor: Colors.indigo.shade600,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade300),
            ),
            showCheckmark: false,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSidebar(List<AroundaiProjectStatus> allTasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Filter tasks that have a follow-up date and are not completed
    final followUpTasks = allTasks.where((t) => t.followUpDate != null && t.taskStatus != 'completed').toList();
    
    // Sort by follow-up date ascending
    followUpTasks.sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.bell, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Follow-up Reminders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (followUpTasks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(LucideIcons.calendarCheck, size: 32, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No upcoming follow-ups', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: followUpTasks.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final task = followUpTasks[index];
                final date = task.followUpDate!.toLocal();
                final taskDate = DateTime(date.year, date.month, date.day);
                
                final isOverdue = taskDate.isBefore(today);
                final isToday = taskDate.isAtSameMomentAs(today);

                Color badgeColor;
                Color badgeBgColor;
                String badgeText;

                if (isOverdue) {
                  badgeColor = Colors.red.shade700;
                  badgeBgColor = Colors.red.shade50;
                  badgeText = 'Overdue';
                } else if (isToday) {
                  badgeColor = Colors.orange.shade800;
                  badgeBgColor = Colors.orange.shade50;
                  badgeText = 'Today';
                } else {
                  badgeColor = Colors.blue.shade700;
                  badgeBgColor = Colors.blue.shade50;
                  badgeText = 'Upcoming';
                }

                return InkWell(
                  onTap: () => _showTaskDialog(task: task),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                task.taskName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeBgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(LucideIcons.calendar, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: isOverdue || isToday ? FontWeight.bold : FontWeight.normal),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
