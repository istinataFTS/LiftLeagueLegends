import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_session_service.dart';

class SignInState extends Equatable {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  const SignInState({
    required this.isSubmitting,
    required this.isSuccess,
    this.errorMessage,
  });

  factory SignInState.initial() {
    return const SignInState(
      isSubmitting: false,
      isSuccess: false,
      errorMessage: null,
    );
  }

  SignInState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SignInState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[isSubmitting, isSuccess, errorMessage];
}

class SignInCubit extends Cubit<SignInState> {
  final AuthSessionService _authSessionService;

  SignInCubit({required AuthSessionService authSessionService})
    : _authSessionService = authSessionService,
      super(SignInState.initial());

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) {
      return;
    }

    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();

    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Email and password are required.',
          clearErrorMessage: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isSubmitting: true,
        isSuccess: false,
        clearErrorMessage: true,
      ),
    );

    final result = await _authSessionService.signInWithEmail(
      email: normalizedEmail,
      password: normalizedPassword,
    );

    if (result.isSuccess) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isSubmitting: false,
        isSuccess: false,
        errorMessage: result.message,
      ),
    );
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }

    emit(state.copyWith(clearErrorMessage: true));
  }
}
