import 'package:get_it/get_it.dart';

import '../../features/history/history.dart';

void registerHistoryModule(GetIt sl) {
  sl.registerFactory(
    () => HistoryBloc(
      getAllWorkoutSets: sl(),
      getSetsByDateRange: sl(),
      getNutritionLogsByDateRange: sl(),
      deleteWorkoutSet: sl(),
      updateWorkoutSet: sl(),
      deleteNutritionLog: sl(),
      updateNutritionLog: sl(),
    ),
  );
}