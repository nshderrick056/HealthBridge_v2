import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Floating dark pill: Home, Patients, Record (lime, in the middle), Alerts, Profile.
/// [current] is null on screens that sit under no tab (the record flow).
class HbBottomNav extends StatelessWidget {
  const HbBottomNav({super.key, required this.current, required this.onTap});

  final int? current;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, 'Home'),
    (Icons.people_outline, 'Patients'),
    (Icons.add, 'Record'),
    (Icons.warning_amber_rounded, 'Alerts'),
    (Icons.person_outline, 'Profile'),
  ];

  static const _inactive = Color(0xFF9AA5A1);

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: HbColors.ink,
          borderRadius: BorderRadius.circular(34),
          boxShadow: HbShadows.card,
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  selected: current == i,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => onTap(i),
                    child: i == 2 ? _record(_items[i]) : _item(i, _items[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _item(int i, (IconData, String) item) {
    final on = current == i;
    final color = on ? HbColors.lime : _inactive;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.$1, size: 22, color: color),
        const SizedBox(height: 3),
        Text(
          item.$2,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HbText.caption.copyWith(
            color: on ? Colors.white : _inactive,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _record((IconData, String) item) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 48,
        height: 34,
        decoration: BoxDecoration(
          color: HbColors.lime,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Icon(item.$1, size: 22, color: HbColors.ink),
      ),
      const SizedBox(height: 2),
      Text(
        item.$2,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HbText.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
