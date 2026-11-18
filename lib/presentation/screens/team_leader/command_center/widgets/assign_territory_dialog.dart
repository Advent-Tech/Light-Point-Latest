import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/storage/local_storage.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/team_model.dart';
import '../../../../../data/models/territory_model.dart';
import '../../../../blocs/territory/territory_bloc.dart';

/// Shows the Assign Territory modal dialog.
Future<bool?> showAssignTerritoryDialog({
  required BuildContext context,
  required GeoTerritory territory,
  required List<TeamMember> workers,
  String? preSelectedWorkerId,
  String? teamId,
  VoidCallback? onAssigned,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AssignTerritoryDialog(
      territory: territory,
      workers: workers,
      preSelectedWorkerId: preSelectedWorkerId,
      teamId: teamId,
      onAssigned: onAssigned,
    ),
  );
}

class AssignTerritoryDialog extends StatefulWidget {
  final GeoTerritory territory;
  final List<TeamMember> workers;
  final String? preSelectedWorkerId;
  final String? teamId;
  final VoidCallback? onAssigned;

  const AssignTerritoryDialog({
    super.key,
    required this.territory,
    required this.workers,
    this.preSelectedWorkerId,
    this.teamId,
    this.onAssigned,
  });

  @override
  State<AssignTerritoryDialog> createState() => _AssignTerritoryDialogState();
}

class _AssignTerritoryDialogState extends State<AssignTerritoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String? _selectedWorkerId;
  String _priority = 'medium';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-select worker if available in list, or default to first
    final hasPreselected = widget.preSelectedWorkerId != null &&
        widget.workers.any((w) => w.userId == widget.preSelectedWorkerId);

    if (hasPreselected) {
      _selectedWorkerId = widget.preSelectedWorkerId;
    } else if (widget.workers.isNotEmpty) {
      _selectedWorkerId = widget.workers.first.userId;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkerId == null || _selectedWorkerId!.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a light squad member';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final storage = await LocalStorage.getInstance();
      final userData = storage.getUserData();
      final leaderId = userData?['id']?.toString() ?? '';

      // Determine team ID from parameters, user data, or worker model
      String resolvedTeamId = widget.teamId ?? userData?['team_id']?.toString() ?? '';
      if (resolvedTeamId.isEmpty && widget.workers.isNotEmpty) {
        final worker = widget.workers.firstWhere(
          (w) => w.userId == _selectedWorkerId,
          orElse: () => widget.workers.first,
        );
        resolvedTeamId = worker.teamId;
      }

      if (widget.territory.id.isEmpty) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Invalid territory: Missing territory ID.';
        });
        return;
      }

      if (!mounted) return;

      debugPrint(
        'Assigning territory: id=${widget.territory.id}, solid=${widget.territory.solid}, worker=$_selectedWorkerId, team=$resolvedTeamId, leader=$leaderId',
      );

      context.read<TerritoryBloc>().add(
            TerritoryAssignToWorker(
              territoryId: widget.territory.id,
              territorySolid: widget.territory.solid,
              workerId: _selectedWorkerId!,
              teamId: resolvedTeamId,
              assignedBy: leaderId,
              priority: _priority,
              notes: _notesController.text.trim().isNotEmpty
                  ? _notesController.text.trim()
                  : null,
            ),
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final territoryTitle = widget.territory.entityName.isNotEmpty
        ? widget.territory.entityName
        : 'Territory #${widget.territory.id.substring(0, widget.territory.id.length > 8 ? 8 : widget.territory.id.length)}';

    return BlocListener<TerritoryBloc, TerritoryState>(
      listener: (context, state) {
        if (state is TerritoryAssignSuccess) {
          setState(() {
            _isSubmitting = false;
          });
          Navigator.of(context).pop(true);
          widget.onAssigned?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else if (state is TerritoryError) {
          setState(() {
            _isSubmitting = false;
            _errorMessage = state.message;
          });
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.assignment_ind_outlined,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assign Territory',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              territoryTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Territory Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.territory.displayLocation.isNotEmpty
                                ? widget.territory.displayLocation
                                : 'Coordinates assigned',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (widget.territory.housingUnits != null &&
                            widget.territory.housingUnits! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${widget.territory.housingUnits} units',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Worker Picker
                  Text(
                    'Assign to Light Squad Member *',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.workers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No team members available to assign. Please add members to your team first.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.warningDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedWorkerId,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      hint: const Text('Select a member'),
                      items: widget.workers.map((worker) {
                        final name = worker.displayName ?? worker.email ?? 'Light Squad';
                        return DropdownMenuItem<String>(
                          value: worker.userId,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'W',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              setState(() {
                                _selectedWorkerId = value;
                                _errorMessage = null;
                              });
                            },
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Please select a member' : null,
                    ),
                  const SizedBox(height: 18),

                  // Priority Selector
                  Text(
                    'Priority',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'low', label: Text('Low')),
                      ButtonSegment(value: 'medium', label: Text('Medium')),
                      ButtonSegment(value: 'high', label: Text('High')),
                      ButtonSegment(value: 'urgent', label: Text('Urgent')),
                    ],
                    selected: {_priority},
                    onSelectionChanged: _isSubmitting
                        ? null
                        : (selection) {
                            setState(() {
                              _priority = selection.first;
                            });
                          },
                  ),
                  const SizedBox(height: 18),

                  // Notes (Optional)
                  Text(
                    'Notes (Optional)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'e.g. Focus on apartment buildings first…',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(_isSubmitting ? 'Assigning…' : 'Assign Territory'),
                        onPressed: (_isSubmitting || widget.workers.isEmpty)
                            ? null
                            : _submitAssignment,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
