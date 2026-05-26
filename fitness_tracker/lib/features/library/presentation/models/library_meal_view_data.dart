import 'package:equatable/equatable.dart';

import '../../../../domain/entities/meal.dart';

class LibraryMealPageViewData extends Equatable {
  const LibraryMealPageViewData({
    required this.items,
    required this.resultCountLabel,
    required this.hasMeals,
    required this.hasResults,
    required this.hasActiveSearch,
    required this.searchQuery,
  });

  final List<LibraryMealItemViewData> items;
  final String resultCountLabel;
  final bool hasMeals;
  final bool hasResults;
  final bool hasActiveSearch;
  final String searchQuery;

  @override
  List<Object?> get props => <Object?>[
    items,
    resultCountLabel,
    hasMeals,
    hasResults,
    hasActiveSearch,
    searchQuery,
  ];
}

class LibraryMealItemViewData extends Equatable {
  const LibraryMealItemViewData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.macroSummary,
    required this.meal,
  });

  final String id;
  final String title;
  final String subtitle;
  final String macroSummary;
  final Meal meal;

  @override
  List<Object?> get props => <Object?>[id, title, subtitle, macroSummary, meal];
}

class LibraryMealViewDataMapper {
  const LibraryMealViewDataMapper._();

  static LibraryMealPageViewData map({
    required List<Meal> allMeals,
    required List<Meal> filteredMeals,
    required String searchQuery,
  }) {
    return LibraryMealPageViewData(
      items: filteredMeals
          .map(
            (Meal meal) => LibraryMealItemViewData(
              id: meal.id,
              title: meal.name,
              subtitle:
                  '${meal.servingSizeGrams.toStringAsFixed(0)} g serving • '
                  '${meal.caloriesPerServing.toStringAsFixed(0)} kcal',
              macroSummary:
                  '${meal.proteinPerServing.toStringAsFixed(0)}P • '
                  '${meal.carbsPerServing.toStringAsFixed(0)}C • '
                  '${meal.fatsPerServing.toStringAsFixed(0)}F',
              meal: meal,
            ),
          )
          .toList(growable: false),
      resultCountLabel: '${filteredMeals.length} of ${allMeals.length} meals',
      hasMeals: allMeals.isNotEmpty,
      hasResults: filteredMeals.isNotEmpty,
      hasActiveSearch: searchQuery.trim().isNotEmpty,
      searchQuery: searchQuery,
    );
  }
}
