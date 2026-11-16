import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/crm_storage_service.dart';
import '../../core/download.dart';
import '../../core/enums.dart';
import '../../core/upload_part.dart';
import '../providers/work_item_edit_provider.dart';
import '../widgets/attachment_picker_section.dart';
import '../widgets/common.dart';

class WorkItemEditScreen extends StatelessWidget {
  final int workItemId;
  const WorkItemEditScreen({super.key, required this.workItemId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => WorkItemEditProvider(workItemId)..load(),
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
  final Map<PlatformFile, UploadPart> _partCache = {};
  bool _hydrated = false;
  bool _saving = false;
  String? _error;
  String? _uploadLabel;
  double? _uploadProgress;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  UploadPart _partFor(PlatformFile file, String field) => _partCache.putIfAbsent(
        file,
        () => UploadPart.fromPlatformFile(file, field: field),
      );

  Future<void> _pick(List<PlatformFile> bucket) async {
    final picked = await pickCrmUploadFiles();
    if (picked.isNotEmpty) {
      setState(() {
        bucket.addAll(picked);
        _error = null;
      });
    }
  }

  void _removeAt(List<PlatformFile> bucket, int index) {
    setState(() {
      _partCache.remove(bucket[index]);
      bucket.removeAt(index);
      _error = null;
    });
  }

  Future<void> _save(WorkItemEditProvider prov) async {
    if (hasInvalidCrmAttachments([..._excel, ..._proposal, ..._other])) {
      setState(() => _error = 'Remove empty or unreadable (0 B) files before saving.');
      return;
    }
    final hasFiles = _excel.isNotEmpty || _proposal.isNotEmpty || _other.isNotEmpty;
    setState(() {
      _saving = true;
      _error = null;
      _uploadLabel = hasFiles ? 'Preparing upload...' : null;
      _uploadProgress = hasFiles ? 0.0 : null;
    });
    try {
      await prov.save(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        removeFileIds: _removeIds.toList(),
        excelFiles: [
          for (final f in _excel) _partFor(f, 'excel_files')
        ],
        proposalFiles: [
          for (final f in _proposal) _partFor(f, 'proposal_files')
        ],
        otherFiles: [
          for (final f in _other) _partFor(f, 'other_files')
        ],
        onUploadProgress: (idx, total, p, filename) {
          if (!mounted) return;
          setState(() {
            _uploadLabel = formatCrmUploadProgressLabel(idx, total, p, filename);
            _uploadProgress = total <= 1 ? p : (idx + p) / total;
          });
        },
      );
      _removeIds.clear();
      _partCache.clear();
      _excel.clear();
      _proposal.clear();
      _other.clear();
      if (mounted) showSavedSnack(context, message: 'Work item saved \u2713');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadLabel = null;
          _uploadProgress = null;
        });
      }
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/dev-crm/clients'),
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
              enabled: !_saving,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _removeIds.add(f.id);
                } else {
                  _removeIds.remove(f.id);
                }
              }),
              title: Text('${f.filename} (${workItemCategoryLabel(f.category)})'),
              subtitle: Text(
                CrmStorageService.isLegacyUnmigratedPath(f.storagePath)
                    ? 'Check to remove \u2022 Legacy attachment (not in Supabase Storage)'
                    : 'Check to remove',
              ),
              secondary: IconButton(
                icon: Icon(
                  CrmStorageService.isLegacyUnmigratedPath(f.storagePath)
                      ? Icons.cloud_off_outlined
                      : Icons.download,
                ),
                tooltip: CrmStorageService.isLegacyUnmigratedPath(f.storagePath)
                    ? 'Legacy attachment not migrated to Supabase Storage'
                    : 'Download',
                onPressed: () => openDownload(context, f.storagePath ?? '', filename: f.filename),
              ),
            ),
          const SizedBox(height: 20),
          const Text('Add new files', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _pick(_excel),
            icon: const Icon(Icons.table_chart),
            label: Text('Excel files (${_excel.length})'),
          ),
          PendingAttachmentList(
            files: _excel,
            enabled: !_saving,
            onRemove: (i) => _removeAt(_excel, i),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _pick(_proposal),
            icon: const Icon(Icons.description),
            label: Text('Proposal files (${_proposal.length})'),
          ),
          PendingAttachmentList(
            files: _proposal,
            enabled: !_saving,
            onRemove: (i) => _removeAt(_proposal, i),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _pick(_other),
            icon: const Icon(Icons.attach_file),
            label: Text('Other files (${_other.length})'),
          ),
          PendingAttachmentList(
            files: _other,
            enabled: !_saving,
            onRemove: (i) => _removeAt(_other, i),
          ),
          if (_saving && _uploadLabel != null) ...[
            const SizedBox(height: 16),
            CrmUploadProgressBanner(
              label: _uploadLabel!,
              progress: _uploadProgress,
            ),
          ],
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
