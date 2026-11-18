class TargetDefinition {
  final String id;
  final String name;
  final String? description;
  final String targetType;
  final String targetUnit;
  final double targetValue;
  final String periodType;
  final bool? isActive;

  const TargetDefinition({
    required this.id,
    required this.name,
    this.description,
    required this.targetType,
    required this.targetUnit,
    required this.targetValue,
    required this.periodType,
    this.isActive,
  });

  static double parseDouble(dynamic v, [double defaultValue = 0.0]) {
    if (v == null) return defaultValue;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  static bool? parseBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return null;
  }

  factory TargetDefinition.fromJson(Map<String, dynamic> json) {
    return TargetDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      targetType: json['target_type']?.toString() ?? '',
      targetUnit: json['target_unit']?.toString() ?? '',
      targetValue: parseDouble(json['target_value']),
      periodType: json['period_type']?.toString() ?? '',
      isActive: parseBool(json['is_active']),
    );
  }

  Map<String, dynamic> toCreateUpdateJson() {
    return {
      'name': name,
      'description': description ?? '',
      'target_type': targetType,
      'target_unit': targetUnit,
      'target_value': targetValue,
      'period_type': periodType,
    };
  }
}

class TargetAssignment {
  final String id;
  final String assignedToType;
  final String assignedToId;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? status;
  final TargetDefinition? target;

  const TargetAssignment({
    required this.id,
    required this.assignedToType,
    required this.assignedToId,
    this.periodStart,
    this.periodEnd,
    this.status,
    this.target,
  });

  factory TargetAssignment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    TargetDefinition? target;
    final dynamic rawTarget = json['target'] ??
        json['target_definition'] ??
        json['targetDefinition'] ??
        json['definition'] ??
        json['template'] ??
        json['target_template'];
    if (rawTarget is Map) {
      target = TargetDefinition.fromJson(
        rawTarget.cast<String, dynamic>(),
      );
    } else if (json['target_type'] != null ||
        json['target_unit'] != null ||
        json['target_value'] != null ||
        json['target_name'] != null ||
        json['name'] != null) {
      target = TargetDefinition.fromJson(json);
    }

    final assignedToType = (json['assigned_to_type'] ??
            json['assignedToType'] ??
            (json['worker_id'] != null
                ? 'worker'
                : (json['team_id'] != null ? 'team' : '')))
        ?.toString() ??
        '';

    final assignedToId = (json['assigned_to_id'] ??
            json['assignedToId'] ??
            json['worker_id'] ??
            json['team_id'] ??
            '')
        ?.toString() ??
        '';

    return TargetAssignment(
      id: json['id']?.toString() ?? json['assignment_id']?.toString() ?? '',
      assignedToType: assignedToType,
      assignedToId: assignedToId,
      periodStart: parseDate(json['period_start']),
      periodEnd: parseDate(json['period_end']),
      status: json['status']?.toString(),
      target: target,
    );
  }
}

class TargetProgress {
  final double currentValue;
  final DateTime? lastUpdated;

  const TargetProgress({
    required this.currentValue,
    this.lastUpdated,
  });

  factory TargetProgress.fromJson(Map<String, dynamic> json) {
    final lastUpdatedRaw = json['last_updated'] ?? json['updated_at'];
    DateTime? lastUpdated;
    if (lastUpdatedRaw is String && lastUpdatedRaw.isNotEmpty) {
      lastUpdated = DateTime.tryParse(lastUpdatedRaw);
    }

    return TargetProgress(
      currentValue: TargetDefinition.parseDouble(
        json['current_value'] ?? json['currentValue'] ?? json['progress_value'],
      ),
      lastUpdated: lastUpdated,
    );
  }
}

class AssignedTargetWithProgress {
  final TargetAssignment assignment;
  final TargetProgress progress;
  final double? percentage;
  final bool? isCompleted;

  const AssignedTargetWithProgress({
    required this.assignment,
    required this.progress,
    this.percentage,
    this.isCompleted,
  });

  factory AssignedTargetWithProgress.fromJson(Map<String, dynamic> json) {
    final assignmentMap = json['assignment'] is Map
        ? (json['assignment'] as Map).cast<String, dynamic>()
        : json;
    final progressMap = json['progress'] is Map
        ? (json['progress'] as Map).cast<String, dynamic>()
        : json;

    final assignment = TargetAssignment.fromJson(assignmentMap);
    final progress = TargetProgress.fromJson(progressMap);

    double? percentage = json['percentage'] == null
        ? null
        : TargetDefinition.parseDouble(json['percentage']);
    if (percentage == null) {
      final current = progress.currentValue;
      final targetVal = assignment.target?.targetValue ?? 0.0;
      if (targetVal > 0) {
        percentage = (current / targetVal) * 100.0;
      }
    }

    return AssignedTargetWithProgress(
      assignment: assignment,
      progress: progress,
      percentage: percentage,
      isCompleted: TargetDefinition.parseBool(json['is_completed']) ??
          (percentage != null && percentage >= 100.0),
    );
  }
}

class TeamMemberLite {
  final String id;
  final String name;
  final String? email;

  const TeamMemberLite({
    required this.id,
    required this.name,
    this.email,
  });

  factory TeamMemberLite.fromJson(Map<String, dynamic> json) {
    final displayName =
        json['display_name']?.toString() ?? json['displayName']?.toString();
    final name = (displayName?.isNotEmpty == true)
        ? displayName!
        : (json['name']?.toString() ?? json['email']?.toString() ?? 'Worker');

    return TeamMemberLite(
      id: json['id']?.toString() ??
          json['user_id']?.toString() ??
          json['worker_id']?.toString() ??
          '',
      name: name,
      email: json['email']?.toString(),
    );
  }
}
