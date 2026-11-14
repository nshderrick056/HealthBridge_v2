import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../patients/patients_screen.dart';
import '../view_models.dart';

/// Preferences saved on the phone (SharedPreferences) and restored on the next launch.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final settings = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HbColors.surface,
        elevation: 0,
        foregroundColor: HbColors.textPrimary,
        toolbarHeight: 44,
      ),
      body: PageBody(
        children: [
          const PageHeader(title: 'Settings', subtitle: 'Saved on this phone'),
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Text size', style: HbText.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final size in TextSize.values)
                      ChoiceChipPill(
                        label: size.label,
                        selected: s.textSize == size,
                        onTap: () => settings.setTextSize(size),
                      ),
                  ],
                ),
              ],
            ),
          ),
          HbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Default visit type', style: HbText.labelMedium),
                const SizedBox(height: 2),
                Text(
                  'Pre-selected when you start a new visit.',
                  style: HbText.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in VisitType.values)
                      ChoiceChipPill(
                        label: visitTypeLabel(t),
                        selected: s.defaultVisitType == t,
                        onTap: () => settings.setDefaultVisitType(t),
                      ),
                  ],
                ),
              ],
            ),
          ),
          HbCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                value: s.rememberLogin,
                onChanged: settings.setRememberLogin,
                title: Text(
                  'Remember my phone number',
                  style: HbText.labelMedium,
                ),
                subtitle: Text(
                  'Fills in the login screen. Your PIN is never saved.',
                  style: HbText.bodySmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
