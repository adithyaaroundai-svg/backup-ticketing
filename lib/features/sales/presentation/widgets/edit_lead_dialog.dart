import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_provider.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';

class EditLeadDialog extends ConsumerStatefulWidget {
  final Lead lead;

  const EditLeadDialog({super.key, required this.lead});

  @override
  ConsumerState<EditLeadDialog> createState() => _EditLeadDialogState();
}

class _EditLeadDialogState extends ConsumerState<EditLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _companyNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _descriptionController;
  late TextEditingController _otherSourceController;
  late TextEditingController _stpNameController;

  String? _selectedOwner;
  String? _selectedSource;
  String? _selectedStatus;
  String? _selectedProduct;
  DateTime? _selectedFollowUpDate;
  bool _isSubmitting = false;

  final List<String> _productOptions = [
    'Tally prime Silver',
    'Tally prime Gold',
    'Tss renewal',
    'Tally prime server',
    'Customisation',
    'Mobile App',
    'WhatsApp',
    'Tally Upgrade silver to Gold',
  ];

  final List<String> _statusOptions = [
    'New Lead',
    'Contacted',
    'Qualified',
    'Proposal',
    'Negotiation',
    'Won',
    'Lost',
  ];

  final List<String> _sourceOptions = [
    'Tally',
    'Online',
    'Incoming call',
    'STP',
    'Existing Customer',
    'Other Customer referral',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(text: widget.lead.customerName ?? '');
    _companyNameController = TextEditingController(text: widget.lead.companyName);
    _phoneNumberController = TextEditingController(text: widget.lead.phoneNumber ?? '');
    _descriptionController = TextEditingController(text: widget.lead.description ?? '');
    
    _selectedFollowUpDate = widget.lead.followUpDate;
    _selectedOwner = widget.lead.owner;
    _selectedProduct = widget.lead.product;

    // Normalize initial status for UI dropdown
    final rawStatus = widget.lead.status;
    if (rawStatus == 'pending' || rawStatus == 'New' || rawStatus == 'New Lead') {
      _selectedStatus = 'New Lead';
    } else if (rawStatus == 'win' || rawStatus == 'Won') {
      _selectedStatus = 'Won';
    } else if (rawStatus == 'loss' || rawStatus == 'Lost') {
      _selectedStatus = 'Lost';
    } else if (_statusOptions.contains(rawStatus)) {
      _selectedStatus = rawStatus;
    } else {
      _selectedStatus = 'New Lead';
    }

    final rawSource = widget.lead.source;
    if (rawSource != null && rawSource.startsWith('STP - ')) {
      _selectedSource = 'STP';
      _otherSourceController = TextEditingController();
      _stpNameController = TextEditingController(text: rawSource.substring(6).trim());
    } else if (rawSource != null && _sourceOptions.contains(rawSource)) {
      _selectedSource = rawSource;
      _otherSourceController = TextEditingController();
      _stpNameController = TextEditingController();
    } else if (rawSource != null && rawSource.isNotEmpty) {
      _selectedSource = 'Other';
      _otherSourceController = TextEditingController(text: rawSource);
      _stpNameController = TextEditingController();
    } else {
      _selectedSource = null;
      _otherSourceController = TextEditingController();
      _stpNameController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _companyNameController.dispose();
    _phoneNumberController.dispose();
    _descriptionController.dispose();
    _otherSourceController.dispose();
    _stpNameController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? label,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      hintStyle: TextStyle(color: context.adaptiveSlate400),
      labelStyle: TextStyle(color: context.adaptiveSlate500),
      border: _outlineBorder(context.adaptiveBorder),
      enabledBorder: _outlineBorder(context.adaptiveBorder),
      focusedBorder: _outlineBorder(AppColors.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  OutlineInputBorder _outlineBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: 1.2),
    );
  }

  Future<void> _selectFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedFollowUpDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: context.isDarkMode
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: Colors.white,
                    surface: context.adaptiveCard,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: AppColors.slate900,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedFollowUpDate = picked;
      });
    }
  }

  Future<void> _saveLead() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final sourceValue = _selectedSource == 'Other'
        ? _otherSourceController.text.trim()
        : (_selectedSource == 'STP' && _stpNameController.text.trim().isNotEmpty
            ? 'STP - ${_stpNameController.text.trim()}'
            : _selectedSource);

    final updates = <String, dynamic>{
      'customer_name': _customerNameController.text.trim().isNotEmpty
          ? _customerNameController.text.trim()
          : null,
      'company_name': _companyNameController.text.trim().isNotEmpty
          ? _companyNameController.text.trim()
          : (_customerNameController.text.trim().isNotEmpty
              ? _customerNameController.text.trim()
              : 'Unnamed Company'),
      'phone_number': _phoneNumberController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      'status': _selectedStatus ?? 'New Lead',
      'owner': _selectedOwner,
      'source': sourceValue,
      'product': _selectedProduct,
      'follow_up_date': _selectedFollowUpDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedFollowUpDate!)
          : null,
    };

    try {
      await ref
          .read(leadControllerProvider.notifier)
          .updateLeadDetails(widget.lead.id, updates);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lead updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating lead: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(agentsListProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = math.max(280.0, math.min(screenWidth - 72, 860.0));

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 36, 24, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Material(
          elevation: 12,
          color: context.isDarkMode ? const Color(0xFF1E2124) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: MediaQuery.of(context).size.height * 0.9),
            child: Container(
              width: dialogWidth,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Lead Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: context.adaptiveSlate900,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // 2-Column Grid Layout
                      ResponsiveFormRow(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer Name
                              Text(
                                'Customer Name *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: context.adaptiveSlate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _customerNameController,
                                decoration: _inputDecoration(
                                  hint: 'Enter customer name',
                                  prefixIcon: const Icon(LucideIcons.user, size: 16),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Customer name is required';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // Company Name
                              Text(
                                'Company Name *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: context.adaptiveSlate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _companyNameController,
                                decoration: _inputDecoration(
                                  hint: 'Enter company name',
                                  prefixIcon: const Icon(LucideIcons.building, size: 16),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Company name is required';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // Phone Number
                              Text(
                                'Phone Number *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: context.adaptiveSlate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _phoneNumberController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: _inputDecoration(
                                  hint: 'Enter 10-digit phone number',
                                  prefixIcon: const Icon(LucideIcons.phone, size: 16),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Phone number is required';
                                  }
                                  if (value.trim().length != 10) {
                                    return 'Phone number must be exactly 10 digits';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // Product
                              Text(
                                'Product',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: context.adaptiveSlate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedProduct,
                                isExpanded: true,
                                dropdownColor: context.isDarkMode ? const Color(0xFF1E2124) : Colors.white,
                                decoration: _inputDecoration(
                                  hint: 'Select product',
                                  prefixIcon: const Icon(LucideIcons.package, size: 16),
                                ),
                                items: _productOptions.map((String product) {
                                  return DropdownMenuItem<String>(
                                    value: product,
                                    child: Text(
                                      product,
                                      style: TextStyle(color: context.adaptiveSlate900, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedProduct = newValue;
                                  });
                                },
                              ),

                              const SizedBox(height: 14),

                              // Status
                              Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: context.adaptiveSlate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                decoration: _inputDecoration(
                                  hint: 'Select status',
                                  prefixIcon: const Icon(LucideIcons.layers, size: 16),
                                ),
                                items: _statusOptions.map((String s) {
                                  return DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(s),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedStatus = newValue;
                                  });
                                },
                              ),
                            ],
                          ),

                          // Right Column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Follow-up Date
                              Text(
                                'Follow-up Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: context.adaptiveSlate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _selectFollowUpDate,
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: _inputDecoration(
                                    hint: 'Select follow-up date',
                                    prefixIcon: const Icon(LucideIcons.calendar, size: 16),
                                    suffixIcon: _selectedFollowUpDate != null
                                        ? IconButton(
                                            icon: const Icon(LucideIcons.x, size: 16),
                                            onPressed: () {
                                              setState(() => _selectedFollowUpDate = null);
                                            },
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    _selectedFollowUpDate != null
                                        ? DateFormat('EEE, MMM d, yyyy').format(_selectedFollowUpDate!)
                                        : 'No date set',
                                    style: TextStyle(
                                      color: _selectedFollowUpDate != null
                                          ? context.adaptiveSlate900
                                          : context.adaptiveSlate400,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Owner
                              Text(
                                'Owner *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: context.adaptiveSlate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              agentsAsync.when(
                                data: (agents) {
                                  final allowedOwnerIds = {
                                    '0a5aeeb8-9544-4dc8-920f-e26c192b0dd3',
                                    '5a06a8df-97f1-4dbf-bc13-9724a3c779c1',
                                    '14db36db-0cb9-44ef-8032-d9610b3bc797',
                                    'd8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c',
                                    'b77b3738-4dfc-4515-a1fd-d6fb170423f4',
                                  };
                                  final ownerOptions = agents
                                      .where((a) => allowedOwnerIds.contains(a['id']?.toString()))
                                      .map<String>((a) {
                                        return (a['full_name'] ?? a['username'] ?? '').toString();
                                      })
                                      .toList();
                                  
                                  // Make sure selected owner is in options if not null
                                  if (_selectedOwner != null && !ownerOptions.contains(_selectedOwner)) {
                                    ownerOptions.add(_selectedOwner!);
                                  }

                                  if (!ownerOptions.contains('Admin')) {
                                    ownerOptions.add('Admin');
                                  }

                                  return DropdownButtonFormField<String>(
                                    value: _selectedOwner,
                                    decoration: _inputDecoration(
                                      hint: 'Select owner',
                                      prefixIcon: const Icon(LucideIcons.userCheck, size: 16),
                                    ),
                                    items: ownerOptions.map((String owner) {
                                      return DropdownMenuItem<String>(
                                        value: owner,
                                        child: Text(owner),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedOwner = newValue;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Owner is required';
                                      }
                                      return null;
                                    },
                                  );
                                },
                                loading: () => const LinearProgressIndicator(),
                                error: (_, __) => const Text('Error loading agents'),
                              ),

                              const SizedBox(height: 14),

                              // Source of Enquiry
                              Text(
                                'Source of Enquiry',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: context.adaptiveSlate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (_selectedSource == 'Other')
                                TextFormField(
                                  controller: _otherSourceController,
                                  autofocus: true,
                                  decoration: _inputDecoration(
                                    hint: 'Type custom source details...',
                                    prefixIcon: const Icon(LucideIcons.globe, size: 16),
                                    suffixIcon: IconButton(
                                      tooltip: 'Select from preset list',
                                      icon: Icon(LucideIcons.x, size: 16, color: context.adaptiveSlate400),
                                      onPressed: () {
                                        setState(() {
                                          _selectedSource = null;
                                          _otherSourceController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  value: _selectedSource,
                                  decoration: _inputDecoration(
                                    hint: 'Select source',
                                    prefixIcon: const Icon(LucideIcons.globe, size: 16),
                                  ),
                                  items: _sourceOptions.map((String source) {
                                    return DropdownMenuItem<String>(
                                      value: source,
                                      child: Text(source),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedSource = newValue;
                                      if (newValue != 'Other') {
                                        _otherSourceController.clear();
                                      }
                                      if (newValue != 'STP') {
                                        _stpNameController.clear();
                                      }
                                    });
                                  },
                                ),

                              if (_selectedSource == 'STP') ...[
                                const SizedBox(height: 14),
                                Text(
                                  'STP Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: context.adaptiveSlate900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _stpNameController,
                                  autofocus: true,
                                  decoration: _inputDecoration(
                                    hint: 'Enter STP name',
                                    prefixIcon: const Icon(LucideIcons.userCheck, size: 16),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      
                      // Description Full Width
                      Text(
                        'Description / Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: context.adaptiveSlate900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          hint: 'Add any specific notes or requirements about this lead...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 36),
                            child: Icon(LucideIcons.fileText, size: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Actions
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 10,
                        overflowSpacing: 10,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: context.adaptiveSlate600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: _isSubmitting ? null : _saveLead,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
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
        ),
      ),
    );
  }
}
