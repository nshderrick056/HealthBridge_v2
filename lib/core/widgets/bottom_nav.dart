import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Home, Patients, Record Visit (raised), Alerts, Profile. [current] is null on screens that sit
/// under no tab (the record flow).
class HbBottomNav extends StatelessWidget {
  const HbBottomNav({super.key, required this.current, required this.onTap});

  final int? current;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, 'Home'),
    (Icons.person_outline, 'Patients'),
    (Icons.add_circle_outline, 'Record Visit'),
    (Icons.error_outline, 'Alerts'),
    (Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.all(8),
    decoration: const BoxDecoration(
      color: HbColors.white,
      border: Border(top: BorderSide(color: HbColors.border)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < _items.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: i == 2 ? _record(_items[i]) : _item(i, _items[i]),
            ),
          ),
      ],
    ),
  );

  Widget _item(int i, (IconData, String) item) {
    final on = current == i;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: on ? HbColors.tealTint : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            item.$1,
            size: 19,
            color: on ? HbColors.teal : HbColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          item.$2,
          style: HbText.caption.copyWith(
            color: on ? HbColors.teal : HbColors.textSecondary,
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
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: HbColors.teal,
          shape: BoxShape.circle,
        ),
        child: Icon(item.$1, size: 20, color: Colors.white),
      ),
      const SizedBox(height: 3),
      Text(
        item.$2,
        style: HbText.caption.copyWith(
          fontSize: 9,
          color: HbColors.teal,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
