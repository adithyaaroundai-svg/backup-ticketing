/// Enums / constant lists mirrored exactly from API.md.
library;

/// All 8 task status values. The quick inline-update endpoint
/// (`POST /api/tasks/:id/update`) accepts all of these.
const List<String> kAllTaskStatuses = [
  'not_started',
  'working',
  'ready_for_testing',
  'ready_for_implementation',
  'awaiting_confirmation',
  'completed',
  'paused',
  'cancelled',
];

/// The 5 values accepted by the full task-edit endpoint
/// (`POST /api/tasks/:id`).
const List<String> kFullEditTaskStatuses = [
  'not_started',
  'working',
  'completed',
  'paused',
  'cancelled',
];

const List<String> kPriorities = ['A+', 'A', 'B'];

const List<String> kWorkItemFileCategories = [
  'tcp',
  'excel',
  'proposal',
  'other',
];

const List<String> kUserRoles = [
  'manager',
  'team_lead',
  'executive',
  'developer',
  'impl_engineer',
  'accountant',
];

String taskStatusLabel(String status) {
  switch (status) {
    case 'not_started':
      return 'Not started';
    case 'working':
      return 'Working';
    case 'ready_for_testing':
      return 'Ready for testing';
    case 'ready_for_implementation':
      return 'Ready for implementation';
    case 'awaiting_confirmation':
      return 'Awaiting confirmation';
    case 'completed':
      return 'Completed';
    case 'paused':
      return 'Paused';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

String userRoleLabel(String role) {
  switch (role) {
    case 'manager':
      return 'Manager';
    case 'team_lead':
      return 'Team lead';
    case 'executive':
      return 'Executive';
    case 'developer':
      return 'Developer';
    case 'impl_engineer':
      return 'Implementation engineer';
    case 'accountant':
      return 'Accountant';
    default:
      return role;
  }
}

String workItemCategoryLabel(String category) {
  switch (category) {
    case 'tcp':
      return 'TCP';
    case 'excel':
      return 'Excel';
    case 'proposal':
      return 'Proposal';
    case 'other':
      return 'Other';
    default:
      return category;
  }
}
