import 'package:flutter/material.dart';

class CenterLoading extends StatelessWidget {
  const CenterLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class PriorityChip extends StatelessWidget {
  final String priority;
  const PriorityChip({super.key, required this.priority});

  Color _color() {
    switch (priority) {
      case 'A+':
        return Colors.red;
      case 'A':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(priority, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: _color(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color _color() {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      case 'working':
        return Colors.blue;
      case 'paused':
        return Colors.brown;
      case 'awaiting_confirmation':
        return Colors.purple;
      case 'ready_for_testing':
      case 'ready_for_implementation':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status.replaceAll('_', ' '),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: _color(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}

/// A tiny inline "Saved ✓" / "Save failed" flash indicator for autosaving
/// controls (board row dropdowns), shown via a SnackBar for simplicity and
/// consistency across the app.
void showSavedSnack(BuildContext context, {bool ok = true, String? message}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      backgroundColor: ok ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
      content: Text(message ?? (ok ? 'Saved \u2713' : 'Save failed')),
    ),
  );
}
