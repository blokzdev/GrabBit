import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/things/curator/priority_types.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';
import 'package:grabbit/features/capture/data/manual_capture.dart';

/// P16b-1 — manual entry: author a schema.org Thing by hand (the first universal
/// "Grab anything" intake). Deterministic and user-initiated, so it asserts
/// straight into the library (ADR-0004) — no model, every device. Generic fields
/// only (type · name · description · url); bespoke per-type forms are P16c.
class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

/// Sentinel dropdown value for a free-typed custom `@type`.
const String _otherType = '__other__';

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _url = TextEditingController();
  final _customType = TextEditingController();

  String _type = kManualNoteType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _customType.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _url.dispose();
    _customType.dispose();
    super.dispose();
  }

  /// The effective schema.org `@type` for the chosen option.
  String get _effectiveType =>
      _type == _otherType ? _customType.text.trim() : _type;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final doc = buildManualThing(
      type: _effectiveType,
      name: _name.text,
      description: _description.text,
      url: _url.text,
    );
    final id = await ref.read(captureCommitServiceProvider).commitThing(doc);
    if (!mounted) return;

    router.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Added to your library'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => router.push('/thing/$id'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final vocab = ref.watch(schemaOrgVocabularyProvider).asData?.value;
    final custom = _customType.text.trim();
    final unknownCustom =
        _type == _otherType &&
        custom.isNotEmpty &&
        vocab != null &&
        !vocab.isKnownType(custom);

    return Scaffold(
      appBar: AppBar(title: const Text('Add manually')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: kManualNoteType,
                  child: Text('Note'),
                ),
                for (final p in kPriorityTypes)
                  DropdownMenuItem(value: p.type, child: Text(p.type)),
                const DropdownMenuItem(
                  value: _otherType,
                  child: Text('Other…'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value ?? kManualNoteType),
            ),
            if (_type == _otherType) ...[
              SizedBox(height: tokens.spaceMd),
              TextFormField(
                controller: _customType,
                decoration: InputDecoration(
                  labelText: 'schema.org type',
                  hintText: 'e.g. Movie, Book, SoftwareApplication',
                  border: const OutlineInputBorder(),
                  helperText: unknownCustom
                      ? "Not a known schema.org type — we'll still save it."
                      : null,
                ),
                validator: (value) =>
                    _type == _otherType &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter a type'
                    : null,
              ),
            ],
            SizedBox(height: tokens.spaceMd),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a name'
                  : null,
            ),
            SizedBox(height: tokens.spaceMd),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 6,
            ),
            SizedBox(height: tokens.spaceMd),
            TextFormField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Link (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            SizedBox(height: tokens.spaceLg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Add to library'),
            ),
          ],
        ),
      ),
    );
  }
}
