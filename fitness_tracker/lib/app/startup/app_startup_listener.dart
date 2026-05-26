import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/time_period.dart';
import '../../features/home/application/home_bloc.dart';
import '../../features/home/application/muscle_visual_bloc.dart';
import '../../features/log/log.dart';

class AppStartupListener extends StatefulWidget {
  const AppStartupListener({required this.child, super.key});

  final Widget child;

  @override
  State<AppStartupListener> createState() => _AppStartupListenerState();
}

class _AppStartupListenerState extends State<AppStartupListener> {
  bool _didDispatchInitialLoads = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dispatchInitialLoads();
    });
  }

  void _dispatchInitialLoads() {
    if (!mounted || _didDispatchInitialLoads) {
      return;
    }

    _didDispatchInitialLoads = true;

    // Keep startup focused on the initial Home experience only.
    // Other feature data is loaded lazily when the user first opens its tab.
    context.read<WorkoutBloc>().add(const LoadWeeklySetsEvent());
    context.read<HomeBloc>().add(LoadHomeDataEvent());
    context.read<MuscleVisualBloc>().add(
      const LoadMuscleVisualsEvent(TimePeriod.week),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
