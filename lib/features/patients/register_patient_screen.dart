import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../sync/sync_service.dart';
import 'patients_screen.dart';

/// Not in the Figma file (it only has the "Register patient" button); built from the same components.
class RegisterPatientScreen extends ConsumerStatefulWidget {
  const RegisterPatientScreen({super.key});

  @override
  ConsumerState<RegisterPatientScreen> createState() =>
      _RegisterPatientScreenState();
}

class _RegisterPatientScreenState extends ConsumerState<RegisterPatientScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _village = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  String? _sex;
  bool _consent = false;

  @override
  void dispose() {
    for (final c in [_name, _village, _age, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate() || !_consent) {
      setState(() {});
      return;
    }
    await ref
        .read(patientsRepositoryProvider)
        .create(
          fullName: _name.text.trim(),
          village: _village.text.trim(),
          sex: _sex,
          ageEstimate: int.tryParse(_age.text.trim()),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
    unawaited(ref.read(syncNowProvider)());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: HbColors.surface,
      elevation: 0,
      foregroundColor: HbColors.textPrimary,
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            const PageHeader(
              title: 'Register patient',
              subtitle: 'Saved on this device, synced when online',
            ),
            const SizedBox(height: 16),
            HbTextField(
              label: 'Full name',
              hint: 'Patient name',
              controller: _name,
              validator: _required,
            ),
            const SizedBox(height: 14),
            HbTextField(
              label: 'Village',
              hint: 'Village',
              controller: _village,
              validator: _required,
            ),
            const SizedBox(height: 14),
            Text('Sex', style: HbText.labelMedium),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChipPill(
                  label: 'Female',
                  selected: _sex == 'F',
                  onTap: () => setState(() => _sex = 'F'),
                ),
                ChoiceChipPill(
                  label: 'Male',
                  selected: _sex == 'M',
                  onTap: () => setState(() => _sex = 'M'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            HbTextField(
              label: 'Age (years)',
              hint: 'Estimated age',
              controller: _age,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            HbTextField(
              label: 'Phone (optional)',
              hint: 'Phone number',
              controller: _phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            HbCard(
              onTap: () => setState(() => _consent = !_consent),
              child: Row(
                children: [
                  Checkbox(
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'The patient agreed to have their health information recorded.',
                      style: HbText.bodySmall.copyWith(
                        color: HbColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            HbButton.primary(
              'Save patient',
              onPressed: _consent ? _save : null,
            ),
          ],
        ),
      ),
    ),
  );
}
