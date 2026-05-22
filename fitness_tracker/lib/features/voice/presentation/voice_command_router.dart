import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/history/history.dart';
import '../../../features/log/application/nutrition_log_bloc.dart';
import '../../../features/log/application/workout_bloc.dart';
import '../application/voice_bloc.dart';

/// Listens to [VoiceBloc.effects] and dispatches each mutation command via
/// `context.read<X>()`. Lives as a child of the auth-session shell's
/// [MultiBlocProvider] so `context.read` resolves the same [WorkoutBloc],
/// [NutritionLogBloc], and [HistoryBloc] instances the user-facing pages
/// observe — no ghost instances, no GetIt detours.
///
/// Replaces the previous design where [VoiceBloc] captured BLoC references
/// at construction time, which forced the target BLoCs to be singletons.
class VoiceCommandRouter extends StatefulWidget {
  const VoiceCommandRouter({required this.child, super.key});

  final Widget child;

  @override
  State<VoiceCommandRouter> createState() => _VoiceCommandRouterState();
}

class _VoiceCommandRouterState extends State<VoiceCommandRouter> {
  StreamSubscription<VoiceEffect>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context.read<VoiceBloc>().effects.listen(_dispatch);
  }

  void _dispatch(VoiceEffect effect) {
    if (!mounted || effect is! VoiceMutationCommand) return;
    switch (effect) {
      case VoiceAddWorkoutSetCommand(:final set):
        context.read<WorkoutBloc>().add(AddWorkoutSetEvent(set));
      case VoiceUpdateWorkoutSetCommand(:final set):
        context.read<HistoryBloc>().add(UpdateSetEvent(set));
      case VoiceDeleteWorkoutSetCommand(:final setId):
        context.read<HistoryBloc>().add(DeleteSetEvent(setId));
      case VoiceAddNutritionLogCommand(:final log):
        context.read<NutritionLogBloc>().add(AddNutritionLogEvent(log));
      case VoiceUpdateNutritionLogCommand(:final log):
        context.read<HistoryBloc>().add(UpdateNutritionHistoryLogEvent(log));
      case VoiceDeleteNutritionLogCommand(:final logId):
        context.read<HistoryBloc>().add(DeleteNutritionHistoryLogEvent(logId));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
