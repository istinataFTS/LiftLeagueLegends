import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/legacy_muscle_group_map.dart';
import '../../../../core/constants/muscle_factor_combine.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/exercise.dart';
import '../../application/exercise_bloc.dart';
import '../../application/library_exercise_filters.dart';
import '../models/library_exercise_view_data.dart';

class ExercisesTab extends StatefulWidget {
  const ExercisesTab({super.key});

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

  // Keys for the exercise dialog factor editor.
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
            ),
          );
        }

        if (state is ExerciseError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
            ),
          );
        }
      },
      builder: (BuildContext context, ExerciseState state) {
        // Keep the cache fresh whenever exercises are loaded.
        if (state is ExercisesLoaded) {
          _cachedExercises = state.exercises;
        }

        if (state is ExerciseLoading) {
          return const Center(
            child: CircularProgressIndicator(
              key: ExercisesTab.loadingIndicatorKey,
              color: AppTheme.primaryOrange,
            ),
          );
        }

        if (state is ExerciseError) {
          return _buildErrorState(context, state.message);
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

        return Column(
          children: <Widget>[
            _buildBrowseHeader(context, viewData),
            Expanded(
              child: !viewData.hasExercises
                  ? _buildEmptyState(context)
                  : !viewData.hasResults
                  ? _buildNoResultsState(context)
                  : _buildExercisesList(context, viewData.items),
            ),
            _buildAddButton(context),
          ],
        );
      },
    );
  }

  Widget _buildBrowseHeader(
    BuildContext context,
    LibraryExercisePageViewData viewData,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: const BoxDecoration(color: AppTheme.backgroundDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: ExercisesTab.searchFieldKey,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search exercises or muscle groups',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      key: ExercisesTab.clearSearchButtonKey,
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
            onChanged: (String value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ExercisesTab.allMusclesChipKey,
                    label: const Text('All muscles'),
                    selected: _selectedMuscleFilter == null,
                    onSelected: (_) {
                      setState(() {
                        _selectedMuscleFilter = null;
                      });
                    },
                    selectedColor: AppTheme.primaryOrange.withValues(
                      alpha: 0.2,
                    ),
                    labelStyle: TextStyle(
                      color: _selectedMuscleFilter == null
                          ? AppTheme.primaryOrange
                          : AppTheme.textMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...MuscleGroups.all.map(
                  (String muscle) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ExercisesTab.muscleChipKey(muscle),
                      label: Text(MuscleGroups.getDisplayName(muscle)),
                      selected: _selectedMuscleFilter == muscle,
                      onSelected: (_) {
                        setState(() {
                          _selectedMuscleFilter =
                              _selectedMuscleFilter == muscle ? null : muscle;
                        });
                      },
                      selectedColor: AppTheme.primaryOrange.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TextStyle(
                        color: _selectedMuscleFilter == muscle
                            ? AppTheme.primaryOrange
                            : AppTheme.textMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            viewData.resultCountLabel,
            key: ExercisesTab.resultCountKey,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // Scrollable + centered: the empty-state column visually centers in the
    // available area when it fits, but degrades to a scrollable column when
    // it doesn't (small viewports + sticky "Add Exercise" CTA below + bottom
    // nav inset). The previous unconditional Center overflowed on phones
    // where the available area shrank below the column's intrinsic height.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 80),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fitness_center_outlined,
                      size: 60,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.noExercisesYet,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.createExercisesDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.textMedium),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _showAddExerciseDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text(AppStrings.addFirstExercise),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    key: ExercisesTab.reloadButtonKey,
                    onPressed: () {
                      context.read<ExerciseBloc>().add(LoadExercisesEvent());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.search_off, size: 48, color: AppTheme.textDim),
              const SizedBox(height: 12),
              Text(
                'No exercises match the current search or filter.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.textMedium),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                key: ExercisesTab.clearFiltersButtonKey,
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Error Loading Exercises',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: ExercisesTab.retryButtonKey,
              onPressed: () {
                context.read<ExerciseBloc>().add(LoadExercisesEvent());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesList(
    BuildContext context,
    List<LibraryExerciseItemViewData> items,
  ) {
    return RefreshIndicator(
      color: AppTheme.primaryOrange,
      onRefresh: () {
        final bloc = context.read<ExerciseBloc>();
        bloc.add(LoadExercisesEvent());
        return bloc.stream
            .firstWhere(
              (ExerciseState s) => s is ExercisesLoaded || s is ExerciseError,
            )
            .then((_) {});
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: items.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildExerciseCard(context, items[index]);
        },
      ),
    );
  }

  Widget _buildExerciseCard(
    BuildContext context,
    LibraryExerciseItemViewData item,
  ) {
    final Exercise exercise = item.exercise;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditExerciseDialog(context, exercise),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: AppTheme.primaryOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.muscleTags.map((String tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: AppTheme.primaryOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (item.overflowLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.overflowLabel!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textDim),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textDim),
                onSelected: (String value) {
                  if (value == 'edit') {
                    _showEditExerciseDialog(context, exercise);
                  } else if (value == 'delete') {
                    _confirmDeleteExercise(context, exercise);
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 12),
                            Text(AppStrings.edit),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppTheme.errorRed,
                            ),
                            SizedBox(width: 12),
                            Text(
                              AppStrings.delete,
                              style: TextStyle(color: AppTheme.errorRed),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: ExercisesTab.addButtonKey,
            onPressed: () => _showAddExerciseDialog(context),
            icon: const Icon(Icons.add),
            label: const Text(
              AppStrings.addExercise,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddExerciseDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider.value(
        value: context.read<ExerciseBloc>(),
        child: const _ExerciseDialog(),
      ),
    );
  }

  void _showEditExerciseDialog(BuildContext context, Exercise exercise) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider.value(
        value: context.read<ExerciseBloc>(),
        child: _ExerciseDialog(exercise: exercise),
      ),
    );
  }

  void _confirmDeleteExercise(BuildContext context, Exercise exercise) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(AppStrings.deleteExercise),
        content: Text(
          '${AppStrings.deleteExerciseConfirm}\n\n${exercise.name}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<ExerciseBloc>().add(
                DeleteExerciseEvent(exercise.id),
              );
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise add/edit dialog
// ---------------------------------------------------------------------------

class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog({this.exercise});

  final Exercise? exercise;

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  late final TextEditingController _nameController;

  /// Insertion-ordered map: simple-key muscle → activation factor ∈ [0, 1].
  /// Replaces the old `Set<String> _selectedMuscles` — the keys serve the same
  /// role as the set members while the values drive the factor sliders.
  late final Map<String, double> _selectedMuscleFactors;

  final Uuid _uuid = const Uuid();

  bool get isEditing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise?.name ?? '');

    // Seed the factor map from the exercise's existing muscle groups.
    // Factors default to 1.0 and are overwritten once [ExerciseFactorsLoaded]
    // arrives from the bloc (see the BlocListener in build()).
    _selectedMuscleFactors = <String, double>{
      for (final muscle in widget.exercise?.muscleGroups ?? const <String>[])
        muscle: 1.0,
    };

    if (isEditing) {
      // Dispatch after the first frame so the BlocProvider is in the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ExerciseBloc>().add(
            LoadExerciseFactorsEvent(widget.exercise!.id),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Called when [ExerciseFactorsLoaded] arrives.
  ///
  /// Keys are now 1:1 with the canonical taxonomy, so loaded factors map
  /// directly onto the sliders. Any stray legacy key is canonicalised (and
  /// duplicates collapsed with the MAX rule) defensively before matching.
  void _applyLoadedFactors(Map<String, double> rawFactors) {
    final Map<String, double> canonical = combineCanonicalFactors(
      rawFactors.entries.map(
        (MapEntry<String, double> e) => MapEntry(e.key, e.value),
      ),
    );

    setState(() {
      for (final String key in _selectedMuscleFactors.keys.toList()) {
        final double? loaded =
            canonical[LegacyMuscleGroupMap.canonicalizeMuscleKey(key)];
        if (loaded != null) {
          _selectedMuscleFactors[key] = loaded;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isValid =
        _nameController.text.trim().isNotEmpty &&
        _selectedMuscleFactors.isNotEmpty;

    return BlocListener<ExerciseBloc, ExerciseState>(
      listenWhen: (_, ExerciseState current) =>
          current is ExerciseFactorsLoaded &&
          current.exerciseId == widget.exercise?.id,
      listener: (BuildContext context, ExerciseState state) {
        _applyLoadedFactors((state as ExerciseFactorsLoaded).factors);
      },
      child: Dialog(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildHeader(context),
              const Divider(height: 1),
              Flexible(child: _buildContent(context)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(AppStrings.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isValid ? _handleSave : null,
                        child: Text(
                          isEditing ? AppStrings.saveChanges : AppStrings.add,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              isEditing ? AppStrings.editExercise : AppStrings.addExercise,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return StatefulBuilder(
      builder: (BuildContext context, void Function(void Function()) setInnerState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: AppStrings.exerciseName,
                  hintText: AppStrings.exerciseNameHint,
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: !isEditing,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.muscleGroups,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MuscleGroups.all.map((String muscle) {
                  final bool isSelected = _selectedMuscleFactors.containsKey(
                    muscle,
                  );
                  return FilterChip(
                    label: Text(MuscleGroups.getDisplayName(muscle)),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setInnerState(() {
                        if (selected) {
                          _selectedMuscleFactors[muscle] = 1.0;
                        } else {
                          _selectedMuscleFactors.remove(muscle);
                        }
                      });
                      // Re-evaluate isValid (name + at-least-one-muscle check).
                      setState(() {});
                    },
                    selectedColor: AppTheme.primaryOrange.withValues(
                      alpha: 0.2,
                    ),
                    checkmarkColor: AppTheme.primaryOrange,
                    backgroundColor: AppTheme.surfaceDark,
                  );
                }).toList(),
              ),

              // Factor editor — only shown when at least one muscle is selected.
              if (_selectedMuscleFactors.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.textDim,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.muscleFactorHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textDim,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.muscleFactorTitle,
                  key: ExercisesTab.factorEditorKey,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ..._selectedMuscleFactors.entries.map((
                  MapEntry<String, double> entry,
                ) {
                  return _FactorRow(
                    key: ExercisesTab.factorSliderKey(entry.key),
                    muscle: entry.key,
                    value: entry.value,
                    onChanged: (double newValue) {
                      setInnerState(() {
                        _selectedMuscleFactors[entry.key] = newValue;
                      });
                    },
                  );
                }),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: ExercisesTab.resetFactorsButtonKey,
                    onPressed: () {
                      setInnerState(() {
                        for (final String key in _selectedMuscleFactors.keys) {
                          _selectedMuscleFactors[key] = 1.0;
                        }
                      });
                    },
                    child: const Text(AppStrings.resetFactors),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _handleSave() {
    final String name = _nameController.text.trim();
    // Snapshot the factor map so the event carries an immutable copy.
    final Map<String, double> muscleFactors = Map<String, double>.of(
      _selectedMuscleFactors,
    );

    if (isEditing) {
      final Exercise updatedExercise = widget.exercise!.copyWith(
        name: name,
        muscleGroups: muscleFactors.keys.toList(),
      );
      context.read<ExerciseBloc>().add(
        UpdateExerciseEvent(updatedExercise, muscleFactors: muscleFactors),
      );
    } else {
      final Exercise newExercise = Exercise(
        id: _uuid.v4(),
        name: name,
        muscleGroups: muscleFactors.keys.toList(),
        createdAt: DateTime.now(),
      );
      context.read<ExerciseBloc>().add(
        AddExerciseEvent(newExercise, muscleFactors: muscleFactors),
      );
    }

    Navigator.pop(context);
  }
}

// ---------------------------------------------------------------------------
// Per-muscle factor slider row
// ---------------------------------------------------------------------------

/// A self-contained slider row for one muscle group inside the exercise dialog.
///
/// Uses its own [State] so that dragging only rebuilds this row rather than
/// the entire dialog.  The parent is notified via [onChanged] only when the
/// drag ends, keeping [_selectedMuscleFactors] in sync without forcing a
/// full-dialog rebuild on every frame.
class _FactorRow extends StatefulWidget {
  const _FactorRow({
    super.key,
    required this.muscle,
    required this.value,
    required this.onChanged,
  });

  final String muscle;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_FactorRow> createState() => _FactorRowState();
}

class _FactorRowState extends State<_FactorRow> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(_FactorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync when the parent resets all factors (e.g. "Reset to defaults").
    if (oldWidget.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              MuscleGroups.getDisplayName(widget.muscle),
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: _localValue,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              activeColor: AppTheme.primaryOrange,
              onChanged: (double value) {
                // Update local state only — fast per-frame feedback.
                setState(() => _localValue = value);
              },
              onChangeEnd: (double value) {
                // Notify parent once the gesture completes.
                widget.onChanged(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              key: ExercisesTab.factorValueKey(widget.muscle),
              '${_localValue.toStringAsFixed(2)}x',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMedium,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
