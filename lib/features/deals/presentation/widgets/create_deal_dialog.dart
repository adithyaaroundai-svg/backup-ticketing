import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/design_system.dart';
import '../providers/deals_provider.dart';

class CreateDealDialog extends ConsumerStatefulWidget {
  final Deal? dealToEdit;
  final String? defaultDate;

  const CreateDealDialog({
    super.key,
    this.dealToEdit,
    this.defaultDate,
  });

  @override
  ConsumerState<CreateDealDialog> createState() => _CreateDealDialogState();
}

class _CreateDealDialogState extends ConsumerState<CreateDealDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _remarkController;
  late final TextEditingController _phoneController;
  late DateTime _selectedDate;
  DateTime? _selectedFollowUpDate;
  bool _isSubmitting = false;

  bool get _isEditing => widget.dealToEdit != null;

  @override
  void initState() {
    super.initState();
    final deal = widget.dealToEdit;
    _nameController = TextEditingController(text: deal?.name ?? '');
    _companyController = TextEditingController(text: deal?.companyName ?? '');
    _remarkController = TextEditingController(text: deal?.remark ?? '');
    _phoneController = TextEditingController(text: deal?.phoneNumber ?? '');

    if (deal != null) {
      _selectedDate = DateTime.tryParse(deal.date) ?? DateTime.now();
      _selectedFollowUpDate = deal.followUpDate != null
          ? DateTime.tryParse(deal.followUpDate!)
          : null;
    } else {
      _selectedDate = widget.defaultDate != null
          ? (DateTime.tryParse(widget.defaultDate!) ?? DateTime.now())
          : DateTime.now();
      _selectedFollowUpDate = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _remarkController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Deal Name')),
      );
      return;
    }

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    String? followUpDateStr;
    if (_selectedFollowUpDate != null) {
      followUpDateStr =
          '${_selectedFollowUpDate!.year}-${_selectedFollowUpDate!.month.toString().padLeft(2, '0')}-${_selectedFollowUpDate!.day.toString().padLeft(2, '0')}';
    }

    setState(() => _isSubmitting = true);

    String? error;
    if (_isEditing) {
      error = await ref.read(dealControllerProvider.notifier).updateDeal(
            id: widget.dealToEdit!.id,
            name: name,
            companyName: _companyController.text.trim(),
            date: dateStr,
            remark: _remarkController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            followUpDate: followUpDateStr,
          );
    } else {
      error = await ref.read(dealControllerProvider.notifier).addDeal(
            name: name,
            companyName: _companyController.text.trim(),
            date: dateStr,
            remark: _remarkController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            followUpDate: followUpDateStr,
          );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Deal updated successfully' : 'Deal created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Deal' : 'Create New Deal',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate900,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, color: AppColors.slate400),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppTextField(
                labelText: 'Deal Name *',
                hintText: 'e.g. Software License Renewal',
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              AppTextField(
                labelText: 'Company Name',
                hintText: 'e.g. Acme Technologies',
                controller: _companyController,
              ),
              const SizedBox(height: 16),
              const Text(
                'Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate700,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.slate200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendarDays, size: 18, color: AppColors.slate500),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14, color: AppColors.slate900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                labelText: 'Phone Number',
                hintText: '+91 9876543210',
                controller: _phoneController,
              ),
              const SizedBox(height: 16),
              AppTextField(
                labelText: 'Remark',
                hintText: 'Optional notes...',
                controller: _remarkController,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text(
                'Follow Up Date (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate700,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedFollowUpDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedFollowUpDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.slate200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendarClock, size: 18, color: AppColors.slate500),
                      const SizedBox(width: 12),
                      Text(
                        _selectedFollowUpDate != null
                            ? '${_selectedFollowUpDate!.year}-${_selectedFollowUpDate!.month.toString().padLeft(2, '0')}-${_selectedFollowUpDate!.day.toString().padLeft(2, '0')}'
                            : 'Select a follow up date',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedFollowUpDate != null
                              ? AppColors.slate900
                              : AppColors.slate400,
                        ),
                      ),
                      if (_selectedFollowUpDate != null) ...[
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _selectedFollowUpDate = null),
                          child: const Icon(LucideIcons.x, size: 16, color: AppColors.slate400),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.slate600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Create Deal'),
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
