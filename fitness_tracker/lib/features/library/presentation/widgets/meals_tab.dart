import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/meal.dart';
import '../../application/library_meal_filters.dart';
import '../../application/meal_bloc.dart';
import '../models/library_meal_view_data.dart';

class MealsTab extends StatefulWidget {
  const MealsTab({super.key});

  static const Key searchFieldKey = ValueKey<String>(
    'library_meals_search_field',
  );
  static const Key clearSearchButtonKey = ValueKey<String>(
    'library_meals_clear_search_button',
  );
  static const Key resultCountKey = ValueKey<String>(
    'library_meals_result_count',
  );
  static const Key retryButtonKey = ValueKey<String>(
    'library_meals_retry_button',
  );
  static const Key clearResultsButtonKey = ValueKey<String>(
    'library_meals_clear_results_button',
  );
  static const Key addButtonKey = ValueKey<String>('library_meals_add_button');
  static const Key loadingIndicatorKey = ValueKey<String>(
    'library_meals_loading_indicator',
  );

  @override
  State<MealsTab> createState() => _MealsTabState();
}

class _MealsTabState extends State<MealsTab> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MealBloc, MealState>(
      listener: (BuildContext context, MealState state) {
        if (state is MealOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
            ),
          );
        }

        if (state is MealError) {
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
      builder: (BuildContext context, MealState state) {
        if (state is MealLoading) {
          return const Center(
            child: CircularProgressIndicator(
              key: MealsTab.loadingIndicatorKey,
              color: AppTheme.primaryOrange,
            ),
          );
        }

        if (state is MealError) {
          return _buildErrorState(context, state.message);
        }

        final List<Meal> allMeals = state is MealsLoaded
            ? state.meals
            : <Meal>[];

        final List<Meal> filteredMeals = LibraryMealFilters.apply(
          meals: allMeals,
          query: _searchQuery,
        );

        final LibraryMealPageViewData viewData = LibraryMealViewDataMapper.map(
          allMeals: allMeals,
          filteredMeals: filteredMeals,
          searchQuery: _searchQuery,
        );

        return Column(
          children: <Widget>[
            _buildBrowseHeader(context, viewData),
            Expanded(
              child: !viewData.hasMeals
                  ? _buildEmptyState(context)
                  : !viewData.hasResults
                  ? _buildNoResultsState(context)
                  : _buildMealsList(context, viewData.items),
            ),
            _buildAddButton(context),
          ],
        );
      },
    );
  }

  Widget _buildBrowseHeader(
    BuildContext context,
    LibraryMealPageViewData viewData,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: const BoxDecoration(color: AppTheme.backgroundDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: MealsTab.searchFieldKey,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search meals',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      key: MealsTab.clearSearchButtonKey,
                      icon: const Icon(Icons.clear),
                      onPressed: _resetSearch,
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
          Text(
            viewData.resultCountLabel,
            key: MealsTab.resultCountKey,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // See exercises_tab._buildEmptyState for the rationale — same shape,
    // same overflow risk on small viewports with the sticky CTA below.
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
                      Icons.restaurant_outlined,
                      size: 60,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No meals yet',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create reusable meals here so nutrition logging stays '
                    'fast and consistent.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.textMedium),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _showAddMealDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add first meal'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
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
                'No meals match the current search.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.textMedium),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                key: MealsTab.clearResultsButtonKey,
                onPressed: _resetSearch,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Clear search'),
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
              'Error Loading Meals',
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
              key: MealsTab.retryButtonKey,
              onPressed: () {
                context.read<MealBloc>().add(LoadMealsEvent());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsList(
    BuildContext context,
    List<LibraryMealItemViewData> items,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildMealCard(context, items[index]);
      },
    );
  }

  Widget _buildMealCard(BuildContext context, LibraryMealItemViewData item) {
    final Meal meal = item.meal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditMealDialog(context, meal),
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
                  Icons.restaurant,
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
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.macroSummary,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textDim),
                onSelected: (String value) {
                  if (value == 'edit') {
                    _showEditMealDialog(context, meal);
                  } else if (value == 'delete') {
                    _confirmDeleteMeal(context, meal);
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
                            Text('Edit'),
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
                              'Delete',
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
            key: MealsTab.addButtonKey,
            onPressed: () => _showAddMealDialog(context),
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Meal',
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

  void _showAddMealDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider.value(
        value: context.read<MealBloc>(),
        child: const _MealDialog(),
      ),
    );
  }

  void _showEditMealDialog(BuildContext context, Meal meal) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider.value(
        value: context.read<MealBloc>(),
        child: _MealDialog(meal: meal),
      ),
    );
  }

  void _confirmDeleteMeal(BuildContext context, Meal meal) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Meal'),
        content: Text(
          'Are you sure you want to delete this meal?\n\n${meal.name}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<MealBloc>().add(DeleteMealEvent(meal.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MealDialog extends StatefulWidget {
  const _MealDialog({this.meal});

  final Meal? meal;

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _servingSizeController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _caloriesController;

  final Uuid _uuid = const Uuid();

  bool get isEditing => widget.meal != null;

  @override
  void initState() {
    super.initState();

    final Meal? meal = widget.meal;

    _nameController = TextEditingController(text: meal?.name ?? '');
    _servingSizeController = TextEditingController(
      text: (meal?.servingSizeGrams ?? 100).toStringAsFixed(0),
    );
    _proteinController = TextEditingController(
      text: (meal?.proteinPer100g ?? 0).toStringAsFixed(0),
    );
    _carbsController = TextEditingController(
      text: (meal?.carbsPer100g ?? 0).toStringAsFixed(0),
    );
    _fatController = TextEditingController(
      text: (meal?.fatPer100g ?? 0).toStringAsFixed(0),
    );
    _caloriesController = TextEditingController(
      text: (meal?.caloriesPer100g ?? 0).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingSizeController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isValid =
        _nameController.text.trim().isNotEmpty &&
        _parseDouble(_servingSizeController.text) > 0;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 520),
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isValid ? _handleSave : null,
                      child: Text(isEditing ? 'Save Changes' : 'Add'),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              isEditing ? 'Edit Meal' : 'Add Meal',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Meal Name',
              hintText: 'Chicken bowl',
              prefixIcon: Icon(Icons.restaurant),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: !isEditing,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _servingSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Serving Size (g)',
              prefixIcon: Icon(Icons.scale_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _proteinController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Protein per 100g',
              prefixIcon: Icon(Icons.fitness_center),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _carbsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Carbs per 100g',
              prefixIcon: Icon(Icons.bakery_dining_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fat per 100g',
              prefixIcon: Icon(Icons.opacity_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caloriesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Calories per 100g',
              prefixIcon: Icon(Icons.local_fire_department_outlined),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSave() {
    final Meal nextMeal = Meal(
      id: widget.meal?.id ?? _uuid.v4(),
      name: _nameController.text.trim(),
      servingSizeGrams: _parseDouble(
        _servingSizeController.text,
        fallback: 100,
      ),
      proteinPer100g: _parseDouble(_proteinController.text),
      carbsPer100g: _parseDouble(_carbsController.text),
      fatPer100g: _parseDouble(_fatController.text),
      caloriesPer100g: _parseDouble(_caloriesController.text),
      createdAt: widget.meal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      syncMetadata: widget.meal?.syncMetadata,
      ownerUserId: widget.meal?.ownerUserId,
    );

    if (isEditing) {
      context.read<MealBloc>().add(UpdateMealEvent(nextMeal));
    } else {
      context.read<MealBloc>().add(AddMealEvent(nextMeal));
    }

    Navigator.pop(context);
  }

  double _parseDouble(String value, {double fallback = 0}) {
    return double.tryParse(value.trim()) ?? fallback;
  }
}
