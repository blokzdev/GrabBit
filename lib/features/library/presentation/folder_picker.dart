import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';

/// A chosen move destination. `id == null` means the library root.
class FolderChoice {
  const FolderChoice(this.id);
  final int? id;
}

/// Shows a destination picker (root + all folders). Returns null if cancelled.
Future<FolderChoice?> pickFolder(BuildContext context, WidgetRef ref) {
  return showDialog<FolderChoice>(
    context: context,
    builder: (context) => const _FolderPickerDialog(),
  );
}

class _FolderPickerDialog extends ConsumerWidget {
  const _FolderPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(allFoldersProvider).asData?.value ?? const [];
    return SimpleDialog(
      title: const Text('Move to'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(const FolderChoice(null)),
          child: const ListTile(
            leading: Icon(Icons.home_outlined),
            title: Text('Library root'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        for (final f in folders)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(FolderChoice(f.id)),
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f.name),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}
