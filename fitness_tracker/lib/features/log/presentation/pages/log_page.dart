import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../widgets/log_exercise_tab.dart';
import '../widgets/log_macros_tab.dart';
import '../widgets/log_meal_tab.dart';

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
          _buildSegmentedControl(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: <Widget>[
          _buildSegmentButton(
            index: 0,
            label: AppStrings.logExerciseTab,
            icon: Icons.fitness_center,
          ),
          _buildSegmentButton(
            index: 1,
            label: AppStrings.logMealTab,
            icon: Icons.restaurant,
          ),
          _buildSegmentButton(
            index: 2,
            label: AppStrings.logMacrosTab,
            icon: Icons.calculate,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textDim,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textDim,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
