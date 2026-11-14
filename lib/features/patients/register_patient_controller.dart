import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../sync/sync_service.dart';

class RegisterPatientState {
  const RegisterPatientState({this.sex, this.consent = false});

  final String? sex;
  final bool consent;
}

/// The register-patient form's choices, and saving the patient.
class RegisterPatientController extends Notifier<RegisterPatientState> {
  @override
  RegisterPatientState build() => const RegisterPatientState();

  void setSex(String sex) =>
      state = RegisterPatientState(sex: sex, consent: state.consent);

  void setConsent(bool consent) =>
      state = RegisterPatientState(sex: state.sex, consent: consent);

  /// Saves on the phone (with its outbox row) and starts an upload if online.
  Future<void> save({
    required String fullName,
    required String village,
    required String age,
    required String phone,
  }) async {
    await ref
        .read(patientsRepositoryProvider)
        .create(
          fullName: fullName.trim(),
          village: village.trim(),
          sex: state.sex,
          ageEstimate: int.tryParse(age.trim()),
          phone: phone.trim().isEmpty ? null : phone.trim(),
        );
    unawaited(ref.read(syncNowProvider)());
  }
}

final registerPatientProvider =
    NotifierProvider.autoDispose<
      RegisterPatientController,
      RegisterPatientState
    >(RegisterPatientController.new);
