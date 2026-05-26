import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/themes/app_theme.dart';
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
      backgroundColor: AppTheme.surfaceDark,
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
  String? _selectedMuscle;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> get _filteredAllExercises {
    var result = widget.exercises;

    if (_selectedMuscle != null) {
      result = result
          .where((e) => e.muscleGroups.contains(_selectedMuscle))
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final String query = _searchQuery.toLowerCase();
      result = result.where((e) {
        return e.name.toLowerCase().contains(query) ||
            e.muscleGroups.any(
              (mg) =>
                  MuscleGroups.getDisplayName(mg).toLowerCase().contains(query),
            );
      }).toList();
    }

    return result;
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
      if (_selectedMuscle != null &&
          !exercise.muscleGroups.contains(_selectedMuscle)) {
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

    return Column(
      children: <Widget>[
        _buildHeader(context),
        const Divider(height: 1),
        _buildSearchField(),
        _buildMuscleFilterChips(),
        const Divider(height: 1),
        Expanded(
          child: hasQuery
              ? _buildFlatList(all)
              : _buildSectionedList(recents, all),
        ),
      ],
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
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
        decoration: InputDecoration(
          hintText: AppStrings.searchExercisesHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
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

  Widget _buildMuscleFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text(AppStrings.all),
              selected: _selectedMuscle == null,
              onSelected: (_) => setState(() => _selectedMuscle = null),
            ),
          ),
          ...MuscleGroups.all.map(
            (String muscle) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(MuscleGroups.getDisplayName(muscle)),
                selected: _selectedMuscle == muscle,
                onSelected: (_) => setState(() {
                  _selectedMuscle = _selectedMuscle == muscle ? null : muscle;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatList(List<Exercise> exercises) {
    if (exercises.isEmpty) {
      return Center(
        child: Text(
          AppStrings.noResultsFound,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
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
          const Divider(height: 16, indent: 16, endIndent: 16),
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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppTheme.textDim,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildExerciseTile(Exercise exercise) {
    final bool isSelected = widget.selected?.id == exercise.id;

    return ListTile(
      title: Text(
        exercise.name,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        exercise.muscleGroups.map(MuscleGroups.getDisplayName).join(', '),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppTheme.primaryOrange)
          : null,
      onTap: () => Navigator.pop(context, exercise),
    );
  }
}
