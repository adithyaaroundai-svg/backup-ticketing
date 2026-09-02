import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/download.dart';
import '../../core/enums.dart';
import '../providers/work_item_edit_provider.dart';
import '../widgets/common.dart';

class WorkItemEditScreen extends StatelessWidget {
  final int workItemId;
  const WorkItemEditScreen({super.key, required this.workItemId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => WorkItemEditProvider(ctx.read<ApiClient>(), workItemId)..load(),
      child: const _WorkItemEditBody(),
    );
  }
}

class _WorkItemEditBody extends StatefulWidget {
  const _WorkItemEditBody();

  @override
  State<_WorkItemEditBody> createState() => _WorkItemEditBodyState();
}

class _WorkItemEditBodyState extends State<_WorkItemEditBody> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<int> _removeIds = {};
  final List<PlatformFile> _excel = [];
  final List<PlatformFile> _proposal = [];
  final List<PlatformFile> _other = [];
  bool _hydrated = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(List<PlatformFile> bucket) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result != null) setState(() => bucket.addAll(result.files));
  }

  Future<void> _save(WorkItemEditProvider prov) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await prov.save(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        removeFileIds: _removeIds.toList(),
        excelFiles: [
          for (final f in _excel) UploadPart(field: 'excel_files', filename: f.name, bytes: f.bytes ?? [])
        ],
        proposalFiles: [
          for (final f in _proposal)
            UploadPart(field: 'proposal_files', filename: f.name, bytes: f.bytes ?? [])
        ],
        otherFiles: [
          for (final f in _other) UploadPart(field: 'other_files', filename: f.name, bytes: f.bytes ?? [])
        ],
      );
      _removeIds.clear();
      _excel.clear();
      _proposal.clear();
      _other.clear();
      if (mounted) showSavedSnack(context, message: 'Work item saved \u2713');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<WorkItemEditProvider>();
    if (prov.loading && prov.item == null) {
      return Scaffold(appBar: AppBar(title: const Text('Edit work item')), body: const CenterLoading());
    }
    if (prov.error != null && prov.item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit work item')),
        body: ErrorBanner(message: prov.error!, onRetry: prov.load),
      );
    }
    final item = prov.item!;
    if (!_hydrated) {
      _titleCtrl.text = item.title;
      _descCtrl.text = item.description ?? '';
      _hydrated = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit work item'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/clients'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
          ],
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          const Text('Existing files', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (item.files.isEmpty) const Text('No files attached.', style: TextStyle(color: Colors.grey)),
          for (final f in item.files)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _removeIds.contains(f.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _removeIds.add(f.id);
                } else {
                  _removeIds.remove(f.id);
                }
              }),
              title: Text('${f.filename} (${workItemCategoryLabel(f.category)})'),
              subtitle: const Text('Check to remove'),
              secondary: IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => openDownload(context, context.read<ApiClient>().fileDownloadUrl(f.storagePath ?? '')),
              ),
            ),
          const SizedBox(height: 20),
          const Text('Add new files', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _pick(_excel),
            icon: const Icon(Icons.table_chart),
            label: Text('Excel files (${_excel.length})'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _pick(_proposal),
            icon: const Icon(Icons.description),
            label: Text('Proposal files (${_proposal.length})'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _pick(_other),
            icon: const Icon(Icons.attach_file),
            label: Text('Other files (${_other.length})'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : () => _save(prov),
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
