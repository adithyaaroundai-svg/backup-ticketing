import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/core/design_system/theme/app_theme.dart';
import 'package:ticketing_system/features/chat/domain/entities/aroundai_project_status.dart';
import 'package:ticketing_system/features/chat/presentation/pages/aroundai_project_status_screen.dart';
import 'package:ticketing_system/features/chat/presentation/providers/aroundai_project_status_provider.dart';

class _FakeProjectStatusNotifier extends AroundaiProjectStatusNotifier {
  _FakeProjectStatusNotifier(this._initialTasks);

  final List<AroundaiProjectStatus> _initialTasks;

  @override
  AroundaiProjectStatusState build() {
    return AroundaiProjectStatusState(tasks: _initialTasks, loading: false);
  }

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets('Edit Task inputs, notes history dialog, and reminder sidebar keep dark legible text in dark theme',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sampleTask = AroundaiProjectStatus(
      id: 1,
      taskName: 'Safenet',
      taskStatus: 'completed',
      notes: 'Tally live , app given and isntalled sync - parvati',
      createdAt: DateTime(2026, 9, 30, 14, 32),
      updatedAt: DateTime(2026, 10, 30, 14, 32),
    );
    final reminderTask = AroundaiProjectStatus(
      id: 2,
      taskName: 'Pending Followup Client',
      taskStatus: 'working',
      notes: 'Call scheduled',
      followUpDate: DateTime(2026, 11, 20),
      createdAt: DateTime(2026, 10, 5, 11, 21),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aroundaiProjectStatusProvider.overrideWith(
            () => _FakeProjectStatusNotifier([sampleTask, reminderTask]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const AroundaiProjectStatusScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reminder card in white sidebar must use dark text in dark mode.
    final sidebarTitleFinder = find.text('Pending Followup Client').last;
    final sidebarTitle = tester.widget<Text>(sidebarTitleFinder);
    expect(sidebarTitle.style?.color, isNotNull);
    expect(sidebarTitle.style!.color!.computeLuminance(), lessThan(0.2));

    // Open Edit Task dialog for the first task ("Safenet").
    final editFinder = find.byTooltip('Edit Task').first;
    await tester.ensureVisible(editFinder);
    await tester.tap(editFinder);
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsOneWidget);

    final editableFields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(editableFields.length, greaterThanOrEqualTo(2));
    for (final editable in editableFields) {
      final textColor = editable.style.color!;
      expect(
        textColor.computeLuminance(),
        lessThan(0.2),
        reason: 'Input "${editable.controller.text}" must remain dark on #F8FAFC light box',
      );
    }

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Open Notes History dialog for the first task.
    final historyFinder = find.byTooltip('Notes History').first;
    await tester.ensureVisible(historyFinder);
    await tester.tap(historyFinder);
    await tester.pumpAndSettle();

    final historyDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(historyDialog.backgroundColor, Colors.white);

    final historyTitle = tester.widget<Text>(find.text('Notes History - Safenet'));
    expect(historyTitle.style?.color?.computeLuminance(), lessThan(0.2));

    final noteText = tester.widget<Text>(
      find.text('Tally live , app given and isntalled sync - parvati').last,
    );
    expect(noteText.style?.color?.computeLuminance(), lessThan(0.2));

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Open Delete Task dialog to verify AlertDialog background and content readability.
    final deleteFinder = find.byTooltip('Delete Task').first;
    await tester.ensureVisible(deleteFinder);
    await tester.tap(deleteFinder);
    await tester.pumpAndSettle();

    final deleteDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(deleteDialog.backgroundColor, Colors.white);
    final deleteTitle = tester.widget<Text>(find.text('Delete Task'));
    expect(deleteTitle.style?.color?.computeLuminance(), lessThan(0.2));
  });
}

