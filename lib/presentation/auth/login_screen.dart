import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../patients/patients_screen.dart';
import 'forgot_screen.dart';
import 'login_controller.dart';

/// Stateful only to own the text controllers; the busy and error state live in [LoginController].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _id = TextEditingController(
    text: ref.read(settingsProvider).savedLoginId,
  );
  final _secret = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  LoginController get _controller => ref.read(loginControllerProvider.notifier);

  void _submit(LoginState login) {
    if (!_form.currentState!.validate()) return;
    if (login.method != LoginMethod.smsCode) {
      _controller.submit(_id.text, _secret.text);
    } else if (login.awaitingCode) {
      _controller.confirmCode(_id.text, _secret.text);
    } else {
      _controller.sendCode(_id.text);
    }
  }

  void _choose(LoginMethod method) {
    _secret.clear();
    _controller.choose(method);
  }

  @override
  Widget build(BuildContext context) {
    final login = ref.watch(loginControllerProvider);
    return _layout(login);
  }

  /// The fields and button for the chosen way of signing in.
  List<Widget> _fields(LoginState login) {
    final busy = login.busy;
    final (idField, secretField, action, busyLabel) = switch (login.method) {
      LoginMethod.pin => (
        HbTextField(
          label: 'Phone number',
          hint: 'e.g. 0788 123 456',
          icon: Icons.phone_outlined,
          controller: _id,
          keyboardType: TextInputType.phone,
          validator: validatePhone,
        ),
        HbTextField(
          label: 'PIN',
          hint: '4 to 6 digits',
          icon: Icons.lock_outline,
          controller: _secret,
          obscure: true,
          keyboardType: TextInputType.number,
          validator: validatePin,
        ),
        'Log in',
        'Logging in...',
      ),
      LoginMethod.email => (
        HbTextField(
          label: 'Email',
          hint: 'you@example.org',
          icon: Icons.mail_outline,
          controller: _id,
          keyboardType: TextInputType.emailAddress,
          validator: validateEmail,
        ),
        HbTextField(
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          controller: _secret,
          obscure: true,
          validator: validatePassword,
        ),
        'Log in',
        'Logging in...',
      ),
      LoginMethod.smsCode => (
        HbTextField(
          label: 'Phone number',
          hint: 'e.g. 0788 123 456',
          icon: Icons.phone_outlined,
          controller: _id,
          keyboardType: TextInputType.phone,
          validator: validatePhone,
        ),
        login.awaitingCode
            ? HbTextField(
                label: 'Code from the SMS',
                hint: '6 digits',
                icon: Icons.sms_outlined,
                controller: _secret,
                keyboardType: TextInputType.number,
                validator: validateCode,
              )
            : null,
        login.awaitingCode ? 'Log in' : 'Send code',
        login.awaitingCode ? 'Logging in...' : 'Sending...',
      ),
    };
    return [
      idField,
      if (secretField != null) ...[const SizedBox(height: 16), secretField],
      if (login.error != null) ...[
        const SizedBox(height: 12),
        Text(
          login.error!,
          style: HbText.bodySmall.copyWith(color: HbColors.red),
        ),
      ],
      const SizedBox(height: 22),
      HbButton.primary(
        busy ? busyLabel : action,
        onPressed: busy ? null : () => _submit(login),
      ),
      if (login.awaitingCode)
        TextButton(
          onPressed: busy ? null : _controller.changeNumber,
          child: const Text('Change number or send a new code'),
        ),
      TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ForgotScreen())),
        child: const Text('Forgot PIN or password?'),
      ),
    ];
  }

  Widget _layout(LoginState login) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Container(
            height: 176,
            width: double.infinity,
            color: HbColors.tealTint,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: HbColors.teal,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HealthBridge',
                      style: HbText.headingLarge.copyWith(fontSize: 21),
                    ),
                    Text(
                      'RWANDA',
                      style: HbText.labelSmall.copyWith(color: HbColors.teal),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: HbText.headingLarge.copyWith(
                        fontSize: 30,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to continue your community health work.',
                      style: HbText.bodyMedium.copyWith(
                        color: HbColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (m, label) in const [
                          (LoginMethod.pin, 'PIN'),
                          (LoginMethod.smsCode, 'SMS code'),
                          (LoginMethod.email, 'Email'),
                        ])
                          ChoiceChipPill(
                            label: label,
                            selected: login.method == m,
                            onTap: () => _choose(m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ..._fields(login),
                    const SizedBox(height: 60),
                    HbCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Text('Language', style: HbText.bodySmall),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'English',
                              textAlign: TextAlign.right,
                              style: HbText.labelMedium,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: HbColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
