import os

filepath = 'lib/features/dashboard/presentation/pages/revenue_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix _DropdownFilter (Overflow)
old_dropdown = '''    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.value,
              child: Text(item.label),
            ),
          )
          .toList(),'''

new_dropdown = '''    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.value,
              child: Text(item.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),'''

content = content.replace(old_dropdown, new_dropdown)

# 2. Fix _SummaryRow Colors
old_summary_text_1 = '''                                Text(
                                card.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),'''
new_summary_text_1 = '''                                Text(
                                card.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.slate800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),'''
content = content.replace(old_summary_text_1, new_summary_text_1)

old_summary_text_2 = '''                                Text(
                                _formatCurrency(card.amount),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),'''
new_summary_text_2 = '''                                Text(
                                _formatCurrency(card.amount),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.slate900,
                                ),
                              ),'''
content = content.replace(old_summary_text_2, new_summary_text_2)

old_summary_text_3 = '''                                Text(
                                card.caption,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),'''
new_summary_text_3 = '''                                Text(
                                card.caption,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.slate500,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),'''
content = content.replace(old_summary_text_3, new_summary_text_3)

# 3. Fix _FiltersCard Colors
old_filter_title = '''                Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),'''
new_filter_title = '''                Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.slate900,
                  ),
                ),'''
content = content.replace(old_filter_title, new_filter_title)

old_filter_chip = '''                return FilterChip(
                  label: Text(role == 'all' ? 'All Roles' : role),
                  selected: isSelected,
                  onSelected: (_) => onRoleChanged(role),
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  checkmarkColor: AppColors.primary,
                );'''
new_filter_chip = '''                final isDark = Theme.of(context).brightness == Brightness.dark;
                return FilterChip(
                  label: Text(role == 'all' ? 'All Roles' : role, style: TextStyle(color: isDark ? Colors.white : AppColors.slate900)),
                  selected: isSelected,
                  onSelected: (_) => onRoleChanged(role),
                  backgroundColor: isDark ? AppColors.slate800 : Colors.white,
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  checkmarkColor: AppColors.primary,
                );'''
content = content.replace(old_filter_chip, new_filter_chip)

# 4. Fix _AgentScopeBanner Colors
old_banner = '''    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.shield, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal View ()',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Showing your personal revenue performance. Upgrades required for team view.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );'''

new_banner = '''    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.shield, color: isDark ? Colors.white : AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal View ()',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing your personal revenue performance. Upgrades required for team view.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );'''
content = content.replace(old_banner, new_banner)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied fixes!")
