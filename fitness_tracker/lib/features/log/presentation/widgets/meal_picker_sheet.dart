import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/meal.dart';
import 'shared/log_ui_colors.dart';

class MealPickerSheet extends StatefulWidget {
  const MealPickerSheet._({
    required this.meals,
    required this.recentMealIds,
    this.selected,
  });

  final List<Meal> meals;
  final List<String> recentMealIds;
  final Meal? selected;

  /// Shows the full-screen meal picker sheet and returns the chosen [Meal],
  /// or `null` if the user dismissed without selecting.
  static Future<Meal?> show(
    BuildContext context, {
    required List<Meal> meals,
    required List<String> recentMealIds,
    Meal? selected,
  }) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    return showModalBottomSheet<Meal>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        minHeight: screenHeight * 0.9,
        maxHeight: screenHeight * 0.9,
      ),
      builder: (_) => MealPickerSheet._(
        meals: meals,
        recentMealIds: recentMealIds,
        selected: selected,
      ),
    );
  }

  @override
  State<MealPickerSheet> createState() => _MealPickerSheetState();
}

class _MealPickerSheetState extends State<MealPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Meal> get _filteredAllMeals {
    if (_searchQuery.isEmpty) return widget.meals;
    final String query = _searchQuery.toLowerCase();
    return widget.meals
        .where((Meal m) => m.name.toLowerCase().contains(query))
        .toList();
  }

  List<Meal> get _recentMeals {
    if (_searchQuery.isNotEmpty) return const <Meal>[];

    final Map<String, Meal> byId = <String, Meal>{
      for (final Meal m in widget.meals) m.id: m,
    };

    final List<Meal> result = <Meal>[];
    for (final String id in widget.recentMealIds) {
      final Meal? meal = byId[id];
      if (meal == null) continue;
      result.add(meal);
      if (result.length >= 5) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final List<Meal> recents = _recentMeals;
    final List<Meal> all = _filteredAllMeals;
    final bool hasQuery = _searchQuery.isNotEmpty;

    return Column(
      children: <Widget>[
        _buildHeader(context),
        const Divider(height: 1),
        _buildSearchField(),
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
              AppStrings.selectMeal,
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
          hintText: AppStrings.searchMeals,
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

  Widget _buildFlatList(List<Meal> meals) {
    if (meals.isEmpty) {
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
      itemCount: meals.length,
      itemBuilder: (_, int index) => _buildMealTile(meals[index]),
    );
  }

  Widget _buildSectionedList(List<Meal> recents, List<Meal> all) {
    return ListView(
      children: <Widget>[
        if (recents.isNotEmpty) ...<Widget>[
          _buildSectionHeader(AppStrings.pickerRecents),
          ...recents.map(_buildMealTile),
          const Divider(height: 16, indent: 16, endIndent: 16),
        ],
        _buildSectionHeader(AppStrings.pickerAllMeals),
        ...all.map(_buildMealTile),
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

  Widget _buildMealTile(Meal meal) {
    final bool isSelected = widget.selected?.id == meal.id;

    return Material(
      color: isSelected
          ? AppTheme.primaryOrange.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, meal),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildLeadingTile(isSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      meal.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isSelected
                            ? AppTheme.primaryOrange
                            : AppTheme.textLight,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildMacroPills(meal),
                  ],
                ),
              ),
              if (isSelected) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: AppTheme.primaryOrange),
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
        gradient: isSelected ? AppTheme.primaryGradient : null,
        color: isSelected ? null : AppTheme.surfaceMedium,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.restaurant,
        size: 18,
        color: isSelected ? Colors.white : AppTheme.textDim,
      ),
    );
  }

  Widget _buildMacroPills(Meal meal) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        _pill(
          label: '${meal.caloriesPer100g.round()} kcal',
          color: AppTheme.primaryOrangeLight,
        ),
        _pill(
          label: 'P ${meal.proteinPer100g.round()}',
          color: LogUiColors.protein,
        ),
        _pill(
          label: 'C ${meal.carbsPer100g.round()}',
          color: LogUiColors.carbs,
        ),
        _pill(label: 'F ${meal.fatPer100g.round()}', color: LogUiColors.fats),
      ],
    );
  }

  Widget _pill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
