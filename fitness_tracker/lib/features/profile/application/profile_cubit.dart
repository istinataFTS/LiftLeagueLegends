import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_session_service.dart';
import '../../../core/session/session_sync_service.dart';
import '../../../core/validation/username_validator.dart';
import '../../../domain/entities/app_session.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/repositories/app_session_repository.dart';
import '../../../domain/repositories/user_profile_repository.dart';

class ProfileState extends Equatable {
  const ProfileState({
    required this.session,
    required this.isLoading,
    required this.hasLoaded,
    this.userProfile,
    this.errorMessage,
  });

  /// Null when the cubit has not yet resolved a session, or when session
  /// lookup failed (the auth gate normally prevents this from being null
  /// in a steady state).
  final AppSession? session;
  final bool isLoading;
  final bool hasLoaded;
  final UserProfile? userProfile;
  final String? errorMessage;

  factory ProfileState.initial() {
    return const ProfileState(
      session: null,
      isLoading: false,
      hasLoaded: false,
      userProfile: null,
      errorMessage: null,
    );
  }

  ProfileState copyWith({
    AppSession? session,
    bool clearSession = false,
    bool? isLoading,
    bool? hasLoaded,
    UserProfile? userProfile,
    bool clearUserProfile = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ProfileState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      userProfile: clearUserProfile ? null : (userProfile ?? this.userProfile),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    session,
    isLoading,
    hasLoaded,
    userProfile,
    errorMessage,
  ];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required AppSessionRepository repository,
    required SessionSyncService sessionSyncService,
    required AuthSessionService authSessionService,
    required UserProfileRepository userProfileRepository,
  }) : _repository = repository,
       _sessionSyncService = sessionSyncService,
       _authSessionService = authSessionService,
       _userProfileRepository = userProfileRepository,
       super(ProfileState.initial()) {
    // Reactively reload when a new authenticated session is established
    // (sign-in / sign-up / OTP). Without this, AuthGate — which keys off
    // ProfileState.session — would not swap to the app until a manual restart
    // re-ran loadProfile(). Mirrors AppSettingsCubit's subscription to
    // AppSettingsRepository.watchSettings().
    _onSessionEstablishedSub = _sessionSyncService.onSessionEstablished.listen((
      _,
    ) {
      if (isClosed) return;
      unawaited(loadProfile());
    });
  }

  final AppSessionRepository _repository;
  final SessionSyncService _sessionSyncService;
  final AuthSessionService _authSessionService;
  final UserProfileRepository _userProfileRepository;
  late final StreamSubscription<void> _onSessionEstablishedSub;

  @override
  Future<void> close() async {
    await _onSessionEstablishedSub.cancel();
    return super.close();
  }

  Future<void> ensureLoaded() async {
    if (state.hasLoaded || state.isLoading) {
      return;
    }

    await _loadProfile();
  }

  Future<void> loadProfile() async {
    await _loadProfile();
  }

  Future<void> refreshProfile() async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    final refreshResult = await _sessionSyncService.runManualRefresh();
    final sessionResult = await _repository.getCurrentSession();

    await sessionResult.fold(
      (failure) async {
        emit(
          state.copyWith(
            clearSession: true,
            isLoading: false,
            hasLoaded: true,
            clearUserProfile: true,
            errorMessage: _combineMessages(
              primary: refreshResult.isSuccess ? null : refreshResult.message,
              fallback: failure.message,
            ),
          ),
        );
      },
      (session) async {
        final userProfile = await _fetchUserProfile(session);

        emit(
          state.copyWith(
            session: session,
            userProfile: userProfile,
            isLoading: false,
            hasLoaded: true,
            errorMessage: refreshResult.isSuccess
                ? null
                : refreshResult.message,
            clearErrorMessage: refreshResult.isSuccess,
          ),
        );
      },
    );
  }

  Future<void> signOut() async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    final signOutResult = await _authSessionService.signOut();
    final sessionResult = await _repository.getCurrentSession();

    sessionResult.fold(
      (failure) {
        emit(
          state.copyWith(
            clearSession: true,
            isLoading: false,
            hasLoaded: true,
            clearUserProfile: true,
            errorMessage: signOutResult.isSuccess
                ? failure.message
                : _combineMessages(
                    primary: signOutResult.message,
                    fallback: failure.message,
                  ),
          ),
        );
      },
      (session) {
        emit(
          state.copyWith(
            session: session,
            isLoading: false,
            hasLoaded: true,
            clearUserProfile: true,
            errorMessage: signOutResult.isSuccess
                ? null
                : signOutResult.message,
          ),
        );
      },
    );
  }

  /// Saves [updated] to the remote and refreshes the in-state profile on success.
  Future<void> updateProfile(UserProfile updated) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    final result = await _userProfileRepository.upsertProfile(updated);

    result.fold(
      (failure) {
        emit(state.copyWith(isLoading: false, errorMessage: failure.message));
      },
      (profile) {
        emit(
          state.copyWith(
            userProfile: profile,
            isLoading: false,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  /// Renames the signed-in user. Validates locally first, no-ops when the
  /// username is unchanged, and otherwise persists via [upsertProfile].
  ///
  /// Returns `true` on success (or when there was nothing to change) and
  /// `false` on validation/persistence failure, in which case
  /// [ProfileState.errorMessage] carries a user-facing reason.
  Future<bool> updateUsername(String rawUsername) async {
    final UserProfile? profile = state.userProfile;
    if (profile == null) {
      emit(
        state.copyWith(
          errorMessage: 'You must be signed in to change your username.',
        ),
      );
      return false;
    }

    final String username = rawUsername.trim();

    final String? validationError = UsernameValidator.validate(username);
    if (validationError != null) {
      emit(state.copyWith(errorMessage: validationError));
      return false;
    }

    if (username == profile.username) {
      return true;
    }

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    final result = await _userProfileRepository.upsertProfile(
      profile.copyWith(username: username, updatedAt: DateTime.now()),
    );

    return result.fold(
      (failure) {
        emit(state.copyWith(isLoading: false, errorMessage: failure.message));
        return false;
      },
      (updated) {
        emit(
          state.copyWith(
            userProfile: updated,
            isLoading: false,
            clearErrorMessage: true,
          ),
        );
        return true;
      },
    );
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }

    emit(state.copyWith(clearErrorMessage: true));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadProfile() async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    final sessionResult = await _repository.getCurrentSession();

    await sessionResult.fold(
      (failure) async {
        emit(
          state.copyWith(
            clearSession: true,
            isLoading: false,
            hasLoaded: true,
            clearUserProfile: true,
            errorMessage: failure.message,
          ),
        );
      },
      (session) async {
        final userProfile = await _fetchUserProfile(session);

        emit(
          state.copyWith(
            session: session,
            userProfile: userProfile,
            isLoading: false,
            hasLoaded: true,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  Future<UserProfile?> _fetchUserProfile(AppSession session) async {
    final result = await _userProfileRepository.getProfile(session.user.id);
    return result.fold((_) => null, (profile) => profile);
  }

  String _combineMessages({
    required String? primary,
    required String fallback,
  }) {
    if (primary == null || primary.isEmpty) {
      return fallback;
    }

    return '$primary | $fallback';
  }
}
