import 'package:flutter/material.dart';

import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/theme/app_theme.dart';

Color adaptiveAccentColor(BuildContext context, Color color) {
  if (!context.isDarkMode) return color;
  if (color == AppColors.primary) return AppColors.primaryLight;
  if (color == AppColors.slate600) return AppColors.slate400;
  return color;
}

class BoardPageHeader extends StatelessWidget {
  const BoardPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: context.adaptiveSlate900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13.5, color: context.adaptiveSlate500, height: 1.3),
        ),
      ],
    );
  }
}

class BoardStatusCard extends StatelessWidget {
  const BoardStatusCard({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final effectiveColor = adaptiveAccentColor(context, color);

    return Material(
      color: selected
          ? effectiveColor.withValues(alpha: isDark ? 0.18 : 0.08)
          : context.adaptiveCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? effectiveColor : context.adaptiveBorder,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: (selected || isDark) ? null : AppTheme.subtleShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: effectiveColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.adaptiveSlate900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.adaptiveSlate500, fontWeight: FontWeight.w500),
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

class BoardAssigneeFilter extends StatelessWidget {
  const BoardAssigneeFilter({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int? value;
  final List<(int id, String name)> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((option) => option.$1 == value).map((option) => option.$2).firstOrNull;
    final label = selected ?? 'All assignees';

    return MenuAnchor(
      style: const MenuStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero)),
      menuChildren: [
        MenuItemButton(
          onPressed: () => onChanged(null),
          child: const Text('All assignees'),
        ),
        for (final option in options)
          MenuItemButton(
            onPressed: () => onChanged(option.$1),
            child: Text(option.$2),
          ),
      ],
      builder: (context, controller, child) {
        final filterFill = context.isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.slate50;
        return Material(
          color: filterFill,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                border: Border.all(color: context.adaptiveBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.adaptiveSlate800),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: context.adaptiveSlate600),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class BoardToolbar extends StatelessWidget {
  const BoardToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.isDarkMode ? null : AppTheme.subtleShadow,
      ),
      child: Material(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.adaptiveBorder),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

class BoardTableCard extends StatelessWidget {
  const BoardTableCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.isDarkMode ? null : AppTheme.cardShadow,
      ),
      child: Material(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.adaptiveBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class BoardDateHeader extends StatelessWidget {
  const BoardDateHeader({super.key, required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.adaptiveSlate900,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.10) : AppColors.slate100,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.adaptiveSlate800,
            ),
          ),
        ),
      ],
    );
  }
}

class BoardEmptyState extends StatelessWidget {
  const BoardEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return BoardTableCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? accent.withValues(alpha: 0.18) : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inbox_outlined, color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: context.adaptiveSlate500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
