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
  bool _confirming = false;

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

  bool get _pinLongEnough => _pin.text.length >= _minLength;
  bool get _matches => _pin.text == _confirm.text;

  String? get _confirmError =>
      _confirm.text.isEmpty || _matches ? null : "PINs don't match";

  void _next() {
    if (_pinLongEnough) setState(() => _confirming = true);
  }

  void _back() => setState(() {
    _confirming = false;
    _confirm.clear();
  });

  void _submit() {
    if (_pinLongEnough && _matches) Navigator.of(context).pop(_pin.text);
  }

  @override
  Widget build(BuildContext context) {
    final formatters = [FilteringTextInputFormatter.digitsOnly];
    // Two steps (enter → confirm) so the fields never crowd each other and a
    // typo can't silently lock the user out.
    final field = _confirming
        ? TextField(
            key: const ValueKey('confirm'),
            controller: _confirm,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            inputFormatters: formatters,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Re-enter PIN',
              helperText: 'Type the same PIN again to confirm',
              errorText: _confirmError,
            ),
            onSubmitted: (_) => _submit(),
          )
        : TextField(
            key: const ValueKey('pin'),
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
            onSubmitted: (_) => _next(),
          );

    return AlertDialog(
      title: Text(_confirming ? 'Confirm PIN' : widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [field]),
      actions: _confirming
          ? [
              TextButton(onPressed: _back, child: const Text('Back')),
              FilledButton(
                onPressed: (_pinLongEnough && _matches) ? _submit : null,
                child: const Text('Set'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _pinLongEnough ? _next : null,
                child: const Text('Next'),
              ),
            ],
    );
  }
}
