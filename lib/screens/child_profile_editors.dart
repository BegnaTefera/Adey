import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/document_storage.dart';
import '../models/child.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';

/// Bottom-sheet editors for a child's profile. Each returns the edited
/// object (or null when cancelled). They never touch the database — the
/// calling screen persists through ChildrenStore.updateChild, so all the
/// sync/error handling stays in one place.

// ---------------------------------------------------------------------
// Child details (name, gender, dob, allergies, health, diet, notes)
// ---------------------------------------------------------------------

Future<Child?> showEditChildSheet(BuildContext context, Child child) {
  return showModalBottomSheet<Child>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditChildSheet(child: child),
  );
}

class _EditChildSheet extends StatefulWidget {
  final Child child;
  const _EditChildSheet({required this.child});

  @override
  State<_EditChildSheet> createState() => _EditChildSheetState();
}

class _EditChildSheetState extends State<_EditChildSheet> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _allergies;
  late final TextEditingController _health;
  late final TextEditingController _diet;
  late final TextEditingController _special;
  late Gender _gender;
  DateTime? _dob;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.child;
    _first = TextEditingController(text: c.firstName);
    _last = TextEditingController(text: c.lastName);
    _allergies = TextEditingController(text: c.allergies.join(', '));
    _health = TextEditingController(text: c.healthCondition);
    _diet = TextEditingController(text: c.dietaryNotes);
    _special = TextEditingController(text: c.specialCharacteristics);
    _gender = c.gender;
    _dob = c.dob;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _allergies.dispose();
    _health.dispose();
    _diet.dispose();
    _special.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _save() {
    final first = _first.text.trim();
    final last = _last.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _error = 'First and last name are required.');
      return;
    }
    if (_dob == null) {
      setState(() => _error = 'Pick a date of birth.');
      return;
    }
    final allergies = _allergies.text
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      widget.child.copyWith(
        firstName: first,
        lastName: last,
        gender: _gender,
        dob: _dob,
        allergies: allergies,
        healthCondition: _health.text.trim(),
        dietaryNotes: _diet.text.trim(),
        specialCharacteristics: _special.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Edit child details',
      onSave: _save,
      error: _error,
      children: [
        TextField(
          controller: _first,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'First name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _last,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Last name'),
        ),
        const SizedBox(height: 12),
        _ChoiceRow<Gender>(
          label: 'Gender',
          value: _gender,
          items: const [
            (Gender.male, 'Male'),
            (Gender.female, 'Female'),
          ],
          onChanged: (g) => setState(() => _gender = g),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDob,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date of birth'),
            child: Text(
              _dob == null
                  ? 'Select a date'
                  : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
              style: AppText.bodyRegular,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _allergies,
          decoration: const InputDecoration(
            labelText: 'Allergies',
            helperText: 'Separate multiple with commas',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _health,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Health condition'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _diet,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Dietary notes'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _special,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Special characteristics'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Guardian
// ---------------------------------------------------------------------

Future<Guardian?> showGuardianEditorSheet(
  BuildContext context, {
  Guardian? guardian,
}) {
  return showModalBottomSheet<Guardian>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GuardianEditorSheet(guardian: guardian),
  );
}

class _GuardianEditorSheet extends StatefulWidget {
  final Guardian? guardian;
  const _GuardianEditorSheet({this.guardian});

  @override
  State<_GuardianEditorSheet> createState() => _GuardianEditorSheetState();
}

class _GuardianEditorSheetState extends State<_GuardianEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _relationship;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _subCity;
  late final TextEditingController _woreda;
  late final TextEditingController _house;
  late bool _isPrimary;
  late bool _authorizedPickup;
  String? _error;

  bool get _isNew => widget.guardian == null;

  @override
  void initState() {
    super.initState();
    final g = widget.guardian;
    _name = TextEditingController(text: g?.name ?? '');
    _relationship = TextEditingController(text: g?.relationship ?? '');
    _phone = TextEditingController(text: g?.phone ?? '');
    _email = TextEditingController(text: g?.email ?? '');
    _subCity = TextEditingController(text: g?.subCity ?? '');
    _woreda = TextEditingController(text: g?.woreda ?? '');
    _house = TextEditingController(text: g?.houseNumber ?? '');
    _isPrimary = g?.isPrimary ?? false;
    _authorizedPickup = g?.authorizedPickup ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone.dispose();
    _email.dispose();
    _subCity.dispose();
    _woreda.dispose();
    _house.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final relationship = _relationship.text.trim();
    if (name.isEmpty || relationship.isEmpty) {
      setState(() => _error = 'Name and relationship are required.');
      return;
    }
    final base = widget.guardian ??
        Guardian(
          id: const Uuid().v4(),
          name: '',
          relationship: '',
          phone: '',
          email: '',
          isPrimary: false,
          authorizedPickup: true,
        );
    Navigator.of(context).pop(
      base.copyWith(
        name: name,
        relationship: relationship,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        subCity: _subCity.text.trim(),
        woreda: _woreda.text.trim(),
        houseNumber: _house.text.trim(),
        isPrimary: _isPrimary,
        authorizedPickup: _authorizedPickup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: _isNew ? 'Add guardian' : 'Edit guardian',
      onSave: _save,
      error: _error,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _relationship,
          decoration: const InputDecoration(
            labelText: 'Relationship',
            hintText: 'Mother, Father, Grandparent…',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subCity,
          decoration: const InputDecoration(labelText: 'Sub-city'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _woreda,
          decoration: const InputDecoration(labelText: 'Woreda'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _house,
          decoration: const InputDecoration(labelText: 'House number'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Primary contact', style: AppText.bodyRegular),
          value: _isPrimary,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _isPrimary = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Authorized to pick up', style: AppText.bodyRegular),
          value: _authorizedPickup,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _authorizedPickup = v),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Document (immunization records, IDs, photos…)
// ---------------------------------------------------------------------

Future<ChildDocument?> showDocumentEditorSheet(
  BuildContext context, {
  ChildDocument? document,
}) {
  return showModalBottomSheet<ChildDocument>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DocumentEditorSheet(document: document),
  );
}

class _DocumentEditorSheet extends StatefulWidget {
  final ChildDocument? document;
  const _DocumentEditorSheet({this.document});

  @override
  State<_DocumentEditorSheet> createState() => _DocumentEditorSheetState();
}

class _DocumentEditorSheetState extends State<_DocumentEditorSheet> {
  late final TextEditingController _label;
  late DocumentType _type;
  late DocumentStatus _status;
  String? _filePath;
  String? _sha256;
  bool _capturing = false;
  String? _error;

  bool get _isNew => widget.document == null;

  @override
  void initState() {
    super.initState();
    final d = widget.document;
    _label = TextEditingController(text: d?.label ?? '');
    _type = d?.type ?? DocumentType.immunization;
    _status = d?.status ?? DocumentStatus.onFile;
    _filePath = d?.filePath;
    _sha256 = d?.sha256;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      final bytes = await _pickImageBytes(context);
      if (bytes == null) return;
      final (path, hash) = await DocumentStorage.save(bytes: bytes);
      if (!mounted) return;
      setState(() {
        _filePath = path;
        _sha256 = hash;
        if (_status == DocumentStatus.pending) {
          _status = DocumentStatus.onFile;
        }
      });
    } catch (e) {
      if (mounted) {
        showAppFeedback(
          context,
          message: 'Could not save that file. $e',
          kind: AppFeedbackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _save() {
    final hasFile = _filePath != null && _filePath!.isNotEmpty;
    final base = widget.document;
    if (base == null) {
      final label = _label.text.trim();
      if (label.isEmpty) {
        setState(() => _error = 'Give the document a name.');
        return;
      }
      Navigator.of(context).pop(
        ChildDocument(
          id: const Uuid().v4(),
          label: label,
          type: _type,
          uploadedAt: DateTime.now(),
          status: hasFile
              ? _status
              : (_status == DocumentStatus.onFile
                  ? DocumentStatus.pending
                  : _status),
          filePath: _filePath,
          sha256: _sha256,
          printed: true,
        ),
      );
      return;
    }
    // Editing only replaces the attached file — the name, type and status
    // were fixed when the document was created.
    Navigator.of(context).pop(
      ChildDocument(
        id: base.id,
        label: base.label,
        type: base.type,
        uploadedAt: base.uploadedAt,
        status: hasFile ? DocumentStatus.onFile : base.status,
        filePath: _filePath,
        sha256: _sha256,
        printed: base.printed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _filePath != null && _filePath!.isNotEmpty;
    const typeItems = <(DocumentType, String)>[
      (DocumentType.id, 'ID'),
      (DocumentType.photo, 'Photo'),
      (DocumentType.registration, 'Registration form'),
      (DocumentType.other, 'Other'),
    ];
    return _SheetScaffold(
      title: _isNew ? 'Add document' : 'Edit document',
      onSave: _save,
      error: _error,
      children: [
        if (_isNew) ...[
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Document name'),
          ),
          const SizedBox(height: 12),
          _ChoiceRow<DocumentType>(
            label: 'Type',
            value: _type,
            items: typeItems,
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: 12),
          _ChoiceRow<DocumentStatus>(
            label: 'Status',
            value: _status,
            items: const [
              (DocumentStatus.onFile, 'On file'),
              (DocumentStatus.pending, 'Pending'),
              (DocumentStatus.expired, 'Expired'),
            ],
            onChanged: (s) => setState(() => _status = s),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.document!.label, style: AppText.bodyRegular),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                hasFile ? Icons.check_circle_outline : Icons.upload_file_outlined,
                color: hasFile ? AppColors.sync : AppColors.mutedForeground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasFile ? 'File attached' : 'No file attached yet',
                  style: AppText.bodyRegular,
                ),
              ),
              TextButton(
                onPressed: _capturing ? null : _capture,
                child: Text(_capturing
                    ? 'Saving…'
                    : hasFile
                        ? 'Replace'
                        : 'Attach'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------

/// Outcome of the payment editor: either a saved record, or a request to
/// remove the existing one. Keeps the destructive action inside the editor
/// instead of cluttering every list row with a delete button.
class PaymentEditResult {
  final PaymentRecord? payment;
  final bool deleteRequested;

  const PaymentEditResult.saved(PaymentRecord this.payment)
      : deleteRequested = false;

  const PaymentEditResult.delete()
      : payment = null,
        deleteRequested = true;
}

Future<PaymentEditResult?> showPaymentEditorSheet(
  BuildContext context, {
  PaymentRecord? payment,
}) {
  return showModalBottomSheet<PaymentEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaymentEditorSheet(payment: payment),
  );
}

class _PaymentEditorSheet extends StatefulWidget {
  final PaymentRecord? payment;
  const _PaymentEditorSheet({this.payment});

  @override
  State<_PaymentEditorSheet> createState() => _PaymentEditorSheetState();
}

class _PaymentEditorSheetState extends State<_PaymentEditorSheet> {
  late final TextEditingController _feeName;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late PaymentStatus _status;
  DateTime _dueDate = DateTime.now();
  String? _error;

  bool get _isNew => widget.payment == null;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _feeName = TextEditingController(text: p?.feeTypeName ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _amount = TextEditingController(
      text: p == null ? '' : (p.amount == p.amount.roundToDouble()
          ? p.amount.toStringAsFixed(0)
          : p.amount.toString()),
    );
    _status = p?.status ?? PaymentStatus.paid;
    _dueDate = p?.dueDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _feeName.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    final feeName = _feeName.text.trim();
    final description = _description.text.trim();
    if (feeName.isEmpty && description.isEmpty) {
      setState(() => _error = 'Give the payment a fee name or description.');
      return;
    }
    final base = widget.payment;
    final paidNow = _status == PaymentStatus.paid;
    Navigator.of(context).pop(
      PaymentEditResult.saved(
        PaymentRecord(
          id: base?.id ?? const Uuid().v4(),
          feeTypeName: feeName.isEmpty ? description : feeName,
          description: description.isEmpty ? feeName : description,
          amount: amount,
          status: _status,
          dueDate: _dueDate,
          paidAt: paidNow ? (base?.paidAt ?? DateTime.now()) : null,
          cycleLabel: base?.cycleLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: _isNew ? 'Log payment' : 'Edit payment',
      onSave: _save,
      error: _error,
      onDelete: _isNew
          ? null
          : () => Navigator.of(context).pop(const PaymentEditResult.delete()),
      deleteLabel: 'Delete payment',
      children: [
        TextField(
          controller: _feeName,
          decoration: const InputDecoration(labelText: 'Fee name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Bank reference or receipt note',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (ETB)'),
        ),
        const SizedBox(height: 12),
        _ChoiceRow<PaymentStatus>(
          label: 'Status',
          value: _status,
          items: const [
            (PaymentStatus.paid, 'Paid'),
            (PaymentStatus.pending, 'Pending'),
            (PaymentStatus.cancelled, 'Cancelled'),
          ],
          onChanged: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDueDate,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Due date'),
            child: Text(
              '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}',
              style: AppText.bodyRegular,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------

class _SheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final String? error;
  final VoidCallback? onDelete;
  final String deleteLabel;

  const _SheetScaffold({
    required this.title,
    required this.children,
    required this.onSave,
    this.error,
    this.onDelete,
    this.deleteLabel = 'Delete',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.sectionTitle),
            const SizedBox(height: 16),
            ...children,
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: AppText.caption.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(deleteLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final (itemValue, itemLabel) in items)
          DropdownMenuItem(value: itemValue, child: Text(itemLabel)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Picks an image and returns its bytes. Desktop opens a file chooser; on
/// mobile the user chooses camera or gallery.
Future<Uint8List?> _pickImageBytes(BuildContext context) async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final path = files.isNotEmpty ? files.single.path : null;
    if (path == null) return null;
    return File(path).readAsBytes();
  }

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final file = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1600,
  );
  if (file == null) return null;
  return file.readAsBytes();
}
