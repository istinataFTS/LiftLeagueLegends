import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/lift_theme.dart';
import '../../../../domain/entities/meal.dart';
import '../../application/library_meal_filters.dart';
import '../../application/meal_bloc.dart';
import '../library_strings.dart';
import '../models/library_meal_view_data.dart';
import 'library_chrome.dart';
import 'meal_dialog.dart';

/// The Meals tab, on the same rules as the Exercises tab (frame 11).
///
/// Frame 11 only draws the Exercises side, but the two are one screen behind
/// one tab strip, so the meal rows take the treatment Task 26 spells out for
/// them: `100 G SERVING · 613 KCAL` over `21P · 22C · 49F`, both in mono.
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
          _showSnack(context, state.message, LiftColors.success);
        }

        if (state is MealError) {
          _showSnack(context, state.message, LiftColors.error);
        }
      },
      builder: (BuildContext context, MealState state) {
        if (state is MealLoading) {
          return const Center(
            child: CircularProgressIndicator(
              key: MealsTab.loadingIndicatorKey,
              color: LiftColors.actionTint,
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
            LibraryCta(
              buttonKey: MealsTab.addButtonKey,
              label: LibraryStrings.addMealCta,
              onPressed: () => _showMealDialog(context),
            ),
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

  Widget _buildBrowseHeader(
    BuildContext context,
    LibraryMealPageViewData viewData,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: libraryGutter),
            child: LibrarySearchField(
              fieldKey: MealsTab.searchFieldKey,
              clearButtonKey: MealsTab.clearSearchButtonKey,
              controller: _searchController,
              hintText: LibraryStrings.searchMealsHint,
              onChanged: (String value) => setState(() => _searchQuery = value),
              onClear: _resetSearch,
            ),
          ),
          const SizedBox(height: 21),
          LibraryCountLabel(
            labelKey: MealsTab.resultCountKey,
            label: viewData.resultCountLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LibraryMessageState(
      title: LibraryStrings.noMealsYet,
      body: LibraryStrings.noMealsBody,
      actionLabel: LibraryStrings.addMealCta,
      onAction: () => _showMealDialog(context),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return LibraryMessageState(
      title: LibraryStrings.clearSearch,
      body: LibraryStrings.noMealMatches,
      actionLabel: LibraryStrings.clearSearch,
      actionKey: MealsTab.clearResultsButtonKey,
      onAction: _resetSearch,
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return LibraryMessageState(
      title: LibraryStrings.mealsLoadFailed,
      titleColor: LiftColors.error,
      body: message,
      actionLabel: 'Retry',
      actionKey: MealsTab.retryButtonKey,
      onAction: () => context.read<MealBloc>().add(LoadMealsEvent()),
    );
  }

  Widget _buildMealsList(
    BuildContext context,
    List<LibraryMealItemViewData> items,
  ) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final LibraryMealItemViewData item = items[index];
        return LibraryListRow(
          key: ValueKey<String>('library_meal_row_${item.id}'),
          title: item.title,
          meta: item.subtitle,
          secondaryMeta: item.macroSummary,
          onTap: () => _showMealDialog(context, item.meal),
          onLongPress: () => _confirmDeleteMeal(context, item.meal),
          editHint: LibraryStrings.editMeal,
          deleteHint: LibraryStrings.deleteMeal,
        );
      },
    );
  }

  void _showMealDialog(BuildContext context, [Meal? meal]) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider<MealBloc>.value(
        value: context.read<MealBloc>(),
        child: MealDialog(
          meal: meal,
          onDelete: meal == null
              ? null
              : () => _confirmDeleteMeal(context, meal),
        ),
      ),
    );
  }

  void _confirmDeleteMeal(BuildContext context, Meal meal) {
    final MealBloc bloc = context.read<MealBloc>();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(LibraryStrings.deleteMeal),
        content: Text(LibraryStrings.deleteMealConfirm(meal.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(LibraryStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              bloc.add(DeleteMealEvent(meal.id));
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
