/// Library's user-facing copy, as frames 11 and 12 spell it.
///
/// Lives beside the page rather than in `AppStrings` for the same reason
/// `history_strings.dart` does: these labels are the restyle's, they change
/// with the frames, and none of them are shared with another feature.
class LibraryStrings {
  const LibraryStrings._();

  // Page and tabs (frame 11).
  static const String title = 'Library';
  static const String exercisesTab = 'Exercises';
  static const String mealsTab = 'Meals';

  // Exercises tab.
  static const String searchExercisesHint = 'Search exercises or muscle groups';
  static const String allMuscles = 'All muscles';
  static const String addExerciseCta = 'Add exercise';
  static const String noExercisesYet = 'No exercises yet';
  static const String noExercisesBody =
      'Exercises you create show up here and in the log.';
  static const String noExerciseMatches =
      'No exercises match the current search or filter.';
  static const String clearFilters = 'Clear filters';
  static const String reload = 'Reload';
  static const String exercisesLoadFailed = 'Could not load exercises';

  // Meals tab.
  static const String searchMealsHint = 'Search meals';
  static const String addMealCta = 'Add meal';
  static const String noMealsYet = 'No meals yet';
  static const String noMealsBody =
      'Meals you save here can be logged in one tap.';
  static const String noMealMatches = 'No meals match the current search.';
  static const String clearSearch = 'Clear search';
  static const String mealsLoadFailed = 'Could not load meals';

  // Exercise dialog (frame 12).
  static const String newExercise = 'New exercise';
  static const String editExercise = 'Edit exercise';
  static const String nameLabel = 'Name';
  static const String nameHint = 'e.g. Bench Press';
  static const String muscleGroupsLabel = 'Muscle groups';
  static const String muscleActivationLabel = 'Muscle activation';
  static const String reset = 'Reset';
  static const String cancel = 'Cancel';
  static const String saveExercise = 'Save exercise';
  static const String saveChanges = 'Save changes';
  static const String deleteExercise = 'Delete exercise';

  // Meal dialog.
  static const String newMeal = 'New meal';
  static const String editMeal = 'Edit meal';
  static const String saveMeal = 'Save meal';
  static const String deleteMeal = 'Delete meal';

  /// Separator between the mono meta fragments on every Library row.
  static const String metaSeparator = ' · ';

  static String deleteExerciseConfirm(String name) =>
      'Delete "$name"? Logged sets keep their history.';

  static String deleteMealConfirm(String name) =>
      'Delete "$name"? Logged entries keep their history.';
}
