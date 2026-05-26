class DatabaseTables {
  DatabaseTables._();

  static const String workoutSets = 'workout_sets';
  static const String exercises = 'exercises';
  static const String meals = 'meals';
  static const String nutritionLogs = 'nutrition_logs';
  static const String exerciseMuscleFactors = 'exercise_muscle_factors';
  static const String muscleStimulus = 'muscle_stimulus';
  static const String pendingSyncDeletes = 'pending_sync_deletes';
  static const String appMetadata = 'app_metadata';

  static const String ownerUserId = 'owner_user_id';

  static const String setId = 'id';
  static const String setExerciseId = 'exercise_id';
  static const String setReps = 'reps';
  static const String setWeight = 'weight';
  static const String setIntensity = 'intensity';
  static const String setDate = 'date';
  static const String setCreatedAt = 'created_at';
  static const String setUpdatedAt = 'updated_at';
  static const String setServerId = 'server_id';
  static const String setSyncStatus = 'sync_status';
  static const String setLastSyncedAt = 'last_synced_at';
  static const String setLastSyncError = 'last_sync_error';

  static const String exerciseId = 'id';
  static const String exerciseName = 'name';
  static const String exerciseMuscleGroups = 'muscle_groups';
  static const String exerciseCreatedAt = 'created_at';
  static const String exerciseUpdatedAt = 'updated_at';
  static const String exerciseServerId = 'server_id';
  static const String exerciseSyncStatus = 'sync_status';
  static const String exerciseLastSyncedAt = 'last_synced_at';
  static const String exerciseLastSyncError = 'last_sync_error';

  static const String mealId = 'id';
  static const String mealName = 'name';
  static const String mealServingSize = 'serving_size_grams';
  static const String mealCarbsPer100g = 'carbs_per_100g';
  static const String mealProteinPer100g = 'protein_per_100g';
  static const String mealFatPer100g = 'fat_per_100g';
  static const String mealCaloriesPer100g = 'calories_per_100g';
  static const String mealCreatedAt = 'created_at';
  static const String mealUpdatedAt = 'updated_at';
  static const String mealServerId = 'server_id';
  static const String mealSyncStatus = 'sync_status';
  static const String mealLastSyncedAt = 'last_synced_at';
  static const String mealLastSyncError = 'last_sync_error';

  static const String nutritionLogId = 'id';
  static const String nutritionLogMealId = 'meal_id';
  static const String nutritionLogMealName = 'meal_name';
  static const String nutritionLogGrams = 'grams';
  static const String nutritionLogCarbs = 'carbs';
  static const String nutritionLogProtein = 'protein';
  static const String nutritionLogFat = 'fat';
  static const String nutritionLogCalories = 'calories';
  static const String nutritionLogDate = 'date';
  static const String nutritionLogCreatedAt = 'created_at';
  static const String nutritionLogUpdatedAt = 'updated_at';
  static const String nutritionLogServerId = 'server_id';
  static const String nutritionLogSyncStatus = 'sync_status';
  static const String nutritionLogLastSyncedAt = 'last_synced_at';
  static const String nutritionLogLastSyncError = 'last_sync_error';

  static const String factorId = 'id';
  static const String factorExerciseId = 'exercise_id';
  static const String factorMuscleGroup = 'muscle_group';
  static const String factorValue = 'factor';
  static const String factorCreatedAt = 'created_at';

  static const String stimulusId = 'id';
  static const String stimulusMuscleGroup = 'muscle_group';
  static const String stimulusDate = 'date';
  static const String stimulusDailyStimulus = 'daily_stimulus';
  static const String stimulusRollingWeeklyLoad = 'rolling_weekly_load';
  static const String stimulusLastSetTimestamp = 'last_set_timestamp';
  static const String stimulusLastSetStimulus = 'last_set_stimulus';
  static const String stimulusCreatedAt = 'created_at';
  static const String stimulusUpdatedAt = 'updated_at';

  static const String pendingDeleteId = 'id';
  static const String pendingDeleteEntityType = 'entity_type';
  static const String pendingDeleteLocalEntityId = 'local_entity_id';
  static const String pendingDeleteServerEntityId = 'server_entity_id';
  static const String pendingDeleteCreatedAt = 'created_at';
  static const String pendingDeleteLastAttemptAt = 'last_attempt_at';
  static const String pendingDeleteErrorMessage = 'error_message';

  static const String metadataKey = 'key';
  static const String metadataValue = 'value';
  static const String metadataUpdatedAt = 'updated_at';
}
