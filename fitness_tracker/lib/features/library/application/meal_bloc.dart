import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/meal.dart';
import '../../../domain/usecases/meals/add_meal.dart';
import '../../../domain/usecases/meals/delete_meal.dart';
import '../../../domain/usecases/meals/ensure_default_meals.dart';
import '../../../domain/usecases/meals/get_all_meals.dart';
import '../../../domain/usecases/meals/get_meal_by_id.dart';
import '../../../domain/usecases/meals/get_meal_by_name.dart';
import '../../../domain/usecases/meals/update_meal.dart';

abstract class MealEvent extends Equatable {
  const MealEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class LoadMealsEvent extends MealEvent {}

class LoadMealByIdEvent extends MealEvent {
  const LoadMealByIdEvent(this.id);

  final String id;

  @override
  List<Object?> get props => <Object?>[id];
}

class LoadMealByNameEvent extends MealEvent {
  const LoadMealByNameEvent(this.name);

  final String name;

  @override
  List<Object?> get props => <Object?>[name];
}

class AddMealEvent extends MealEvent {
  const AddMealEvent(this.meal);

  final Meal meal;

  @override
  List<Object?> get props => <Object?>[meal];
}

class UpdateMealEvent extends MealEvent {
  const UpdateMealEvent(this.meal);

  final Meal meal;

  @override
  List<Object?> get props => <Object?>[meal];
}

class DeleteMealEvent extends MealEvent {
  const DeleteMealEvent(this.id);

  final String id;

  @override
  List<Object?> get props => <Object?>[id];
}

abstract class MealState extends Equatable {
  const MealState();

  @override
  List<Object?> get props => <Object?>[];
}

class MealInitial extends MealState {}

class MealLoading extends MealState {}

class MealsLoaded extends MealState {
  const MealsLoaded(this.meals);

  final List<Meal> meals;

  @override
  List<Object?> get props => <Object?>[meals];
}

class MealLoaded extends MealState {
  const MealLoaded(this.meal);

  final Meal meal;

  @override
  List<Object?> get props => <Object?>[meal];
}

class MealError extends MealState {
  const MealError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

class MealOperationSuccess extends MealState {
  const MealOperationSuccess(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

class MealBloc extends Bloc<MealEvent, MealState> {
  MealBloc({
    required this.getAllMeals,
    required this.getMealById,
    required this.getMealByName,
    required this.addMeal,
    required this.updateMeal,
    required this.deleteMeal,
    required this.ensureDefaultMeals,
  }) : super(MealInitial()) {
    on<LoadMealsEvent>(_onLoadMeals);
    on<LoadMealByIdEvent>(_onLoadMealById);
    on<LoadMealByNameEvent>(_onLoadMealByName);
    on<AddMealEvent>(_onAddMeal);
    on<UpdateMealEvent>(_onUpdateMeal);
    on<DeleteMealEvent>(_onDeleteMeal);
  }

  final GetAllMeals getAllMeals;
  final GetMealById getMealById;
  final GetMealByName getMealByName;
  final AddMeal addMeal;
  final UpdateMeal updateMeal;
  final DeleteMeal deleteMeal;
  final EnsureDefaultMeals ensureDefaultMeals;

  bool _hasEnsuredDefaults = false;

  Future<void> _onLoadMeals(
    LoadMealsEvent event,
    Emitter<MealState> emit,
  ) async {
    emit(MealLoading());
    final result = await getAllMeals();
    await result.fold((failure) async => emit(MealError(failure.message)), (
      meals,
    ) async {
      // Safety-net: an empty catalog on a fresh device / new cloud account
      // gets the defaults provisioned once per session. The flag prevents
      // an infinite re-seed loop if seeding yields nothing.
      if (meals.isEmpty && !_hasEnsuredDefaults) {
        _hasEnsuredDefaults = true;
        await ensureDefaultMeals();

        final reloadResult = await getAllMeals();
        reloadResult.fold(
          (failure) => emit(MealError(failure.message)),
          (seeded) => emit(MealsLoaded(seeded)),
        );
        return;
      }

      emit(MealsLoaded(meals));
    });
  }

  Future<void> _onLoadMealById(
    LoadMealByIdEvent event,
    Emitter<MealState> emit,
  ) async {
    emit(MealLoading());
    final result = await getMealById(event.id);
    result.fold((failure) => emit(MealError(failure.message)), (meal) {
      if (meal == null) {
        emit(const MealError('Meal not found'));
      } else {
        emit(MealLoaded(meal));
      }
    });
  }

  Future<void> _onLoadMealByName(
    LoadMealByNameEvent event,
    Emitter<MealState> emit,
  ) async {
    emit(MealLoading());
    final result = await getMealByName(event.name);
    result.fold((failure) => emit(MealError(failure.message)), (meal) {
      if (meal == null) {
        emit(const MealError('Meal not found'));
      } else {
        emit(MealLoaded(meal));
      }
    });
  }

  Future<void> _onAddMeal(AddMealEvent event, Emitter<MealState> emit) async {
    final result = await addMeal(event.meal);
    await result.fold((failure) async => emit(MealError(failure.message)), (
      _,
    ) async {
      emit(const MealOperationSuccess('Meal added successfully'));
      add(LoadMealsEvent());
    });
  }

  Future<void> _onUpdateMeal(
    UpdateMealEvent event,
    Emitter<MealState> emit,
  ) async {
    final result = await updateMeal(event.meal);
    await result.fold((failure) async => emit(MealError(failure.message)), (
      _,
    ) async {
      emit(const MealOperationSuccess('Meal updated successfully'));
      add(LoadMealsEvent());
    });
  }

  Future<void> _onDeleteMeal(
    DeleteMealEvent event,
    Emitter<MealState> emit,
  ) async {
    final result = await deleteMeal(event.id);
    await result.fold((failure) async => emit(MealError(failure.message)), (
      _,
    ) async {
      emit(const MealOperationSuccess('Meal deleted successfully'));
      add(LoadMealsEvent());
    });
  }
}
