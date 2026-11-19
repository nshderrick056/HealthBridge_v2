import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// White, 24 dp, softly shadowed card: one per section, never nested.
class HbCard extends StatelessWidget {
  const HbCard({
    super.key,
    required this.child,
    this.color = HbColors.white,
    this.borderColor,
    this.padding = const EdgeInsets.all(18),
    this.shadow = true,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final Color? borderColor;
  final EdgeInsets padding;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: shadow && color == HbColors.white ? HbShadows.card : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Green gradient card for the one thing to do next (a due visit, the patient header).
class HbGradientCard extends StatelessWidget {
  const HbGradientCard({
    super.key,
    required this.child,
    this.gradient = HbGradients.brand,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum _ButtonKind { primary, secondary, danger, light }

/// 56 dp pill. Primary is dark ink; danger (red) only when the press sends an alert; light is
/// the white pill on green screens.
class HbButton extends StatelessWidget {
  const HbButton.primary(this.label, {super.key, this.icon, this.onPressed})
    : _kind = _ButtonKind.primary;
  const HbButton.secondary(this.label, {super.key, this.icon, this.onPressed})
    : _kind = _ButtonKind.secondary;
  const HbButton.danger(this.label, {super.key, this.icon, this.onPressed})
    : _kind = _ButtonKind.danger;
  const HbButton.light(this.label, {super.key, this.icon, this.onPressed})
    : _kind = _ButtonKind.light;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final _ButtonKind _kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (_kind) {
      _ButtonKind.primary => (HbColors.ink, Colors.white),
      _ButtonKind.secondary => (HbColors.white, HbColors.ink),
      _ButtonKind.danger => (HbColors.red, Colors.white),
      _ButtonKind.light => (HbColors.white, HbColors.ink),
    };
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: bg,
          shape: StadiumBorder(
            side: _kind == _ButtonKind.secondary
                ? const BorderSide(color: HbColors.edge, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: HbText.headingSmall.copyWith(color: fg),
                  ),
                ),
              ],
            ),
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
    this.labelColor = HbColors.ink,
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

  /// White on green screens (sign in).
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: HbText.labelMedium.copyWith(
          color: labelColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        onChanged: onChanged,
        style: HbText.bodyMedium.copyWith(fontSize: 17),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 20, color: HbColors.muted),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 14 : 16,
          ),
        ),
      ),
    ],
  );
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

/// Tinted pill: one word of status, coloured only when it means urgent or due.
class StatusChip extends StatelessWidget {
  const StatusChip(this.kind, {super.key, this.label});

  final StatusKind kind;
  final String? label;

  static (Color, Color, String) style(StatusKind kind) => switch (kind) {
    StatusKind.online => (HbColors.greenTint, HbColors.brand, 'Online'),
    StatusKind.offline => (HbColors.neutralTint, HbColors.muted, 'Offline'),
    StatusKind.pending => (
      HbColors.neutralTint,
      HbColors.muted,
      'Pending sync',
    ),
    StatusKind.synced => (HbColors.greenTint, HbColors.brand, 'Synced'),
    StatusKind.smsSent => (HbColors.greenTint, HbColors.brand, 'SMS sent'),
    StatusKind.stable => (HbColors.greenTint, HbColors.brand, 'Stable'),
    StatusKind.followUp => (
      HbColors.amberTint,
      HbColors.warning,
      'Follow-up due',
    ),
    StatusKind.urgent => (HbColors.redTint, HbColors.red, 'Urgent'),
    StatusKind.attention => (
      HbColors.amberTint,
      HbColors.warning,
      'Needs attention',
    ),
    StatusKind.failed => (HbColors.redTint, HbColors.red, 'Failed'),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, text) = style(kind);
    return HbPill(label ?? text, background: bg, foreground: fg);
  }
}

/// Rounded label with an optional dot or icon, e.g. "Offline · 3 visits not sent yet".
class HbPill extends StatelessWidget {
  const HbPill(
    this.text, {
    super.key,
    this.background = HbColors.white,
    this.foreground = HbColors.ink,
    this.dot,
    this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final Color? dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
        ] else if (dot != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            style: HbText.labelSmall.copyWith(color: foreground),
          ),
        ),
      ],
    ),
  );
}

enum AvatarKind { plain, lime, urgent, due }

/// Initials in a circle; its colour carries the status (red urgent, amber due).
class HbAvatar extends StatelessWidget {
  const HbAvatar(
    this.name, {
    super.key,
    this.kind = AvatarKind.plain,
    this.size = 44,
  });

  final String name;
  final AvatarKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      AvatarKind.plain => (HbColors.tealTint, HbColors.brand),
      AvatarKind.lime => (HbColors.lime, HbColors.ink),
      AvatarKind.urgent => (HbColors.red, Colors.white),
      AvatarKind.due => (const Color(0xFFFBE3A6), HbColors.warning),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: HbText.labelMedium.copyWith(
          color: fg,
          fontSize: size >= 48 ? 18 : 15,
        ),
      ),
    );
  }
}

/// 48 dp white circle with one icon, e.g. back.
class HbCircleButton extends StatelessWidget {
  const HbCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: HbColors.white,
        shape: BoxShape.circle,
        boxShadow: HbShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, size: 22, color: HbColors.ink),
        ),
      ),
    ),
  );
}

/// Round back button with an optional "Step 2 / 3" in the middle.
class HbStepBar extends StatelessWidget {
  const HbStepBar({super.key, this.step, this.onBack});

  final String? step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      HbCircleButton(
        icon: Icons.chevron_left,
        tooltip: 'Back',
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      Expanded(
        child: Text(
          step ?? '',
          textAlign: TextAlign.center,
          style: HbText.bodyMedium.copyWith(
            color: HbColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 48),
    ],
  );
}

/// Selectable white chip; the chosen one gets a dark 2 dp outline.
class HbChoice extends StatelessWidget {
  const HbChoice(
    this.label, {
    super.key,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: HbColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? HbColors.ink : HbColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: HbText.bodyMedium.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
              const SizedBox(height: 4),
              Text(subtitle!, style: HbText.bodySmall),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// Avatar, name and role at the top of a home screen.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      HbAvatar(name, kind: AvatarKind.lime, size: 48),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: HbText.headingSmall),
            Text(role, style: HbText.bodySmall),
          ],
        ),
      ),
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

  /// Kept for older callers; every section heading is now the same weight.
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: Text(title, style: HbText.sectionBold)),
      if (action != null)
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              action!,
              style: HbText.bodyMedium.copyWith(
                color: HbColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
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
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: HbText.bodyMedium.copyWith(color: HbColors.muted)),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: HbText.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? HbColors.ink,
          ),
        ),
      ),
    ],
  );
}

/// A count and what it counts. [icon] and [tint] are kept for older callers; v3 shows the number
/// alone, coloured only when it means urgent or due.
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
  Widget build(BuildContext context) => HbCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: HbText.headingLarge.copyWith(
            color: color == HbColors.red || color == HbColors.warning
                ? color
                : HbColors.ink,
          ),
        ),
        Text(label, style: HbText.bodySmall),
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

AvatarKind avatarFor(StatusKind status) => switch (status) {
  StatusKind.urgent || StatusKind.failed => AvatarKind.urgent,
  StatusKind.followUp || StatusKind.attention => AvatarKind.due,
  _ => AvatarKind.plain,
};

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
    onTap: onTap,
    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
    child: Row(
      children: [
        HbAvatar(name, kind: avatarFor(status)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: HbText.headingSmall),
              const SizedBox(height: 2),
              Text(detail, style: HbText.bodySmall),
              Text('$village · $when', style: HbText.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatusChip(status),
      ],
    ),
  );
}

/// Icon + bold title + secondary text on a tinted card, for confirmations and notices.
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
    shadow: false,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            glyph,
            style: HbText.labelMedium.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HbText.headingSmall),
              const SizedBox(height: 4),
              Text(body, style: HbText.bodyMedium),
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
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: HbText.bodyMedium.copyWith(fontWeight: FontWeight.w500),
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
      const Divider(height: 1, thickness: 1, color: HbColors.line);
}

/// Scrolling page body with 20 dp side padding and a 16 dp rhythm.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
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
