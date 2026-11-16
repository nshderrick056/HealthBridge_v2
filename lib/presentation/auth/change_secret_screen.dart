import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import 'change_secret_controller.dart';
import 'login_controller.dart';

/// Shown after signing in with the temporary details the admin's SMS gave. A CHW sets a PIN; anyone
/// with an email sets a password. Stateful only to own the text controllers.
class ChangeSecretScreen extends ConsumerStatefulWidget {
  const ChangeSecretScreen({super.key});

  @override
  ConsumerState<ChangeSecretScreen> createState() => _ChangeSecretScreenState();
}

class _ChangeSecretScreenState extends ConsumerState<ChangeSecretScreen> {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  @override
  void dispose() {
    for (final c in [_pin, _pin2, _password, _password2]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final s = ref.watch(changeSecretProvider);
    final controller = ref.read(changeSecretProvider.notifier);
    final needsPin = session?.role == 'chw';
    final needsPassword = session?.email != null;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
            children: [
              PageHeader(
                title: 'Choose your own ${needsPin ? 'PIN' : 'password'}',
                subtitle:
                    'You signed in with the temporary details from the SMS. '
                    'Set your own to continue.',
              ),
              const SizedBox(height: 16),
              if (needsPin) ...[
                HbTextField(
                  label: 'New PIN',
                  hint: '4 to 6 digits',
                  controller: _pin,
                  obscure: true,
                  keyboardType: TextInputType.number,
                  validator: validatePin,
                ),
                HbTextField(
                  label: 'Repeat the PIN',
                  hint: 'The same digits',
                  controller: _pin2,
                  obscure: true,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v?.trim() == _pin.text.trim() ? null : 'The PINs differ',
                ),
              ],
              if (needsPassword) ...[
                HbTextField(
                  label: 'New password',
                  hint: 'At least 8 characters',
                  controller: _password,
                  obscure: true,
                  validator: validatePassword,
                ),
                HbTextField(
                  label: 'Repeat the password',
                  hint: 'The same password',
                  controller: _password2,
                  obscure: true,
                  validator: (v) =>
                      v == _password.text ? null : 'The passwords differ',
                ),
              ],
              if (s.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  s.error!,
                  style: HbText.bodySmall.copyWith(color: HbColors.red),
                ),
              ],
              const SizedBox(height: 22),
              HbButton.primary(
                s.busy ? 'Please wait...' : 'Save and continue',
                onPressed: s.busy
                    ? null
                    : () {
                        if (!_form.currentState!.validate()) return;
                        controller.save(
                          pin: needsPin ? _pin.text.trim() : null,
                          password: needsPassword ? _password.text : null,
                        );
                      },
              ),
              const SizedBox(height: 8),
              HbButton.secondary('Log out', onPressed: controller.logout),
            ],
          ),
        ),
      ),
    );
  }
}
