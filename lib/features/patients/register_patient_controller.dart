import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../data/providers.dart';
import '../../sync/sync_service.dart';

class RegisterPatientState {
  const RegisterPatientState({this.sex, this.consent = false});

  final String? sex;
  final bool consent;
}

/// The register / edit patient form's choices, and saving the patient.
/// Keyed by the patient being edited; null registers a new one.
class RegisterPatientController extends Notifier<RegisterPatientState> {
  RegisterPatientController(this.editing);

  final Patient? editing;

  // An existing patient already gave consent when they were registered.
  @override
  RegisterPatientState build() =>
      RegisterPatientState(sex: editing?.sex, consent: editing != null);

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
    final repo = ref.read(patientsRepositoryProvider);
    final ageEstimate = int.tryParse(age.trim());
    final phoneOrNull = phone.trim().isEmpty ? null : phone.trim();
    final p = editing;
    if (p == null) {
      await repo.create(
        fullName: fullName.trim(),
        village: village.trim(),
        sex: state.sex,
        ageEstimate: ageEstimate,
        phone: phoneOrNull,
      );
    } else {
      await repo.update(
        p.copyWith(
          fullName: fullName.trim(),
          village: village.trim(),
          sex: Value(state.sex),
          ageEstimate: Value(ageEstimate),
          phone: Value(phoneOrNull),
        ),
      );
    }
    unawaited(ref.read(syncNowProvider)());
  }
}

final registerPatientProvider = NotifierProvider.autoDispose
    .family<RegisterPatientController, RegisterPatientState, Patient?>(
      RegisterPatientController.new,
    );

/// Age is optional; when given it must be whole years, 0 to 130 (the server's limit).
String? validateAge(String? v) {
  final text = v?.trim() ?? '';
  if (text.isEmpty) return null;
  final n = int.tryParse(text);
  return n == null || n < 0 || n > 130
      ? 'Enter the age in whole years (0 to 130)'
      : null;
}
