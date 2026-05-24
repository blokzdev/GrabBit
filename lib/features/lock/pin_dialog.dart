import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prompts for a new PIN with an enter-then-confirm flow so a typo can't
/// silently lock the user out. Returns the chosen PIN, or null if cancelled.
Future<String?> showPinDialog(
  BuildContext context, {
  String title = 'Set a PIN',
}) => showDialog<String>(
  context: context,
  builder: (_) => _PinDialog(title: title),
);

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});
  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  static const _minLength = 4;

  @override
  void initState() {
    super.initState();
    _pin.addListener(_refresh);
    _confirm.addListener(_refresh);
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _valid =>
      _pin.text.length >= _minLength && _pin.text == _confirm.text;

  String? get _error {
    if (_confirm.text.isEmpty || _pin.text == _confirm.text) return null;
    return "PINs don't match";
  }

  @override
  Widget build(BuildContext context) {
    final formatters = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            inputFormatters: formatters,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'PIN',
              helperText: 'At least $_minLength digits',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show' : 'Hide',
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            inputFormatters: formatters,
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              errorText: _error,
            ),
            onSubmitted: (_) {
              if (_valid) Navigator.of(context).pop(_pin.text);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? () => Navigator.of(context).pop(_pin.text) : null,
          child: const Text('Set'),
        ),
      ],
    );
  }
}
