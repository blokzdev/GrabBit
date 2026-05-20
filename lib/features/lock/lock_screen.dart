import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _busy = false;

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
    }
  }

  Future<void> _biometric() async {
    await ref.read(lockControllerProvider.notifier).unlockWithBiometric();
  }

  @override
  Widget build(BuildContext context) {
    final biometric =
        ref.watch(settingsControllerProvider).asData?.value.appLock.biometric ??
        false;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'GrabBit is locked',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submitPin(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submitPin,
                  child: const Text('Unlock'),
                ),
                if (biometric)
                  TextButton.icon(
                    onPressed: _biometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use biometrics'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
