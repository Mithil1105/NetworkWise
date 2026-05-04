import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin/device_admin_provider.dart';
import '../../../core/models/device.dart';
import '../../../core/theme/app_colors.dart';

/// Built-in tag catalogue. Admins can still type free-form tags; these
/// are just the quick-pick chips we surface in the dialog.
const _kSuggestedTags = <String>[
  'Workstation',
  'Laptop',
  'Server',
  'Priority',
  'Finance',
  'Audit',
  'Shared',
];

/// Admin-only dialog for editing a device — friendly label, assignee,
/// location and tags. Archive / un-enroll is a separate action on the
/// detail screen because it needs its own confirm step.
class EditDeviceDialog extends ConsumerStatefulWidget {
  const EditDeviceDialog({super.key, required this.device});

  final Device device;

  static Future<Device?> show(BuildContext context, Device device) {
    return showDialog<Device>(
      context: context,
      builder: (_) => EditDeviceDialog(device: device),
    );
  }

  @override
  ConsumerState<EditDeviceDialog> createState() => _EditDeviceDialogState();
}

class _EditDeviceDialogState extends ConsumerState<EditDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _assignee;
  late final TextEditingController _location;
  late final TextEditingController _tagInput;

  late List<String> _tags;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.device.hostnameLabel);
    _assignee = TextEditingController(text: widget.device.assignedUser);
    _location = TextEditingController(text: widget.device.location);
    _tagInput = TextEditingController();
    _tags = List<String>.from(widget.device.tags);
  }

  @override
  void dispose() {
    _label.dispose();
    _assignee.dispose();
    _location.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    if (_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) return;
    setState(() {
      _tags.add(tag);
      _tagInput.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.removeWhere((t) => t == tag));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(deviceAdminControllerProvider);
      final updated = await controller.updateDevice(
        deviceId: widget.device.id,
        hostnameLabel: _label.text,
        assignedUser: _assignee.text,
        location: _location.text,
        tags: _tags,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_outlined, color: AppColors.seed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit device'),
                Text(
                  widget.device.hostname,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.neutral,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _label,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: 'Display label',
                    helperText:
                        'Shown everywhere in NetworkWise. Leave blank to '
                        'use the Windows hostname (${widget.device.hostname}).',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  maxLength: 64,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _assignee,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Assigned to',
                    helperText: 'Person responsible for this machine.',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 64,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _location,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    helperText: 'City, floor, desk, or site code.',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 80,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tags',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _TagEditor(
                  tags: _tags,
                  onRemove: _busy ? null : _removeTag,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagInput,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    hintText: 'Add a tag and press Enter',
                    prefixIcon: const Icon(Icons.sell_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _busy ? null : () => _addTag(_tagInput.text),
                      tooltip: 'Add tag',
                    ),
                  ),
                  onSubmitted: _addTag,
                ),
                const SizedBox(height: 10),
                _SuggestedTags(
                  existing: _tags,
                  onPick: _busy ? null : _addTag,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 16),
          label: Text(_busy ? 'Saving…' : 'Save changes'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------

class _TagEditor extends StatelessWidget {
  const _TagEditor({required this.tags, this.onRemove});

  final List<String> tags;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No tags yet — use the field below or pick a suggestion.',
          style: TextStyle(fontSize: 11.5, color: AppColors.neutral),
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map(
            (t) => InputChip(
              label: Text(t),
              onDeleted: onRemove == null ? null : () => onRemove!(t),
              deleteIconColor: AppColors.neutral,
              backgroundColor: AppColors.infoBg,
              side: const BorderSide(color: AppColors.divider),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.brandDark,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SuggestedTags extends StatelessWidget {
  const _SuggestedTags({required this.existing, this.onPick});

  final List<String> existing;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final available = _kSuggestedTags
        .where(
          (t) => !existing.any((e) => e.toLowerCase() == t.toLowerCase()),
        )
        .toList(growable: false);
    if (available.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 2),
          child: Text(
            'Quick add:',
            style: TextStyle(fontSize: 11, color: AppColors.neutral),
          ),
        ),
        ...available.map(
          (t) => ActionChip(
            label: Text(t),
            onPressed: onPick == null ? null : () => onPick!(t),
            labelStyle: const TextStyle(fontSize: 11.5),
            side: const BorderSide(color: AppColors.divider),
          ),
        ),
      ],
    );
  }
}
