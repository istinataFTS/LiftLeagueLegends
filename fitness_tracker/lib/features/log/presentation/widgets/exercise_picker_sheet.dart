import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/themes/lift_theme.dart';
import '../../../../domain/entities/exercise.dart';

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet._({
    required this.exercises,
    required this.recentExerciseIds,
    this.selected,
  });

  final List<Exercise> exercises;
  final List<String> recentExerciseIds;
  final Exercise? selected;

  /// Shows the full-screen exercise picker sheet and returns the chosen
  /// [Exercise], or `null` if the user dismissed without selecting.
  static Future<Exercise?> show(
    BuildContext context, {
    required List<Exercise> exercises,
    required List<String> recentExerciseIds,
    Exercise? selected,
  }) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        minHeight: screenHeight * 0.9,
        maxHeight: screenHeight * 0.9,
      ),
      builder: (_) => ExercisePickerSheet._(
        exercises: exercises,
        recentExerciseIds: recentExerciseIds,
        selected: selected,
      ),
    );
  }

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> get _filteredAllExercises {
    if (_searchQuery.isEmpty) return widget.exercises;

    final String query = _searchQuery.toLowerCase();
    return widget.exercises.where((Exercise e) {
      return e.name.toLowerCase().contains(query) ||
          e.muscleGroups.any(
            (mg) =>
                MuscleGroups.getDisplayName(mg).toLowerCase().contains(query),
          );
    }).toList();
  }

  List<Exercise> get _recentExercises {
    if (_searchQuery.isNotEmpty) return const [];

    final Map<String, Exercise> exerciseById = {
      for (final Exercise e in widget.exercises) e.id: e,
    };

    final List<Exercise> result = [];
    for (final String id in widget.recentExerciseIds) {
      final Exercise? exercise = exerciseById[id];
      if (exercise == null) {
        continue;
      }
      result.add(exercise);
      if (result.length >= 5) break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final List<Exercise> recents = _recentExercises;
    final List<Exercise> all = _filteredAllExercises;
    final bool hasQuery = _searchQuery.isNotEmpty;

    return Container(
      key: const ValueKey<String>('exercise-picker-panel'),
      decoration: const BoxDecoration(
        color: LiftColors.panelTop,
        border: Border.fromBorderSide(
          BorderSide(
            color: LiftColors.borderStrong,
            width: LiftShape.borderWidth,
          ),
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: LiftElevation.elevated,
      ),
      child: Column(
        children: <Widget>[
          _buildHeader(context),
          const Divider(height: 1, color: LiftColors.hairline),
          _buildSearchField(),
          _buildResultCount(all.length, widget.exercises.length, hasQuery),
          const Divider(height: 1, color: LiftColors.hairline),
          Expanded(
            child: hasQuery
                ? _buildFlatList(all)
                : _buildSectionedList(recents, all),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              AppStrings.selectExercise,
              style: LiftText.titleLarge.copyWith(
                color: LiftColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: LiftColors.textDim),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        style: LiftText.bodyLarge.copyWith(color: LiftColors.textPrimary),
        decoration: InputDecoration(
          hintText: AppStrings.searchExercisesHint,
          prefixIcon: const Icon(Icons.search, color: LiftColors.textDim),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: LiftColors.textDim),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
        onChanged: (String value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildResultCount(int shown, int total, bool hasQuery) {
    final String text = hasQuery ? '$shown OF $total' : '$total ITEMS';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
        ),
      ),
    );
  }

  Widget _buildFlatList(List<Exercise> exercises) {
    if (exercises.isEmpty) {
      return Center(
        child: Text(
          AppStrings.noResultsFound,
          style: LiftText.bodyMedium.copyWith(color: LiftColors.textDim),
        ),
      );
    }

    return ListView.builder(
      itemCount: exercises.length,
      itemBuilder: (_, int index) => _buildExerciseTile(exercises[index]),
    );
  }

  Widget _buildSectionedList(List<Exercise> recents, List<Exercise> all) {
    return ListView(
      children: <Widget>[
        if (recents.isNotEmpty) ...<Widget>[
          _buildSectionHeader(AppStrings.pickerRecents),
          ...recents.map(_buildExerciseTile),
          const Divider(
            height: 16,
            indent: 16,
            endIndent: 16,
            color: LiftColors.hairline,
          ),
        ],
        _buildSectionHeader(AppStrings.pickerAllExercises),
        ...all.map(_buildExerciseTile),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
      ),
    );
  }

  Widget _buildExerciseTile(Exercise exercise) {
    final bool isSelected = widget.selected?.id == exercise.id;
    final String muscleText = exercise.muscleGroups
        .map(MuscleGroups.getDisplayName)
        .join(' · ')
        .toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, exercise),
        child: Container(
          key: ValueKey<String>('exercise-row-${exercise.id}'),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? LiftColors.actionWash : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? LiftColors.actionTint : Colors.transparent,
                width: LiftShape.borderWidthActive,
              ),
              bottom: const BorderSide(color: LiftColors.hairline, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildLeadingTile(isSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise.name,
                  style: LiftText.bodyLarge.copyWith(
                    color: LiftColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (muscleText.isNotEmpty) ...<Widget>[
                const SizedBox(width: 12),
                Text(
                  muscleText,
                  textAlign: TextAlign.right,
                  style: LiftText.labelLarge.copyWith(
                    color: LiftColors.textDim,
                  ),
                ),
              ],
              if (isSelected) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: LiftColors.actionTint),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingTile(bool isSelected) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isSelected ? LiftColors.actionFill : LiftColors.surfaceRaised,
      ),
      child: Icon(
        Icons.fitness_center,
        size: 18,
        color: isSelected ? Colors.white : LiftColors.textDim,
      ),
    );
  }
}
