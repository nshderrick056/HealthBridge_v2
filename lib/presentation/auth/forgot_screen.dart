import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../patients/patients_screen.dart';
import 'forgot_controller.dart';
import 'login_controller.dart';

/// Forgot PIN or password. Not in the Figma file; built from its components.
/// Stateful only to own the text controllers; the steps live in [ForgotController].
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_id, _code, _pin, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  ForgotController get _controller =>
      ref.read(forgotControllerProvider.notifier);

  void _next(ForgotState s) {
    if (s.step == ForgotStep.done) return Navigator.of(context).pop();
    if (!_form.currentState!.validate()) return;
    switch (s.step) {
      case ForgotStep.who:
        _controller.request(_id.text);
      case ForgotStep.code:
        _controller.verify(_code.text);
      case ForgotStep.newSecret:
        _controller.complete(
          pin: s.byEmail ? null : _pin.text.trim(),
          password: s.byEmail ? _password.text : null,
        );
      case ForgotStep.done:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(forgotControllerProvider);
    final (title, intro, action) = switch (s.step) {
      ForgotStep.who => (
        'Forgot PIN or password',
        'Your request goes to the admin. Once they approve it, you get an SMS with a 6-digit code.',
        'Send request',
      ),
      ForgotStep.code => (
        'Enter the code',
        'Request sent. When the admin approves it, an SMS with your code arrives. The code works for 30 minutes.',
        'Check code',
      ),
      ForgotStep.newSecret => (
        s.byEmail ? 'New password' : 'New PIN',
        s.byEmail
            ? 'Choose a password of at least 8 characters.'
            : 'Choose a PIN of 4 to 6 digits.',
        'Save',
      ),
      ForgotStep.done => (
        'All set',
        s.byEmail
            ? 'Your password has been changed. Log in with it now.'
            : 'Your PIN has been changed. Log in with it now.',
        'Back to log in',
      ),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: HbColors.surface,
        elevation: 0,
        foregroundColor: HbColors.textPrimary,
        toolbarHeight: 44,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              PageHeader(title: title, subtitle: intro),
              const SizedBox(height: 16),
              if (s.step == ForgotStep.who) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChipPill(
                      label: 'Phone',
                      selected: !s.byEmail,
                      onTap: () => _controller.useEmail(false),
                    ),
                    ChoiceChipPill(
                      label: 'Email',
                      selected: s.byEmail,
                      onTap: () => _controller.useEmail(true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                HbTextField(
                  label: s.byEmail ? 'Email' : 'Phone number',
                  hint: s.byEmail ? 'you@example.org' : 'e.g. 0788 123 456',
                  controller: _id,
                  keyboardType: s.byEmail
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  validator: s.byEmail ? validateEmail : validatePhone,
                ),
              ],
              if (s.step == ForgotStep.code)
                HbTextField(
                  label: 'Code from the SMS',
                  hint: '6 digits',
                  controller: _code,
                  keyboardType: TextInputType.number,
                  validator: validateCode,
                ),
              if (s.step == ForgotStep.newSecret)
                s.byEmail
                    ? HbTextField(
                        label: 'New password',
                        hint: 'At least 8 characters',
                        controller: _password,
                        obscure: true,
                        validator: validatePassword,
                      )
                    : HbTextField(
                        label: 'New PIN',
                        hint: '4 to 6 digits',
                        controller: _pin,
                        obscure: true,
                        keyboardType: TextInputType.number,
                        validator: validatePin,
                      ),
              if (s.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  s.error!,
                  style: HbText.bodySmall.copyWith(color: HbColors.red),
                ),
              ],
              const SizedBox(height: 22),
              HbButton.primary(
                s.busy ? 'Please wait...' : action,
                onPressed: s.busy ? null : () => _next(s),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
