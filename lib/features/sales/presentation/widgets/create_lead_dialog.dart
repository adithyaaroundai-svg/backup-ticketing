import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../providers/lead_provider.dart';
import 'lead_success_celebration.dart';

class CreateLeadDialog extends ConsumerStatefulWidget {
  const CreateLeadDialog({super.key});

  @override
  ConsumerState<CreateLeadDialog> createState() => _CreateLeadDialogState();
}

class _CreateLeadDialogState extends ConsumerState<CreateLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _otherSourceController = TextEditingController();
  final _stpNameController = TextEditingController();

  String? _selectedOwner;
  String? _selectedSource;
  String? _selectedProduct;
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
  void dispose() {
    _customerNameController.dispose();
    _companyNameController.dispose();
    _phoneNumberController.dispose();
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
      fillColor: context.isDarkMode ? Colors.white.withValues(alpha: 0.05) : null,
      filled: context.isDarkMode,
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

  Future<void> _createLead() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final container = ProviderScope.containerOf(context, listen: false);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final currentUser = ref.read(authProvider);

    // Capture user data before async operations
    final senderId = currentUser?.id;
    final senderName = currentUser?.fullName;
    final senderRole = currentUser?.role;
    final senderAvatarUrl = currentUser?.avatarUrl;

    try {
      final sourceValue = _selectedSource == 'Other'
          ? _otherSourceController.text.trim()
          : (_selectedSource == 'STP' && _stpNameController.text.trim().isNotEmpty
              ? 'STP - ${_stpNameController.text.trim()}'
              : _selectedSource);

      final leadData = {
        'customer_name': _customerNameController.text.trim().isNotEmpty
            ? _customerNameController.text.trim()
            : null,
        'company_name': _companyNameController.text.trim().isNotEmpty
            ? _companyNameController.text.trim()
            : (_customerNameController.text.trim().isNotEmpty
                ? _customerNameController.text.trim()
                : 'Unnamed Company'),
        'status': 'New Lead',
        'phone_number': _phoneNumberController.text.trim(),
        'owner': _selectedOwner ?? currentUser?.fullName ?? 'Unassigned',
        'source': sourceValue,
        'product': _selectedProduct,
        'demo_needed': 'Yes',
        'created_by': currentUser?.id,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await Supabase.instance.client.from('leads').insert(leadData);

      // Invalidate the leads provider so the pipeline updates
      container.invalidate(leadsProvider);

      // Prepare chat content
      String chatContent = [
        '🎯 New Lead (Demo Requested)',
        'Company: ${leadData['company_name'] ?? 'Not provided'}',
        if (leadData['customer_name'] != null) 'Customer: ${leadData['customer_name']}',
        'Phone: ${leadData['phone_number']}',
        if (leadData['source'] != null) 'Source: ${leadData['source']}',
        if (leadData['product'] != null) 'Product: ${leadData['product']}',
        'Owner: ${leadData['owner']}',
        'Status: New Lead',
      ].join('\n');

      // Close dialog immediately
      if (mounted) {
        LeadSuccessCelebration.show(context);
        rootNavigator.pop(true);
      }

      // Send to chat after closing
      if (senderId != null &&
          senderName != null &&
          senderRole != null) {
        try {
          // Send to sales-channel
          await container.read(chatControllerProvider.notifier).sendMessage(
                senderId: senderId,
                senderName: senderName,
                senderRole: senderRole,
                content: chatContent,
                senderAvatarUrl: senderAvatarUrl,
                channel: 'sales-channel',
              );
        } catch (error) {
          messenger?.showSnackBar(
            SnackBar(
              content: Text('Lead created, but chat post failed: $error'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Error creating lead: $e'),
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
        padding: EdgeInsets.fromLTRB(24, 48, 24, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Material(
          elevation: 12,
          color: context.isDarkMode ? const Color(0xFF1E2124) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogWidth),
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
                            'Create New Lead',
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
                                  style: TextStyle(color: context.adaptiveSlate900, fontSize: 12),
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
                                  'Company Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: context.adaptiveSlate900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _companyNameController,
                                  style: TextStyle(color: context.adaptiveSlate900, fontSize: 12),
                                  decoration: _inputDecoration(
                                    hint: 'Enter company name',
                                    prefixIcon: const Icon(LucideIcons.building, size: 16),
                                  ),
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
                                  style: TextStyle(color: context.adaptiveSlate900, fontSize: 12),
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


                            ],
                          ),

                          // Right Column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                    
                                    if (!ownerOptions.contains('Admin')) {
                                      ownerOptions.add('Admin');
                                    }
                                    return DropdownButtonFormField<String>(
                                      value: _selectedOwner,
                                      isExpanded: true,
                                      dropdownColor: context.isDarkMode ? const Color(0xFF1E2124) : Colors.white,
                                      decoration: _inputDecoration(
                                        hint: 'Select owner',
                                        prefixIcon: const Icon(LucideIcons.userCheck, size: 16),
                                      ),
                                      items: ownerOptions.map((String owner) {
                                        return DropdownMenuItem<String>(
                                          value: owner,
                                          child: Text(
                                            owner,
                                            style: TextStyle(color: context.adaptiveSlate900, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                                    style: TextStyle(color: context.adaptiveSlate900, fontSize: 12),
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
                                    isExpanded: true,
                                    dropdownColor: context.isDarkMode ? const Color(0xFF1E2124) : Colors.white,
                                    decoration: _inputDecoration(
                                      hint: 'Select source',
                                      prefixIcon: const Icon(LucideIcons.globe, size: 16),
                                    ),
                                    items: _sourceOptions.map((String source) {
                                      return DropdownMenuItem<String>(
                                        value: source,
                                        child: Text(
                                          source,
                                          style: TextStyle(color: context.adaptiveSlate900, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                                    style: TextStyle(color: context.adaptiveSlate900, fontSize: 12),
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


                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 10,
                        overflowSpacing: 10,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                            onPressed: _isSubmitting ? null : _createLead,
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
                                    'Save Lead',
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
