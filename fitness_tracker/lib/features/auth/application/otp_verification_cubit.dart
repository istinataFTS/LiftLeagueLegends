import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_session_service.dart';

enum OtpVerificationStatus { initial, submitting, success, failure }

class OtpVerificationState extends Equatable {
  final OtpVerificationStatus status;
  final String? errorMessage;

  const OtpVerificationState({required this.status, this.errorMessage});

  factory OtpVerificationState.initial() =>
      const OtpVerificationState(status: OtpVerificationStatus.initial);

  bool get isSubmitting => status == OtpVerificationStatus.submitting;
  bool get isSuccess => status == OtpVerificationStatus.success;
  bool get isFailure => status == OtpVerificationStatus.failure;

  OtpVerificationState copyWith({
    OtpVerificationStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return OtpVerificationState(
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, errorMessage];
}

class OtpVerificationCubit extends Cubit<OtpVerificationState> {
  OtpVerificationCubit({
    required AuthSessionService authSessionService,
    required this.email,
  }) : _authSessionService = authSessionService,
       super(OtpVerificationState.initial());

  final AuthSessionService _authSessionService;
  final String email;

  Future<void> submit(String token) async {
    if (state.isSubmitting) return;

    final trimmed = token.trim();
    if (trimmed.length != 6 || int.tryParse(trimmed) == null) {
      emit(
        state.copyWith(
          status: OtpVerificationStatus.failure,
          errorMessage: 'Enter the 6-digit code from your email.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OtpVerificationStatus.submitting,
        clearErrorMessage: true,
      ),
    );

    final result = await _authSessionService.verifyEmailOtp(
      email: email,
      token: trimmed,
    );

    if (result.isFailure) {
      emit(
        state.copyWith(
          status: OtpVerificationStatus.failure,
          errorMessage: result.message,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OtpVerificationStatus.success,
        clearErrorMessage: true,
      ),
    );
  }
}
