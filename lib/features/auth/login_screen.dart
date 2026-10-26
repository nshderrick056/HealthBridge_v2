import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _id = TextEditingController();
  final _secret = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(authServiceProvider)
          .login(_id.text, _secret.text);
      ref.read(sessionProvider.notifier).state = session;
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                    const SizedBox(height: 22),
                    HbTextField(
                      label: 'CHW ID or phone number',
                      hint: 'Enter your ID or phone',
                      icon: Icons.badge_outlined,
                      controller: _id,
                      keyboardType: TextInputType.emailAddress,
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    HbTextField(
                      label: 'Password',
                      hint: 'Enter your password',
                      icon: Icons.lock_outline,
                      controller: _secret,
                      obscure: true,
                      validator: _required,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: HbText.bodySmall.copyWith(color: HbColors.red),
                      ),
                    ],
                    const SizedBox(height: 22),
                    HbButton.primary(
                      _busy ? 'Logging in...' : 'Log in',
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 120),
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
