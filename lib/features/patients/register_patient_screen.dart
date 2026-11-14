import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import 'patients_screen.dart';
import 'register_patient_controller.dart';

/// Not in the Figma file (it only has the "Register patient" button); built from the same components.
/// Stateful only to own the text controllers; the choices live in [RegisterPatientController].
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
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(registerPatientProvider.notifier)
          .save(
            fullName: _name.text,
            village: _village.text,
            age: _age.text,
            phone: _phone.text,
          );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the patient. Try again.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final choices = ref.watch(registerPatientProvider);
    final controller = ref.read(registerPatientProvider.notifier);
    return _layout(choices, controller);
  }

  Widget _layout(
    RegisterPatientState choices,
    RegisterPatientController controller,
  ) => Scaffold(
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
                  selected: choices.sex == 'F',
                  onTap: () => controller.setSex('F'),
                ),
                ChoiceChipPill(
                  label: 'Male',
                  selected: choices.sex == 'M',
                  onTap: () => controller.setSex('M'),
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
              onTap: () => controller.setConsent(!choices.consent),
              child: Row(
                children: [
                  Checkbox(
                    value: choices.consent,
                    onChanged: (v) => controller.setConsent(v ?? false),
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
              onPressed: choices.consent ? _save : null,
            ),
          ],
        ),
      ),
    ),
  );
}
