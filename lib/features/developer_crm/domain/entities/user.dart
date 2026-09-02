import '../../core/parse_utils.dart';

/// Covers both the "public" User shape (`{id,name,email,role,mustChangePassword}`)
/// returned by auth/me endpoints, and the settings-list shape
/// (`{id,name,email,role,must_change_password,is_super_admin}`).
class AppUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final bool mustChangePassword;
  final bool? isSuperAdmin;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.mustChangePassword,
    this.isSuperAdmin,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: asInt(json['id']),
      name: asString(json['name']),
      email: asString(json['email']),
      role: asString(json['role']),
      mustChangePassword: asBool(json['mustChangePassword'] ?? json['must_change_password']),
      isSuperAdmin: json.containsKey('is_super_admin') ? asBool(json['is_super_admin']) : null,
    );
  }

  bool get isManager => role == 'manager';
  bool get isAccountant => role == 'accountant';
  bool get isTeamLead => role == 'team_lead';
  bool get canSeeTeam => role == 'manager' || role == 'team_lead';
  bool get canSeeBilling => role == 'manager' || role == 'accountant';
  bool get canSeeDashboard => role == 'manager';
  bool get canSeeSettings => role == 'manager';
}

/// A bare `{id, name}` or `{id, name, role}` reference, used for assignee
/// lists, the settings users list filter data, etc.
class UserRef {
  final int id;
  final String name;
  final String? role;

  UserRef({required this.id, required this.name, this.role});

  factory UserRef.fromJson(Map<String, dynamic> json) => UserRef(
        id: asInt(json['id']),
        name: asString(json['name']),
        role: asStringOrNull(json['role']),
      );
}
