import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/enums.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SettingsProvider(ctx.read<ApiClient>())..load(),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  final _codePwCtrl = TextEditingController();
  bool _savingCodePw = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'developer';
  bool _addingMember = false;
  String? _addError;

  @override
  void dispose() {
    _codePwCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SettingsProvider>();
    final currentUserId = context.watch<AuthProvider>().user?.id;

    if (prov.loading && prov.users.isEmpty) return const CenterLoading();
    if (prov.error != null && prov.users.isEmpty) {
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
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Activity log'),
                onPressed: () => context.push('/activity'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Universal code-reveal password', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    prov.hasCodePw ? 'A password is currently set.' : 'No password set yet.',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _codePwCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'New password (min 4 chars)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _savingCodePw
                          ? null
                          : () async {
                              if (_codePwCtrl.text.length < 4) {
                                showSavedSnack(context,
                                    ok: false, message: 'Password must be at least 4 characters.');
                                return;
                              }
                              setState(() => _savingCodePw = true);
                              try {
                                await prov.setCodePassword(_codePwCtrl.text);
                                _codePwCtrl.clear();
                                if (mounted) showSavedSnack(context, message: 'Code password set \u2713');
                              } catch (e) {
                                if (mounted) showSavedSnack(context, ok: false, message: e.toString());
                              } finally {
                                if (mounted) setState(() => _savingCodePw = false);
                              }
                            },
                      child: const Text('Set'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add team member', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (_addError != null) ...[
                    Text(_addError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 8),
                  ],
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    SizedBox(
                      width: 200,
                      child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Password (default: changeme)'),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: [
                          for (final r in kUserRoles) DropdownMenuItem(value: r, child: Text(userRoleLabel(r)))
                        ],
                        onChanged: (v) => setState(() => _role = v ?? _role),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _addingMember
                        ? null
                        : () async {
                            if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
                              setState(() => _addError = 'Name and email are required.');
                              return;
                            }
                            setState(() {
                              _addingMember = true;
                              _addError = null;
                            });
                            try {
                              await prov.addMember(
                                name: _nameCtrl.text.trim(),
                                email: _emailCtrl.text.trim(),
                                password: _passwordCtrl.text.trim(),
                                role: _role,
                              );
                              _nameCtrl.clear();
                              _emailCtrl.clear();
                              _passwordCtrl.clear();
                              if (mounted) showSavedSnack(context, message: 'Member added \u2713');
                            } catch (e) {
                              setState(() => _addError = e.toString());
                            } finally {
                              if (mounted) setState(() => _addingMember = false);
                            }
                          },
                    child: _addingMember
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Add member'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Team members', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Must change pw')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final u in prov.users)
                    DataRow(cells: [
                      DataCell(Text(u.name + (u.isSuperAdmin == true ? ' \u2b50' : ''))),
                      DataCell(Text(u.email)),
                      DataCell(Text(userRoleLabel(u.role))),
                      DataCell(Text(u.mustChangePassword ? 'Yes' : 'No')),
                      DataCell(
                        (u.isSuperAdmin == true && u.id != currentUserId)
                            ? const Text('Protected', style: TextStyle(color: Colors.grey, fontSize: 12))
                            : TextButton(
                                onPressed: () => _resetPassword(context, prov, u.id, u.name),
                                child: const Text('Reset password'),
                              ),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(BuildContext context, SettingsProvider prov, int userId, String name) async {
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Reset password for $name'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password (min 6 chars)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Reset')),
        ],
      ),
    );
    if (password == null || password.isEmpty) return;
    try {
      await prov.resetPassword(userId, password);
      if (context.mounted) showSavedSnack(context, message: 'Password reset \u2713');
    } catch (e) {
      if (context.mounted) showSavedSnack(context, ok: false, message: e.toString());
    }
  }
}
