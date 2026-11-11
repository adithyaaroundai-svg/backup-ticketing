import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/features/developer_crm/core/time_utils.dart';
import 'package:ticketing_system/features/developer_crm/domain/entities/task.dart';

void main() {
  group('IST carry-forward date helpers', () {
    test('formatIstDateKey shifts UTC across midnight IST boundary', () {
      // 2026-11-11 18:29:59 UTC == 2026-11-11 23:59:59 IST
      final beforeMidnightIst = DateTime.utc(2026, 11, 11, 18, 29, 59);
      expect(formatIstDateKey(beforeMidnightIst), '2026-11-11');

      // 2026-11-11 18:30:00 UTC == 2026-11-12 00:00:00 IST
      final atMidnightIst = DateTime.utc(2026, 11, 11, 18, 30, 0);
      expect(formatIstDateKey(atMidnightIst), '2026-11-12');
    });

    test('resolveTaskDisplayDateKey prefers displayDate then IST createdAt', () {
      expect(
        resolveTaskDisplayDateKey(
          displayDate: '2026-11-10',
          createdAt: '2026-11-08 04:00:00',
        ),
        '2026-11-10',
      );
      expect(
        resolveTaskDisplayDateKey(
          displayDate: null,
          createdAt: '2026-11-10 19:00:00', // 2026-11-11 00:30 IST
        ),
        '2026-11-11',
      );
      expect(resolveTaskDisplayDateKey(), 'No date');
    });

    test('auto carry forward triggers only for prior-day Today not_started tasks', () {
      const today = '2026-11-11';

      // Prior-day display_date in Today's Tasks with not_started -> carry forward
      expect(
        shouldAutoCarryForwardNotStarted(
          status: 'not_started',
          pending: false,
          displayDate: '2026-11-10',
          taskDate: '2026-11-10',
          createdAt: '2026-11-10 04:26:43',
          todayIst: today,
        ),
        isTrue,
      );

      // Same-day display_date with stale task_date -> synchronize to today
      expect(
        shouldAutoCarryForwardNotStarted(
          status: 'not_started',
          pending: false,
          displayDate: today,
          taskDate: '2026-11-10',
          createdAt: '2026-11-10 04:26:43',
          todayIst: today,
        ),
        isTrue,
      );

      // Already on today for both display_date and task_date -> no-op
      expect(
        shouldAutoCarryForwardNotStarted(
          status: 'not_started',
          pending: false,
          displayDate: today,
          taskDate: today,
          createdAt: '2026-11-09 05:13:51',
          todayIst: today,
        ),
        isFalse,
      );

      // Null display_date falls back to IST createdAt
      expect(
        shouldAutoCarryForwardNotStarted(
          status: 'not_started',
          pending: false,
          displayDate: null,
          taskDate: null,
          createdAt: '2026-11-10 04:26:43',
          todayIst: today,
        ),
        isTrue,
      );

      // Pending board not_started task -> never auto-carried forward
      expect(
        shouldAutoCarryForwardNotStarted(
          status: 'not_started',
          pending: true,
          displayDate: '2026-07-27',
          taskDate: '2026-07-27',
          createdAt: '2026-07-27 10:58:07',
          todayIst: today,
        ),
        isFalse,
      );

      // Other statuses in Today's Tasks -> stay manual
      for (final status in [
        'working',
        'paused',
        'ready_for_testing',
        'awaiting_confirmation',
        'completed',
        'cancelled',
      ]) {
        expect(
          shouldAutoCarryForwardNotStarted(
            status: status,
            pending: false,
            displayDate: '2026-11-10',
            taskDate: '2026-11-10',
            createdAt: '2026-11-10 04:26:43',
            todayIst: today,
          ),
          isFalse,
          reason: '$status must not auto carry forward',
        );
      }
    });

    test('Task.copyWith updates displayDate/taskDate without losing createdAt', () {
      final original = Task(
        id: 288,
        description: 'modification',
        priority: 'A',
        approved: false,
        status: 'not_started',
        taskDate: '2026-11-10',
        displayDate: '2026-11-10',
        createdAt: '2026-11-10 04:26:43',
        pending: false,
        billed: false,
        timeSpentSeconds: 0,
      );

      final updated = original.copyWith(
        taskDate: '2026-11-11',
        displayDate: '2026-11-11',
      );

      expect(updated.status, 'not_started');
      expect(updated.taskDate, '2026-11-11');
      expect(updated.displayDate, '2026-11-11');
      expect(updated.createdAt, '2026-11-10 04:26:43');
      expect(updated.description, 'modification');
    });
  });
}

