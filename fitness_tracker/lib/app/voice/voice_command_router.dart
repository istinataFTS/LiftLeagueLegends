import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/history/history.dart';
import '../../features/log/application/nutrition_log_bloc.dart';
import '../../features/log/application/workout_bloc.dart';
import '../../features/voice/application/voice_bloc.dart';
import '../../features/voice/application/voice_mutation_outcome.dart';

/// Listens to [VoiceBloc.effects] and dispatches each mutation command via
/// `context.read<X>()`. Lives as a child of the auth-session shell's
/// [MultiBlocProvider] so `context.read` resolves the same [WorkoutBloc],
/// [NutritionLogBloc], and [HistoryBloc] instances the user-facing pages
/// observe — no ghost instances, no GetIt detours.
///
/// ## Round-trip dispatch contract
///
/// Each [VoiceMutationCommand] carries a [Completer<VoiceMutationOutcome>]
/// owned by [VoiceBloc]. After dispatching the corresponding target-BLoC
/// event, this router listens for the target BLoC's next success or failure
/// effect and completes the completer accordingly. [VoiceBloc] awaits the
/// completer before speaking a response, so the user hears an accurate
/// outcome rather than a phantom success.
///
/// ## Serialisation
///
/// At most one mutation dispatch is in-flight at any time. Subsequent
/// [VoiceMutationCommand]s are queued in FIFO order (up to
/// [_maxQueueSize]). Commands arriving when the queue is full are immediately
/// completed with [VoiceMutationTimeout] so [VoiceBloc] can report back
/// without hanging.
class VoiceCommandRouter extends StatefulWidget {
  const VoiceCommandRouter({required this.child, super.key});

  final Widget child;

  @override
  State<VoiceCommandRouter> createState() => _VoiceCommandRouterState();
}

// Identifies which BLoC is the target of the current in-flight dispatch,
// so that unrelated effects from other BLoCs do not accidentally complete
// the in-flight completer.
enum _InflightTarget { workout, nutritionLog, history }

/// Bundles a pending command with the BLoC-dispatch closure and the target
/// identifier used to route outcome effects back to the right completer.
class _PendingDispatch {
  _PendingDispatch({
    required this.command,
    required this.dispatch,
    required this.target,
  });

  final VoiceMutationCommand command;
  final VoidCallback dispatch;
  final _InflightTarget target;
}

class _VoiceCommandRouterState extends State<VoiceCommandRouter> {
  static const int _maxQueueSize = 5;

  StreamSubscription<VoiceEffect>? _voiceSub;
  StreamSubscription<WorkoutUiEffect>? _workoutSub;
  StreamSubscription<NutritionLogUiEffect>? _nutritionSub;
  StreamSubscription<HistoryUiEffect>? _historySub;

  // The completer belonging to the in-flight command; null when idle.
  Completer<VoiceMutationOutcome>? _inflightCompleter;

  // Which BLoC we are waiting on for the in-flight dispatch.
  _InflightTarget? _inflightTarget;

  // Commands waiting for the in-flight dispatch to settle.
  final Queue<_PendingDispatch> _queue = Queue<_PendingDispatch>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voiceSub ??= context.read<VoiceBloc>().effects.listen(_onVoiceEffect);
    _workoutSub ??= context.read<WorkoutBloc>().effects.listen(
      _onWorkoutEffect,
    );
    _nutritionSub ??= context.read<NutritionLogBloc>().effects.listen(
      _onNutritionEffect,
    );
    _historySub ??= context.read<HistoryBloc>().effects.listen(
      _onHistoryEffect,
    );
  }

  // ---------------------------------------------------------------------------
  // Voice effect handler — receives commands from VoiceBloc
  // ---------------------------------------------------------------------------

  void _onVoiceEffect(VoiceEffect effect) {
    if (!mounted || effect is! VoiceMutationCommand) return;

    final pending = _buildPending(effect);

    // Serialise: if another dispatch is in-flight, queue or drop.
    if (_inflightCompleter != null) {
      if (_queue.length >= _maxQueueSize) {
        // Queue is full — complete immediately with timeout so VoiceBloc
        // does not hang waiting for a response that will never come.
        effect.completer.complete(const VoiceMutationTimeout());
        return;
      }
      _queue.addLast(pending);
    } else {
      _executeDispatch(pending);
    }
  }

  // ---------------------------------------------------------------------------
  // Target BLoC effect handlers — complete the in-flight completer
  // ---------------------------------------------------------------------------

  void _onWorkoutEffect(WorkoutUiEffect effect) {
    if (_inflightTarget != _InflightTarget.workout) return;
    switch (effect) {
      case WorkoutLoggedEffect():
        _completeInflight(const VoiceMutationSuccess());
      case WorkoutMutationFailedEffect(:final message):
        _completeInflight(VoiceMutationFailure(message));
    }
  }

  void _onNutritionEffect(NutritionLogUiEffect effect) {
    if (_inflightTarget != _InflightTarget.nutritionLog) return;
    switch (effect) {
      case NutritionLogSuccessEffect():
        _completeInflight(const VoiceMutationSuccess());
      case NutritionMutationFailedEffect(:final message):
        _completeInflight(VoiceMutationFailure(message));
    }
  }

  void _onHistoryEffect(HistoryUiEffect effect) {
    if (_inflightTarget != _InflightTarget.history) return;
    switch (effect) {
      case HistorySuccessEffect():
        _completeInflight(const VoiceMutationSuccess());
      case HistoryMutationFailedEffect(:final message):
        _completeInflight(VoiceMutationFailure(message));
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Builds a [_PendingDispatch] from a [VoiceMutationCommand], binding
  /// the appropriate BLoC event-add closure and target identifier.
  _PendingDispatch _buildPending(VoiceMutationCommand effect) {
    switch (effect) {
      case VoiceAddWorkoutSetCommand(:final set):
        return _PendingDispatch(
          command: effect,
          dispatch: () =>
              context.read<WorkoutBloc>().add(AddWorkoutSetEvent(set)),
          target: _InflightTarget.workout,
        );
      case VoiceUpdateWorkoutSetCommand(:final set):
        return _PendingDispatch(
          command: effect,
          dispatch: () => context.read<HistoryBloc>().add(UpdateSetEvent(set)),
          target: _InflightTarget.history,
        );
      case VoiceDeleteWorkoutSetCommand(:final setId):
        return _PendingDispatch(
          command: effect,
          dispatch: () =>
              context.read<HistoryBloc>().add(DeleteSetEvent(setId)),
          target: _InflightTarget.history,
        );
      case VoiceAddNutritionLogCommand(:final log):
        return _PendingDispatch(
          command: effect,
          dispatch: () =>
              context.read<NutritionLogBloc>().add(AddNutritionLogEvent(log)),
          target: _InflightTarget.nutritionLog,
        );
      case VoiceUpdateNutritionLogCommand(:final log):
        return _PendingDispatch(
          command: effect,
          dispatch: () => context.read<HistoryBloc>().add(
            UpdateNutritionHistoryLogEvent(log),
          ),
          target: _InflightTarget.history,
        );
      case VoiceDeleteNutritionLogCommand(:final logId):
        return _PendingDispatch(
          command: effect,
          dispatch: () => context.read<HistoryBloc>().add(
            DeleteNutritionHistoryLogEvent(logId),
          ),
          target: _InflightTarget.history,
        );
    }
  }

  /// Marks the command as in-flight and calls the dispatch closure.
  void _executeDispatch(_PendingDispatch pending) {
    _inflightCompleter = pending.command.completer;
    _inflightTarget = pending.target;
    if (mounted) {
      pending.dispatch();
    }
  }

  /// Completes the in-flight completer with [outcome] and drains the queue.
  void _completeInflight(VoiceMutationOutcome outcome) {
    final completer = _inflightCompleter;
    _inflightCompleter = null;
    _inflightTarget = null;
    completer?.complete(outcome);
    _drainQueue();
  }

  /// Starts the next queued dispatch if one exists.
  void _drainQueue() {
    if (_queue.isEmpty) return;
    final next = _queue.removeFirst();
    _executeDispatch(next);
  }

  @override
  void dispose() {
    // Complete any in-flight or queued completers with Timeout so VoiceBloc
    // is not permanently suspended if the router is unmounted mid-dispatch.
    _inflightCompleter?.complete(const VoiceMutationTimeout());
    _inflightCompleter = null;
    for (final pending in _queue) {
      pending.command.completer.complete(const VoiceMutationTimeout());
    }
    _queue.clear();
    _voiceSub?.cancel();
    _workoutSub?.cancel();
    _nutritionSub?.cancel();
    _historySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
