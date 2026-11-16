import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/crm_storage_service.dart';
import '../../core/download.dart';
import '../../core/enums.dart';
import '../../core/time_utils.dart';
import '../../core/upload_part.dart';
import '../../domain/entities/work_item.dart';
import '../providers/client_detail_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/attachment_picker_section.dart';
import '../widgets/common.dart';
import '../widgets/edit_client_dialog.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/task_table.dart';

class ClientDetailScreen extends StatelessWidget {
  final int clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ClientDetailProvider(clientId)..load(),
      child: const _ClientDetailBody(),
    );
  }
}

class _ClientDetailBody extends StatefulWidget {
  const _ClientDetailBody();

  @override
  State<_ClientDetailBody> createState() => _ClientDetailBodyState();
}

class _ClientDetailBodyState extends State<_ClientDetailBody> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ClientDetailProvider>();
    if (prov.loading && prov.customer == null) return const CenterLoading();
    if (prov.error != null && prov.customer == null) {
      return ErrorBanner(message: prov.error!, onRetry: () => prov.load());
    }
    final customer = prov.customer!;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/dev-crm/clients'),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer.name,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              if (customer.contact != null && customer.contact!.isNotEmpty)
                                Text(customer.contact!, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit client details',
                          splashRadius: 18,
                          onPressed: () async {
                            final authProv = context.read<AuthProvider>();
                            final updated = await showEditClientDialog(
                              context,
                              client: customer,
                              onSave: (newName, newContact) => prov.updateClientDetails(
                                name: newName,
                                contact: newContact,
                                currentUserId: authProv.user?.id,
                                currentUserName: authProv.user?.name,
                              ),
                            );
                            if (updated == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Client details updated successfully'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<int?>(
                    hint: const Text('All assignees'),
                    value: prov.filterAssignee,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All assignees')),
                      for (final u in prov.users)
                        DropdownMenuItem<int?>(value: u.id, child: Text(u.name)),
                    ],
                    onChanged: (v) => prov.setAssigneeFilter(v),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "Today's Tasks"),
                Tab(text: 'Pending Tasks'),
                Tab(text: 'Work History'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _TasksTab(pending: false),
            _TasksTab(pending: true),
            const _WorkHistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _TasksTab extends StatefulWidget {
  final bool pending;
  const _TasksTab({required this.pending});

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ClientDetailProvider>();
    final tasks = widget.pending ? prov.pendingTasks : prov.tasks;
    return RefreshIndicator(
      onRefresh: () => prov.load(tab: prov.tab, assignee: prov.filterAssignee),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(widget.pending ? 'Add pending task' : 'Add task'),
                onPressed: () async {
                  final authUser = context.read<AuthProvider>().user;
                  final result = await showTaskFormDialog(
                    context,
                    users: prov.users,
                    initialPending: widget.pending,
                    onSubmit: (formResult, onUploadProgress) => prov.createTask(
                      description: formResult.description,
                      priority: formResult.priority,
                      status: formResult.status,
                      expectedFinish: formResult.expectedFinish,
                      startDate: formResult.startDate,
                      approved: formResult.approved,
                      pending: formResult.pending,
                      assigneeIds: formResult.assigneeIds,
                      files: formResult.files,
                      onUploadProgress: onUploadProgress,
                      currentUserId: authUser?.id,
                      currentUserName: authUser?.name,
                    ),
                  );
                  if (result != null && context.mounted) {
                    showSavedSnack(context, message: 'Task created \u2713');
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: TaskTable(
                tasks: tasks,
                showClient: false,
                emptyMessage: widget.pending ? 'No pending tasks.' : 'No tasks for today.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkHistoryTab extends StatelessWidget {
  const _WorkHistoryTab();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ClientDetailProvider>();
    return RefreshIndicator(
      onRefresh: () => prov.load(tab: prov.tab, assignee: prov.filterAssignee),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New work item'),
              onPressed: () => _showAddWorkItemDialog(context, prov),
            ),
          ),
          const SizedBox(height: 8),
          if (prov.workItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No work history yet.', style: TextStyle(color: Colors.grey)),
            ),
          for (final wi in prov.workItems) _WorkItemCard(item: wi),
        ],
      ),
    );
  }

  Future<void> _showAddWorkItemDialog(BuildContext context, ClientDetailProvider prov) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final langCtrl = TextEditingController();
    final snippetCtrl = TextEditingController();
    final excel = <PlatformFile>[];
    final proposal = <PlatformFile>[];
    final other = <PlatformFile>[];
    final partCache = <PlatformFile, UploadPart>{};
    bool submitting = false;
    String? error;
    String? progressLabel;
    double? progressValue;

    UploadPart partFor(PlatformFile file, String field) => partCache.putIfAbsent(
          file,
          () => UploadPart.fromPlatformFile(file, field: field),
        );

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) {
          Future<void> pick(List<PlatformFile> bucket) async {
            final picked = await pickCrmUploadFiles();
            if (picked.isNotEmpty) {
              setState(() {
                bucket.addAll(picked);
                error = null;
              });
            }
          }

          void removeAt(List<PlatformFile> bucket, int index) {
            setState(() {
              partCache.remove(bucket[index]);
              bucket.removeAt(index);
              error = null;
            });
          }

          return AlertDialog(
            title: const Text('New work item'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(dialogCtx).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          error!,
                          style: TextStyle(color: Theme.of(dialogCtx).colorScheme.onErrorContainer),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: langCtrl,
                        decoration: const InputDecoration(labelText: 'Code language (optional)')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: snippetCtrl,
                      decoration: const InputDecoration(labelText: 'Code snippet (optional)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: submitting ? null : () => pick(excel),
                      icon: const Icon(Icons.table_chart),
                      label: Text('Excel files (${excel.length})'),
                    ),
                    PendingAttachmentList(
                      files: excel,
                      enabled: !submitting,
                      onRemove: (i) => removeAt(excel, i),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: submitting ? null : () => pick(proposal),
                      icon: const Icon(Icons.description),
                      label: Text('Proposal files (${proposal.length})'),
                    ),
                    PendingAttachmentList(
                      files: proposal,
                      enabled: !submitting,
                      onRemove: (i) => removeAt(proposal, i),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: submitting ? null : () => pick(other),
                      icon: const Icon(Icons.attach_file),
                      label: Text('Other files (${other.length})'),
                    ),
                    PendingAttachmentList(
                      files: other,
                      enabled: !submitting,
                      onRemove: (i) => removeAt(other, i),
                    ),
                    if (submitting && progressLabel != null) ...[
                      const SizedBox(height: 12),
                      CrmUploadProgressBanner(
                        label: progressLabel!,
                        progress: progressValue,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: submitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          setState(() => error = 'Title is required.');
                          return;
                        }
                        if (hasInvalidCrmAttachments([...excel, ...proposal, ...other])) {
                          setState(() =>
                              error = 'Remove empty or unreadable (0 B) files before creating.');
                          return;
                        }
                        final hasFiles = excel.isNotEmpty || proposal.isNotEmpty || other.isNotEmpty;
                        setState(() {
                          submitting = true;
                          error = null;
                          progressLabel = hasFiles ? 'Preparing upload...' : 'Creating work item...';
                          progressValue = hasFiles ? 0.0 : null;
                        });
                        try {
                          await prov.addWorkItem(
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                            language: langCtrl.text.trim().isEmpty ? null : langCtrl.text.trim(),
                            codeSnippet: snippetCtrl.text.trim().isEmpty ? null : snippetCtrl.text.trim(),
                            excelFiles: [
                              for (final f in excel) partFor(f, 'excel_files')
                            ],
                            proposalFiles: [
                              for (final f in proposal) partFor(f, 'proposal_files')
                            ],
                            otherFiles: [
                              for (final f in other) partFor(f, 'other_files')
                            ],
                            onUploadProgress: (idx, total, p, filename) {
                              if (!dialogCtx.mounted) return;
                              setState(() {
                                progressLabel = formatCrmUploadProgressLabel(idx, total, p, filename);
                                progressValue = total <= 1 ? p : (idx + p) / total;
                              });
                            },
                          );
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                        } catch (e) {
                          if (!dialogCtx.mounted) return;
                          setState(() {
                            error = e.toString();
                            submitting = false;
                            progressLabel = null;
                            progressValue = null;
                          });
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkItemCard extends StatelessWidget {
  final WorkItem item;
  const _WorkItemCard({required this.item});

  Map<String, List> _filesByCategory() {
    final map = <String, List>{for (final c in kWorkItemFileCategories) c: []};
    for (final f in item.files) {
      (map[f.category] ??= []).add(f);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final byCategory = _filesByCategory();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (item.source == 'task')
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(label: Text('Auto (task completion)'), visualDensity: VisualDensity.compact),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => context.push('/dev-crm/work-items/${item.id}/edit'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete work item?'),
                        content: const Text('This removes the entry and its attached files.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await context.read<ClientDetailProvider>().deleteWorkItem(item.id);
                    }
                  },
                ),
              ],
            ),
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.description!),
            ],
            const SizedBox(height: 6),
            Text(
              '${item.authorName ?? 'Unknown'} \u2022 ${fmtDateTimeIst(item.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (item.code.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in item.code)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.code, size: 16),
                      label: Text(c.filename ?? c.language ?? 'code'),
                      onPressed: () => _revealCode(context, item.id),
                    ),
                ],
              ),
            ],
            for (final cat in kWorkItemFileCategories)
              if ((byCategory[cat] ?? []).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(workItemCategoryLabel(cat),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final f in byCategory[cat]!)
                      ActionChip(
                        avatar: Icon(
                          CrmStorageService.isLegacyUnmigratedPath(f.storagePath)
                              ? Icons.cloud_off_outlined
                              : Icons.download,
                          size: 16,
                        ),
                        tooltip: CrmStorageService.isLegacyUnmigratedPath(f.storagePath)
                            ? 'Legacy attachment (not migrated to Supabase Storage)'
                            : null,
                        label: Text(f.filename),
                        onPressed: () => openDownload(context, f.storagePath ?? '', filename: f.filename),
                      ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _revealCode(BuildContext context, int workItemId) async {
    final passwordCtrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enter code password'),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, passwordCtrl.text), child: const Text('Reveal')),
        ],
      ),
    );
    if (password == null || password.isEmpty || !context.mounted) return;
    try {
      final blocks =
          await context.read<ClientDetailProvider>().revealCode(workItemId, password);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Code'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final b in blocks) ...[
                    Text(b.filename ?? b.language ?? 'snippet',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.black87,
                      child: SelectableText(
                        b.content,
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (context.mounted) showSavedSnack(context, ok: false, message: e.toString());
    }
  }
}
