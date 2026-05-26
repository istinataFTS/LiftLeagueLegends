class CalendarConstants {
  CalendarConstants._();

  // ==================== Date Ranges ====================
  static final DateTime minAllowedDate = DateTime.now().subtract(
    const Duration(days: 365 * 5), // 5 years in past
  );
  static final DateTime maxAllowedDate = DateTime.now();

  // ==================== Calendar UI ====================
  static const double calendarHeight = 340.0;
  static const double weekdayHeaderHeight = 40.0;
  static const double dayItemHeight = 48.0;
  static const double monthNavHeight = 56.0;

  // ==================== Bottom Sheet ====================
  static const double bottomSheetMaxHeight = 0.75; // 75% of screen height
  static const double bottomSheetMinHeight = 0.3; // 30% of screen height
  static const double bottomSheetBorderRadius = 24.0;
  static const Duration bottomSheetAnimationDuration = Duration(
    milliseconds: 300,
  );

  // ==================== Performance ====================
  /// Number of months to preload for smooth navigation
  static const int preloadMonthsCount = 3; // current + 1 before + 1 after

  /// Cache duration for month data
  static const Duration monthDataCacheDuration = Duration(minutes: 10);

  // ==================== Visual Indicators ====================
  static const double dateIndicatorSize = 4.0;
  static const double todayBorderWidth = 2.0;
  static const double selectedDateElevation = 4.0;

  // ==================== Swipe Gestures ====================
  static const double swipeThreshold = 100.0; // pixels
  static const Duration swipeAnimationDuration = Duration(milliseconds: 250);

  // ==================== Empty State ====================
  static const String emptyDayMessage = 'No workouts logged';
  static const String emptyDayAction = 'Log a workout';
}
