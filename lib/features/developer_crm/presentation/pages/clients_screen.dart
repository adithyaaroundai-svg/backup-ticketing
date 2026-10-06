import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/clients_provider.dart';
import '../widgets/board_chrome.dart';
import '../widgets/common.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = context.read<ClientsProvider>();
        if (prov.clients.isEmpty && !prov.loading) {
          prov.load();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _ClientsBody();
  }
}

class _ClientsBody extends StatefulWidget {
  const _ClientsBody();

  @override
  State<_ClientsBody> createState() => _ClientsBodyState();
}

class _ClientsBodyState extends State<_ClientsBody> {
  final ScrollController _horizontalScrollController = ScrollController();
  bool _showForm = false;
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _searchCtrl.dispose();
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
      final authProv = context.read<AuthProvider>();
      await prov.createClient(
        _nameCtrl.text.trim(),
        _contactCtrl.text.trim(),
        currentUserId: authProv.user?.id,
        currentUserName: authProv.user?.name,
      );
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

    final query = _searchQuery.trim().toLowerCase();
    final clients = query.isEmpty
        ? prov.clients
        : prov.clients.where((client) => client.name.toLowerCase().contains(query)).toList();

    return RefreshIndicator(
      onRefresh: prov.load,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BoardPageHeader(
                    title: 'Clients',
                    subtitle: '${prov.clients.length} clients in the workspace',
                  ),
                ),
                if (isManager)
                  FilledButton.icon(
                    onPressed: () => setState(() => _showForm = !_showForm),
                    icon: Icon(_showForm ? Icons.close : Icons.add, size: 18),
                    label: Text(_showForm ? 'Cancel' : 'New customer'),
                  ),
              ],
            ),
            if (isManager && _showForm) ...[
              const SizedBox(height: 16),
              _NewClientForm(
                nameCtrl: _nameCtrl,
                contactCtrl: _contactCtrl,
                error: _formError,
                submitting: _submitting,
                onSubmit: () => _submit(prov),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: AppTheme.subtleShadow,
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(fontSize: 14, color: AppColors.slate900),
                decoration: InputDecoration(
                  hintText: 'Search clients by name',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.slate400),
                  prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.slate400),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (clients.isEmpty)
              BoardEmptyState(message: query.isEmpty ? 'No clients yet.' : 'No clients match that search.')
            else
              BoardTableCard(
                child: Column(
                  children: [
                    const _ClientLine(
                      header: true,
                      name: 'Name',
                      contact: 'Contact',
                      open: 'Open tasks',
                      ongoing: 'Ongoing',
                      activity: 'Last activity',
                    ),
                    for (var i = 0; i < clients.length; i++)
                      InkWell(
                        onTap: () => context.push('/dev-crm/clients/${clients[i].id}'),
                        child: _ClientLine(
                          header: false,
                          shaded: i.isOdd,
                          name: clients[i].name,
                          contact: clients[i].contact?.trim().isNotEmpty == true ? clients[i].contact! : '-',
                          open: clients[i].openCount ?? '0',
                          ongoing: clients[i].ongoing == true ? 'Active' : 'Idle',
                          activity: clients[i].lastActivity == null ? '-' : fmtDateTimeIst(clients[i].lastActivity),
                          ongoingActive: clients[i].ongoing == true,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewClientForm extends StatelessWidget {
  const _NewClientForm({
    required this.nameCtrl,
    required this.contactCtrl,
    required this.error,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController nameCtrl;
  final TextEditingController contactCtrl;
  final String? error;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New customer', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate800)),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Client name'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact (optional)'))),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create client'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientLine extends StatelessWidget {
  const _ClientLine({
    required this.header,
    required this.name,
    required this.contact,
    required this.open,
    required this.ongoing,
    required this.activity,
    this.shaded = false,
    this.ongoingActive = false,
  });

  final bool header;
  final bool shaded;
  final String name;
  final String contact;
  final String open;
  final String ongoing;
  final String activity;
  final bool ongoingActive;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: header ? FontWeight.w700 : FontWeight.w500,
      color: header ? AppColors.slate600 : AppColors.slate800,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: header ? AppColors.slate100 : (shaded ? AppColors.slate50 : Colors.white),
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: _text(name, style)),
          Expanded(flex: 3, child: _text(contact, style.copyWith(color: header ? AppColors.slate600 : AppColors.slate600))),
          Expanded(flex: 2, child: _text(open, style, align: TextAlign.right)),
          Expanded(
            flex: 2,
            child: header
                ? _text(ongoing, style, align: TextAlign.right)
                : Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (ongoingActive ? AppColors.success : AppColors.slate400).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        ongoing,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ongoingActive ? AppColors.success : AppColors.slate500,
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(flex: 3, child: _text(activity, style, align: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _text(String value, TextStyle style, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(value, textAlign: align, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}
