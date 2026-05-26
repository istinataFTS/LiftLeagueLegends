import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'models/home_dashboard_data.dart';
import 'usecases/load_home_dashboard_data.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class LoadHomeDataEvent extends HomeEvent {
  const LoadHomeDataEvent();
}

class RefreshHomeDataEvent extends HomeEvent {
  const RefreshHomeDataEvent();
}

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => <Object?>[];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  const HomeLoaded({required this.data});

  final HomeDashboardData data;

  @override
  List<Object?> get props => <Object?>[data];
}

class HomeError extends HomeState {
  const HomeError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required LoadHomeDashboardData loadHomeDashboardData})
    : _loadHomeDashboardData = loadHomeDashboardData,
      super(const HomeInitial()) {
    on<LoadHomeDataEvent>(_onLoadHomeData);
    on<RefreshHomeDataEvent>(_onRefreshHomeData);
  }

  final LoadHomeDashboardData _loadHomeDashboardData;

  Future<void> _onLoadHomeData(
    LoadHomeDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());
    await _loadAndEmitHomeState(emit);
  }

  Future<void> _onRefreshHomeData(
    RefreshHomeDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    await _loadAndEmitHomeState(emit, preserveCurrentStateOnFailure: true);
  }

  Future<void> _loadAndEmitHomeState(
    Emitter<HomeState> emit, {
    bool preserveCurrentStateOnFailure = false,
  }) async {
    final result = await _loadHomeDashboardData();

    result.fold(
      (failure) {
        _emitErrorOrPreserve(
          emit,
          failure.message,
          preserveCurrentStateOnFailure,
        );
      },
      (data) {
        emit(HomeLoaded(data: data));
      },
    );
  }

  void _emitErrorOrPreserve(
    Emitter<HomeState> emit,
    String message,
    bool preserveCurrentStateOnFailure,
  ) {
    if (preserveCurrentStateOnFailure && state is HomeLoaded) {
      emit(state);
      return;
    }

    emit(HomeError(message));
  }
}
