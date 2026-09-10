import 'package:flutter/material.dart';
import '../../domain/entities/client.dart';

/// Shows a dialog to choose a client with a live search filter.
/// Returns the selected client ID or null if cancelled.
Future<int?> showChooseClientDialog(
  BuildContext context, {
  required List<Client> clients,
  int? initialClientId,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => ChooseClientDialog(
      clients: clients,
      initialClientId: initialClientId,
    ),
  );
}

class ChooseClientDialog extends StatefulWidget {
  final List<Client> clients;
  final int? initialClientId;

  const ChooseClientDialog({
    super.key,
    required this.clients,
    this.initialClientId,
  });

  @override
  State<ChooseClientDialog> createState() => _ChooseClientDialogState();
}

class _ChooseClientDialogState extends State<ChooseClientDialog> {
  late int? _selectedClientId;
  final TextEditingController _searchCtrl = TextEditingController();
  late List<Client> _filteredClients;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.initialClientId ?? (widget.clients.isNotEmpty ? widget.clients.first.id : null);
    _filteredClients = widget.clients;
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredClients = widget.clients;
      } else {
        _filteredClients = widget.clients.where((c) {
          final nameMatch = c.name.toLowerCase().contains(query);
          final contactMatch = c.contact?.toLowerCase().contains(query) ?? false;
          return nameMatch || contactMatch;
        }).toList();
      }
    });
  }

  void _submit() {
    if (_selectedClientId != null) {
      Navigator.pop(context, _selectedClientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_search, color: theme.colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose client',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Select customer to assign task',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search customer name or contact...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  ),
                ),
                onSubmitted: (_) {
                  if (_filteredClients.isNotEmpty) {
                    if (_selectedClientId == null || !_filteredClients.any((c) => c.id == _selectedClientId)) {
                      _selectedClientId = _filteredClients.first.id;
                    }
                    _submit();
                  }
                },
              ),
              const SizedBox(height: 12),

              // Results Count / Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CUSTOMERS (${_filteredClients.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      Text(
                        'Filtered from ${widget.clients.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Client List
              Expanded(
                child: _filteredClients.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 36, color: theme.disabledColor),
                              const SizedBox(height: 8),
                              Text(
                                'No customers found',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try searching with a different keyword',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ListView.separated(
                            itemCount: _filteredClients.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: theme.dividerColor.withValues(alpha: 0.1),
                            ),
                            itemBuilder: (context, index) {
                              final client = _filteredClients[index];
                              final isSelected = client.id == _selectedClientId;

                              return Material(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedClientId = client.id);
                                  },
                                  onDoubleTap: () {
                                    setState(() => _selectedClientId = client.id);
                                    _submit();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                          size: 18,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.disabledColor,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                client.name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                  color: isSelected
                                                      ? theme.colorScheme.primary
                                                      : theme.textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                              if (client.contact != null && client.contact!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  client.contact!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (client.openCount != null && client.openCount != '0')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${client.openCount} tasks',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedClientId == null ? null : _submit,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
