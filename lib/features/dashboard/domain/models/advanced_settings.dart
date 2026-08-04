/// Advanced settings model for role-based permissions and workflow configuration.
/// All accessors have safe defaults so the app never breaks due to missing config.
class AdvancedSettings {
  final Map<String, bool> featureFlags;
  final RolePermissions rolePermissions;
  final WorkflowConfig workflowConfig;

  AdvancedSettings({
    required this.featureFlags,
    required this.rolePermissions,
    required this.workflowConfig,
  });

  /// Parse from raw app_settings rows. Missing keys get safe defaults.
  factory AdvancedSettings.fromRaw(Map<String, dynamic> rawSettings) {
    // Feature flags (simple booleans)
    final featureFlags = <String, bool>{};
    for (final entry in rawSettings.entries) {
      if (entry.value is bool) {
        featureFlags[entry.key] = entry.value;
      }
    }

    // Role permissions from 'role_permissions' key
    final rolePermissionsRaw = rawSettings['role_permissions'];
    final rolePermissions = RolePermissions.fromJson(
      rolePermissionsRaw is Map<String, dynamic> ? rolePermissionsRaw : {},
    );

    // Workflow config from 'workflow_config' key
    final workflowConfigRaw = rawSettings['workflow_config'];
    final workflowConfig = WorkflowConfig.fromJson(
      workflowConfigRaw is Map<String, dynamic> ? workflowConfigRaw : {},
    );

    return AdvancedSettings(
      featureFlags: featureFlags,
      rolePermissions: rolePermissions,
      workflowConfig: workflowConfig,
    );
  }

  /// Check if a feature/module is enabled globally
  bool isFeatureEnabled(String key) => featureFlags[key] ?? true;

  /// Check if a role can see a specific screen
  bool canRoleSeeScreen(String role, String screenId) {
    // First check if module is enabled globally
    final moduleKey = _screenToModuleKey(screenId);
    if (moduleKey != null && !isFeatureEnabled(moduleKey)) {
      return false;
    }
    // Then check role-specific permission
    return rolePermissions.canSeeScreen(role, screenId);
  }

  /// Check if a role can perform a specific action
  bool canRolePerformAction(String role, String actionId) {
    // Check if related feature is enabled
    final featureKey = _actionToFeatureKey(actionId);
    if (featureKey != null && !isFeatureEnabled(featureKey)) {
      return false;
    }
    return rolePermissions.canPerformAction(role, actionId);
  }

  /// Get response time target duration in minutes for a priority
  int slaMinutesForPriority(String? priority) {
    if (priority == null) {
      return workflowConfig.slaMinutes['medium'] ??
          workflowConfig.slaMinutes['normal'] ??
          480;
    }
    return workflowConfig.slaMinutes[priority.toLowerCase()] ??
        workflowConfig.slaMinutes['medium'] ??
        workflowConfig.slaMinutes['normal'] ??
        480;
  }

  /// Get list of visible ticket statuses
  List<String> get visibleStatuses => workflowConfig.visibleStatuses;

  /// Map screen IDs to their module feature keys
  String? _screenToModuleKey(String screenId) {
    const mapping = {
      'wiki': 'enable_wiki',
      'reports': 'enable_reports',
      'deals': 'enable_deals',
      'notifications': 'enable_notifications',
    };
    return mapping[screenId];
  }

  /// Map action IDs to their feature keys
  String? _actionToFeatureKey(String actionId) {
    const mapping = {
      'moderator_force_resolve': 'enable_moderator_force_resolve',
      'billing': 'enable_billing',
      'ticket_creation': 'enable_ticket_creation',
    };
    return mapping[actionId];
  }
}

/// Role-based screen and action permissions
class RolePermissions {
  /// role -> screen -> allowed
  final Map<String, Map<String, bool>> screenPermissions;

  /// role -> action -> allowed
  final Map<String, Map<String, bool>> actionPermissions;

  RolePermissions({
    required this.screenPermissions,
    required this.actionPermissions,
  });

  factory RolePermissions.fromJson(Map<String, dynamic> json) {
    final screenPermissions = <String, Map<String, bool>>{};
    final actionPermissions = <String, Map<String, bool>>{};

    for (final role in json.keys) {
      final roleData = json[role];
      if (roleData is! Map<String, dynamic>) continue;

      // Parse screens
      final screens = roleData['screens'];
      if (screens is Map<String, dynamic>) {
        screenPermissions[role] = screens.map((k, v) => MapEntry(k, v == true));
      }

      // Parse actions
      final actions = roleData['actions'];
      if (actions is Map<String, dynamic>) {
        actionPermissions[role] = actions.map((k, v) => MapEntry(k, v == true));
      }
    }

    return RolePermissions(
      screenPermissions: screenPermissions,
      actionPermissions: actionPermissions,
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    final allRoles = {...screenPermissions.keys, ...actionPermissions.keys};

    for (final role in allRoles) {
      result[role] = {
        'screens': screenPermissions[role] ?? {},
        'actions': actionPermissions[role] ?? {},
      };
    }
    return result;
  }

  /// Check if role can see a screen. Defaults to true if not specified.
  bool canSeeScreen(String role, String screenId) {
    return screenPermissions[role]?[screenId] ?? true;
  }

  /// Check if role can perform an action. Defaults based on role.
  bool canPerformAction(String role, String actionId) {
    // If explicitly set, use that
    final explicit = actionPermissions[role]?[actionId];
    if (explicit != null) return explicit;

    // Default permissions by role and action
    return _defaultActionPermission(role, actionId);
  }

  bool _defaultActionPermission(String role, String actionId) {
    // Sensible defaults matching current hard-coded behavior
    switch (actionId) {
      case 'moderator_force_resolve':
        return role == 'Moderator' || role == 'Admin';
      case 'assign_any':
        return role == 'Admin' || role == 'Moderator';
      case 'billing_override':
        return role == 'Admin' || role == 'Accountant';
      case 'ticket_claim':
        return role == 'Support' || role == 'Agent';
      case 'ticket_resolve':
        return true; // Any assigned agent
      default:
        return true;
    }
  }
}

/// Ticket workflow configuration
class WorkflowConfig {
  final List<String> visibleStatuses;
  final Map<String, int> slaMinutes; // priority -> minutes

  WorkflowConfig({required this.visibleStatuses, required this.slaMinutes});

  factory WorkflowConfig.fromJson(Map<String, dynamic> json) {
    // Default statuses
    const defaultStatuses = [
      'New',
      'Open',
      'In Progress',
      'On Hold',
      'Waiting for Customer',
      'Resolved',
      'Closed',
      'BillRaised',
      'BillProcessed',
    ];

    // Default response time targets (in minutes)
    const defaultSla = {
      'urgent': 60,
      'critical': 60,
      'high': 180,
      'medium': 480,
      'normal': 480,
      'low': 1440,
    };

    // Parse statuses
    List<String> statuses = defaultStatuses;
    final statusesRaw = json['visible_statuses'];
    if (statusesRaw is List) {
      statuses = statusesRaw.whereType<String>().toList();
      if (statuses.isEmpty) statuses = defaultStatuses;
    }

    // Parse response time targets
    Map<String, int> sla = Map.from(defaultSla);
    final slaRaw = json['sla'];
    if (slaRaw is Map<String, dynamic>) {
      for (final entry in slaRaw.entries) {
        final minutes = entry.value;
        if (minutes is int) {
          sla[entry.key.toLowerCase()] = minutes;
        } else if (minutes is double) {
          sla[entry.key.toLowerCase()] = minutes.toInt();
        }
      }
    }

    return WorkflowConfig(visibleStatuses: statuses, slaMinutes: sla);
  }

  Map<String, dynamic> toJson() {
    return {'visible_statuses': visibleStatuses, 'sla': slaMinutes};
  }
}
