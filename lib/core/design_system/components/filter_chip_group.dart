import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Unified filter chip group for consistent filtering UI
/// Matches the "All / Open / Closed" style chips from mockups
class FilterChipGroup extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool allowDeselect;

  const FilterChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allowDeselect = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected == option;
        return _FilterChip(
          label: option,
          isSelected: isSelected,
          onTap: () {
            if (isSelected && allowDeselect) {
              onSelected(null);
            } else {
              onSelected(option);
            }
          },
        );
      }).toList(),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.primary
                  : (_isHovered ? AppColors.slate50 : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.primary
                    : (_isHovered ? AppColors.borderHover : AppColors.border),
                width: widget.isSelected ? 1.5 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                color: widget.isSelected ? Colors.white : AppColors.slate700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Enterprise tab-style filter group
class FilterTabGroup extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterTabGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = selected == option;
          return _FilterTab(
            label: option,
            isSelected: isSelected,
            onTap: () => onSelected(option),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterTab extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterTab> createState() => _FilterTabState();
}

class _FilterTabState extends State<_FilterTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primarySurface
                : (_isHovered ? AppColors.slate50 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: widget.isSelected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected ? AppColors.primary : AppColors.slate600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown-style filter for limited space
class FilterDropdown extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String? hint;

  const FilterDropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          hint: hint != null
              ? Text(
                  hint!,
                  style: TextStyle(fontSize: 13, color: AppColors.slate500),
                )
              : null,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.slate400,
            size: 20,
          ),
          style: TextStyle(fontSize: 13, color: AppColors.slate900),
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onSelected(value);
            }
          },
        ),
      ),
    );
  }
}
