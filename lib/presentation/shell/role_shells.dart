import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/bottom_nav.dart';
import '../admin/admin_screens.dart';
import '../profile/profile_screen.dart';
import '../supervisor/chws_screen.dart';
import '../supervisor/history_screens.dart';
import '../supervisor/inbox_screen.dart';

/// Tab index for the supervisor and admin shells (each starts on its first tab).
class _TabController extends Notifier<int> {
  @override
  int build() => 0;

  void go(int i) => state = i;
}

final _supervisorTab = NotifierProvider<_TabController, int>(
  _TabController.new,
);
final _adminTab = NotifierProvider<_TabController, int>(_TabController.new);

/// A shell with its own tabs in the floating dark pill.
class _RoleShell extends ConsumerWidget {
  const _RoleShell({
    required this.tab,
    required this.pages,
    required this.items,
  });

  final NotifierProvider<_TabController, int> tab;
  final List<Widget> pages;
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tab);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: HbPillNav(
        items: items,
        current: index,
        onTap: ref.read(tab.notifier).go,
      ),
    );
  }
}

/// Supervisors: their health centre's urgent alerts and CHWs.
class SupervisorShell extends StatelessWidget {
  const SupervisorShell({super.key});

  @override
  Widget build(BuildContext context) => _RoleShell(
    tab: _supervisorTab,
    pages: const [
      InboxScreen(),
      ChwsScreen(),
      SupervisorPatientsScreen(),
      ProfileScreen(),
    ],
    items: const [
      (Icons.warning_amber_rounded, 'Alerts'),
      (Icons.groups_outlined, 'CHWs'),
      (Icons.folder_shared_outlined, 'Patients'),
      (Icons.person_outline, 'Profile'),
    ],
  );
}

/// The system admin: reset requests, new accounts and health centres.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) => _RoleShell(
    tab: _adminTab,
    pages: const [
      ResetRequestsScreen(),
      NewAccountScreen(),
      CentresScreen(),
      ProfileScreen(),
    ],
    items: const [
      (Icons.lock_reset, 'Resets'),
      (Icons.person_add_alt_outlined, 'New account'),
      (Icons.local_hospital_outlined, 'Centres'),
      (Icons.person_outline, 'Profile'),
    ],
  );
}
