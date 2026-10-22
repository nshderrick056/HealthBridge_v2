import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db.dart';
import '../../data/forms/validation.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../patients/patients_screen.dart';
import '../shell/app_shell.dart';
import '../view_models.dart';
import 'review_visit_screen.dart';
import 'visit_form.dart';

class RecordVisitScreen extends ConsumerStatefulWidget {
  const RecordVisitScreen({super.key, this.patientId});

  final String? patientId;

  @override
  ConsumerState<RecordVisitScreen> createState() => _RecordVisitScreenState();
}

class _RecordVisitScreenState extends ConsumerState<RecordVisitScreen> {
  String? _patientId;
  VisitForm? _form;
  List<DangerSign> _signs = const [];
  final _symptoms = TextEditingController();
  final _temperature = TextEditingController();
  final _notes = TextEditingController();
  final _key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
  }

  @override
  void dispose() {
    for (final c in [_symptoms, _temperature, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _draftKey => 'visit.record.$_patientId';

  var _opening = false;

  Future<void> _open(Patient p) async {
    // build() and the picker can both ask; one form per screen.
    if (_opening) return;
    _opening = true;
    final form = VisitForm(patient: p);
    final draft = await ref
        .read(draftsRepositoryProvider)
        .load('visit.record.${p.id}');
    if (draft != null) {
      form.restore(draft); // half-filled forms survive a crash or app switch
    }
    _symptoms.text = form.symptoms;
    _temperature.text = form.temperature?.toString() ?? '';
    _notes.text = form.notes;
    await _loadSigns(form.type);
    if (mounted) setState(() => _form = form);
  }

  Future<void> _loadSigns(VisitType t) async {
    final signs = await ref.read(dangerSignsRepositoryProvider).forType(t);
    if (mounted) setState(() => _signs = signs);
  }

  void _save() {
    final f = _form!;
    f.symptoms = _symptoms.text;
    f.temperature = double.tryParse(_temperature.text.trim());
    f.notes = _notes.text;
    ref.read(draftsRepositoryProvider).save(_draftKey, f.toDraft());
  }

  void _review() {
    if (!_key.currentState!.validate()) return;
    _save();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewVisitScreen(form: _form!, draftKey: _draftKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(allPatientsProvider).value ?? const [];
    final visits = ref.watch(allVisitsProvider).value ?? const <Visit>[];
    final online = ref.watch(isOnlineProvider);
    final id = _patientId;
    if (id != null && _form == null) {
      final p = patients.where((p) => p.id == id);
      if (p.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(p.first));
      }
    }
    final form = _form;

    return Scaffold(
      bottomNavigationBar: const SubPageNav(current: 2),
      body: form == null
          ? _picker(patients, visits, online)
          : _formBody(form, visits, online),
    );
  }

  // Same status as every other screen, from the patient's own visits.
  PatientView _view(Patient p, List<Visit> visits) =>
      PatientView(p, visits.where((v) => v.patientId == p.id).toList());

  Widget _picker(List<Patient> patients, List<Visit> visits, bool online) =>
      PageBody(
        children: [
          PageHeader(
            title: 'Record visit',
            subtitle: 'Choose the patient',
            trailing: StatusChip(
              online ? StatusKind.online : StatusKind.offline,
            ),
          ),
          if (patients.isEmpty)
            Text('Register a patient first.', style: HbText.bodySmall),
          for (final p in patients)
            PatientCard(
              name: p.fullName,
              detail: p.shortId,
              status: _view(p, visits).status,
              village: p.village,
              when: 'Select',
              onTap: () {
                setState(() => _patientId = p.id);
                _open(p);
              },
            ),
        ],
      );

  Widget _formBody(VisitForm f, List<Visit> visits, bool online) {
    final view = _view(f.patient, visits);
    return Form(
      key: _key,
      onChanged: _save,
      child: PageBody(
        children: [
          PageHeader(
            title: 'Record visit',
            subtitle: 'Add a field visit',
            trailing: StatusChip(
              online ? StatusKind.online : StatusKind.offline,
            ),
          ),
          PatientCard(
            name: f.patient.fullName,
            detail: view.ageSex.isEmpty ? f.patient.shortId : view.ageSex,
            status: view.status,
            village: f.patient.village,
            when: 'Selected',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading('Visit type'),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final t in VisitType.values)
                    ChoiceChipPill(
                      label: visitTypeLabel(t),
                      selected: f.type == t,
                      onTap: () {
                        setState(() {
                          f.type = t;
                          f.signs.clear();
                        });
                        _loadSigns(t);
                        _save();
                      },
                    ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Visit date', style: HbText.labelMedium),
              const SizedBox(height: 7),
              HbCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 19,
                      color: HbColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${fullDate(DateTime.now())} (today)',
                      style: HbText.bodyMedium.copyWith(
                        color: HbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          HbTextField(
            label: 'Symptoms / observations',
            hint: 'What did you observe?',
            controller: _symptoms,
            maxLines: 3,
          ),
          HbCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Basic measurements / assessment',
                  style: HbText.labelMedium,
                ),
                const SizedBox(height: 7),
                HbTextField(
                  label: 'Temperature (\u00B0C)',
                  hint: 'e.g. 37.2',
                  controller: _temperature,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? null
                      : temperatureC.check(double.tryParse(v.trim())),
                ),
                const SizedBox(height: 10),
                Text('General condition', style: HbText.labelMedium),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  children: [
                    for (final c in const ['Stable', needsAttention])
                      ChoiceChipPill(
                        label: c,
                        selected: f.condition == c,
                        onTap: () => setState(() {
                          f.condition = c;
                          _save();
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_signs.isNotEmpty)
            HbCard(
              color: f.signs.isEmpty ? HbColors.white : HbColors.redTint,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Danger signs', style: HbText.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Tick any that apply. Any danger sign makes this visit urgent.',
                    style: HbText.bodySmall,
                  ),
                  for (final s in _signs)
                    Material(
                      type: MaterialType.transparency,
                      child: CheckboxListTile(
                        dense: false,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(s.labelEn, style: HbText.bodyMedium),
                        value: f.signs.contains(s.code),
                        onChanged: (v) => setState(() {
                          v == true
                              ? f.signs.add(s.code)
                              : f.signs.remove(s.code);
                          _save();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          HbTextField(
            label: 'Notes',
            hint: 'Anything else to record',
            controller: _notes,
            maxLines: 3,
          ),
          HbButton.primary(
            'Review visit',
            icon: Icons.add_circle_outline,
            onPressed: _review,
          ),
        ],
      ),
    );
  }
}
