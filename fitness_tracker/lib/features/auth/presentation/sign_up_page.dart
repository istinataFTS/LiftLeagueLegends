import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_session_service.dart';
import '../../../injection/injection_container.dart' as di;
import '../application/sign_up_cubit.dart';
import 'otp_verification_page.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  static const Key emailFieldKey = Key('sign_up_email_field');
  static const Key usernameFieldKey = Key('sign_up_username_field');
  static const Key passwordFieldKey = Key('sign_up_password_field');
  static const Key confirmPasswordFieldKey = Key(
    'sign_up_confirm_password_field',
  );
  static const Key submitButtonKey = Key('sign_up_submit_button');

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SignUpCubit>(
      create: (_) =>
          SignUpCubit(authSessionService: di.sl<AuthSessionService>()),
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView();

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  late final TextEditingController _emailController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _otpNavigationInProgress = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SignUpCubit, SignUpState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.isFailure &&
            state.errorMessage != null &&
            state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          context.read<SignUpCubit>().clearError();
        }

        if (state.isSuccess) {
          Navigator.of(context).pop(true);
        }

        if (state.isAwaitingEmailConfirmation && state.email != null) {
          _navigateToOtpVerification(context, state.email!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Create account')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: SignUpPage.emailFieldKey,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: SignUpPage.usernameFieldKey,
                    controller: _usernameController,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText:
                          'Letters, numbers and underscores only (3–30 chars)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: SignUpPage.passwordFieldKey,
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'Minimum 8 characters',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: SignUpPage.confirmPasswordFieldKey,
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(context),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: SignUpPage.submitButtonKey,
                    onPressed: state.isSubmitting
                        ? null
                        : () => _submit(context),
                    child: state.isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit(BuildContext context) {
    context.read<SignUpCubit>().submit(
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      username: _usernameController.text,
    );
  }

  Future<void> _navigateToOtpVerification(
    BuildContext context,
    String email,
  ) async {
    if (_otpNavigationInProgress) return;
    _otpNavigationInProgress = true;

    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OtpVerificationPage(email: email),
      ),
    );

    _otpNavigationInProgress = false;

    if ((confirmed ?? false) && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
