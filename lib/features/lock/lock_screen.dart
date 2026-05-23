import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  String? _error;
  bool _busy = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    final biometric =
        ref.read(settingsControllerProvider).asData?.value.appLock.biometric ??
        false;
    if (biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref
        .read(lockControllerProvider.notifier)
        .unlockWithPin(_pinController.text);
    if (!ok && mounted) {
      setState(() {
        _error = 'Incorrect PIN';
        _busy = false;
      });
      _pinController.clear();
      unawaited(_shake.forward(from: 0));
    }
  }

  Future<void> _biometric() async {
    await ref.read(lockControllerProvider.notifier).unlockWithBiometric();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final biometric =
        ref.watch(settingsControllerProvider).asData?.value.appLock.biometric ??
        false;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceXl),
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                // Damped horizontal shake: a few oscillations that decay to 0.
                final dx =
                    math.sin(_shake.value * math.pi * 4) *
                    12 *
                    (1 - _shake.value);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 36,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: tokens.spaceLg),
                  Text('GrabBit is locked', style: theme.textTheme.titleMedium),
                  SizedBox(height: tokens.spaceXl),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _submitPin(),
                  ),
                  SizedBox(height: tokens.spaceLg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submitPin,
                      child: const Text('Unlock'),
                    ),
                  ),
                  if (biometric) ...[
                    SizedBox(height: tokens.spaceXs),
                    TextButton.icon(
                      onPressed: _biometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use biometrics'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
