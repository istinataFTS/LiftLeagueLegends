import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_session_service.dart';
import '../../../injection/injection_container.dart' as di;
import '../application/sign_in_cubit.dart';
import 'sign_up_page.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  static const Key emailFieldKey = Key('sign_in_email_field');
  static const Key passwordFieldKey = Key('sign_in_password_field');
  static const Key submitButtonKey = Key('sign_in_submit_button');

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SignInCubit>(
      create: (_) =>
          SignInCubit(authSessionService: di.sl<AuthSessionService>()),
      child: const _SignInView(),
    );
  }
}

class _SignInView extends StatefulWidget {
  const _SignInView();

  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _formKey = GlobalKey<FormState>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SignInCubit, SignInState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.isSuccess != current.isSuccess,
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          context.read<SignInCubit>().clearError();
        }

        if (state.isSuccess) {
          // Pop when SignInPage was pushed (the legacy entry from Profile);
          // skip when it's the root route under AuthGate — the gate's
          // BlocSelector observes the new authenticated session and swaps to
          // the authenticated tree declaratively.
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop(true);
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sign in')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: SignInPage.emailFieldKey,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: SignInPage.passwordFieldKey,
                      controller: _passwordController,
                      obscureText: true,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Password'),
                      onFieldSubmitted: (_) => _submit(context, state),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      key: SignInPage.submitButtonKey,
                      onPressed: state.isSubmitting
                          ? null
                          : () => _submit(context, state),
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _navigateToSignUp(context),
                      child: const Text("Don't have an account? Sign up"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit(BuildContext context, SignInState state) {
    context.read<SignInCubit>().submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _navigateToSignUp(BuildContext context) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const SignUpPage()));

    // Sign-up succeeded and a session was established — propagate the
    // success back up the navigation stack the same way sign-in does.
    if (result == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
