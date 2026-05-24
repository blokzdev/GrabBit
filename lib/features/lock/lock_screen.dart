import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/duration_format.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/lock/lockout_policy.dart';
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
  bool _obscure = true;
  Duration _lockout = Duration.zero;
  Timer? _ticker;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: GrabBitTokens.standard.motionLong,
  );

  @override
  void initState() {
    super.initState();
    _refreshLockout();
    final biometric =
        ref.read(settingsControllerProvider).asData?.value.appLock.biometric ??
        false;
    if (biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pinController.dispose();
    _shake.dispose();
    super.dispose();
  }

  /// Reads the remaining cooldown and, while it's active, ticks every second to
  /// update the countdown and re-enable input when it elapses.
  Future<void> _refreshLockout() async {
    final remaining = await ref.read(lockoutPolicyProvider).remaining();
    if (!mounted) return;
    setState(() => _lockout = remaining);
    _ticker?.cancel();
    if (remaining > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final next = _lockout - const Duration(seconds: 1);
        if (!mounted) return;
        setState(() => _lockout = next > Duration.zero ? next : Duration.zero);
        if (next <= Duration.zero) _ticker?.cancel();
      });
    }
  }

  bool get _lockedOut => _lockout > Duration.zero;

  Future<void> _submitPin() async {
    if (_lockedOut) return;
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
      unawaited(HapticFeedback.heavyImpact());
      unawaited(_shake.forward(from: 0));
      await _refreshLockout();
    }
  }

  Future<void> _biometric() async {
    if (_lockedOut) return;
    final ok = await ref
        .read(lockControllerProvider.notifier)
        .unlockWithBiometric();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Biometric unlock failed')),
        );
    }
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
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !_lockedOut,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      errorText: _lockedOut
                          ? 'Too many attempts. Try again in '
                                '${formatDuration(_lockout.inSeconds)}'
                          : _error,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show' : 'Hide',
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submitPin(),
                  ),
                  SizedBox(height: tokens.spaceLg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_busy || _lockedOut) ? null : _submitPin,
                      child: const Text('Unlock'),
                    ),
                  ),
                  if (biometric) ...[
                    SizedBox(height: tokens.spaceXs),
                    TextButton.icon(
                      onPressed: _lockedOut ? null : _biometric,
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
