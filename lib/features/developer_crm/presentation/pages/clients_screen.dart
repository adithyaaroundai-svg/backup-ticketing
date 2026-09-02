import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/time_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/clients_provider.dart';
import '../widgets/common.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ClientsProvider(ctx.read<ApiClient>())..load(),
      child: const _ClientsBody(),
    );
  }
}

class _ClientsBody extends StatefulWidget {
  const _ClientsBody();

  @override
  State<_ClientsBody> createState() => _ClientsBodyState();
}

class _ClientsBodyState extends State<_ClientsBody> {
  bool _showForm = false;
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(ClientsProvider prov) async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _formError = 'Client name is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      await prov.createClient(_nameCtrl.text.trim(), _contactCtrl.text.trim());
      _nameCtrl.clear();
      _contactCtrl.clear();
      if (mounted) setState(() => _showForm = false);
    } catch (e) {
      setState(() => _formError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ClientsProvider>();
    final isManager = context.watch<AuthProvider>().user?.isManager ?? false;

    if (prov.loading && prov.clients.isEmpty) return const CenterLoading();
    if (prov.error != null && prov.clients.isEmpty) {
      return ErrorBanner(message: prov.error!, onRetry: prov.load);
    }

    return RefreshIndicator(
      onRefresh: prov.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Clients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (isManager)
                FilledButton.icon(
                  onPressed: () => setState(() => _showForm = !_showForm),
                  icon: Icon(_showForm ? Icons.close : Icons.add),
                  label: Text(_showForm ? 'Cancel' : 'New Customer'),
                ),
            ],
          ),
          if (isManager && _showForm)
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_formError != null) ...[
                      Text(_formError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Client name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contactCtrl,
                      decoration: const InputDecoration(labelText: 'Contact (optional)'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _submitting ? null : () => _submit(prov),
                      child: _submitting
                          ? const SizedBox(
                              height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create client'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Contact')),
                  DataColumn(label: Text('Open tasks')),
                  DataColumn(label: Text('Ongoing')),
                  DataColumn(label: Text('Last activity')),
                ],
                rows: [
                  for (final c in prov.clients)
                    DataRow(
                      onSelectChanged: (_) => context.push('/clients/${c.id}'),
                      cells: [
                        DataCell(Text(c.name)),
                        DataCell(Text(c.contact ?? '-')),
                        DataCell(Text(c.openCount ?? '0')),
                        DataCell(c.ongoing == true
                            ? const Icon(Icons.circle, color: Colors.green, size: 12)
                            : const Icon(Icons.circle_outlined, color: Colors.grey, size: 12)),
                        DataCell(Text(c.lastActivity == null ? '-' : fmtDateTimeIst(c.lastActivity))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
