import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum StatusVariant {
  success, // Green (Active, Resolved)
  warning, // Amber (Expiring, In Progress)
  error, // Red (Expired, Critical)
  info, // Blue (New, TSS)
  neutral, // Gray (Closed, Unknown)
  primary, // Primary brand color
}

enum StatusBadgeSize { small, medium, large }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusVariant variant;
  final bool outlined;
  final IconData? icon;
  final StatusBadgeSize size;

  const StatusBadge({
    super.key,
    required this.label,
    required this.variant,
    this.outlined = false,
    this.icon,
    this.size = StatusBadgeSize.medium,
  });

  Color get _color {
    switch (variant) {
      case StatusVariant.success:
        return AppColors.success;
      case StatusVariant.warning:
        return AppColors.warning;
      case StatusVariant.error:
        return AppColors.error;
      case StatusVariant.info:
        return AppColors.info;
      case StatusVariant.neutral:
        return AppColors.slate500;
      case StatusVariant.primary:
        return AppColors.primary;
    }
  }

  Color get _backgroundColor {
    switch (variant) {
      case StatusVariant.success:
        return AppColors.successSurface;
      case StatusVariant.warning:
        return AppColors.warningSurface;
      case StatusVariant.error:
        return AppColors.errorSurface;
      case StatusVariant.info:
        return AppColors.infoSurface;
      case StatusVariant.neutral:
        return AppColors.slate100;
      case StatusVariant.primary:
        return AppColors.primarySurface;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case StatusBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
      case StatusBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
      case StatusBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
    }
  }

  double get _fontSize {
    switch (size) {
      case StatusBadgeSize.small:
        return 11;
      case StatusBadgeSize.medium:
        return 12;
      case StatusBadgeSize.large:
        return 13;
    }
  }

  double get _iconSize {
    switch (size) {
      case StatusBadgeSize.small:
        return 12;
      case StatusBadgeSize.medium:
        return 14;
      case StatusBadgeSize.large:
        return 16;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final bgColor = _backgroundColor;

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: outlined ? color : color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot indicator for status
class StatusDot extends StatelessWidget {
  final StatusVariant variant;
  final double size;
  final bool pulse;

  const StatusDot({
    super.key,
    required this.variant,
    this.size = 8,
    this.pulse = false,
  });

  Color get _color {
    switch (variant) {
      case StatusVariant.success:
        return AppColors.success;
      case StatusVariant.warning:
        return AppColors.warning;
      case StatusVariant.error:
        return AppColors.error;
      case StatusVariant.info:
        return AppColors.info;
      case StatusVariant.neutral:
        return AppColors.slate400;
      case StatusVariant.primary:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: _color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
