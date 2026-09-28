import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../sales/domain/entities/lead.dart';

const leadCardMarker = '__LEAD_CARD__';

class ForwardedLeadData {
  final String companyName;
  final String status;
  final double amount;
  final String? phoneNumber;
  final String? customerName;
  final String? description;
  final DateTime? followUpDate;
  final String? product;
  final String? source;
  final String? owner;

  const ForwardedLeadData({
    required this.companyName,
    required this.status,
    required this.amount,
    this.phoneNumber,
    this.customerName,
    this.description,
    this.followUpDate,
    this.product,
    this.source,
    this.owner,
  });

  String get statusLabel {
    if (status == 'pending' || status == 'New' || status == 'New Lead') {
      return 'New Lead';
    }
    if (status == 'win') return 'Won';
    if (status == 'loss') return 'Lost';
    return status;
  }

  factory ForwardedLeadData.fromLead(Lead lead) {
    return ForwardedLeadData(
      companyName: lead.companyName,
      status: lead.status,
      amount: lead.amount,
      phoneNumber: lead.phoneNumber,
      customerName: lead.customerName,
      description: lead.description,
      followUpDate: lead.followUpDate,
      product: lead.product,
      source: lead.source,
      owner: lead.owner,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'status': status,
        'amount': amount,
        'phoneNumber': phoneNumber,
        'customerName': customerName,
        'description': description,
        'followUpDate': followUpDate?.toUtc().toIso8601String(),
        'product': product,
        'source': source,
        'owner': owner,
      };

  factory ForwardedLeadData.fromJson(Map<String, dynamic> json) {
    return ForwardedLeadData(
      companyName: json['companyName']?.toString() ?? 'Unnamed Company',
      status: json['status']?.toString() ?? 'New Lead',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      phoneNumber: json['phoneNumber']?.toString(),
      customerName: json['customerName']?.toString(),
      description: json['description']?.toString(),
      followUpDate: DateTime.tryParse(json['followUpDate']?.toString() ?? '')?.toLocal(),
      product: json['product']?.toString(),
      source: json['source']?.toString(),
      owner: json['owner']?.toString(),
    );
  }
}

String encodeLeadCardMessage(Lead lead) {
  return '$leadCardMarker${jsonEncode(ForwardedLeadData.fromLead(lead).toJson())}';
}

ForwardedLeadData? tryParseLeadCard(String content) {
  final trimmed = content.trim();
  if (trimmed.startsWith(leadCardMarker)) {
    try {
      final raw = jsonDecode(trimmed.substring(leadCardMarker.length));
      if (raw is! Map) return null;
      return ForwardedLeadData.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }
  return _parsePlainLeadForward(trimmed);
}

ForwardedLeadData? _parsePlainLeadForward(String content) {
  final lines = content.split('\n');
  if (lines.isEmpty || lines.first.trim().toLowerCase() != 'forwarded lead') {
    return null;
  }

  String? company;
  String? customer;
  String? phone;
  String? product;
  String? status;
  String? amountRaw;
  String? followUpRaw;
  final note = StringBuffer();
  var inNote = false;

  for (final raw in lines.skip(1)) {
    final line = raw.trimRight();
    if (!inNote && line.trim().isEmpty) continue;

    String? take(String key) {
      final prefix = '$key:';
      if (line.trim().toLowerCase().startsWith(prefix.toLowerCase())) {
        return line.trim().substring(prefix.length).trim();
      }
      return null;
    }

    if (inNote) {
      if (note.isNotEmpty) note.write('\n');
      note.write(line.trim());
      continue;
    }

    final noteLine = take('Note');
    if (noteLine != null) {
      inNote = true;
      if (noteLine.isNotEmpty) note.write(noteLine);
      continue;
    }

    company ??= take('Company');
    customer ??= take('Customer');
    phone ??= take('Phone');
    product ??= take('Product');
    status ??= take('Status');
    amountRaw ??= take('Amount');
    followUpRaw ??= take('Follow-up');
  }

  if (company == null || company.isEmpty) return null;

  DateTime? followUp;
  if (followUpRaw != null && followUpRaw.isNotEmpty) {
    try {
      followUp = DateFormat('dd MMM yyyy, h:mm a').parse(followUpRaw);
    } catch (_) {
      followUp = null;
    }
  }

  final amountText = (amountRaw ?? '').replaceAll(RegExp(r'[^0-9.]'), '');

  return ForwardedLeadData(
    companyName: company,
    status: (status == null || status.isEmpty) ? 'New Lead' : status,
    amount: double.tryParse(amountText) ?? 0,
    phoneNumber: phone,
    customerName: customer,
    description: note.isEmpty ? null : note.toString(),
    followUpDate: followUp,
    product: product,
  );
}

Color _statusColor(String label) {
  switch (label.toLowerCase()) {
    case 'contacted':
      return const Color(0xFF2563EB);
    case 'qualified':
      return const Color(0xFF0F766E);
    case 'negotiation':
      return const Color(0xFFEA580C);
    case 'won':
      return const Color(0xFF059669);
    case 'lost':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF475569);
  }
}

class ForwardedLeadCardView extends StatelessWidget {
  final ForwardedLeadData lead;

  const ForwardedLeadCardView({super.key, required this.lead});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final accent = _statusColor(lead.statusLabel);
    final amount = lead.amount > 0
        ? NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(lead.amount)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showForwardedLeadDetails(context, lead),
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dark ? Colors.white12 : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.22 : 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.briefcase, size: 13, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      'LEAD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: accent,
                      ),
                    ),
                    const Spacer(),
                    _StatusChip(label: lead.statusLabel, color: accent),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.companyName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    if ((lead.customerName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        lead.customerName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.adaptiveSlate500),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if ((lead.product ?? '').isNotEmpty)
                      _MetaLine(icon: LucideIcons.package, text: lead.product!),
                    if ((lead.phoneNumber ?? '').isNotEmpty)
                      _MetaLine(icon: LucideIcons.phone, text: lead.phoneNumber!),
                    if (amount != null)
                      _MetaLine(icon: LucideIcons.indianRupee, text: amount),
                    const SizedBox(height: 8),
                    Text(
                      'View details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: context.adaptiveSlate400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.adaptiveSlate600),
            ),
          ),
        ],
      ),
    );
  }
}

void showForwardedLeadDetails(BuildContext context, ForwardedLeadData lead) {
  final amount = lead.amount > 0
      ? NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(lead.amount)
      : null;
  final followUp = lead.followUpDate == null
      ? null
      : DateFormat('dd MMM yyyy, h:mm a').format(lead.followUpDate!);
  final fields = <(String, String)>[
    ('Status', lead.statusLabel),
    if ((lead.customerName ?? '').isNotEmpty) ('Contact', lead.customerName!),
    if ((lead.phoneNumber ?? '').isNotEmpty) ('Phone', lead.phoneNumber!),
    if ((lead.product ?? '').isNotEmpty) ('Product', lead.product!),
    if (amount != null) ('Value', amount),
    if (followUp != null) ('Follow-up', followUp),
    if ((lead.source ?? '').isNotEmpty) ('Source', lead.source!),
    if ((lead.owner ?? '').isNotEmpty) ('Owner', lead.owner!),
  ];
  final accent = _statusColor(lead.statusLabel);

  showDialog<void>(
    context: context,
    builder: (context) {
      final dark = context.isDarkMode;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.18 : 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FORWARDED LEAD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lead.companyName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: dark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    for (final field in fields)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 88,
                              child: Text(
                                field.$1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.adaptiveSlate400,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                field.$2,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: dark ? Colors.white : AppColors.slate800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if ((lead.description ?? '').trim().isNotEmpty) ...[
                      const Divider(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          lead.description!.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: context.adaptiveSlate600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
