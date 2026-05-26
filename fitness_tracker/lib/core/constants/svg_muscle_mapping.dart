class SvgMuscleMapping {
  SvgMuscleMapping._(); // Private constructor

  // ==================== FRONT VIEW MUSCLES ====================

  /// Muscles visible on front body diagram
  static const List<String> frontViewMuscles = [
    'front-delts', // Front deltoids
    'side-delts', // Side deltoids (partially visible)
    'upper-chest', // Upper pectoralis major
    'mid-chest', // Mid pectoralis major
    'lower-chest', // Lower pectoralis major
    'biceps', // Biceps brachii
    'forearms', // Forearm flexors
    'abs', // Rectus abdominis
    'obliques', // External obliques
    'quads', // Quadriceps femoris
  ];

  // ==================== BACK VIEW MUSCLES ====================

  /// Muscles visible on back body diagram
  static const List<String> backViewMuscles = [
    'rear-delts', // Rear deltoids
    'side-delts', // Side deltoids (partially visible)
    'upper-traps', // Upper trapezius
    'middle-traps', // Middle trapezius
    'lower-traps', // Lower trapezius
    'lats', // Latissimus dorsi
    'triceps', // Triceps brachii
    'forearms', // Forearm extensors
    'lower-back', // Erector spinae
    'glutes', // Gluteus maximus
    'hamstrings', // Hamstring complex
    'calves', // Gastrocnemius & soleus
  ];

  // ==================== SVG PATH MAPPING ====================

  static const Map<String, String> svgPathIds = {
    // ==================== FRONT VIEW PATHS ====================
    'front-delts-front': 'TODO',
    'side-delts-front': 'TODO',
    'upper-chest-front': 'TODO',
    'mid-chest-front': 'TODO',
    'lower-chest-front': 'TODO',
    'biceps-front': 'TODO',
    'forearms-front': 'TODO',
    'abs-front': 'TODO',
    'obliques-front': 'TODO',
    'quads-front': 'TODO',

    // ==================== BACK VIEW PATHS ====================
    'rear-delts-back': 'TODO',
    'side-delts-back': 'TODO',
    'upper-traps-back': 'TODO',
    'middle-traps-back': 'TODO',
    'lower-traps-back': 'TODO',
    'lats-back': 'TODO',
    'triceps-back': 'TODO',
    'forearms-back': 'TODO',
    'lower-back-back': 'TODO',
    'glutes-back': 'TODO',
    'hamstrings-back': 'TODO',
    'calves-back': 'TODO',
  };

  // ==================== BILATERAL MUSCLES ====================

  /// Muscles that appear on both sides (left/right)
  /// May need separate path IDs for left and right sides
  static const List<String> bilateralMuscles = [
    'front-delts',
    'side-delts',
    'rear-delts',
    'upper-chest',
    'mid-chest',
    'lower-chest',
    'lats',
    'biceps',
    'triceps',
    'forearms',
    'obliques',
    'glutes',
    'quads',
    'hamstrings',
    'calves',
  ];

  // ==================== MIDLINE MUSCLES ====================

  /// Muscles that are single/central (not bilateral)
  static const List<String> midlineMuscles = [
    'upper-traps',
    'middle-traps',
    'lower-traps',
    'abs',
    'lower-back',
  ];

  // ==================== COLOR APPLICATION ====================

  /// Get view type for a muscle group
  static String? getMuscleView(String muscleGroup) {
    if (frontViewMuscles.contains(muscleGroup)) {
      return 'front';
    } else if (backViewMuscles.contains(muscleGroup)) {
      return 'back';
    }
    return null; // Muscle not visible in either view
  }

  /// Check if muscle appears on front view
  static bool isVisibleOnFront(String muscleGroup) {
    return frontViewMuscles.contains(muscleGroup);
  }

  /// Check if muscle appears on back view
  static bool isVisibleOnBack(String muscleGroup) {
    return backViewMuscles.contains(muscleGroup);
  }

  /// Check if muscle is bilateral
  static bool isBilateral(String muscleGroup) {
    return bilateralMuscles.contains(muscleGroup);
  }

  /// Check if muscle is on midline
  static bool isMidline(String muscleGroup) {
    return midlineMuscles.contains(muscleGroup);
  }

  // ==================== SVG INTEGRATION HELPERS ====================

  /// Get SVG path ID(s) for a muscle group on a specific view
  /// Returns list of path IDs (may be empty, or multiple for bilateral muscles)
  static List<String> getPathIdsForMuscle(
    String muscleGroup,
    bool isFrontView,
  ) {
    final view = isFrontView ? 'front' : 'back';
    final key = '$muscleGroup-$view';

    if (svgPathIds.containsKey(key)) {
      final pathId = svgPathIds[key]!;
      if (pathId != 'TODO') {
        return [pathId];
      }
    }

    return []; // No path configured yet
  }

  /// Validate that all TODO placeholders have been replaced
  /// Returns true if all SVG paths are configured
  static bool isFullyConfigured() {
    return !svgPathIds.values.any((id) => id == 'TODO');
  }

  /// Get list of muscles that still need SVG path configuration
  static List<String> getUnconfiguredMuscles() {
    final unconfigured = <String>[];
    svgPathIds.forEach((key, value) {
      if (value == 'TODO') {
        unconfigured.add(key);
      }
    });
    return unconfigured;
  }
}
