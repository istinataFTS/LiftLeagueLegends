import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/lift_number.dart';
import '../../../../core/themes/lift_theme.dart';
import '../../../../domain/entities/meal.dart';

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

    return Container(
      key: const ValueKey<String>('meal-picker-panel'),
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
          _buildResultCount(all.length, widget.meals.length, hasQuery),
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
              AppStrings.selectMeal,
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
          hintText: AppStrings.searchMeals,
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

  Widget _buildFlatList(List<Meal> meals) {
    if (meals.isEmpty) {
      return Center(
        child: Text(
          AppStrings.noResultsFound,
          style: LiftText.bodyMedium.copyWith(color: LiftColors.textDim),
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
          const Divider(
            height: 16,
            indent: 16,
            endIndent: 16,
            color: LiftColors.hairline,
          ),
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
        style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
      ),
    );
  }

  Widget _buildMealTile(Meal meal) {
    final bool isSelected = widget.selected?.id == meal.id;
    final String kcal = meal.caloriesPer100g.round().toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, meal),
        child: Container(
          key: ValueKey<String>('meal-row-${meal.id}'),
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
                  meal.name,
                  style: LiftText.bodyLarge.copyWith(
                    color: LiftColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LiftNumber(kcal, '', LiftText.dataSmall),
              const SizedBox(width: 6),
              Text(
                'KCAL / 100G',
                style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
              ),
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
        Icons.restaurant,
        size: 18,
        color: isSelected ? Colors.white : LiftColors.textDim,
      ),
    );
  }
}
