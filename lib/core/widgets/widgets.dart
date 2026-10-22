import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// White, bordered, 12 dp card used for every grouped block in the design.
class HbCard extends StatelessWidget {
  const HbCard({
    super.key,
    required this.child,
    this.color = HbColors.white,
    this.borderColor = HbColors.border,
    this.padding = const EdgeInsets.all(14),
    this.shadow = false,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsets padding;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x12123D35),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    );
    return onTap == null
        ? box
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: box,
          );
  }
}

class HbButton extends StatelessWidget {
  const HbButton.primary(this.label, {super.key, this.icon, this.onPressed})
    : primary = true;
  const HbButton.secondary(this.label, {super.key, this.icon, this.onPressed})
    : primary = false;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : HbColors.teal;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: primary ? HbColors.teal : HbColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: primary ? HbColors.teal : HbColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 10),
              ],
              Text(label, style: HbText.headingSmall.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class HbTextField extends StatelessWidget {
  const HbTextField({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final String hint;
  final IconData? icon;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HbText.labelMedium),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          onChanged: onChanged,
          style: HbText.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: HbText.bodyMedium.copyWith(
              color: HbColors.textSecondary,
            ),
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 19, color: HbColors.textSecondary),
            filled: true,
            fillColor: HbColors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 14 : 16,
            ),
            enabledBorder: border(HbColors.border),
            focusedBorder: border(HbColors.teal),
            errorBorder: border(HbColors.red),
            focusedErrorBorder: border(HbColors.red),
          ),
        ),
      ],
    );
  }
}

enum StatusKind {
  online,
  offline,
  followUp,
  urgent,
  attention,
  stable,
  synced,
  pending,
  failed,
  smsSent,
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.kind, {super.key, this.label});

  final StatusKind kind;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, text, icon) = switch (kind) {
      StatusKind.online => (
        HbColors.greenTint,
        HbColors.green,
        'Online',
        Icons.wifi,
      ),
      StatusKind.offline => (
        HbColors.neutralTint,
        HbColors.textSecondary,
        'Offline',
        Icons.cancel_outlined,
      ),
      StatusKind.pending => (
        HbColors.neutralTint,
        HbColors.textSecondary,
        'Pending sync',
        Icons.cancel_outlined,
      ),
      StatusKind.synced => (
        HbColors.greenTint,
        HbColors.green,
        'Synced',
        Icons.wifi,
      ),
      StatusKind.smsSent => (
        HbColors.greenTint,
        HbColors.green,
        'SMS sent',
        Icons.check,
      ),
      StatusKind.stable => (HbColors.greenTint, HbColors.green, 'Stable', null),
      StatusKind.followUp => (
        HbColors.amberTint,
        HbColors.warning,
        'Follow-up due',
        null,
      ),
      StatusKind.urgent => (HbColors.redTint, HbColors.red, 'Urgent', null),
      StatusKind.attention => (
        HbColors.amberTint,
        HbColors.warning,
        'Needs attention',
        null,
      ),
      StatusKind.failed => (HbColors.redTint, HbColors.red, 'Failed', null),
    };
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: fg)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(label ?? text, style: HbText.labelSmall.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: HbText.headingLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: HbText.bodySmall.copyWith(height: 1.4)),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.bold = false,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: bold ? HbText.sectionBold : HbText.labelMedium),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(
            action!,
            style: HbText.labelSmall.copyWith(color: HbColors.teal),
          ),
        ),
    ],
  );
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: HbText.bodySmall),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: HbText.labelMedium.copyWith(
            color: valueColor ?? HbColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.icon,
    required this.tint,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    // A floor, not a fixed height: fallback fonts and large system text sizes need more room.
    constraints: const BoxConstraints(minHeight: 100),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: HbColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: HbColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 8,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: HbText.headingLarge),
            Text(
              label,
              style: HbText.bodySmall.copyWith(fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ],
    ),
  );
}

/// A row of [SummaryCard]s that all take the height of the tallest one.
class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class PatientCard extends StatelessWidget {
  const PatientCard({
    super.key,
    required this.name,
    required this.detail,
    required this.status,
    required this.village,
    required this.when,
    this.onTap,
  });

  final String name;
  final String detail;
  final StatusKind status;
  final String village;
  final String when;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => HbCard(
    shadow: true,
    onTap: onTap,
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: HbText.headingSmall),
                  const SizedBox(height: 3),
                  Text(detail, style: HbText.bodySmall),
                ],
              ),
            ),
            StatusChip(status),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 13,
                  color: HbColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(village, style: HbText.bodySmall),
              ],
            ),
            Text(when, style: HbText.bodySmall),
          ],
        ),
      ],
    ),
  );
}

/// Round icon + bold title + secondary text, used for the confirmation and urgent notices.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.color,
    required this.tint,
    required this.glyph,
    required this.title,
    required this.body,
  });

  final Color color;
  final Color tint;
  final String glyph;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => HbCard(
    color: tint,
    borderColor: color == HbColors.green ? HbColors.border : color,
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            glyph,
            style: HbText.headingMedium.copyWith(
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
              Text(title, style: HbText.headingSmall),
              const SizedBox(height: 3),
              Text(body, style: HbText.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class BulletLine extends StatelessWidget {
  const BulletLine(this.text, this.color, {super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: HbText.bodySmall.copyWith(color: HbColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

class HbDivider extends StatelessWidget {
  const HbDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: HbColors.divider);
}

/// Scrolling page body with the design's 18 dp side padding and 12 dp rhythm.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => children[i],
    ),
  );
}

String initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
      .toUpperCase();
}
