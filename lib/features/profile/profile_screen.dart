import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../sync/background_sync.dart';
import '../shell/app_shell.dart';
import '../sync/sync_status_screen.dart';

/// The CHW's own profile tab. Not in Figma; built from its components.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider)?.fullName ?? '';
    return PageBody(
      children: [
        const PageHeader(title: 'Profile', subtitle: 'Your account'),
        HbCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: HbColors.teal,
                child: Text(
                  initials(name),
                  style: HbText.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: HbText.headingSmall),
                    const SizedBox(height: 3),
                    Text('Community Health Worker', style: HbText.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        HbButton.secondary(
          'Sync status',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SyncStatusScreen()),
          ),
        ),
        HbButton.secondary(
          'Log out',
          onPressed: () async {
            await cancelBackgroundSync();
            await ref.read(authServiceProvider).logout();
            ref.read(tabIndexProvider.notifier).state = 0;
            ref.read(sessionProvider.notifier).state = null;
          },
        ),
      ],
    );
  }
}
