import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/design_system.dart';
import '../providers/deals_provider.dart';

class CreateDealDialog extends ConsumerStatefulWidget {
  const CreateDealDialog({super.key});

  @override
  ConsumerState<CreateDealDialog> createState() => _CreateDealDialogState();
}

class _CreateDealDialogState extends ConsumerState<CreateDealDialog> {
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _remarkController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedFollowUpDate;
  bool _isSubmitting = false;

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

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    String? followUpDateStr;
    if (_selectedFollowUpDate != null) {
      followUpDateStr = '${_selectedFollowUpDate!.year}-${_selectedFollowUpDate!.month.toString().padLeft(2, '0')}-${_selectedFollowUpDate!.day.toString().padLeft(2, '0')}';
    }

    setState(() => _isSubmitting = true);

    final error = await ref.read(dealControllerProvider.notifier).addDeal(
      name: name,
      companyName: _companyController.text.trim(),
      date: dateStr,
      remark: _remarkController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      followUpDate: followUpDateStr,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create deal: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deal created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create New Deal',
                  style: TextStyle(
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
            const SizedBox(height: 24),
            AppTextField(
              labelText: 'Deal Name',
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
              labelText: 'Remark',
              hintText: 'Optional notes...',
              controller: _remarkController,
            ),
            const SizedBox(height: 16),
            AppTextField(
              labelText: 'Phone Number',
              hintText: '+1 234 567 8900',
              controller: _phoneController,
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
                    const Icon(LucideIcons.calendarDays, size: 18, color: AppColors.slate500),
                    const SizedBox(width: 12),
                    Text(
                      _selectedFollowUpDate != null 
                        ? '${_selectedFollowUpDate!.year}-${_selectedFollowUpDate!.month.toString().padLeft(2, '0')}-${_selectedFollowUpDate!.day.toString().padLeft(2, '0')}'
                        : 'Select a follow up date',
                      style: TextStyle(
                        fontSize: 14, 
                        color: _selectedFollowUpDate != null ? AppColors.slate900 : AppColors.slate400,
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
            const SizedBox(height: 32),
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
                    backgroundColor: const Color(0xFF10B981), // Emerald
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
                      : const Text('Create Deal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
