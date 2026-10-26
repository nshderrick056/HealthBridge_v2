import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/widgets/bottom_nav.dart';
import '../alerts/alerts_screen.dart';
import '../home/home_screen.dart';
import '../patients/patients_screen.dart';
import '../profile/profile_screen.dart';
import '../record/record_visit_screen.dart';

final tabIndexProvider = StateProvider<int>((ref) => 0);

/// Bottom navigation for the screens pushed on top of the shell: switches the tab and returns to it.
class SubPageNav extends ConsumerWidget {
  const SubPageNav({super.key, this.current});

  final int? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) => HbBottomNav(
    current: current,
    onTap: (i) {
      if (i == 2) {
        if (current != 2) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RecordVisitScreen()),
          );
        }
        return;
      }
      ref.read(tabIndexProvider.notifier).state = i;
      Navigator.of(context).popUntil((r) => r.isFirst);
    },
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _tabs = <Widget>[
    HomeScreen(),
    PatientsScreen(),
    SizedBox.shrink(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: index, children: _tabs),
      ),
      bottomNavigationBar: HbBottomNav(
        current: index,
        onTap: (i) {
          if (i == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecordVisitScreen(),
              ),
            );
          } else {
            ref.read(tabIndexProvider.notifier).state = i;
          }
        },
      ),
    );
  }
}
