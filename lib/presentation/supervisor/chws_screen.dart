import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../view_models.dart';
import 'history_screens.dart';
import 'supervisor_controllers.dart';

/// The health centre's CHWs: when each last synced, and SMS-only cases waiting for the full record.
class ChwsScreen extends ConsumerWidget {
  const ChwsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chws = ref.watch(chwsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(chwsProvider.future),
      child: PageBody(
        children: [
          const PageHeader(
            title: 'Community health workers',
            subtitle: 'Pull down to refresh',
          ),
          ...chws.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              Text(
                'Could not load the CHWs. Check your connection.',
                style: HbText.bodyMedium.copyWith(color: HbColors.red),
              ),
            ],
            data: (list) => [
              if (list.isEmpty)
                HbCard(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    'No CHWs at this centre yet.',
                    style: HbText.bodyMedium.copyWith(color: HbColors.muted),
                  ),
                )
              else
                HbCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, c) in list.indexed) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: HbDivider(),
                          ),
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChwHistoryScreen(chwId: c.id),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HbAvatar(
                                  c.name,
                                  kind: c.pendingCount > 0
                                      ? AvatarKind.due
                                      : AvatarKind.plain,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: HbText.headingSmall),
                                      Text(
                                        [
                                          if (c.chwRole != null)
                                            c.chwRole!.toUpperCase(),
                                          if (c.village != null) c.village!,
                                          if (c.phone != null) c.phone!,
                                        ].join(' · '),
                                        style: HbText.bodySmall,
                                      ),
                                      Text(
                                        c.lastSyncAt == null
                                            ? 'Has not synced yet'
                                            : 'Last sync ${relativeDay(c.lastSyncAt!)} ${clock(c.lastSyncAt!)}',
                                        style: HbText.bodySmall,
                                      ),
                                      if (c.pendingCount > 0)
                                        Text(
                                          '${c.pendingCount} SMS case${c.pendingCount == 1 ? '' : 's'} waiting for the full record',
                                          style: HbText.bodySmall.copyWith(
                                            color: HbColors.warning,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: HbColors.chevron,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
