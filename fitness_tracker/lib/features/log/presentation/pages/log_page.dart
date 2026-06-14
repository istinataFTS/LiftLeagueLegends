import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../widgets/log_exercise_tab.dart';
import '../widgets/log_macros_tab.dart';
import '../widgets/log_meal_tab.dart';
import '../widgets/shared/log_tab_selector.dart';

typedef LogTabBuilder = Widget Function(DateTime initialDate);

class LogPage extends StatefulWidget {
  final int initialIndex;
  final DateTime? initialDate;
  final LogTabBuilder? exerciseTabBuilder;
  final LogTabBuilder? mealTabBuilder;
  final LogTabBuilder? macrosTabBuilder;

  const LogPage({
    super.key,
    this.initialIndex = 0,
    this.initialDate,
    this.exerciseTabBuilder,
    this.mealTabBuilder,
    this.macrosTabBuilder,
  });

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  static const int _minTabIndex = 0;
  static const int _maxTabIndex = 2;

  late int _selectedIndex;

  DateTime get _effectiveInitialDate => widget.initialDate ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(_minTabIndex, _maxTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text(AppStrings.logTitle),
        automaticallyImplyLeading: canPop,
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: LogTabSelector(
              selectedIndex: _selectedIndex,
              onChanged: (int i) => setState(() => _selectedIndex = i),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildExerciseTab();
      case 1:
        return _buildMealTab();
      case 2:
        return _buildMacrosTab();
      default:
        return _buildExerciseTab();
    }
  }

  Widget _buildExerciseTab() {
    return widget.exerciseTabBuilder?.call(_effectiveInitialDate) ??
        LogExerciseTab(initialDate: _effectiveInitialDate);
  }

  Widget _buildMealTab() {
    return widget.mealTabBuilder?.call(_effectiveInitialDate) ??
        LogMealTab(initialDate: _effectiveInitialDate);
  }

  Widget _buildMacrosTab() {
    return widget.macrosTabBuilder?.call(_effectiveInitialDate) ??
        LogMacrosTab(initialDate: _effectiveInitialDate);
  }
}
