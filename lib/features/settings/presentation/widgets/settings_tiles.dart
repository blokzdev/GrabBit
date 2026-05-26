import 'package:flutter/material.dart';
import 'package:grabbit/features/settings/presentation/widgets/info_hint.dart';

/// A boolean setting row. Wraps [SwitchListTile]; an optional [hint] renders as
/// a tappable [InfoHintButton] in the leading slot.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// Nullable so a tile can be shown disabled (e.g. while a toggle is busy).
  final ValueChanged<bool>? onChanged;
  final InfoHint? hint;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
      secondary: hint == null ? null : InfoHintButton(hint!),
    );
  }
}

/// A single-choice setting row: a label (+ optional subtitle) with a trailing
/// [DropdownButton]. An optional [hint] renders as a leading [InfoHintButton].
/// The null-guard on selection is handled here, so callers pass a plain
/// `ValueChanged<T>`.
class SettingsChoiceTile<T> extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String title;
  final String? subtitle;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;
  final InfoHint? hint;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: hint == null ? null : InfoHintButton(hint!),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: items,
      ),
    );
  }
}

/// A navigation row: a label (+ optional subtitle / leading icon) with a
/// trailing chevron, opening another screen on tap. Used for the P10j
/// sub-screens and existing pushes (`/storage`, `/about`).
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading == null ? null : Icon(leading),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
