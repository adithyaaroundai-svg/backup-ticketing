import 'package:flutter/material.dart';
import '../../../customers/domain/entities/customer.dart';

/// AMC Status Badge - Shows green for active, red for expired
class AmcStatusBadge extends StatelessWidget {
  final Customer? customer;
  final bool showLabel;

  const AmcStatusBadge({
    super.key,
    required this.customer,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (customer == null || customer!.amcExpiryDate == null) {
      return const SizedBox.shrink();
    }

    final isActive = customer!.isAmcActive;
    final daysRemaining = customer!.amcDaysRemaining;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green : Colors.red,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.warning,
            size: 14,
            color: isActive ? Colors.green : Colors.red,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              isActive
                  ? 'AMC Active${daysRemaining < 30 ? " ($daysRemaining days)" : ""}'
                  : 'AMC Expired',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.green.shade900 : Colors.red.shade900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// TSS Status Badge - Shows Tally Software Services status
class TssStatusBadge extends StatelessWidget {
  final Customer? customer;

  const TssStatusBadge({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    if (customer == null || customer!.tssExpiryDate == null) {
      return const SizedBox.shrink();
    }

    final isActive = customer!.isTssActive;
    final daysRemaining = customer!.tssDaysRemaining;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.blue : Colors.orange,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.verified : Icons.info,
            size: 14,
            color: isActive ? Colors.blue : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isActive
                ? 'TSS Active${daysRemaining < 30 ? " ($daysRemaining days)" : ""}'
                : 'TSS Expired',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.blue.shade900 : Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
