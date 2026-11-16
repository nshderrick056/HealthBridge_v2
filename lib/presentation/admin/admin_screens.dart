import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../domain/entities/supervision.dart';
import '../auth/login_controller.dart';
import '../patients/patients_screen.dart';
import '../view_models.dart';

/// Reset requests waiting for the admin; refreshed after each approval.
final resetRequestsProvider = FutureProvider.autoDispose<List<ResetRequest>>(
  (ref) => ref.watch(adminRepositoryProvider).resetRequests(),
);

final centresProvider = FutureProvider.autoDispose<List<HealthCentre>>(
  (ref) => ref.watch(adminRepositoryProvider).centres(),
);

/// Forgot-PIN/password requests. Approving texts the user a one-time code; the admin never sees it.
class ResetRequestsScreen extends ConsumerWidget {
  const ResetRequestsScreen({super.key});

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    ResetRequest r,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRepositoryProvider).approve(r.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Code sent to ${r.name ?? r.phone ?? 'the user'}'),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'sms_failed'
                ? 'The SMS could not be sent. Try again in a moment.'
                : 'Could not approve. Check your connection and try again.',
          ),
        ),
      );
    }
    ref.invalidate(resetRequestsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(resetRequestsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(resetRequestsProvider.future),
      child: PageBody(
        children: [
          const PageHeader(
            title: 'Reset requests',
            subtitle: 'Approving texts the person a one-time code',
          ),
          ...requests.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              Text(
                'Could not load requests. Check your connection.',
                style: HbText.bodySmall.copyWith(color: HbColors.red),
              ),
            ],
            data: (list) => [
              if (list.isEmpty)
                Text('No one is waiting.', style: HbText.bodySmall),
              for (final r in list)
                HbCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name ?? 'Unknown',
                              style: HbText.headingSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                r.role?.toUpperCase() ?? '',
                                r.phone ?? '',
                                if (r.createdAt != null)
                                  '${relativeDay(r.createdAt!)} ${clock(r.createdAt!)}',
                              ].join(' · '),
                              style: HbText.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _approve(context, ref, r),
                        style: FilledButton.styleFrom(
                          backgroundColor: HbColors.teal,
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the new-account form has chosen; the text fields live in the screen.
class NewAccountState {
  const NewAccountState({
    this.role = 'chw',
    this.chwRole = 'asm',
    this.centreId,
    this.busy = false,
  });

  final String role;
  final String chwRole;
  final String? centreId;
  final bool busy;

  NewAccountState copyWith({
    String? role,
    String? chwRole,
    String? centreId,
    bool? busy,
  }) => NewAccountState(
    role: role ?? this.role,
    chwRole: chwRole ?? this.chwRole,
    centreId: centreId ?? this.centreId,
    busy: busy ?? this.busy,
  );
}

class NewAccountController extends Notifier<NewAccountState> {
  @override
  NewAccountState build() => const NewAccountState();

  void setRole(String role) => state = state.copyWith(role: role);
  void setChwRole(String r) => state = state.copyWith(chwRole: r);
  void setCentre(String id) => state = state.copyWith(centreId: id);

  /// Returns null on success, or a message to show.
  Future<String?> create(Map<String, Object?> fields) async {
    state = state.copyWith(busy: true);
    try {
      final smsSent = await ref.read(adminRepositoryProvider).createUser({
        ...fields,
        'role': state.role,
        'healthCenterId': state.centreId,
        if (state.role == 'chw') 'chwRole': state.chwRole,
      });
      return smsSent
          ? null
          : 'Account created, but the SMS with the sign-in details failed. '
                'They can get in with Forgot PIN/password.';
    } on ApiException catch (e) {
      return switch (e.code) {
        'phone_or_email_taken' =>
          'That phone number or email already has an account.',
        'unknown_health_center' => 'Choose a health centre.',
        'invalid_request' => 'Check the fields and try again.',
        _ => 'Could not create the account. Check your connection.',
      };
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }
}

final newAccountProvider =
    NotifierProvider.autoDispose<NewAccountController, NewAccountState>(
      NewAccountController.new,
    );

/// Creates a CHW (phone, optional email) or a supervisor (phone + email). The server texts them a
/// temporary PIN/password, which they replace at first sign-in. Stateful only to own the text controllers.
class NewAccountScreen extends ConsumerStatefulWidget {
  const NewAccountScreen({super.key});

  @override
  ConsumerState<NewAccountScreen> createState() => _NewAccountScreenState();
}

class _NewAccountScreenState extends ConsumerState<NewAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _village = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _phone, _village, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create(NewAccountState s) async {
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final isChw = s.role == 'chw';
    final error = await ref.read(newAccountProvider.notifier).create({
      'fullName': _name.text.trim(),
      'phone': normalizePhone(_phone.text),
      if (isChw) 'village': _village.text.trim(),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
    });
    if (error == null || error.startsWith('Account created')) {
      for (final c in [_name, _phone, _village, _email]) {
        c.clear();
      }
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Account created. Their sign-in details were sent by SMS.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(newAccountProvider);
    final controller = ref.read(newAccountProvider.notifier);
    final centres = ref.watch(centresProvider);
    final isChw = s.role == 'chw';
    return Form(
      key: _form,
      child: PageBody(
        children: [
          const PageHeader(
            title: 'New account',
            subtitle: 'The person gets a temporary PIN or password by SMS and sets their own at first sign-in',
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChipPill(
                label: 'CHW',
                selected: isChw,
                onTap: () => controller.setRole('chw'),
              ),
              ChoiceChipPill(
                label: 'Supervisor',
                selected: !isChw,
                onTap: () => controller.setRole('supervisor'),
              ),
            ],
          ),
          centres.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(
              'Could not load health centres.',
              style: HbText.bodySmall.copyWith(color: HbColors.red),
            ),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: s.centreId,
              decoration: const InputDecoration(labelText: 'Health centre'),
              items: [
                for (final c in list)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => v == null ? null : controller.setCentre(v),
              validator: (v) => v == null ? 'Choose a health centre' : null,
            ),
          ),
          HbTextField(
            label: 'Full name',
            hint: 'Name',
            controller: _name,
            validator: requiredField,
          ),
          HbTextField(
            label: 'Phone number',
            hint: 'e.g. 0788 123 456',
            controller: _phone,
            keyboardType: TextInputType.phone,
            validator: validatePhone,
          ),
          if (isChw) ...[
            Wrap(
              spacing: 8,
              children: [
                ChoiceChipPill(
                  label: 'ASM',
                  selected: s.chwRole == 'asm',
                  onTap: () => controller.setChwRole('asm'),
                ),
                ChoiceChipPill(
                  label: 'Binome',
                  selected: s.chwRole == 'binome',
                  onTap: () => controller.setChwRole('binome'),
                ),
              ],
            ),
            HbTextField(
              label: 'Village',
              hint: 'Village',
              controller: _village,
              validator: requiredField,
            ),
          ],
          HbTextField(
            label: isChw ? 'Email (optional)' : 'Email',
            hint: 'you@example.org',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => isChw && (v == null || v.trim().isEmpty)
                ? null
                : validateEmail(v),
          ),
          HbButton.primary(
            s.busy ? 'Creating...' : 'Create account',
            onPressed: s.busy ? null : () => _create(s),
          ),
        ],
      ),
    );
  }
}

class NewCentreController extends Notifier<bool> {
  @override
  bool build() => false; // busy

  /// Returns null on success, or a message to show.
  Future<String?> create({
    required String name,
    required String district,
    required String sector,
    String? callNumber,
  }) async {
    state = true;
    try {
      await ref
          .read(adminRepositoryProvider)
          .createCentre(
            name: name,
            district: district,
            sector: sector,
            callNumber: callNumber,
          );
      ref.invalidate(centresProvider);
      return null;
    } on ApiException catch (e) {
      return e.code == 'invalid_request'
          ? 'Check the fields and try again.'
          : 'Could not save the health centre. Check your connection.';
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final newCentreProvider =
    NotifierProvider.autoDispose<NewCentreController, bool>(
      NewCentreController.new,
    );

/// The health centres, and a form to add one. Stateful only to own the text controllers.
class CentresScreen extends ConsumerStatefulWidget {
  const CentresScreen({super.key});

  @override
  ConsumerState<CentresScreen> createState() => _CentresScreenState();
}

class _CentresScreenState extends ConsumerState<CentresScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _district = TextEditingController();
  final _sector = TextEditingController();
  final _call = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _district, _sector, _call]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final call = _call.text.trim();
    final error = await ref
        .read(newCentreProvider.notifier)
        .create(
          name: _name.text,
          district: _district.text,
          sector: _sector.text,
          callNumber: call.isEmpty ? null : normalizePhone(call),
        );
    if (error == null) {
      for (final c in [_name, _district, _sector, _call]) {
        c.clear();
      }
    }
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Health centre added')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(newCentreProvider);
    final centres = ref.watch(centresProvider);
    return Form(
      key: _form,
      child: PageBody(
        children: [
          const PageHeader(
            title: 'Health centres',
            subtitle: 'Each account belongs to one',
          ),
          ...centres.when(
            loading: () => [const LinearProgressIndicator()],
            error: (_, _) => [
              Text(
                'Could not load health centres.',
                style: HbText.bodySmall.copyWith(color: HbColors.red),
              ),
            ],
            data: (list) => [
              if (list.isEmpty)
                Text('No health centres yet.', style: HbText.bodySmall),
              for (final c in list)
                HbCard(child: Text(c.name, style: HbText.headingSmall)),
            ],
          ),
          Text('New health centre', style: HbText.headingSmall),
          HbTextField(
            label: 'Name',
            hint: 'e.g. Nyamata Health Centre',
            controller: _name,
            validator: (v) =>
                requiredField(v) ??
                (v!.trim().length < 2 ? 'At least 2 characters' : null),
          ),
          HbTextField(
            label: 'District',
            hint: 'District',
            controller: _district,
            validator: requiredField,
          ),
          HbTextField(
            label: 'Sector',
            hint: 'Sector',
            controller: _sector,
            validator: requiredField,
          ),
          HbTextField(
            label: 'Call number (optional)',
            hint: 'Shown to CHWs for urgent cases',
            controller: _call,
            keyboardType: TextInputType.phone,
            validator: (v) =>
                v == null || v.trim().isEmpty ? null : validatePhone(v),
          ),
          HbButton.primary(
            busy ? 'Saving...' : 'Add health centre',
            onPressed: busy ? null : _create,
          ),
        ],
      ),
    );
  }
}
