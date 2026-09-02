/// Landing route + basic route-access helpers per role, mirroring the old
/// EJS app's `landingFor(role)` redirect logic (see API.md's "Roles and
/// route access" table). Not documented verbatim in API.md, so this is a
/// reasonable, consistent derivation:
/// - `accountant` -> billing (their only screen)
/// - `manager` -> dashboard
/// - `team_lead` -> team
/// - everyone else (`executive`, `developer`, `impl_engineer`) -> clients,
///   which was the app's `/` root/home view.
String landingRouteFor(String role) {
  switch (role) {
    case 'accountant':
      return '/billing';
    case 'manager':
      return '/dashboard';
    case 'team_lead':
      return '/team';
    default:
      return '/clients';
  }
}

bool roleCanSeeDashboard(String role) => role == 'manager';
bool roleCanSeeSettings(String role) => role == 'manager';
bool roleCanSeeBilling(String role) => role == 'manager' || role == 'accountant';
bool roleCanSeeTeam(String role) => role == 'manager' || role == 'team_lead';
bool roleIsAccountant(String role) => role == 'accountant';
