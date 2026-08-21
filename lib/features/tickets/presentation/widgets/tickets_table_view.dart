import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/ticket_provider.dart';
import '../providers/table_font_size_provider.dart';
import '../../domain/entities/ticket.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customers/presentation/providers/customer_provider.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/theme/app_theme_style.dart';

class TicketsTableView extends ConsumerStatefulWidget {
  final List<Ticket> tickets;
  final bool showAllTickets;
  final bool showOnlyMine;
  final bool showOnlyUnclaimed;
  final bool groupResolved;
  final bool isUnclaimedTab;
  final bool hasMore;
  final VoidCallback? onLoadMore;

  const TicketsTableView({
    super.key,
    required this.tickets,
    this.showAllTickets = false,
    this.showOnlyMine = false,
    this.showOnlyUnclaimed = false,
    this.groupResolved = false,
    this.isUnclaimedTab = false,
    this.hasMore = false,
    this.onLoadMore,
  });

  @override
  ConsumerState<TicketsTableView> createState() => _TicketsTableViewState();
}

class _TicketsTableViewState extends ConsumerState<TicketsTableView> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  String? _addingTicketGroup;
  final TextEditingController _newCustomerController = TextEditingController();
  final TextEditingController _newContactController = TextEditingController();
  final TextEditingController _newTaskController = TextEditingController();
  final TextEditingController _newBillAmountController = TextEditingController();
  String? _newClaimedById;
  String _newStatus = 'Open';
  String _newPaymentCollected = 'No';
  DateTime? _newCompletedDate;
  DateTime? _newReportedDate;
  bool _isSavingNewTicket = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _verticalScrollController.addListener(() {
      if (widget.hasMore && 
          widget.onLoadMore != null &&
          _verticalScrollController.position.pixels >= _verticalScrollController.position.maxScrollExtent - 200) {
        widget.onLoadMore!();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _verticalScrollController.dispose();
    _newCustomerController.dispose();
    _newContactController.dispose();
    _newTaskController.dispose();
    _newBillAmountController.dispose();
    super.dispose();
  }

  void _startAddingTicket(String groupDateKey) {
    setState(() {
      _addingTicketGroup = groupDateKey;
      _newCustomerController.clear();
      _newContactController.clear();
      _newTaskController.clear();
      _newBillAmountController.clear();
      _newClaimedById = null;
      _newStatus = 'Open';
      _newPaymentCollected = 'No';
      _newCompletedDate = null;
      _newReportedDate = null;
    });
    // Scroll table to the left so the new inline row is fully visible from the first column
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildTableHeaders(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.adaptiveSlate50,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('Ticket #', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: Text('Name of Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: Text('Contact No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: Text('Claimed by', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(left: 12), child: Text('Task', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600)))),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: Text('Bill Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: Text('Bill Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 1, child: Text('Payment\nCollected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 1, child: Text('AMC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: Text('Completed Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 32),
          Expanded(flex: 2, child: Text('Reported Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.adaptiveSlate600))),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  void _cancelAddingTicket() {
    setState(() {
      _addingTicketGroup = null;
      _newCustomerController.clear();
      _newContactController.clear();
      _newTaskController.clear();
      _newBillAmountController.clear();
      _newClaimedById = null;
      _newCompletedDate = null;
      _newReportedDate = null;
    });
  }

  Future<void> _saveNewTicket() async {
    final customerName = _newCustomerController.text.trim();
    final contactNumber = _newContactController.text.trim();
    final task = _newTaskController.text.trim();
    final billAmount = _newBillAmountController.text.trim();

    if (customerName.isEmpty || task.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in Customer Name and Task'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (_isSavingNewTicket) return;
    setState(() => _isSavingNewTicket = true);

    try {
      // Create customer if needed
      String customerId;
      final customersAsync = ref.read(customersListProvider);
      final customers = customersAsync.value ?? [];
      final existingCustomer = customers.firstWhere(
        (c) => c.companyName.toLowerCase() == customerName.toLowerCase(),
        orElse: () => const Customer(id: '', companyName: ''),
      );

      if (existingCustomer.id.isNotEmpty) {
        customerId = existingCustomer.id;
        // Update contact number if provided
        if (contactNumber.isNotEmpty) {
          await Supabase.instance.client
              .from('customers')
              .update({'contact_phone': contactNumber})
              .eq('id', customerId);
        }
      } else {
        final newCustomer = await Supabase.instance.client
            .from('customers')
            .insert({
              'company_name': customerName,
              'contact_phone': contactNumber.isEmpty ? null : contactNumber,
            })
            .select()
            .single();
        customerId = newCustomer['id'].toString();
        ref.invalidate(customersListProvider);
      }

      // Create ticket
      final currentUser = ref.read(authProvider);
      final newTicketData = {
        'customer_id': customerId,
        'title': task,
        'status': _newStatus,
        'contact_phone': contactNumber.isEmpty ? null : contactNumber,
        'assigned_to': _newClaimedById,
        'bill_amount': billAmount.isEmpty ? null : double.tryParse(billAmount),
        'payment_collected': _newPaymentCollected == 'Yes',
        'completed_at': _newCompletedDate?.toIso8601String(),
        'created_at': _newReportedDate?.toIso8601String(),
        'created_by': currentUser?.id,
      };

      // Remove null values so DB defaults (like created_at -> now()) trigger correctly
      newTicketData.removeWhere((key, value) => value == null);

      await Supabase.instance.client.from('tickets').insert(newTicketData);

      if (mounted) {
        ref.invalidate(rawTicketsStreamProvider);
        ref.invalidate(rawAllTicketsStreamProvider);
        ref.invalidate(paginatedTicketsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket created successfully'), backgroundColor: Colors.green),
        );
        _cancelAddingTicket();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create ticket: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNewTicket = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final agentsAsync = ref.watch(agentsListProvider);
    final customersAsync = ref.watch(customersListProvider);

    final customers = customersAsync.value ?? [];
    final customersMap = {for (final c in customers) c.id.toString(): c};

    final agentsList = agentsAsync.value ?? [];
    final agentsMapForSearch = {for (final a in agentsList) a['id'].toString(): a};

    final globalAssigneeFilter = ref.watch(ticketAssigneeFilterProvider);
    String? dropdownValue;
    if (globalAssigneeFilter.startsWith('agent:')) {
      dropdownValue = globalAssigneeFilter.substring(6);
      if (agentsAsync.value != null) {
        final agentExists = agentsAsync.value!.any((a) => a['id']?.toString() == dropdownValue);
        if (!agentExists) dropdownValue = null;
      }
    }

    // Filter tickets by search query and apply optimistic overrides
    final statusOverrides = ref.watch(ticketOptimisticStatusOverridesProvider);
    final assigneeOverrides = ref.watch(
      ticketOptimisticAssigneeOverridesProvider,
    );
    var filteredTickets =
        widget.tickets.map((t) {
          return t.copyWith(
            status: statusOverrides[t.ticketId] ?? t.status,
            assignedTo: assigneeOverrides[t.ticketId] ?? t.assignedTo,
          );
        }).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredTickets = filteredTickets.where((ticket) {
        final customer = customersMap[ticket.customerId];
        final customerName = customer?.companyName.toLowerCase() ?? '';
        final ticketPhone = ticket.contactPhone?.toLowerCase() ?? '';
        final customerPhones = customer?.phoneNumbers.join(' ').toLowerCase() ?? '';
        
        final agentId = ticket.assignedTo;
        final agent = agentId != null ? agentsMapForSearch[agentId] : null;
        final agentName = (agent?['full_name']?.toString() ?? agent?['username']?.toString() ?? '').toLowerCase();

        return ticket.title.toLowerCase().contains(query) || 
               customerName.contains(query) || 
               ticketPhone.contains(query) || 
               customerPhones.contains(query) ||
               agentName.contains(query);
      }).toList();
    }

    // Group tickets by date
    final groupedTickets = _groupTicketsByDate(filteredTickets);
    final fontScale = ref.watch(tableFontSizeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Force desktop table view on mobile as well per user request
        final isMobile = false;

        if (isMobile) {
          return _buildMobileView(
            context,
            groupedTickets,
            currentUser,
            agentsAsync,
            customersAsync,
          );
        }

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.adaptiveCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.adaptiveSlate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.adaptiveBorder),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search customer, task, agent...',
                        hintStyle: TextStyle(fontSize: 13, color: context.adaptiveSlate400),
                        prefixIcon: Icon(LucideIcons.search, size: 16, color: context.adaptiveSlate400),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: TextStyle(fontSize: 13, color: context.adaptiveSlate700),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 36,
                  width: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.adaptiveSlate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.adaptiveBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      isDense: true,
                      value: dropdownValue,
                      hint: Text('Filter by Assigned Agent', style: TextStyle(fontSize: 13, color: context.adaptiveSlate400)),
                      icon: Icon(LucideIcons.chevronDown, size: 16, color: context.adaptiveSlate400),
                      style: TextStyle(fontSize: 13, color: context.adaptiveSlate700),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Agents'),
                        ),
                        ...(agentsAsync.value ?? []).map((agent) {
                          final agentId = agent['id']?.toString();
                          final agentName = agent['full_name']?.toString() ?? agent['username']?.toString() ?? 'Unknown';
                          return DropdownMenuItem<String?>(
                            value: agentId,
                            child: Text(agentName),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val == null) {
                          ref.read(ticketAssigneeFilterProvider.notifier).setAll();
                        } else {
                          ref.read(ticketAssigneeFilterProvider.notifier).setAgent(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Expanded(
            child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 8,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(bottom: 16),
          child: SizedBox(
          width: 1600,
          child: Column(
            children: [
              // Global Table Headers removed and placed inside each group
          // Table Content
          Expanded(
            child: groupedTickets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.inbox,
                          size: 48,
                          color: context.adaptiveSlate300,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No tickets found',
                          style: TextStyle(
                            color: context.adaptiveSlate500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : customersAsync.when(
                    data: (customers) {
                      return agentsAsync.when(
                        data: (agents) {
                          // Optimize lookups by creating maps
                          final agentsMap = {for (final a in agents) a['id'].toString(): a};
                          final customersMap = {for (final c in customers) c.id.toString(): c};

                          return ListView.builder(
                            controller: _verticalScrollController,
                            padding: EdgeInsets.zero,
                            itemCount: groupedTickets.length + ((widget.hasMore && _searchQuery.isEmpty) ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= groupedTickets.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final group = groupedTickets[index];
                              final groupDateKey = '${group['date']}-$index'; // Unique key for each group
                              final isAdding = _addingTicketGroup == groupDateKey;
                              return Padding(
                                key: ValueKey(groupDateKey),
                                padding: EdgeInsets.only(
                                  top: index == 0 ? 0 : 32,
                                  bottom: 24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (group['date'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: context.adaptiveSlate50,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            topRight: Radius.circular(8),
                                          ),
                                          border: Border(
                                            top: BorderSide(color: AppColors.border),
                                            left: BorderSide(color: AppColors.border),
                                            right: BorderSide(color: AppColors.border),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(LucideIcons.calendarDays, size: 13, color: context.adaptiveSlate500),
                                            const SizedBox(width: 6),
                                            Text(group['date'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.adaptiveSlate700, letterSpacing: 0.3)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: context.isDarkMode ? Colors.white.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text('${(group['tickets'] as List).length} Items', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.isDarkMode ? Colors.white : AppColors.primary)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: context.adaptiveCard,
                                        borderRadius: BorderRadius.only(
                                          topRight: const Radius.circular(10),
                                          bottomLeft: const Radius.circular(10),
                                          bottomRight: const Radius.circular(10),
                                          topLeft: group['date'] == null ? const Radius.circular(10) : Radius.zero,
                                        ),
                                        border: Border.all(color: AppColors.border),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (group['date'] != null)
                                            _buildTableHeaders(context),
                                      // Tickets for this date
                                      ...group['tickets'].map<Widget>((ticket) {
                                        return TicketTableRow(
                                          key: ValueKey(ticket.ticketId),
                                          ticket: ticket,
                                          currentUser: currentUser,
                                          agents: agents,
                                          customers: customers,
                                          agentsMap: agentsMap,
                                          customersMap: customersMap,
                                          isUnclaimedTab: widget.isUnclaimedTab,
                                        );
                                      }).toList(),
                                      // Add item button
                                      InkWell(
                                        onTap: isAdding ? null : () => _startAddingTicket(groupDateKey),
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(color: AppColors.border),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                LucideIcons.plus,
                                                size: 16,
                                                color: context.isDarkMode ? const Color(0xFF60A5FA) : AppColors.primary,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                isAdding ? 'Adding new ticket...' : 'Add item',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: context.isDarkMode ? const Color(0xFF60A5FA) : AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Inline new ticket row
                                      if (isAdding)
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: context.adaptiveSlate50,
                                            border: Border(
                                              top: BorderSide(color: AppColors.border),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Fields row - exact same flex ratios and gaps as table header
                                              Row(
                                                children: [
                                                  // Ticket Number placeholder (flex: 1)
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text('Auto', style: TextStyle(fontSize: 11, color: context.adaptiveSlate500, fontStyle: FontStyle.italic)),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Status dropdown (flex: 2)
                                                  Expanded(
                                                    flex: 2,
                                                    child: DropdownButtonFormField<String>(
                                                      isDense: true,
                                                      isExpanded: true,
                                                      initialValue: _newStatus,
                                                      decoration: const InputDecoration(
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                      ),
                                                      items: ['Open', 'In Progress', 'Resolved', 'Closed'].map((s) {
                                                        return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 11)));
                                                      }).toList(),
                                                      onChanged: (v) => setState(() => _newStatus = v ?? 'Open'),
                                                    ),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Customer Name text field (flex: 2)
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextFormField(
                                                      controller: _newCustomerController,
                                                      decoration: const InputDecoration(
                                                        hintText: 'Customer Name',
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                      ),
                                                      style: TextStyle(fontSize: 11),
                                                    ),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Contact Number text field (flex: 2)
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextFormField(
                                                      controller: _newContactController,
                                                      decoration: const InputDecoration(
                                                        hintText: 'Contact No.',
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                      ),
                                                      style: TextStyle(fontSize: 11),
                                                      keyboardType: TextInputType.phone,
                                                    ),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Claimed by dropdown (flex: 2)
                                                  Expanded(
                                                    flex: 2,
                                                    child: DropdownButtonFormField<String>(
                                                      isDense: true,
                                                      isExpanded: true,
                                                      initialValue: _newClaimedById,
                                                      decoration: const InputDecoration(
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                      ),
                                                      items: agents.map((agent) {
                                                        return DropdownMenuItem(
                                                          value: agent['id']?.toString(),
                                                          child: Text(
                                                            agent['full_name'] ?? agent['username'] ?? '',
                                                            style: TextStyle(fontSize: 11),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        );
                                                      }).toList(),
                                                      selectedItemBuilder: (context) {
                                                        return agents.map((agent) {
                                                          return Text(
                                                            agent['full_name'] ?? agent['username'] ?? '',
                                                            style: TextStyle(fontSize: 11),
                                                            overflow: TextOverflow.ellipsis,
                                                          );
                                                        }).toList();
                                                      },
                                                      onChanged: (v) => setState(() => _newClaimedById = v),
                                                    ),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Task text field (flex: 3)
                                                  Expanded(
                                                    flex: 3,
                                                    child: TextFormField(
                                                      controller: _newTaskController,
                                                      decoration: const InputDecoration(
                                                        hintText: 'Task',
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                      ),
                                                      style: TextStyle(fontSize: 11),
                                                    ),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Bill Amount text field (flex: 2)
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextFormField(
                                                      controller: _newBillAmountController,
                                                      decoration: const InputDecoration(
                                                        hintText: 'Bill Amount',
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                      ),
                                                      style: TextStyle(fontSize: 11),
                                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                    ),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Bill description placeholder during creation
                                                  Expanded(
                                                    flex: 2,
                                                    child: SizedBox.shrink(),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Payment Collected dropdown (flex: 1)
                                                  Expanded(
                                                    flex: 1,
                                                    child: DropdownButtonFormField<String>(
                                                      isDense: true,
                                                      isExpanded: true,
                                                      initialValue: _newPaymentCollected,
                                                      decoration: const InputDecoration(
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                      ),
                                                      items: ['Yes', 'No'].map((p) {
                                                        return DropdownMenuItem(value: p, child: Text(p, style: TextStyle(fontSize: 11)));
                                                      }).toList(),
                                                      onChanged: (v) => setState(() => _newPaymentCollected = v ?? 'No'),
                                                    ),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Completed Date (flex: 2)
                                                  Expanded(
                                                    flex: 2,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        final date = await showDatePicker(
                                                          context: context,
                                                          initialDate: DateTime.now(),
                                                          firstDate: DateTime(2020),
                                                          lastDate: DateTime(2030),
                                                        );
                                                        if (date != null) {
                                                          setState(() => _newCompletedDate = date);
                                                        }
                                                      },
                                                      child: InputDecorator(
                                                        decoration: const InputDecoration(
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                        ),
                                                        child: Text(
                                                          _newCompletedDate == null
                                                              ? 'Completed Date'
                                                              : DateFormat('d/M/yy').format(_newCompletedDate!),
                                                          style: TextStyle(fontSize: 11),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 32),
                                                  // Reported Date (flex: 2)
                                                  Expanded(
                                                    flex: 2,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        final date = await showDatePicker(
                                                          context: context,
                                                          initialDate: DateTime.now(),
                                                          firstDate: DateTime(2020),
                                                          lastDate: DateTime(2030),
                                                        );
                                                        if (date != null) {
                                                          setState(() => _newReportedDate = date);
                                                        }
                                                      },
                                                      child: InputDecorator(
                                                        decoration: const InputDecoration(
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                        ),
                                                        child: Text(
                                                          _newReportedDate == null
                                                              ? 'Reported Date'
                                                              : DateFormat('d/M/yy').format(_newReportedDate!),
                                                          style: TextStyle(fontSize: 11),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 12),
                                              // Save/Cancel buttons row - placed after all column fields
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: _isSavingNewTicket ? null : _saveNewTicket,
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.primary,
                                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    ),
                                                    child: _isSavingNewTicket
                                                        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: context.adaptiveCard))
                                                        : Text('Save', style: TextStyle(fontSize: 12, color: context.adaptiveCard)),
                                                  ),
                                                  SizedBox(width: 8),
                                                  ElevatedButton(
                                                    onPressed: _cancelAddingTicket,
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.grey,
                                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    ),
                                                    child: Text('Cancel', style: TextStyle(fontSize: 12, color: context.adaptiveCard)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                          );
                        },
                        loading: () => Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Text(
                            'Error loading agents: $error',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      );
                    },
                    loading: () => Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text(
                        'Error loading customers: $error',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
          ),
        ],
      ),
        ),
        ),
      ),
          ),
        ],
      ),
        ),
    );
  },
);
  }

  List<Map<String, dynamic>> _groupTicketsByDate(List<Ticket> tickets) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Group by exact calendar date (yyyy-MM-dd key for sorting)
    final Map<String, List<Ticket>> groups = {};
    final Map<String, DateTime> keyToDate = {};

    for (final ticket in tickets) {
      final dateToUse = (ticket.createdAt ?? ticket.updatedAt ?? DateTime.now()).toLocal();
      final ticketDate = DateTime(dateToUse.year, dateToUse.month, dateToUse.day);
      final sortKey = '${ticketDate.year.toString().padLeft(4, '0')}-${ticketDate.month.toString().padLeft(2, '0')}-${ticketDate.day.toString().padLeft(2, '0')}';

      groups.putIfAbsent(sortKey, () => []).add(ticket);
      keyToDate[sortKey] = ticketDate;
    }

    // Sort keys newest first
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final result = <Map<String, dynamic>>[];
    for (final key in sortedKeys) {
      final groupTickets = groups[key]!;
      // Sort tickets within each group by creation time (newest first)
      groupTickets.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      final date = keyToDate[key]!;
      String label;
      if (date.isAtSameMomentAs(today)) {
        label = 'Today  ·  ${DateFormat('d MMM yyyy').format(date)}';
      } else if (date.isAtSameMomentAs(yesterday)) {
        label = 'Yesterday  ·  ${DateFormat('d MMM yyyy').format(date)}';
      } else {
        label = DateFormat('d MMM yyyy').format(date);
      }

      result.add({'date': label, 'tickets': groupTickets});
    }

    return result;
  }

  // ignore: unused_element
  Widget _buildMobileView(
    BuildContext context,
    List<Map<String, dynamic>> groupedTickets,
    dynamic currentUser,
    AsyncValue<List<dynamic>> agentsAsync,
    AsyncValue<List<Customer>> customersAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.adaptiveSlate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: customersAsync.when(
        data: (customers) {
          return agentsAsync.when(
            data: (agents) {
              final agentsMap = {for (final a in agents) a['id'].toString(): a};
              final customersMap = {for (final c in customers) c.id.toString(): c};
              if (groupedTickets.isEmpty) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.inbox, size: 48, color: context.adaptiveSlate300),
                        SizedBox(height: 16),
                        Text('No tickets found', style: TextStyle(color: context.adaptiveSlate500, fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: groupedTickets.length,
                itemBuilder: (context, index) {
                  final group = groupedTickets[index];
                  final groupDateKey = '${group['date']}-$index';
                  final isAdding = _addingTicketGroup == groupDateKey;
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.adaptiveSlate100,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.calendarDays, size: 13, color: context.adaptiveSlate500),
                              SizedBox(width: 6),
                              Text(
                                group['date'],
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.adaptiveSlate700),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.isDarkMode 
                                      ? Colors.white.withValues(alpha: 0.15) 
                                      : AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(group['tickets'] as List).length} ticket${(group['tickets'] as List).length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: context.isDarkMode 
                                        ? Colors.white 
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tickets
                        ...group['tickets'].map<Widget>((ticket) {
                          return _buildMobileTicketCard(ticket, currentUser, agentsMap, customersMap);
                        }).toList(),
                        // Add item button
                        InkWell(
                          onTap: isAdding ? null : () => _startAddingTicket(groupDateKey),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.border)),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.plus, size: 16, color: context.isDarkMode ? const Color(0xFF60A5FA) : AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  isAdding ? 'Adding new ticket...' : 'Add item',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.isDarkMode ? const Color(0xFF60A5FA) : AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isAdding) _buildMobileInlineAddForm(context, agents),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error loading agents: $error', style: TextStyle(color: AppColors.error)),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading customers: $error', style: TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildMobileTicketCard(
    Ticket ticket,
    dynamic currentUser,
    Map<String, dynamic> agentsMap,
    Map<String, Customer> customersMap,
  ) {
    final assignedAgentMap = ticket.assignedTo != null ? agentsMap[ticket.assignedTo.toString()] : null;
    final assignedAgentName = assignedAgentMap != null
        ? ((assignedAgentMap['full_name'] ?? assignedAgentMap['username']) ?? 'Unknown Agent').toString()
        : 'Unassigned';

    final customer = customersMap[ticket.customerId.toString()];
    final customerName = customer != null ? (customer.companyName ?? 'Unknown Customer') : 'Unknown Customer';

    final statusColor = _statusColor(context, ticket.status);
    final statusText = _statusText(ticket.status, ticket.assignedTo != null);

    return InkWell(
      onTap: () => context.push('/ticket/${ticket.ticketId}'),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
                const Spacer(),
                Expanded(
                  child: Text(
                    ticket.ticketNumber != null ? '#${ticket.ticketNumber}' : '#${ticket.ticketId.length > 8 ? ticket.ticketId.substring(0, 8) : ticket.ticketId}',
                    style: TextStyle(fontSize: 11, color: context.adaptiveSlate400),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(customerName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.adaptiveSlate800)),
            SizedBox(height: 4),
            _mobileInfoRow(LucideIcons.phone, ticket.contactPhone ?? 'N/A'),
            _mobileInfoRow(LucideIcons.user, assignedAgentName),
            _mobileInfoRow(LucideIcons.fileText, ticket.title, isLast: true),
            if (ticket.billAmount != null || (ticket.paymentCollected != null) || ticket.completedDate != null) ...[
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (ticket.billAmount != null)
                    _mobileTag('Bill: ${ticket.billAmount}'),
                  if (ticket.paymentCollected != null)
                    _mobileTag('Paid: ${ticket.paymentCollected == true ? 'Yes' : 'No'}'),
                  if (ticket.completedDate != null)
                    _mobileTag('Completed: ${DateFormat('d/M/yy').format(ticket.completedDate!)}'),
                ],
              ),
            ],
            if (ticket.billDescription != null && ticket.billDescription!.isNotEmpty) ...[
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.isDarkMode ? AppColors.slate800 : AppColors.slate50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.isDarkMode ? AppColors.slate700 : AppColors.slate200),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.fileText, size: 14, color: AppColors.slate500),
                    SizedBox(width: 6),
                    Expanded(
                      child: _buildHighlightedMentionText(ticket.billDescription!, agentsMap, context, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mobileInfoRow(IconData icon, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: context.adaptiveSlate400),
          SizedBox(width: 6),
          Expanded(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                style: TextStyle(fontSize: 12, color: context.adaptiveSlate600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.adaptiveSlate100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: context.adaptiveSlate600)),
    );
  }

  Widget _buildMobileInlineAddForm(BuildContext context, List<dynamic> agents) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.adaptiveSlate50,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isDense: true,
                  isExpanded: true,
                  initialValue: _newStatus,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: ['Open', 'In Progress', 'Resolved', 'Closed'].map((s) {
                    return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (v) => setState(() => _newStatus = v ?? 'Open'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isDense: true,
                  isExpanded: true,
                  initialValue: _newClaimedById,
                  decoration: const InputDecoration(labelText: 'Claimed by', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: agents.map((agent) {
                    return DropdownMenuItem(
                      value: agent['id']?.toString(),
                      child: Text(agent['full_name'] ?? agent['username'] ?? '', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _newClaimedById = v),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _newCustomerController,
            decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _newContactController,
            decoration: const InputDecoration(labelText: 'Contact No.', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: TextStyle(fontSize: 12),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _newTaskController,
            decoration: const InputDecoration(labelText: 'Task', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _newBillAmountController,
                  decoration: const InputDecoration(labelText: 'Bill Amount', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  style: TextStyle(fontSize: 12),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isDense: true,
                  isExpanded: true,
                  initialValue: _newPaymentCollected,
                  decoration: const InputDecoration(labelText: 'Payment', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: ['Yes', 'No'].map((p) {
                    return DropdownMenuItem(value: p, child: Text(p, style: TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (v) => setState(() => _newPaymentCollected = v ?? 'No'),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (date != null) setState(() => _newCompletedDate = date);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Completed Date', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    child: Text(
                      _newCompletedDate == null ? 'Select' : DateFormat('d/M/yy').format(_newCompletedDate!),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (date != null) setState(() => _newReportedDate = date);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Reported Date', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    child: Text(
                      _newReportedDate == null ? 'Select' : DateFormat('d/M/yy').format(_newReportedDate!),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveNewTicket,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 10)),
                  child: Text('Save', style: TextStyle(color: context.adaptiveCard)),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _cancelAddingTicket,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, padding: EdgeInsets.symmetric(vertical: 10)),
                  child: Text('Cancel', style: TextStyle(color: context.adaptiveCard)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status.toLowerCase()) {
      case 'new':
        return isDark ? Colors.red.shade300 : const Color(0xFFDC2626);
      case 'open':
        return isDark ? Colors.blue.shade300 : const Color(0xFF1E40AF);
      case 'inprogress':
      case 'in_progress':
        return isDark ? Colors.orange.shade300 : const Color(0xFFEA580C);
      case 'resolved':
        return isDark ? Colors.green.shade300 : const Color(0xFF16A34A);
      case 'closed':
        return isDark ? AppColors.slate300 : AppColors.slate600;
      case 'onhold':
      case 'on_hold':
        return isDark ? Colors.amber.shade300 : const Color(0xFFD97706);
      case 'waitingforcustomer':
      case 'waiting_for_customer':
        return isDark ? AppColors.slate300 : AppColors.slate600;
      case 'billraised':
      case 'bill_raised':
        return isDark ? Colors.red.shade300 : const Color(0xFFDC2626);
      case 'billprocessed':
      case 'bill_processed':
        return isDark ? Colors.green.shade400 : const Color(0xFF059669);
      default:
        return isDark ? AppColors.slate300 : AppColors.slate600;
    }
  }

  String _statusText(String status, bool isClaimed) {
    switch (status.toLowerCase()) {
      case 'new':
        return isClaimed ? 'In Progress' : 'Unclaimed';
      case 'open':
        return 'Open';
      case 'inprogress':
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'onhold':
      case 'on_hold':
        return 'On Hold';
      case 'waitingforcustomer':
      case 'waiting_for_customer':
        return 'Waiting';
      case 'billraised':
      case 'bill_raised':
        return 'Bill Raised';
      case 'billprocessed':
      case 'bill_processed':
        return 'Billed';
      default:
        return status;
    }
  }
}

class TicketTableRow extends ConsumerStatefulWidget {
  final Ticket ticket;
  final dynamic currentUser;
  final List<dynamic> agents;
  final List<dynamic> customers;
  final Map<String, dynamic> agentsMap;
  final Map<String, Customer> customersMap;
  final bool isUnclaimedTab;

  const TicketTableRow({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.agents,
    required this.customers,
    required this.agentsMap,
    required this.customersMap,
    this.isUnclaimedTab = false,
  });

  @override
  ConsumerState<TicketTableRow> createState() => _TicketTableRowState();
}

class _TicketTableRowState extends ConsumerState<TicketTableRow> {
  bool _editingCustomer = false;
  bool _editingTask = false;
  bool _savingCustomer = false;
  bool _savingTask = false;
  bool _editingContact = false;
  bool _savingContact = false;
  bool _editingBill = false;
  bool _savingBill = false;
  bool _editingBillDesc = false;
  bool _savingBillDesc = false;
  bool _showMentions = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;
  bool _savingCompletedDate = false;
  bool _savingReportedDate = false;
  bool _isDeleting = false;
  bool _suppressNextTap = false;

  late TextEditingController _customerCtrl;
  late TextEditingController _taskCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _billCtrl;
  late TextEditingController _billDescCtrl;

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController();
    _taskCtrl = TextEditingController(text: widget.ticket.title);
    _contactCtrl = TextEditingController(text: widget.ticket.contactPhone ?? '');
    _billCtrl = TextEditingController(text: widget.ticket.billAmount?.toString() ?? '');
    _billDescCtrl = TextEditingController(text: widget.ticket.billDescription ?? '');
    _billDescCtrl.addListener(_onBillDescChanged);
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _taskCtrl.dispose();
    _contactCtrl.dispose();
    _billCtrl.dispose();
    _billDescCtrl.removeListener(_onBillDescChanged);
    _billDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCustomerName(String customerId, String newName) async {
    setState(() => _savingCustomer = true);
    try {
      final nameStr = newName.trim();
      if (nameStr.isEmpty) {
        if (mounted) setState(() => _editingCustomer = false);
        return;
      }

      final existingCustomerEntry = widget.customersMap.entries.where((e) {
        return (e.value.companyName ?? '').toLowerCase() == nameStr.toLowerCase();
      }).toList();

      String newCustomerId;
      if (existingCustomerEntry.isNotEmpty) {
        newCustomerId = existingCustomerEntry.first.key;
      } else {
        final newCustomer = await Supabase.instance.client
            .from('customers')
            .insert({'company_name': nameStr})
            .select()
            .single();
        newCustomerId = newCustomer['id'].toString();
      }

      // Update the ticket to point to the new or existing customer
      await Supabase.instance.client
          .from('tickets')
          .update({'customer_id': newCustomerId})
          .eq('id', widget.ticket.ticketId);

      // Invalidate relevant providers to refresh the UI
      ref.invalidate(customersListProvider);
      ref.invalidate(rawTicketsStreamProvider);
      ref.invalidate(rawAllTicketsStreamProvider);
      ref.invalidate(paginatedTicketsProvider);

      if (mounted) setState(() => _editingCustomer = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update customer name: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCustomer = false);
    }
  }

  Future<void> _saveTask(String newTitle) async {
    setState(() => _savingTask = true);
    // Capture notifier and context before any async gap to avoid use-after-dispose
    final notifier = ref.read(ticketUpdaterProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = widget.ticket.copyWith(title: newTitle.trim());
      await notifier.updateTicket(updated);
      if (mounted) setState(() => _editingTask = false);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update task: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTask = false);
    }
  }

  Future<void> _saveContact(String newContact) async {
    setState(() => _savingContact = true);
    final notifier = ref.read(ticketUpdaterProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = widget.ticket.copyWith(contactPhone: newContact.trim());
      await notifier.updateTicket(updated);
      if (mounted) setState(() => _editingContact = false);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update contact: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingContact = false);
    }
  }

  Future<void> _saveBillAmount(String newBillAmount) async {
    setState(() => _savingBill = true);
    final notifier = ref.read(ticketUpdaterProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final val = double.tryParse(newBillAmount.trim());
      final updated = widget.ticket.copyWith(billAmount: val);
      await notifier.updateTicket(updated);
      if (mounted) setState(() => _editingBill = false);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update bill amount: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBill = false);
    }
  }

  void _onBillDescChanged() {
    if (!_editingBillDesc) return;
    final text = _billDescCtrl.text;
    final selection = _billDescCtrl.selection;
    if (!selection.isValid || selection.isDirectional || selection.baseOffset <= 0) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtSignIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtSignIndex != -1) {
      if (lastAtSignIndex == 0 || textBeforeCursor[lastAtSignIndex - 1] == ' ') {
        final query = textBeforeCursor.substring(lastAtSignIndex + 1);
        if (!query.contains(' ') && !query.contains(']')) {
          setState(() {
            _showMentions = true;
            _mentionQuery = query.toLowerCase();
            _mentionStartIndex = lastAtSignIndex;
          });
          return;
        }
      }
    }
    if (_showMentions) setState(() => _showMentions = false);
  }

  void _insertMention(String agentId) {
    final text = _billDescCtrl.text;
    final selection = _billDescCtrl.selection;
    if (_mentionStartIndex == -1 || _mentionStartIndex >= text.length) return;
    
    final before = text.substring(0, _mentionStartIndex);
    final after = selection.isValid && selection.baseOffset <= text.length 
        ? text.substring(selection.baseOffset) 
        : '';
    
    final newText = '$before@[$agentId] $after';
    _billDescCtrl.text = newText;
    final newOffset = _mentionStartIndex + agentId.length + 4;
    if (newOffset <= newText.length) {
      _billDescCtrl.selection = TextSelection.collapsed(offset: newOffset);
    }
    setState(() => _showMentions = false);
  }

  Future<void> _saveBillDescription(String newDesc) async {
    setState(() => _savingBillDesc = true);
    final notifier = ref.read(ticketUpdaterProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final val = newDesc.trim().isEmpty ? null : newDesc.trim();
      final updated = widget.ticket.copyWith(billDescription: val);
      await notifier.updateTicket(updated);
      if (mounted) setState(() => _editingBillDesc = false);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update bill description: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBillDesc = false);
    }
  }

  Future<void> _saveStatus(String newStatus) async {
    final notifier = ref.read(ticketUpdaterProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = widget.ticket.copyWith(status: newStatus);
      await notifier.updateTicket(updated);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveCompletedDate(DateTime? newDate) async {
    setState(() => _savingCompletedDate = true);
    final notifier = ref.read(ticketUpdaterProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = widget.ticket.copyWith(completedDate: newDate);
      await notifier.updateTicket(updated);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update completed date: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCompletedDate = false);
    }
  }

  Future<void> _saveReportedDate(DateTime? newDate) async {
    setState(() => _savingReportedDate = true);
    final notifier = ref.read(ticketUpdaterProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = widget.ticket.copyWith(createdAt: newDate);
      await notifier.updateTicket(updated);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update reported date: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingReportedDate = false);
    }
  }

  Future<void> _deleteTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Ticket'),
        content: Text('Are you sure you want to delete this ticket? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    final repo = ref.read(ticketRepositoryProvider);
    final result = await repo.deleteTickets([widget.ticket.ticketId]);
    
    result.fold(
      (failure) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${failure.message}'), backgroundColor: Colors.red),
          );
        }
      },
      (_) {
        // Success
        if (mounted) {
          setState(() => _isDeleting = false);
        }
        ref.invalidate(ticketsStreamProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final currentUser = widget.currentUser;
    final agentsMap = widget.agentsMap;
    final customersMap = widget.customersMap;
    final isUnclaimedTab = widget.isUnclaimedTab;

    final assignedAgentMap = ticket.assignedTo != null ? agentsMap[ticket.assignedTo.toString()] : null;
    final assignedAgentName = assignedAgentMap != null
        ? ((assignedAgentMap['full_name'] ?? assignedAgentMap['username']) ?? 'Unknown Agent')
            .toString()
        : 'Unassigned';

    final customer = customersMap[ticket.customerId.toString()];
    final customerName =
        customer != null ? (customer.companyName ?? 'Unknown Customer') : 'Unknown Customer';

    // Only the agent who claimed the ticket can edit
    final isClaimedByMe = currentUser != null && ticket.assignedTo == currentUser.id;
    // Agent who claimed OR created the ticket can delete it
    final isCreatedByMe = currentUser != null && ticket.createdBy == currentUser.id;
    final canDelete = isClaimedByMe || isCreatedByMe;

    return InkWell(
      onTap: (_editingCustomer || _editingTask || _editingContact || _editingBill || _suppressNextTap || _isDeleting)
          ? null
          : () => context.push('/ticket/${ticket.ticketId}'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Ticket Number
            Expanded(
              flex: 1,
              child: Text(
                ticket.ticketNumber != null ? '#${ticket.ticketNumber}' : '-',
                style: TextStyle(
                  color: context.adaptiveSlate900,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 32),
            // Status
            Expanded(
              flex: 2,
              child: (isClaimedByMe || (currentUser?.role?.toString().toLowerCase() == 'accountant'))
                  ? (() {
                      final isAccountant = currentUser?.role?.toString().toLowerCase() == 'accountant';
                      final allowedStatuses = isAccountant 
                          ? ['BillProcessed', 'Closed'] 
                          : ['New', 'Resolved', 'Closed', 'BillRaised', 'BillProcessed'];
                          
                      final currentStatus = allowedStatuses.contains(ticket.status) ? ticket.status : ticket.status;
                      
                      return DropdownButton<String>(
                        value: currentStatus,
                        items: [
                          if (!isAccountant) DropdownMenuItem(value: 'New', child: Text('New')),
                          if (!isAccountant) DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                          if (!isAccountant) DropdownMenuItem(value: 'BillRaised', child: Text('Bill Raised')),
                          DropdownMenuItem(value: 'BillProcessed', child: Text('Billed')),
                          DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                          if (!allowedStatuses.contains(ticket.status))
                            DropdownMenuItem(value: ticket.status, child: Text(ticket.status)),
                        ],
                      onChanged: (val) {
                        if (val != null && val != ticket.status) {
                          _saveStatus(val);
                        }
                      },
                      isDense: true,
                      underline: SizedBox(),
                      iconSize: 16,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.adaptiveSlate800),
                    );
                  })()
                  : _buildStatusChip(context, ticket.status, isUnclaimedTab, ticket.assignedTo != null),
            ),
            SizedBox(width: 32),
            // Customer Name
            Expanded(
              flex: 2,
              child: isClaimedByMe
                  ? _editingCustomer
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customerCtrl,
                                autofocus: true,
                                style: TextStyle(fontSize: 13, color: context.adaptiveSlate800),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _saveCustomerName(ticket.customerId, _customerCtrl.text),
                              ),
                            ),
                            SizedBox(width: 4),
                            if (_savingCustomer)
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            else ...[
                              InkWell(
                                onTap: () => _saveCustomerName(ticket.customerId, _customerCtrl.text),
                                child: Icon(LucideIcons.check, size: 16, color: Colors.green),
                              ),
                              SizedBox(width: 4),
                              InkWell(
                                onTap: () => setState(() {
                                  _editingCustomer = false;
                                  _customerCtrl.text = customerName;
                                }),
                                child: Icon(LucideIcons.x, size: 16, color: Colors.grey),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: Tooltip(
                                message: customerName,
                                child: Text(
                                  customerName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.isDarkMode ? Colors.white : context.adaptiveSlate800,
                                    fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            _EditButton(
                              onTap: () => setState(() {
                                _suppressNextTap = true;
                                _customerCtrl.text = customerName;
                                _editingCustomer = true;
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (mounted) setState(() => _suppressNextTap = false);
                                });
                              }),
                            ),
                          ],
                        )
                  : Tooltip(
                      message: customerName,
                      child: Text(
                        customerName,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.isDarkMode ? Colors.white : context.adaptiveSlate800,
                          fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
            SizedBox(width: 32),
            // Contact Number
            Expanded(
              flex: 2,
              child: isClaimedByMe
                  ? _editingContact
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _contactCtrl,
                                autofocus: true,
                                style: TextStyle(fontSize: 13, color: context.adaptiveSlate800),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _saveContact(_contactCtrl.text),
                              ),
                            ),
                            SizedBox(width: 4),
                            if (_savingContact)
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            else ...[
                              InkWell(
                                onTap: () => _saveContact(_contactCtrl.text),
                                child: Icon(LucideIcons.check, size: 16, color: Colors.green),
                              ),
                              SizedBox(width: 4),
                              InkWell(
                                onTap: () => setState(() {
                                  _editingContact = false;
                                  _contactCtrl.text = ticket.contactPhone ?? '';
                                }),
                                child: Icon(LucideIcons.x, size: 16, color: Colors.grey),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: Tooltip(
                                message: ticket.contactPhone ?? 'N/A',
                                child: Text(
                                  ticket.contactPhone ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
                                    fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            _EditButton(
                              onTap: () => setState(() {
                                _suppressNextTap = true;
                                _contactCtrl.text = ticket.contactPhone ?? '';
                                _editingContact = true;
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (mounted) setState(() => _suppressNextTap = false);
                                });
                              }),
                            ),
                          ],
                        )
                  : Tooltip(
                      message: ticket.contactPhone ?? 'N/A',
                      child: Text(
                        ticket.contactPhone ?? 'N/A',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
                          fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
            SizedBox(width: 32),
            // Allocated to
            Expanded(
              flex: 2,
              child: Tooltip(
                message: assignedAgentName,
                child: Text(
                  assignedAgentName,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
                    fontWeight: context.isDarkMode
                        ? FontWeight.bold
                        : (ticket.assignedTo != null ? FontWeight.w500 : FontWeight.normal),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(width: 32),
            // Task (Title)
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.only(left: 12),
                child: isClaimedByMe
                    ? _editingTask
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _taskCtrl,
                                  autofocus: true,
                                  style: TextStyle(fontSize: 13, color: context.adaptiveSlate700),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _saveTask(_taskCtrl.text),
                                ),
                              ),
                              SizedBox(width: 4),
                              if (_savingTask)
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              else ...[
                                InkWell(
                                  onTap: () => _saveTask(_taskCtrl.text),
                                  child: Icon(LucideIcons.check, size: 16, color: Colors.green),
                                ),
                                SizedBox(width: 4),
                                InkWell(
                                  onTap: () => setState(() {
                                    _editingTask = false;
                                    _taskCtrl.text = ticket.title;
                                  }),
                                  child: Icon(LucideIcons.x, size: 16, color: Colors.grey),
                                ),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              Flexible(
                                child: Tooltip(
                                  message: ticket.ticketNumber != null ? '#${ticket.ticketNumber} · ${ticket.title}' : ticket.title,
                                  child: Text(
                                    ticket.ticketNumber != null ? '#${ticket.ticketNumber} · ${ticket.title}' : ticket.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.isDarkMode ? Colors.white : context.adaptiveSlate700,
                                      fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              _EditButton(
                                onTap: () => setState(() {
                                  _suppressNextTap = true;
                                  _taskCtrl.text = ticket.title;
                                  _editingTask = true;
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    if (mounted) setState(() => _suppressNextTap = false);
                                  });
                                }),
                              ),
                            ],
                          )
                    : Tooltip(
                        message: ticket.ticketNumber != null ? '#${ticket.ticketNumber} · ${ticket.title}' : ticket.title,
                        child: Text(
                          ticket.ticketNumber != null ? '#${ticket.ticketNumber} · ${ticket.title}' : ticket.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.isDarkMode ? Colors.white : context.adaptiveSlate700,
                            fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 32),
            // Billing Procedure (Bill Amount)
            Expanded(
              flex: 2,
              child: isClaimedByMe
                  ? _editingBill
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _billCtrl,
                                autofocus: true,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 13, color: context.isDarkMode ? Colors.lightBlue.shade300 : Colors.lightBlue.shade600, fontWeight: FontWeight.w500),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _saveBillAmount(_billCtrl.text),
                              ),
                            ),
                            SizedBox(width: 4),
                            if (_savingBill)
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            else ...[
                              InkWell(
                                onTap: () => _saveBillAmount(_billCtrl.text),
                                child: Icon(LucideIcons.check, size: 16, color: Colors.green),
                              ),
                              SizedBox(width: 4),
                              InkWell(
                                onTap: () => setState(() {
                                  _editingBill = false;
                                  _billCtrl.text = ticket.billAmount?.toString() ?? '';
                                }),
                                child: Icon(LucideIcons.x, size: 16, color: Colors.grey),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: Text(
                                (ticket.billAmount != null && ticket.billAmount! > 0)
                                    ? '₹ ${ticket.billAmount!.toStringAsFixed(2)}'
                                    : '₹ 0.00',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
                                  fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4),
                            _EditButton(
                              onTap: () => setState(() {
                                _suppressNextTap = true;
                                _billCtrl.text = ticket.billAmount?.toString() ?? '';
                                _editingBill = true;
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (mounted) setState(() => _suppressNextTap = false);
                                });
                              }),
                            ),
                          ],
                        )
                  : Text(
                      (ticket.billAmount != null && ticket.billAmount! > 0)
                          ? '₹ ${ticket.billAmount!.toStringAsFixed(2)}'
                          : '₹ 0.00',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
                        fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            SizedBox(width: 32),
            // Bill Description cell with @ mentions
            Expanded(
              flex: 2,
              child: isClaimedByMe
                  ? _editingBillDesc
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _billDescCtrl,
                                    autofocus: true,
                                    style: TextStyle(fontSize: 13, color: context.adaptiveSlate900, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Type notes or @name...',
                                      hintStyle: TextStyle(fontSize: 11, color: context.adaptiveSlate400),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      border: const OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => _saveBillDescription(_billDescCtrl.text),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (_savingBillDesc)
                                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                else ...[
                                  InkWell(
                                    onTap: () => _saveBillDescription(_billDescCtrl.text),
                                    child: const Icon(LucideIcons.check, size: 16, color: Colors.green),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => setState(() {
                                      _editingBillDesc = false;
                                      _showMentions = false;
                                      _billDescCtrl.text = widget.ticket.billDescription ?? '';
                                    }),
                                    child: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                            if (_showMentions) ...[
                              const SizedBox(height: 4),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 150),
                                decoration: BoxDecoration(
                                  color: context.isDarkMode ? AppColors.slate800 : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
                                  ],
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: widget.agents.where((a) {
                                    final name = (a['full_name'] ?? a['username'] ?? '').toString().toLowerCase();
                                    return name.contains(_mentionQuery);
                                  }).map<Widget>((a) {
                                    final id = a['id'].toString();
                                    final name = (a['full_name'] ?? a['username'] ?? 'User').toString();
                                    return InkWell(
                                      onTap: () => _insertMention(id),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        child: Row(
                                          children: [
                                            Icon(LucideIcons.user, size: 14, color: AppColors.primary),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: (widget.ticket.billDescription != null && widget.ticket.billDescription!.isNotEmpty)
                                  ? _buildHighlightedMentionText(widget.ticket.billDescription!, widget.agentsMap, context)
                                  : Text(
                                      'Add description...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.adaptiveSlate400,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                            const SizedBox(width: 4),
                            _EditButton(
                              onTap: () => setState(() {
                                _suppressNextTap = true;
                                _billDescCtrl.text = widget.ticket.billDescription ?? '';
                                _editingBillDesc = true;
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (mounted) setState(() => _suppressNextTap = false);
                                });
                              }),
                            ),
                          ],
                        )
                  : (widget.ticket.billDescription != null && widget.ticket.billDescription!.isNotEmpty)
                      ? _buildHighlightedMentionText(widget.ticket.billDescription!, widget.agentsMap, context)
                      : Text(
                          '-',
                          style: TextStyle(fontSize: 13, color: context.adaptiveSlate400),
                        ),
            ),
            SizedBox(width: 32),
            // Payment collected
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: currentUser?.isAccountant == true
                    ? Transform.translate(
                        offset: const Offset(-12, 0),
                        child: DropdownButton<bool>(
                          isExpanded: true,
                          value: ticket.paymentCollected ?? false,
                          items: const [
                            DropdownMenuItem(value: false, child: Text('No')),
                            DropdownMenuItem(value: true, child: Text('Yes')),
                          ],
                          selectedItemBuilder: (BuildContext context) {
                            return [
                              Text(
                                'No',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
                                  fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Yes',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ];
                          },
                          onChanged: (val) async {
                            if (val != null && val != ticket.paymentCollected) {
                              final updated = ticket.copyWith(paymentCollected: val);
                              await ref.read(ticketUpdaterProvider.notifier).updateTicket(updated);
                            }
                          },
                          isDense: true,
                          underline: SizedBox(),
                          icon: Icon(Icons.arrow_drop_down, color: context.isDarkMode ? Colors.white : context.adaptiveSlate600),
                          iconSize: 20,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.isDarkMode ? Colors.white : context.adaptiveSlate700,
                            fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      )
                    : Text(
                        (ticket.paymentCollected ?? false) ? 'Yes' : 'No',
                        style: TextStyle(
                          fontSize: 13,
                          color: (ticket.paymentCollected ?? false) ? Colors.green : (context.isDarkMode ? Colors.white : context.adaptiveSlate600),
                          fontWeight: (ticket.paymentCollected ?? false) ? FontWeight.w600 : (context.isDarkMode ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
              ),
            ),
            SizedBox(width: 32),
            // AMC
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: isClaimedByMe
                    ? Transform.translate(
                        offset: const Offset(-12, 0),
                        child: DropdownButton<bool?>(
                          isExpanded: true,
                          value: ticket.hasAmc,
                          items: const [
                            DropdownMenuItem(value: null, child: SizedBox.shrink()),
                            DropdownMenuItem(value: false, child: Text('No')),
                            DropdownMenuItem(value: true, child: Text('Yes')),
                          ],
                          selectedItemBuilder: (BuildContext context) {
                            return [
                              SizedBox.shrink(),
                              SizedBox.shrink(), // Don't show 'No' text, just the dropdown arrow
                              Text(
                                'Yes',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ];
                          },
                          onChanged: (val) async {
                            if (val != null && val != ticket.hasAmc) {
                              final updated = ticket.copyWith(hasAmc: val);
                              await ref.read(ticketUpdaterProvider.notifier).updateTicket(updated);
                            }
                          },
                          isDense: true,
                          underline: SizedBox(),
                          icon: Icon(Icons.arrow_drop_down, color: context.isDarkMode ? Colors.white : context.adaptiveSlate600),
                          iconSize: 20,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.isDarkMode ? Colors.white : context.adaptiveSlate700,
                            fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      )
                    : Text(
                        ticket.hasAmc == true ? 'Yes' : '', // Don't show 'No' when not editable
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 32),
            // Completed Date
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(LucideIcons.calendarDays, size: 14, color: context.isDarkMode ? Colors.white : context.adaptiveSlate400),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      () {
                        // Use completedDate (completed_at) if available
                        if (ticket.completedDate != null) {
                          return DateFormat('dd/MM/yyyy').format(ticket.completedDate!.toLocal());
                        }
                        // For resolved/closed/billed tickets without completed_at, fall back to updatedAt
                        const resolvedStatuses = {'Resolved', 'Closed', 'BillRaised', 'BillProcessed'};
                        if (resolvedStatuses.contains(ticket.status) && ticket.updatedAt != null) {
                          return DateFormat('dd/MM/yyyy').format(ticket.updatedAt!.toLocal());
                        }
                        return '';
                      }(),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
                        fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 4),
                  if (isClaimedByMe)
                    _savingCompletedDate
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : _EditButton(
                            onTap: () async {
                              setState(() => _suppressNextTap = true);
                              final initialDate = ticket.completedDate ?? ticket.updatedAt ?? DateTime.now();
                              final date = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (date != null && mounted) {
                                _saveCompletedDate(date);
                              }
                              if (mounted) setState(() => _suppressNextTap = false);
                            },
                          ),
                ],
              ),
            ),
            SizedBox(width: 32),
            // Reported Date
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(LucideIcons.calendarDays, size: 14, color: context.isDarkMode ? Colors.white : context.adaptiveSlate400),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      ticket.createdAt != null ? DateFormat('dd/MM/yyyy').format(ticket.createdAt!.toLocal()) : '',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
                        fontWeight: context.isDarkMode ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 4),
                  if (isClaimedByMe)
                    _savingReportedDate
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : _EditButton(
                            onTap: () async {
                              setState(() => _suppressNextTap = true);
                              final initialDate = ticket.createdAt ?? DateTime.now();
                              final date = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (date != null && mounted) {
                                _saveReportedDate(date);
                              }
                              if (mounted) setState(() => _suppressNextTap = false);
                            },
                          ),
                ],
              ),
            ),
            // Delete button (conditionally shown)
            if (canDelete)
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: _isDeleting
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : InkWell(
                        onTap: _deleteTicket,
                        child: Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                      ),
              )
            else
              SizedBox(width: 34), // Maintain spacing if no delete button
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status, bool isUnclaimedTab, bool isClaimed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'new':
        // If the ticket is claimed (has assignedTo), show "In Progress"
        // Otherwise show "Unclaimed"
        if (isClaimed) {
          textColor = isDark ? Colors.orange.shade300 : const Color(0xFFEA580C);
          displayText = 'In Progress';
        } else {
          textColor = isDark ? Colors.red.shade300 : const Color(0xFFDC2626);
          displayText = 'Unclaimed';
        }
        break;
      case 'open':
        textColor = isDark ? Colors.blue.shade300 : const Color(0xFF1E40AF);
        displayText = 'Open';
        break;
      case 'inprogress':
      case 'in_progress':
        textColor = isDark ? Colors.orange.shade300 : const Color(0xFFEA580C);
        displayText = 'In Progress';
        break;
      case 'resolved':
        textColor = isDark ? Colors.green.shade300 : const Color(0xFF16A34A);
        displayText = 'Resolved';
        break;
      case 'closed':
        textColor = isDark ? AppColors.slate300 : AppColors.slate600;
        displayText = 'Closed';
        break;
      case 'onhold':
      case 'on_hold':
        textColor = isDark ? Colors.amber.shade300 : const Color(0xFFD97706);
        displayText = 'On Hold';
        break;
      case 'waitingforcustomer':
      case 'waiting_for_customer':
        textColor = isDark ? AppColors.slate300 : AppColors.slate600;
        displayText = 'Waiting';
        break;
      case 'billraised':
      case 'bill_raised':
        textColor = isDark ? Colors.red.shade300 : const Color(0xFFDC2626);
        displayText = 'Bill Raised';
        break;
      case 'billprocessed':
      case 'bill_processed':
        textColor = isDark ? Colors.green.shade400 : const Color(0xFF059669);
        displayText = 'Billed';
        break;
      default:
        textColor = isDark ? AppColors.slate300 : AppColors.slate600;
        displayText = status;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final color = isDark ? Colors.white : AppColors.primary;

    return GestureDetector(
      // Absorb the event so it doesn't bubble to the row's InkWell
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Listener(
        onPointerDown: (event) {},
        child: Tooltip(
          message: 'Click to edit',
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(LucideIcons.pencil, size: 12, color: color),
          ),
        ),
      ),
    );
  }
}

Widget _buildHighlightedMentionText(String text, Map<String, dynamic> agentsMap, BuildContext context, {double fontSize = 13, bool isBold = false}) {
  if (text.isEmpty) return const SizedBox.shrink();
  final regExp = RegExp(r'@\[([a-zA-Z0-9\-]{1,40})\]');
  final spans = <InlineSpan>[];
  int lastMatchEnd = 0;

  for (final match in regExp.allMatches(text)) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd, match.start),
        style: TextStyle(
          fontSize: fontSize,
          color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
          fontWeight: isBold ? (context.isDarkMode ? FontWeight.bold : FontWeight.w500) : FontWeight.normal,
        ),
      ));
    }

    final agentId = match.group(1);
    final agentData = agentId != null ? agentsMap[agentId] : null;
    final agentName = agentData != null
        ? ((agentData['full_name'] ?? agentData['username']) ?? 'User').toString()
        : 'User';

    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          '@$agentName',
          style: TextStyle(
            fontSize: fontSize - 1,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    ));

    lastMatchEnd = match.end;
  }

  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastMatchEnd),
      style: TextStyle(
        fontSize: fontSize,
        color: context.isDarkMode ? Colors.white : context.adaptiveSlate600,
        fontWeight: isBold ? (context.isDarkMode ? FontWeight.bold : FontWeight.w500) : FontWeight.normal,
      ),
    ));
  }

  return RichText(
    text: TextSpan(children: spans),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}
