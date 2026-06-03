import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/auth_gate.dart';
import 'package:fitness_tracker/app/auth_loading_view.dart';
import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/features/auth/presentation/sign_in_page.dart';
import 'package:fitness_tracker/features/profile/application/profile_cubit.dart';
import 'package:fitness_tracker/injection/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

class _MockAuthSessionService extends Mock implements AuthSessionService {}

const _authenticatedChildKey = ValueKey<String>('authenticated-child');

ProfileState _resolvingState() => ProfileState.initial();

ProfileState _unauthenticatedState() =>
    const ProfileState(session: null, isLoading: false, hasLoaded: true);

ProfileState _authenticatedState() => const ProfileState(
  session: AppSession(
    user: AppUser(id: 'user-1', email: 'user-1@test.com'),
  ),
  isLoading: false,
  hasLoaded: true,
);

Widget _harness(ProfileCubit cubit) {
  return MaterialApp(
    home: BlocProvider<ProfileCubit>.value(
      value: cubit,
      child: const AuthGate(
        authenticatedChild: ColoredBox(
          key: _authenticatedChildKey,
          color: Color(0xFF000000),
        ),
      ),
    ),
  );
}

void main() {
  // SignInPage constructs a SignInCubit that pulls AuthSessionService from
  // the DI container. Stub it so the page can mount in the widget test.
  late _MockAuthSessionService authSessionService;

  setUp(() async {
    authSessionService = _MockAuthSessionService();
    if (di.sl.isRegistered<AuthSessionService>()) {
      await di.sl.unregister<AuthSessionService>();
    }
    di.sl.registerLazySingleton<AuthSessionService>(() => authSessionService);
  });

  tearDown(() async {
    if (di.sl.isRegistered<AuthSessionService>()) {
      await di.sl.unregister<AuthSessionService>();
    }
  });

  testWidgets('renders SignInPage when no authenticated user is present', (
    tester,
  ) async {
    final cubit = _MockProfileCubit();
    when(() => cubit.state).thenReturn(_unauthenticatedState());

    await tester.pumpWidget(_harness(cubit));

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byKey(_authenticatedChildKey), findsNothing);
  });

  testWidgets(
    'renders authenticatedChild when an authenticated user is present',
    (tester) async {
      final cubit = _MockProfileCubit();
      when(() => cubit.state).thenReturn(_authenticatedState());

      await tester.pumpWidget(_harness(cubit));

      expect(find.byKey(_authenticatedChildKey), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
    },
  );

  testWidgets(
    'swaps from SignInPage to authenticatedChild when the session emits a user',
    (tester) async {
      final cubit = _MockProfileCubit();
      whenListen(
        cubit,
        Stream<ProfileState>.fromIterable([_authenticatedState()]),
        initialState: _unauthenticatedState(),
      );

      await tester.pumpWidget(_harness(cubit));

      expect(find.byType(SignInPage), findsOneWidget);

      // Let the streamed authenticated state propagate.
      await tester.pump();

      expect(find.byKey(_authenticatedChildKey), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
    },
  );

  testWidgets(
    'renders the loading splash while the session is still resolving',
    (tester) async {
      final cubit = _MockProfileCubit();
      when(() => cubit.state).thenReturn(_resolvingState());

      await tester.pumpWidget(_harness(cubit));

      expect(find.byType(AuthLoadingView), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
      expect(find.byKey(_authenticatedChildKey), findsNothing);
    },
  );

  testWidgets(
    'does not show SignInPage when an authenticated session resolves from a cold start',
    (tester) async {
      final cubit = _MockProfileCubit();
      whenListen(
        cubit,
        Stream<ProfileState>.fromIterable([_authenticatedState()]),
        initialState: _resolvingState(),
      );

      await tester.pumpWidget(_harness(cubit));

      // While resolving: splash shown, sign-in page never appears.
      expect(find.byType(AuthLoadingView), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);

      // After the authenticated state arrives: authenticated child shown, sign-in page still absent.
      await tester.pump();

      expect(find.byKey(_authenticatedChildKey), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
    },
  );
}
