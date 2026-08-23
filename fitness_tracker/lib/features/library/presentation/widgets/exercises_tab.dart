import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/themes/lift_theme.dart';
import '../../../../domain/entities/exercise.dart';
import '../../application/exercise_bloc.dart';
import '../../application/library_exercise_filters.dart';
import '../library_strings.dart';
import '../models/library_exercise_view_data.dart';
import 'exercise_dialog.dart';
import 'library_chrome.dart';

/// The Exercises tab, rebuilt from frame 11.
///
/// The frame replaces cards with rules: no icon tile, no muscle pills, no `⋮`
/// overflow menu, no bottom action bar behind the CTA. Each exercise is a name
/// over one mono meta line, closed by a hairline. Editing is a tap on the row
/// and deleting is a long-press, because the frame draws no control for either.
class ExercisesTab extends StatefulWidget {
  const ExercisesTab({this.headerSlivers = const <Widget>[], super.key});

  /// Slivers the page stacks above the tab's own content — its title and the
  /// pinned tab strip. They ride inside this tab's scroll view rather than
  /// above it so the title scrolls away with the rest of the header instead
  /// of holding a band of chrome open over a list that needs the room.
  final List<Widget> headerSlivers;

  static const Key searchFieldKey = ValueKey<String>(
    'library_exercises_search_field',
  );
  static const Key clearSearchButtonKey = ValueKey<String>(
    'library_exercises_clear_search_button',
  );
  static const Key allMusclesChipKey = ValueKey<String>(
    'library_exercises_all_muscles_chip',
  );
  static const Key resultCountKey = ValueKey<String>(
    'library_exercises_result_count',
  );
  static const Key retryButtonKey = ValueKey<String>(
    'library_exercises_retry_button',
  );
  static const Key reloadButtonKey = ValueKey<String>(
    'library_exercises_reload_button',
  );
  static const Key clearFiltersButtonKey = ValueKey<String>(
    'library_exercises_clear_filters_button',
  );
  static const Key addButtonKey = ValueKey<String>(
    'library_exercises_add_button',
  );
  static const Key loadingIndicatorKey = ValueKey<String>(
    'library_exercises_loading_indicator',
  );

  // Keys for the exercise dialog factor editor. They live here rather than on
  // [ExerciseDialog] because eleven test files already resolve them from this
  // class.
  static const Key factorEditorKey = ValueKey<String>(
    'library_exercise_dialog_factor_editor',
  );
  static const Key resetFactorsButtonKey = ValueKey<String>(
    'library_exercise_dialog_reset_factors_button',
  );

  static Key muscleChipKey(String muscle) =>
      ValueKey<String>('library_exercises_muscle_chip_$muscle');

  static Key factorSliderKey(String muscle) =>
      ValueKey<String>('library_exercise_dialog_factor_slider_$muscle');

  static Key factorValueKey(String muscle) =>
      ValueKey<String>('library_exercise_dialog_factor_value_$muscle');

  @override
  State<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<ExercisesTab> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedMuscleFilter;

  /// Caches the last-loaded exercise list so the tab remains visible when the
  /// bloc emits [ExerciseFactorsLoaded] (which is not an [ExercisesLoaded]
  /// state and would otherwise clear the list).
  List<Exercise> _cachedExercises = const <Exercise>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedMuscleFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExerciseBloc, ExerciseState>(
      listener: (BuildContext context, ExerciseState state) {
        if (state is ExerciseOperationSuccess) {
          _showSnack(context, state.message, LiftColors.success);
        }

        if (state is ExerciseError) {
          _showSnack(context, state.message, LiftColors.error);
        }
      },
      builder: (BuildContext context, ExerciseState state) {
        // Keep the cache fresh whenever exercises are loaded.
        if (state is ExercisesLoaded) {
          _cachedExercises = state.exercises;
        }

        if (state is ExerciseLoading) {
          return _buildScrollView(
            context,
            slivers: <Widget>[
              librarySliverFill(
                const Center(
                  child: CircularProgressIndicator(
                    key: ExercisesTab.loadingIndicatorKey,
                    color: LiftColors.actionTint,
                  ),
                ),
              ),
            ],
          );
        }

        if (state is ExerciseError) {
          return _buildScrollView(
            context,
            slivers: <Widget>[
              librarySliverFill(_buildErrorState(context, state.message)),
            ],
          );
        }

        final List<Exercise> filteredExercises = LibraryExerciseFilters.apply(
          exercises: _cachedExercises,
          query: _searchQuery,
          selectedMuscle: _selectedMuscleFilter,
        );

        final LibraryExercisePageViewData viewData =
            LibraryExerciseViewDataMapper.map(
              allExercises: _cachedExercises,
              filteredExercises: filteredExercises,
              searchQuery: _searchQuery,
              selectedMuscle: _selectedMuscleFilter,
            );

        return _buildScrollView(
          context,
          slivers: <Widget>[
            SliverToBoxAdapter(child: _buildBrowseHeader(context, viewData)),
            if (!viewData.hasExercises)
              librarySliverFill(_buildEmptyState(context))
            else if (!viewData.hasResults)
              librarySliverFill(_buildNoResultsState(context))
            else
              _buildExercisesList(context, viewData.items),
          ],
        );
      },
    );
  }

  void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(libraryGutter),
      ),
    );
  }

  Widget _buildScrollView(
    BuildContext context, {
    required List<Widget> slivers,
  }) {
    return LibraryTabScrollView(
      onRefresh: () => _reload(context),
      slivers: <Widget>[...widget.headerSlivers, ...slivers],
    );
  }

  /// Reloads and completes when the bloc reaches a terminal state.
  /// [LibraryTabScrollView] owns the timeout and the error handling.
  Future<void> _reload(BuildContext context) {
    final ExerciseBloc bloc = context.read<ExerciseBloc>();
    if (bloc.isClosed) return Future<void>.value();

    bloc.add(LoadExercisesEvent());
    return bloc.stream
        .firstWhere(
          (ExerciseState s) => s is ExercisesLoaded || s is ExerciseError,
        )
        .then((_) {});
  }

  Widget _buildBrowseHeader(
    BuildContext context,
    LibraryExercisePageViewData viewData,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LibraryBrowseBar(
            searchField: LibrarySearchField(
              fieldKey: ExercisesTab.searchFieldKey,
              clearButtonKey: ExercisesTab.clearSearchButtonKey,
              controller: _searchController,
              hintText: LibraryStrings.searchExercisesHint,
              onChanged: (String value) => setState(() => _searchQuery = value),
              onClear: () => setState(() {
                _searchController.clear();
                _searchQuery = '';
              }),
            ),
            addButton: LibraryAddButton(
              buttonKey: ExercisesTab.addButtonKey,
              semanticLabel: LibraryStrings.addExerciseCta,
              onPressed: () => _showExerciseDialog(context),
            ),
          ),
          const SizedBox(height: 14),
          LibraryFilterChipRow(
            chips: <Widget>[
              LibraryFilterChip(
                chipKey: ExercisesTab.allMusclesChipKey,
                label: LibraryStrings.allMuscles,
                selected: _selectedMuscleFilter == null,
                onTap: () => setState(() => _selectedMuscleFilter = null),
              ),
              ...MuscleGroups.all.map(
                (String muscle) => LibraryFilterChip(
                  chipKey: ExercisesTab.muscleChipKey(muscle),
                  label: MuscleGroups.getDisplayName(muscle),
                  selected: _selectedMuscleFilter == muscle,
                  onTap: () => setState(() {
                    _selectedMuscleFilter = _selectedMuscleFilter == muscle
                        ? null
                        : muscle;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          LibraryCountLabel(
            labelKey: ExercisesTab.resultCountKey,
            label: viewData.resultCountLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LibraryMessageState(
      title: LibraryStrings.noExercisesYet,
      body: LibraryStrings.noExercisesBody,
      actionLabel: LibraryStrings.addExerciseCta,
      onAction: () => _showExerciseDialog(context),
      secondaryActionLabel: LibraryStrings.reload,
      secondaryActionKey: ExercisesTab.reloadButtonKey,
      onSecondaryAction: () =>
          context.read<ExerciseBloc>().add(LoadExercisesEvent()),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return LibraryMessageState(
      title: LibraryStrings.clearFilters,
      body: LibraryStrings.noExerciseMatches,
      actionLabel: LibraryStrings.clearFilters,
      actionKey: ExercisesTab.clearFiltersButtonKey,
      onAction: _resetFilters,
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return LibraryMessageState(
      title: LibraryStrings.exercisesLoadFailed,
      titleColor: LiftColors.error,
      body: message,
      actionLabel: 'Retry',
      actionKey: ExercisesTab.retryButtonKey,
      onAction: () => context.read<ExerciseBloc>().add(LoadExercisesEvent()),
    );
  }

  Widget _buildExercisesList(
    BuildContext context,
    List<LibraryExerciseItemViewData> items,
  ) {
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final LibraryExerciseItemViewData item = items[index];
        return LibraryListRow(
          key: ValueKey<String>('library_exercise_row_${item.id}'),
          title: item.title,
          meta: _metaLine(item),
          onTap: () => _showExerciseDialog(context, item.exercise),
          onLongPress: () => _confirmDeleteExercise(context, item.exercise),
          editHint: LibraryStrings.editExercise,
          deleteHint: LibraryStrings.deleteExercise,
        );
      },
    );
  }

  /// `CHEST · TRICEPS · SHOULDERS` (frame 11). The mapper caps the list at
  /// three and hands back the remainder as an overflow label, which rides the
  /// same line rather than a second one.
  String _metaLine(LibraryExerciseItemViewData item) {
    final List<String> parts = <String>[
      ...item.muscleTags,
      if (item.overflowLabel != null) item.overflowLabel!,
    ];
    return parts.join(LibraryStrings.metaSeparator).toUpperCase();
  }

  void _showExerciseDialog(BuildContext context, [Exercise? exercise]) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider<ExerciseBloc>.value(
        value: context.read<ExerciseBloc>(),
        child: ExerciseDialog(
          exercise: exercise,
          onDelete: exercise == null
              ? null
              : () => _confirmDeleteExercise(context, exercise),
        ),
      ),
    );
  }

  void _confirmDeleteExercise(BuildContext context, Exercise exercise) {
    final ExerciseBloc bloc = context.read<ExerciseBloc>();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(LibraryStrings.deleteExercise),
        content: Text(LibraryStrings.deleteExerciseConfirm(exercise.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(LibraryStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              bloc.add(DeleteExerciseEvent(exercise.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: LiftColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
