import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// Drop-in replacement for [AsyncValue.when] that cross-fades between the
/// loading / error / data widgets instead of swapping them abruptly, so a
/// skeleton dissolves into its content. Keyed on the load phase (not the data),
/// so ordinary data refreshes don't re-trigger the fade.
class AsyncFade<T> extends StatelessWidget {
  const AsyncFade({
    required this.value,
    required this.data,
    required this.loading,
    required this.error,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function() loading;
  final Widget Function(Object error, StackTrace stackTrace) error;

  @override
  Widget build(BuildContext context) {
    final phase = value.isLoading
        ? 0
        : value.hasError
        ? 1
        : 2;
    return AnimatedSwitcher(
      duration: GrabBitTokens.of(context).motionMedium,
      child: KeyedSubtree(
        key: ValueKey(phase),
        child: value.when(data: data, loading: loading, error: error),
      ),
    );
  }
}
