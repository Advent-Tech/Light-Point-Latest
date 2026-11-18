import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/target_models.dart';

class TargetsRepository {
  ApiClient? _apiClient;

  TargetsRepository();

  Future<ApiClient> get apiClient async {
    _apiClient ??= await ApiClient.getInstance();
    return _apiClient!;
  }

  List<dynamic> _extractList(
    dynamic raw, [
    List<String> keys = const ['data', 'targets'],
  ]) {
    if (raw == null) return const [];
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in keys) {
        final val = raw[key];
        if (val is List) return val;
        if (val is Map) {
          for (final innerKey in keys) {
            final innerVal = val[innerKey];
            if (innerVal is List) return innerVal;
          }
          for (final entry in val.values) {
            if (entry is List) return entry;
          }
        }
      }
      for (final k in const [
        'assigned_targets',
        'assignedTargets',
        'target_assignments',
        'targetAssignments',
        'assignments',
        'assigned',
        'targets',
        'templates',
        'items',
        'results',
        'data',
        'workers',
        'members',
        'teams',
      ]) {
        final val = raw[k];
        if (val is List) return val;
      }
      for (final val in raw.values) {
        if (val is List) return val;
      }
    }
    return const [];
  }

  Future<ApiResult<List<TargetDefinition>>> getLeaderTargetTemplates() async {
    try {
      final client = await apiClient;
      final response = await client.dio.get('/api/teams/targets');
      debugPrint(
        'getLeaderTargetTemplates response: ${response.statusCode} - ${response.data}',
      );

      final list = _extractList(response.data, const [
        'data',
        'targets',
        'templates',
      ]);
      final targets = list
          .whereType<Map>()
          .map((e) => TargetDefinition.fromJson(e.cast<String, dynamic>()))
          .toList();

      return ApiResult.success(targets);
    } on DioException catch (e) {
      debugPrint('getLeaderTargetTemplates error: $e');
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      debugPrint('getLeaderTargetTemplates exception: $e');
      return ApiResult.failure('Failed to load target templates: $e');
    }
  }

  Future<ApiResult<List<AssignedTargetWithProgress>>> getLeaderAssignedTargets({
    String? teamId,
  }) async {
    try {
      final client = await apiClient;
      debugPrint('getLeaderAssignedTargets requesting with teamId=$teamId');
      Response<dynamic> response;
      try {
        response = await client.dio.get(
          '/api/teams/targets/assigned',
          queryParameters: {
            if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
          },
        );
      } on DioException {
        response = await client.dio.get('/api/teams/targets/assigned');
      }

      debugPrint(
        'getLeaderAssignedTargets response: ${response.statusCode} - ${response.data}',
      );

      var list = _extractList(response.data, const [
        'data',
        'targets',
        'assigned_targets',
        'assigned',
        'assignments',
        'items',
      ]);

      // If passing team_id yielded empty, also check without team_id filter
      if (list.isEmpty && teamId != null && teamId.isNotEmpty) {
        try {
          final fallbackResponse = await client.dio.get(
            '/api/teams/targets/assigned',
          );
          debugPrint(
            'getLeaderAssignedTargets fallback response: ${fallbackResponse.statusCode} - ${fallbackResponse.data}',
          );
          final fallbackList = _extractList(fallbackResponse.data, const [
            'data',
            'targets',
            'assigned_targets',
            'assigned',
            'assignments',
            'items',
          ]);
          if (fallbackList.isNotEmpty) {
            list = fallbackList;
          }
        } catch (e) {
          debugPrint('getLeaderAssignedTargets fallback error: $e');
        }
      }

      final targets = list
          .whereType<Map>()
          .map(
            (e) =>
                AssignedTargetWithProgress.fromJson(e.cast<String, dynamic>()),
          )
          .toList();

      debugPrint(
        'getLeaderAssignedTargets successfully parsed ${targets.length} assigned targets',
      );
      return ApiResult.success(targets);
    } on DioException catch (e) {
      debugPrint('getLeaderAssignedTargets error: $e');
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      debugPrint('getLeaderAssignedTargets exception: $e');
      return ApiResult.failure('Failed to load assigned targets: $e');
    }
  }

  Future<ApiResult<TargetDefinition>> createTargetTemplate({
    required String name,
    required String description,
    required String targetType,
    required String targetUnit,
    required double targetValue,
    required String periodType,
  }) async {
    try {
      final client = await apiClient;
      final response = await client.dio.post(
        '/api/teams/targets',
        data: {
          'name': name,
          'description': description,
          'target_type': targetType,
          'target_unit': targetUnit,
          'target_value': targetValue,
          'period_type': periodType,
        },
      );

      final raw = response.data;
      Map<String, dynamic> data;
      if (raw is Map) {
        if (raw['data'] is Map) {
          data = (raw['data'] as Map).cast<String, dynamic>();
        } else if (raw['target'] is Map) {
          data = (raw['target'] as Map).cast<String, dynamic>();
        } else {
          data = raw.cast<String, dynamic>();
        }
      } else {
        data = <String, dynamic>{};
      }
      return ApiResult.success(TargetDefinition.fromJson(data));
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to create target: $e');
    }
  }

  Future<ApiResult<void>> updateTargetTemplate({
    required String targetId,
    required String name,
    required String description,
    required String targetType,
    required String targetUnit,
    required double targetValue,
    required String periodType,
  }) async {
    try {
      final client = await apiClient;
      await client.dio.put(
        '/api/teams/targets/$targetId',
        data: {
          'name': name,
          'description': description,
          'target_type': targetType,
          'target_unit': targetUnit,
          'target_value': targetValue,
          'period_type': periodType,
        },
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to update target: $e');
    }
  }

  Future<ApiResult<void>> deleteTargetTemplate(String targetId) async {
    try {
      final client = await apiClient;
      await client.dio.delete('/api/teams/targets/$targetId');
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to delete target: $e');
    }
  }

  Future<ApiResult<void>> assignTargetToTeam({
    required String targetId,
    required String teamId,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    try {
      final client = await apiClient;
      final payload = {
        'team_id': teamId,
        if (periodStart != null) 'period_start': periodStart.toIso8601String(),
        if (periodEnd != null) 'period_end': periodEnd.toIso8601String(),
      };
      debugPrint('assignTargetToTeam targetId=$targetId payload=$payload');
      final response = await client.dio.post(
        '/api/teams/targets/$targetId/assign-team',
        data: payload,
      );
      debugPrint(
        'assignTargetToTeam response: ${response.statusCode} - ${response.data}',
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      debugPrint('assignTargetToTeam error: $e response=${e.response?.data}');
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      debugPrint('assignTargetToTeam exception: $e');
      return ApiResult.failure('Failed to assign to team: $e');
    }
  }

  Future<ApiResult<void>> assignTargetToWorker({
    required String targetId,
    required String workerId,
    String? teamId,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    try {
      final client = await apiClient;
      final payload = {
        'worker_id': workerId,
        if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
        if (periodStart != null) 'period_start': periodStart.toIso8601String(),
        if (periodEnd != null) 'period_end': periodEnd.toIso8601String(),
      };
      debugPrint('assignTargetToWorker targetId=$targetId payload=$payload');
      final response = await client.dio.post(
        '/api/teams/targets/$targetId/assign-worker',
        data: payload,
      );
      debugPrint(
        'assignTargetToWorker response: ${response.statusCode} - ${response.data}',
      );
      return const ApiResult.success(null);
    } on DioException catch (e) {
      debugPrint('assignTargetToWorker error: $e response=${e.response?.data}');
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      debugPrint('assignTargetToWorker exception: $e');
      return ApiResult.failure('Failed to assign to worker: $e');
    }
  }

  Future<ApiResult<void>> deleteAssignment({
    required String assignmentId,
    String? targetId,
    String? assignedToType,
    String? assignedToId,
  }) async {
    try {
      final client = await apiClient;
      DioException? lastDioError;

      // Candidate 1: /api/teams/targets/assignments/$assignmentId
      if (assignmentId.isNotEmpty) {
        try {
          debugPrint('Trying deleteAssignment: /api/teams/targets/assignments/$assignmentId');
          final response = await client.dio.delete('/api/teams/targets/assignments/$assignmentId');
          debugPrint('deleteAssignment Candidate 1 success: ${response.statusCode}');
          return const ApiResult.success(null);
        } on DioException catch (e) {
          lastDioError = e;
          debugPrint('/api/teams/targets/assignments/$assignmentId failed: ${e.response?.statusCode}');
          if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
            return ApiResult.failure(_handleDioError(e), statusCode: e.response?.statusCode, error: e);
          }
        }
      }

      // Candidate 2: /api/teams/targets/assigned/$assignmentId
      if (assignmentId.isNotEmpty) {
        try {
          debugPrint('Trying deleteAssignment: /api/teams/targets/assigned/$assignmentId');
          final response = await client.dio.delete('/api/teams/targets/assigned/$assignmentId');
          debugPrint('deleteAssignment Candidate 2 success: ${response.statusCode}');
          return const ApiResult.success(null);
        } on DioException catch (e) {
          lastDioError = e;
          debugPrint('/api/teams/targets/assigned/$assignmentId failed: ${e.response?.statusCode}');
          if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
            return ApiResult.failure(_handleDioError(e), statusCode: e.response?.statusCode, error: e);
          }
        }
      }

      // Candidate 3: Target-scoped: /api/teams/targets/$targetId/assignments/$assignmentId
      if (targetId != null && targetId.isNotEmpty && assignmentId.isNotEmpty) {
        try {
          debugPrint('Trying deleteAssignment: /api/teams/targets/$targetId/assignments/$assignmentId');
          final response = await client.dio.delete('/api/teams/targets/$targetId/assignments/$assignmentId');
          debugPrint('deleteAssignment Candidate 3 success: ${response.statusCode}');
          return const ApiResult.success(null);
        } on DioException catch (e) {
          lastDioError = e;
          debugPrint('/api/teams/targets/$targetId/assignments/$assignmentId failed: ${e.response?.statusCode}');
          if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
            return ApiResult.failure(_handleDioError(e), statusCode: e.response?.statusCode, error: e);
          }
        }
      }

      // Candidate 4: Target-scoped unassign: /api/teams/targets/$targetId/assign-worker (DELETE)
      if (targetId != null && targetId.isNotEmpty) {
        final isWorker = assignedToType?.toLowerCase() == 'worker';
        final isTeam = assignedToType?.toLowerCase() == 'team';

        if (isWorker || (assignedToId != null && assignedToId.isNotEmpty)) {
          try {
            debugPrint('Trying deleteAssignment: DELETE /api/teams/targets/$targetId/assign-worker');
            final response = await client.dio.delete(
              '/api/teams/targets/$targetId/assign-worker',
              data: {
                if (assignedToId != null && assignedToId.isNotEmpty) 'worker_id': assignedToId,
                if (assignmentId.isNotEmpty) 'assignment_id': assignmentId,
              },
            );
            debugPrint('deleteAssignment Candidate 4 (worker) success: ${response.statusCode}');
            return const ApiResult.success(null);
          } on DioException catch (e) {
            lastDioError = e;
            debugPrint('DELETE /api/teams/targets/$targetId/assign-worker failed: ${e.response?.statusCode}');
            if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
              return ApiResult.failure(_handleDioError(e), statusCode: e.response?.statusCode, error: e);
            }
          }
        }

        if (isTeam || (assignedToId != null && assignedToId.isNotEmpty)) {
          try {
            debugPrint('Trying deleteAssignment: DELETE /api/teams/targets/$targetId/assign-team');
            final response = await client.dio.delete(
              '/api/teams/targets/$targetId/assign-team',
              data: {
                if (assignedToId != null && assignedToId.isNotEmpty) 'team_id': assignedToId,
                if (assignmentId.isNotEmpty) 'assignment_id': assignmentId,
              },
            );
            debugPrint('deleteAssignment Candidate 4 (team) success: ${response.statusCode}');
            return const ApiResult.success(null);
          } on DioException catch (e) {
            lastDioError = e;
            debugPrint('DELETE /api/teams/targets/$targetId/assign-team failed: ${e.response?.statusCode}');
            if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
              return ApiResult.failure(_handleDioError(e), statusCode: e.response?.statusCode, error: e);
            }
          }
        }

        // Candidate 5: POST /api/teams/targets/$targetId/unassign
        try {
          debugPrint('Trying deleteAssignment: POST /api/teams/targets/$targetId/unassign');
          final response = await client.dio.post(
            '/api/teams/targets/$targetId/unassign',
            data: {
              if (assignmentId.isNotEmpty) 'assignment_id': assignmentId,
              if (assignedToId != null && assignedToId.isNotEmpty)
                (assignedToType?.toLowerCase() == 'worker' ? 'worker_id' : 'team_id'): assignedToId,
            },
          );
          debugPrint('deleteAssignment Candidate 5 success: ${response.statusCode}');
          return const ApiResult.success(null);
        } on DioException catch (e) {
          lastDioError = e;
          debugPrint('POST /api/teams/targets/$targetId/unassign failed: ${e.response?.statusCode}');
          if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
            return ApiResult.failure(_handleDioError(e), statusCode: e.response?.statusCode, error: e);
          }
        }
      }

      // Candidate 6: /api/targets/assignments/$assignmentId
      if (assignmentId.isNotEmpty) {
        try {
          debugPrint('Trying deleteAssignment: /api/targets/assignments/$assignmentId');
          final response = await client.dio.delete('/api/targets/assignments/$assignmentId');
          debugPrint('deleteAssignment Candidate 6 success: ${response.statusCode}');
          return const ApiResult.success(null);
        } on DioException catch (e) {
          lastDioError = e;
          debugPrint('/api/targets/assignments/$assignmentId failed: ${e.response?.statusCode}');
          if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
            return ApiResult.failure(_handleDioError(e), statusCode: e.response?.statusCode, error: e);
          }
        }
      }

      // Candidate 7: Query parameter variant /api/teams/targets/assigned?assignment_id=$assignmentId
      if (assignmentId.isNotEmpty) {
        try {
          debugPrint('Trying deleteAssignment: /api/teams/targets/assigned?assignment_id=$assignmentId');
          final response = await client.dio.delete(
            '/api/teams/targets/assigned',
            queryParameters: {'assignment_id': assignmentId},
          );
          debugPrint('deleteAssignment Candidate 7 success: ${response.statusCode}');
          return const ApiResult.success(null);
        } on DioException catch (e) {
          lastDioError = e;
          debugPrint('/api/teams/targets/assigned?assignment_id=$assignmentId failed: ${e.response?.statusCode}');
        }
      }

      // Candidate 8: Old endpoint /api/teams/assignments/$assignmentId
      if (assignmentId.isNotEmpty) {
        try {
          debugPrint('Trying deleteAssignment: /api/teams/assignments/$assignmentId');
          final response = await client.dio.delete('/api/teams/assignments/$assignmentId');
          debugPrint('deleteAssignment Candidate 8 success: ${response.statusCode}');
          return const ApiResult.success(null);
        } on DioException catch (e) {
          lastDioError = e;
        }
      }

      if (lastDioError != null) {
        return ApiResult.failure(
          _handleDioError(lastDioError),
          statusCode: lastDioError.response?.statusCode,
          error: lastDioError,
        );
      }
      return const ApiResult.failure('Unable to delete assignment');
    } catch (e) {
      debugPrint('deleteAssignment exception: $e');
      return ApiResult.failure('Failed to delete assignment: $e');
    }
  }

  Future<ApiResult<String?>> getLeaderTeamId(String leaderId) async {
    try {
      final client = await apiClient;
      final response = await client.dio.get('/api/teams?leader_id=$leaderId');

      final teams = _extractList(response.data, const ['teams', 'data']);
      if (teams.isEmpty) return const ApiResult.success(null);

      final first = teams.first;
      if (first is Map) {
        return ApiResult.success(first['id']?.toString());
      }
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to resolve team id: $e');
    }
  }

  /// Best-effort worker list for assignment UI.
  ///
  /// The backend team-members endpoint is team-scoped; in the Flutter app
  /// there are older routes like `/api/teams/my/workers`. We try a couple
  /// options so the UI can function without additional backend work.
  Future<ApiResult<List<TeamMemberLite>>> getAssignableWorkers({
    String? teamId,
  }) async {
    try {
      final client = await apiClient;

      Response<dynamic> response;
      try {
        response = await client.dio.get('/api/teams/my/workers');
      } on DioException {
        if (teamId == null || teamId.isEmpty) rethrow;
        response = await client.dio.get('/api/teams/$teamId/workers');
      }

      final list = _extractList(response.data, const [
        'data',
        'workers',
        'members',
      ]);
      final workers = list
          .whereType<Map>()
          .map((e) => TeamMemberLite.fromJson(e.cast<String, dynamic>()))
          .where((w) => w.id.isNotEmpty)
          .toList();

      return ApiResult.success(workers);
    } on DioException catch (e) {
      return ApiResult.failure(
        _handleDioError(e),
        statusCode: e.response?.statusCode,
        error: e,
      );
    } catch (e) {
      return ApiResult.failure('Failed to load workers: $e');
    }
  }

  String _handleDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (data is Map && data['message'] != null)
      return data['message'].toString();

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        return 'Server error (Status: ${e.response?.statusCode})';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      default:
        return 'An unexpected error occurred';
    }
  }
}
