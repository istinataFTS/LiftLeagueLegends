import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/themes/app_theme.dart';
import 'widgets/exercises_tab.dart';
import 'widgets/meals_tab.dart';

/// Feature-owned Library page.
///
/// Library owns reusable browse/search/filter surfaces for discovery and
/// lightweight management of exercises and meals.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text(AppStrings.libraryTitle),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryOrange,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: AppTheme.textDim,
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.fitness_center),
                text: AppStrings.exercisesTab,
              ),
              Tab(icon: Icon(Icons.restaurant), text: AppStrings.mealsTab),
            ],
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showInfoDialog(context),
              tooltip: 'About Library',
            ),
          ],
        ),
        body: const TabBarView(children: <Widget>[ExercisesTab(), MealsTab()]),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('About Library'),
          content: const Text(
            'Manage reusable exercises and meals here.\n\n'
            'Exercises: browse, search, filter, create, edit, and remove exercises.\n\n'
            'Meals: browse, search, create, edit, and remove meals for faster nutrition logging.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(AppStrings.gotIt),
            ),
          ],
        );
      },
    );
  }
}
