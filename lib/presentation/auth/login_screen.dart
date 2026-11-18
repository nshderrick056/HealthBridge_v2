import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
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
          controller: _id,
          keyboardType: TextInputType.phone,
          validator: validatePhone,
          labelColor: Colors.white,
        ),
        HbTextField(
          label: 'PIN',
          hint: '4 to 6 digits',
          controller: _secret,
          obscure: true,
          keyboardType: TextInputType.number,
          validator: validatePin,
          labelColor: Colors.white,
        ),
        'Sign in',
        'Signing in...',
      ),
      LoginMethod.email => (
        HbTextField(
          label: 'Email',
          hint: 'you@example.org',
          controller: _id,
          keyboardType: TextInputType.emailAddress,
          validator: validateEmail,
          labelColor: Colors.white,
        ),
        HbTextField(
          label: 'Password',
          hint: 'Enter your password',
          controller: _secret,
          obscure: true,
          validator: validatePassword,
          labelColor: Colors.white,
        ),
        'Sign in',
        'Signing in...',
      ),
      LoginMethod.smsCode => (
        HbTextField(
          label: 'Phone number',
          hint: 'e.g. 0788 123 456',
          controller: _id,
          keyboardType: TextInputType.phone,
          validator: validatePhone,
          labelColor: Colors.white,
        ),
        login.awaitingCode
            ? HbTextField(
                label: 'Code from the SMS',
                hint: '6 digits',
                controller: _secret,
                keyboardType: TextInputType.number,
                validator: validateCode,
                labelColor: Colors.white,
              )
            : null,
        login.awaitingCode ? 'Sign in' : 'Send code',
        login.awaitingCode ? 'Signing in...' : 'Sending...',
      ),
    };
    return [
      idField,
      if (secretField != null) ...[const SizedBox(height: 18), secretField],
      if (login.error != null) ...[
        const SizedBox(height: 12),
        Text(
          login.error!,
          style: HbText.bodyMedium.copyWith(
            color: _errorOnGreen,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
      const SizedBox(height: 24),
      HbButton.light(
        busy ? busyLabel : action,
        onPressed: busy ? null : () => _submit(login),
      ),
      const SizedBox(height: 4),
      if (login.awaitingCode)
        _Link(
          'Change number or send a new code',
          onTap: busy ? null : _controller.changeNumber,
        ),
      _Link(
        'Forgot PIN or password?',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ForgotScreen())),
      ),
    ];
  }

  /// Light red that stays readable on the green (about 7:1).
  static const _errorOnGreen = Color(0xFFFFD7D2);

  Widget _layout(LoginState login) => Scaffold(
    // The green stays still when the keyboard opens; only the form scrolls up above it.
    resizeToAvoidBottomInset: false,
    // The gradient ends in this colour, so no light edge can show below it.
    backgroundColor: HbColors.brandDeep,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: HbGradients.deep),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              40,
              24,
              28 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HealthBridge',
                    style: HbText.headingMedium.copyWith(color: HbColors.lime),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Sign in',
                    style: HbText.display.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use the phone number your supervisor registered.',
                    style: HbText.bodyMedium.copyWith(color: HbColors.onBrand),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final (m, label) in const [
                        (LoginMethod.pin, 'PIN'),
                        (LoginMethod.smsCode, 'SMS code'),
                        (LoginMethod.email, 'Email'),
                      ])
                        _MethodChip(
                          label,
                          selected: login.method == m,
                          onTap: () => _choose(m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ..._fields(login),
                  const SizedBox(height: 32),
                  Text(
                    'Your visits are kept on this phone and sent when you have signal.',
                    style: HbText.bodySmall.copyWith(color: HbColors.onBrand),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// White pill for the chosen method, plain text for the others: a segmented control on green.
class _MethodChip extends StatelessWidget {
  const _MethodChip(this.label, {required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? Colors.white : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            label,
            style: HbText.bodyMedium.copyWith(
              color: selected ? HbColors.ink : HbColors.onBrand,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Link extends StatelessWidget {
  const _Link(this.label, {required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label,
        style: HbText.bodyMedium.copyWith(
          color: HbColors.lime,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: HbColors.lime,
        ),
      ),
    ),
  );
}
