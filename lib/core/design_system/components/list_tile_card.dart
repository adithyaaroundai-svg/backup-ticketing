import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Enterprise-style list tile card for consistent list item styling
class ListTileCard extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accentColor;
  final Widget? bottom;
  final EdgeInsetsGeometry? padding;
  final bool showAccentBorder;

  const ListTileCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.accentColor,
    this.bottom,
    this.padding,
    this.showAccentBorder = false,
  });

  @override
  State<ListTileCard> createState() => _ListTileCardState();
}

class _ListTileCardState extends State<ListTileCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.surfaceHover : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? AppColors.borderHover : AppColors.border,
            width: 1,
          ),
          boxShadow: _isHovered ? AppTheme.cardShadow : AppTheme.subtleShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: AppColors.slate200.withValues(alpha: 0.3),
            highlightColor: AppColors.slate100.withValues(alpha: 0.5),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Accent border on left
                  if (widget.showAccentBorder && widget.accentColor != null)
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: widget.padding ?? const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.leading != null) ...[
                                widget.leading!,
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.slate900,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.subtitle != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.subtitle!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.slate500,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (widget.trailing != null) ...[
                                const SizedBox(width: 14),
                                widget.trailing!,
                              ],
                            ],
                          ),
                          if (widget.bottom != null) ...[
                            const SizedBox(height: 14),
                            widget.bottom!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transaction/Bill list item variant
class TransactionListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String? status;
  final Color? statusColor;
  final VoidCallback? onTap;

  const TransactionListItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.status,
    this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTileCard(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (statusColor ?? AppColors.slate500).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor ?? AppColors.slate500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state placeholder for lists
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Color? titleColor;
  final Color? subtitleColor;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor ?? AppColors.slate300),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: titleColor != null ? FontWeight.bold : FontWeight.w500,
                color: titleColor ?? AppColors.slate600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14, 
                  color: subtitleColor ?? AppColors.slate400,
                  fontWeight: subtitleColor != null ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
