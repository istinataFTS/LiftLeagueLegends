class InputValidators {
  InputValidators._();

  /// Validate exercise name
  static String? validateExerciseName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Exercise name is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (trimmed.length > 50) {
      return 'Name must be less than 50 characters';
    }

    // Check for valid characters (letters, numbers, spaces, hyphens, parentheses)
    if (!RegExp(r'^[a-zA-Z0-9\s\-()]+$').hasMatch(trimmed)) {
      return 'Name contains invalid characters';
    }

    return null;
  }

  /// Validate reps input
  static String? validateReps(String? value) {
    if (value == null || value.isEmpty) {
      return 'Reps is required';
    }

    final reps = int.tryParse(value);

    if (reps == null) {
      return 'Enter a valid number';
    }

    if (reps < 1) {
      return 'Reps must be at least 1';
    }

    if (reps > 1000) {
      return 'Reps must be less than 1000';
    }

    return null;
  }

  /// Validate weight input
  static String? validateWeight(String? value) {
    if (value == null || value.isEmpty) {
      return 'Weight is required';
    }

    final weight = double.tryParse(value);

    if (weight == null) {
      return 'Enter a valid number';
    }

    if (weight <= 0) {
      return 'Weight must be greater than 0';
    }

    if (weight > 1000) {
      return 'Weight must be less than 1000kg';
    }

    // Check decimal places (max 2)
    if (value.contains('.')) {
      final parts = value.split('.');
      if (parts.length > 1 && parts[1].length > 2) {
        return 'Maximum 2 decimal places';
      }
    }

    return null;
  }

  /// Validate weekly goal
  static String? validateWeeklyGoal(int? value) {
    if (value == null) {
      return 'Goal is required';
    }

    if (value < 1) {
      return 'Goal must be at least 1';
    }

    if (value > 100) {
      return 'Goal must be less than 100';
    }

    return null;
  }

  /// Validate muscle groups selection
  static String? validateMuscleGroups(List<String>? muscles) {
    if (muscles == null || muscles.isEmpty) {
      return 'Select at least one muscle group';
    }

    if (muscles.length > 10) {
      return 'Maximum 10 muscle groups';
    }

    return null;
  }

  /// Sanitize text input
  static String sanitizeInput(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single
        .replaceAll(
          RegExp(r'[<>"`;]'),
          '',
        ); // Remove potentially harmful characters
  }

  /// Format weight for display
  static String formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return weight.toStringAsFixed(0);
    }
    return weight.toStringAsFixed(2);
  }

  /// Check if date is valid workout date (not in future)
  static bool isValidWorkoutDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return !date.isAfter(today);
  }

  /// Validate date selection
  static String? validateWorkoutDate(DateTime? date) {
    if (date == null) {
      return 'Date is required';
    }

    if (!isValidWorkoutDate(date)) {
      return 'Cannot log workouts for future dates';
    }

    // Don't allow dates more than 1 year in the past
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    if (date.isBefore(oneYearAgo)) {
      return 'Date is too far in the past';
    }

    return null;
  }
}
