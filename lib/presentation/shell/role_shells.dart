import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../admin/admin_screens.dart';
import '../profile/profile_screen.dart';
import '../supervisor/chws_screen.dart';
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

/// A shell with its own bottom tabs, in the app's colours.
class _RoleShell extends ConsumerWidget {
  const _RoleShell({
    required this.tab,
    required this.pages,
    required this.destinations,
  });

  final NotifierProvider<_TabController, int> tab;
  final List<Widget> pages;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tab);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: HbColors.white,
        indicatorColor: HbColors.tealTint,
        onDestinationSelected: ref.read(tab.notifier).go,
        destinations: destinations,
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
    pages: const [InboxScreen(), ChwsScreen(), ProfileScreen()],
    destinations: const [
      NavigationDestination(icon: Icon(Icons.error_outline), label: 'Alerts'),
      NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'CHWs'),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
    ],
  );
}

/// The system admin: reset requests and new accounts.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) => _RoleShell(
    tab: _adminTab,
    pages: const [ResetRequestsScreen(), NewAccountScreen(), ProfileScreen()],
    destinations: const [
      NavigationDestination(icon: Icon(Icons.lock_reset), label: 'Resets'),
      NavigationDestination(
        icon: Icon(Icons.person_add_alt_outlined),
        label: 'New account',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
    ],
  );
}
