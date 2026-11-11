import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/core/design_system/theme/app_colors.dart';
import 'package:ticketing_system/core/design_system/theme/app_theme.dart';
import 'package:ticketing_system/features/developer_crm/domain/entities/task.dart';
import 'package:ticketing_system/features/developer_crm/presentation/widgets/board_chrome.dart';
import 'package:ticketing_system/features/developer_crm/presentation/widgets/editable_task_table.dart';

void main() {
  Task sampleTask() => Task(
        id: 1,
        clientId: 10,
        client: 'Pavizham Oil',
        description: 'New requirements',
        priority: 'A',
        approved: false,
        status: 'not_started',
        taskDate: '2026-11-11',
        displayDate: '2026-11-11',
        createdAt: '2026-11-11 04:00:00',
        pending: false,
        billed: false,
        timeSpentSeconds: 0,
      );

  Widget buildBoardHarness(ThemeMode themeMode) {
    final task = sampleTask();
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        backgroundColor: themeMode == ThemeMode.dark ? AppColors.slate950 : AppColors.background,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BoardPageHeader(
                title: "Today's Tasks",
                subtitle: 'Work planned for today, grouped by created date.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BoardStatusCard(
                      label: 'Active',
                      count: 23,
                      selected: true,
                      color: AppColors.primary,
                      icon: Icons.bolt_rounded,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BoardStatusCard(
                      label: 'Completed',
                      count: 224,
                      selected: false,
                      color: AppColors.success,
                      icon: Icons.check_circle_outline_rounded,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BoardToolbar(
                children: [
                  BoardAssigneeFilter(
                    value: null,
                    options: const [(1, 'Sharika')],
                    onChanged: (_) {},
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Carry forward'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const BoardDateHeader(
                label: 'Created Date: 11 Nov 2026 (Today)',
                count: 10,
              ),
              const SizedBox(height: 8),
              BoardTableCard(
                child: EditableTaskTable(
                  tasks: [task],
                  onQuickUpdate: (_, {priority, status}) async {},
                  rowActionsBuilder: (_) => const [
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color resolvedTextColor(WidgetTester tester, String label) {
    final text = tester.widget<Text>(find.text(label));
    final ctx = tester.element(find.text(label));
    return text.style?.color ?? DefaultTextStyle.of(ctx).style.color!;
  }

  testWidgets('developer CRM board headings and labels are bright in dark mode and dark in light mode',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildBoardHarness(ThemeMode.dark));
    await tester.pumpAndSettle();

    expect(resolvedTextColor(tester, "Today's Tasks").computeLuminance(), greaterThan(0.4));
    expect(resolvedTextColor(tester, 'Work planned for today, grouped by created date.').computeLuminance(), greaterThan(0.3));
    expect(resolvedTextColor(tester, 'Created Date: 11 Nov 2026 (Today)').computeLuminance(), greaterThan(0.4));
    expect(resolvedTextColor(tester, '10').computeLuminance(), greaterThan(0.3));
    expect(resolvedTextColor(tester, '23').computeLuminance(), greaterThan(0.4));
    expect(resolvedTextColor(tester, '224').computeLuminance(), greaterThan(0.4));
    expect(resolvedTextColor(tester, 'All assignees').computeLuminance(), greaterThan(0.4));
    expect(resolvedTextColor(tester, 'Carry forward').computeLuminance(), greaterThan(0.18));
    expect(resolvedTextColor(tester, 'Client').computeLuminance(), greaterThan(0.4));
    expect(resolvedTextColor(tester, 'Actions').computeLuminance(), greaterThan(0.4));
    expect(resolvedTextColor(tester, 'Pavizham Oil').computeLuminance(), greaterThan(0.4));
    expect(resolvedTextColor(tester, 'New requirements').computeLuminance(), greaterThan(0.4));

    await tester.pumpWidget(buildBoardHarness(ThemeMode.light));
    await tester.pumpAndSettle();

    expect(resolvedTextColor(tester, "Today's Tasks").computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, 'Work planned for today, grouped by created date.').computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, 'Created Date: 11 Nov 2026 (Today)').computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, '23').computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, '224').computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, 'All assignees').computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, 'Client').computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, 'Actions').computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, 'Pavizham Oil').computeLuminance(), lessThan(0.3));
    expect(resolvedTextColor(tester, 'New requirements').computeLuminance(), lessThan(0.3));
  });
}

