import '../../domain/entities/app_settings.dart';

class WeightUnitUtils {
  WeightUnitUtils._();

  static const double _kgToLb = 2.2046226218;

  static double fromStoredKilograms(double kilograms, WeightUnit unit) {
    switch (unit) {
      case WeightUnit.kilograms:
        return kilograms;
      case WeightUnit.pounds:
        return kilograms * _kgToLb;
    }
  }

  static double toStoredKilograms(double enteredWeight, WeightUnit unit) {
    switch (unit) {
      case WeightUnit.kilograms:
        return enteredWeight;
      case WeightUnit.pounds:
        return enteredWeight / _kgToLb;
    }
  }

  static String unitLabel(WeightUnit unit) {
    switch (unit) {
      case WeightUnit.kilograms:
        return 'kg';
      case WeightUnit.pounds:
        return 'lbs';
    }
  }

  static String inputLabel(WeightUnit unit) {
    switch (unit) {
      case WeightUnit.kilograms:
        return 'Weight (kg)';
      case WeightUnit.pounds:
        return 'Weight (lbs)';
    }
  }

  static String inputHint(WeightUnit unit) {
    switch (unit) {
      case WeightUnit.kilograms:
        return 'Enter weight in kg';
      case WeightUnit.pounds:
        return 'Enter weight in lbs';
    }
  }

  static String formatForDisplay(double kilograms, WeightUnit unit) {
    final converted = fromStoredKilograms(kilograms, unit);
    final formatted = formatNumber(converted);

    return '$formatted ${unitLabel(unit)}';
  }

  static String formatInputValueFromStoredKilograms(
    double kilograms,
    WeightUnit unit,
  ) {
    return formatNumber(fromStoredKilograms(kilograms, unit));
  }

  static String formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}
