import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/children_store.dart';
import '../data/document_storage.dart';
import '../data/formatters.dart';
import '../data/registration_pdf.dart';
import '../data/settings_store.dart';
import '../models/child.dart';
import '../models/authorized_pickup.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/immunization_gallery.dart';

const _agreementText = registrationAgreementText;

const _guardianRelationships = [
  'Mother',
  'Father',
  'Grandparent',
  'Legal guardian',
  'Aunt',
  'Uncle',
  'Sibling',
  'Other',
];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  bool _isSubmitting = false;

  // Child
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  Gender? _gender;
  DateTime? _dob;
  final _allergiesController = TextEditingController();
  final _healthController = TextEditingController();
  final _dietController = TextEditingController();
  final _specialController = TextEditingController();

  // Guardian
  final _guardianNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _subCityController = TextEditingController();
  final _woredaController = TextEditingController();
  final _houseNumberController = TextEditingController();
  String? _guardianRelationship;
  bool _hasSecondGuardian = false;
  final _secondGuardianNameController = TextEditingController();
  final _secondRelationshipController = TextEditingController();
  final _secondPhoneController = TextEditingController();
  final _secondEmailController = TextEditingController();
  final _secondSubCityController = TextEditingController();
  final _secondWoredaController = TextEditingController();
  final _secondHouseNumberController = TextEditingController();

  // Captured documents (local file paths, before being copied into
  // permanent storage at submission time)
  String? _guardianIdImagePath;
  String? _parentPhotoPath;
  String? _childPhotoPath;
  final List<String> _immunizationPagePaths = [];

  // Pickup
  final _pickupNameController = TextEditingController();
  final _pickupPhoneController = TextEditingController();
  final List<AuthorizedPickup> _pickupPeople = [];
  // Signature
  final List<List<ui.Offset>> _signatureStrokes = [];
  ui.Size _signatureAreaSize = ui.Size.zero;

  static const _stepTitles = [
    'Child',
    'Guardian',
    'Documents',
    'Pickup',
    'Review & sign',
    'Preview',
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _firstNameController,
      _lastNameController,
      _guardianNameController,
      _phoneController,
      _secondGuardianNameController,
      _secondRelationshipController,
      _secondPhoneController,
    ]) {
      controller.addListener(_onValidationFieldChanged);
    }
  }

  void _onValidationFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _firstNameController,
      _lastNameController,
      _guardianNameController,
      _phoneController,
      _secondGuardianNameController,
      _secondRelationshipController,
      _secondPhoneController,
    ]) {
      controller.removeListener(_onValidationFieldChanged);
    }
    _firstNameController.dispose();
    _lastNameController.dispose();
    _allergiesController.dispose();
    _healthController.dispose();
    _dietController.dispose();
    _specialController.dispose();
    _guardianNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _subCityController.dispose();
    _woredaController.dispose();
    _houseNumberController.dispose();
    _secondGuardianNameController.dispose();
    _secondRelationshipController.dispose();
    _secondPhoneController.dispose();
    _secondEmailController.dispose();
    _secondSubCityController.dispose();
    _secondWoredaController.dispose();
    _secondHouseNumberController.dispose();
    _pickupNameController.dispose();
    _pickupPhoneController.dispose();
    super.dispose();
  }

  bool _canGoNext() {
    switch (_step) {
      case 0:
        return _firstNameController.text.trim().isNotEmpty &&
            _lastNameController.text.trim().isNotEmpty &&
            _gender != null &&
            _dob != null;
      case 1:
        final primaryComplete =
          _guardianNameController.text.trim().isNotEmpty &&
            _guardianRelationship != null &&
            _phoneController.text.trim().isNotEmpty;
        final secondComplete = !_hasSecondGuardian ||
          (_secondGuardianNameController.text.trim().isNotEmpty &&
            _secondRelationshipController.text.trim().isNotEmpty &&
            _secondPhoneController.text.trim().isNotEmpty);
        return primaryComplete && secondComplete;
      case 2:
        return true; // document capture is optional to proceed
      case 3:
        return true; // optional — guardians are already authorized pickups
      case 4:
        return _signatureStrokes.isNotEmpty;
      case 5:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Register', style: AppText.sectionTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: List.generate(_stepTitles.length, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i == _stepTitles.length - 1 ? 0 : 6),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.muted,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('STEP ${_step + 1} OF ${_stepTitles.length} · ${_stepTitles[_step]}'.toUpperCase(),
                    style: AppText.monoLabel),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedSwitcher(
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStepBody(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => setState(() => _step -= 1),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : !_canGoNext()
                              ? null
                              : _step == _stepTitles.length - 1
                                  ? _completeRegistration
                                  : () => setState(() => _step += 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                            : Text(
                              _step == _stepTitles.length - 1
                                ? 'Confirm & continue to billing'
                                : _step == 4
                                  ? 'Preview registration'
                                  : 'Next',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _buildChildStep();
      case 1:
        return _buildGuardianStep();
      case 2:
        return _buildDocumentStep();
      case 3:
        return _buildPickupStep();
      case 4:
        return _buildReviewStep();
      case 5:
        return _buildPreviewStep();
      default:
        return const SizedBox();
    }
  }

  // ---------------------------------------------------------------------
  // Step 0: Child
  // ---------------------------------------------------------------------
  Widget _buildChildStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Child's information", style: AppText.sectionTitle),
          const SizedBox(height: 16),
          _FormField(label: 'First name', controller: _firstNameController),
          const SizedBox(height: 12),
          _FormField(label: 'Last name', controller: _lastNameController),
          const SizedBox(height: 12),
          Text('Gender', style: AppText.caption),
          const SizedBox(height: 6),
          Row(
            children: Gender.values.map((g) {
              final selected = _gender == g;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g == Gender.male ? 'Male' : 'Female'),
                  selected: selected,
                  onSelected: (_) => setState(() => _gender = g),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.foreground,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('Date of birth', style: AppText.caption),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await _pickEthiopianDate();
              if (picked != null) setState(() => _dob = picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _dob == null
                  ? 'Select Ethiopian date of birth'
                  : _ethiopianDateLabel(_dob!),
                style: AppText.bodyRegular.copyWith(
                  color: _dob == null ? AppColors.mutedForeground : AppColors.foreground,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Allergies (comma-separated, optional)',
            controller: _allergiesController,
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Health condition (optional)',
            controller: _healthController,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Dietary condition (optional)',
            controller: _dietController,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Special characteristics (optional)',
            controller: _specialController,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 1: Guardian
  // ---------------------------------------------------------------------
  Widget _buildGuardianStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guardian information', style: AppText.sectionTitle),
          const SizedBox(height: 16),
          _FormField(label: 'Full name', controller: _guardianNameController),
          const SizedBox(height: 12),
          Text('Relationship', style: AppText.caption),
          const SizedBox(height: 6),
          _RelationshipDropdown(
            value: _guardianRelationship,
            onChanged: (value) => setState(() => _guardianRelationship = value),
          ),
          const SizedBox(height: 12),
          _FormField(label: 'Phone', controller: _phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _FormField(label: 'Email (optional)', controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _FormField(label: 'Sub-city (optional)', controller: _subCityController),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FormField(label: 'Woreda (optional)', controller: _woredaController),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(label: 'House No. (optional)', controller: _houseNumberController),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DocumentButton(
            label: "Guardian's ID copy",
            icon: Icons.badge_outlined,
            captured: _guardianIdImagePath != null,
            statusLabel: _guardianIdImagePath != null ? 'Captured' : 'Not captured',
            onTap: () => _captureImage(onCaptured: (path) => _guardianIdImagePath = path),
          ),
          const SizedBox(height: 8),
          Text(
            'Guardians are automatically treated as emergency contacts and '
            'authorized pickups — no separate entry needed.',
            style: AppText.caption,
          ),
          const SizedBox(height: 20),
          if (!_hasSecondGuardian)
            OutlinedButton.icon(
              onPressed: () => setState(() => _hasSecondGuardian = true),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add another guardian'),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Second guardian', style: AppText.bodyMedium),
                IconButton(
                  onPressed: () => setState(() {
                    _hasSecondGuardian = false;
                    _secondGuardianNameController.clear();
                    _secondRelationshipController.clear();
                    _secondPhoneController.clear();
                    _secondEmailController.clear();
                    _secondSubCityController.clear();
                    _secondWoredaController.clear();
                    _secondHouseNumberController.clear();
                  }),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove second guardian',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _FormField(
              label: 'Full name',
              controller: _secondGuardianNameController,
            ),
            const SizedBox(height: 12),
            Text('Relationship', style: AppText.caption),
            const SizedBox(height: 6),
            _RelationshipDropdown(
              value: _secondRelationshipController.text.isEmpty
                  ? null
                  : _secondRelationshipController.text,
              onChanged: (value) {
                setState(() {
                  _secondRelationshipController.text = value ?? '';
                });
              },
            ),
            const SizedBox(height: 12),
            _FormField(
              label: 'Phone',
              controller: _secondPhoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _FormField(
              label: 'Email (optional)',
              controller: _secondEmailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _FormField(label: 'Sub-city (optional)', controller: _secondSubCityController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FormField(label: 'Woreda (optional)', controller: _secondWoredaController),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(label: 'House No. (optional)', controller: _secondHouseNumberController),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Only the primary guardian's ID is captured during registration.",
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 2: Documents & photos
  // ---------------------------------------------------------------------
  Widget _buildDocumentStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Documents & photos', style: AppText.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Optional here — you can still complete registration and add '
            'these later.',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          _DocumentButton(
            label: 'Primary guardian photo',
            icon: Icons.photo_camera_outlined,
            captured: _parentPhotoPath != null,
            statusLabel: _parentPhotoPath != null ? 'Captured' : 'Not captured',
            onTap: () => _captureImage(onCaptured: (path) => _parentPhotoPath = path),
          ),
          const SizedBox(height: 12),
          _DocumentButton(
            label: 'Child photo',
            icon: Icons.child_care_outlined,
            captured: _childPhotoPath != null,
            statusLabel: _childPhotoPath != null ? 'Captured' : 'Not captured',
            onTap: () => _captureImage(onCaptured: (path) => _childPhotoPath = path),
          ),
          const SizedBox(height: 12),
          _DocumentButton(
            label: 'Immunization page(s)',
            icon: Icons.upload_file_outlined,
            captured: _immunizationPagePaths.isNotEmpty,
            statusLabel: _immunizationPagePaths.isEmpty
                ? 'Not captured'
                : '${_immunizationPagePaths.length} page(s) captured — tap to add another',
            onTap: _openImmunizationGallery,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 3: Pickup
  // ---------------------------------------------------------------------
  Widget _buildPickupStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Authorized pickup', style: AppText.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Guardians are already authorized. Add anyone else who may '
            'pick up this child — optional.',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label: 'Full name',
                  controller: _pickupNameController,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addPickupPerson,
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                tooltip: 'Add authorized pickup person',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Phone number',
            controller: _pickupPhoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          ..._pickupPeople.map(
            (person) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: AppText.bodyMedium),
                        const SizedBox(height: 2),
                        Text(person.phone, style: AppText.caption),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _pickupPeople.remove(person)),
                    child: const Icon(Icons.close, size: 18, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addPickupPerson() {
    final name = _pickupNameController.text.trim();
    final phone = _pickupPhoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    setState(() {
      _pickupPeople.add(AuthorizedPickup(name: name, phone: phone));
      _pickupNameController.clear();
      _pickupPhoneController.clear();
    });
  }

  // ---------------------------------------------------------------------
  // Step 4: Review & signature
  // ---------------------------------------------------------------------
  Widget _buildReviewStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & sign', style: AppText.sectionTitle),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Text(_agreementText, style: AppText.bodyRegular.copyWith(height: 1.5)),
          ),
          const SizedBox(height: 16),
          Text('Signature', style: AppText.caption),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              _signatureAreaSize = ui.Size(constraints.maxWidth, 180);
              return GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _signatureStrokes.add([details.localPosition]);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _signatureStrokes.last.add(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  if (_signatureStrokes.isEmpty) return;
                  setState(() => _smoothSignatureStroke(_signatureStrokes.last));
                },
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: CustomPaint(
                    painter: _SignaturePainter(_signatureStrokes),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _signatureStrokes.clear()),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear'),
            ),
          ),
        ],
      ),
    );
  }

  void _smoothSignatureStroke(List<ui.Offset> stroke) {
    if (stroke.length < 3) return;
    final smoothed = List<ui.Offset>.of(stroke);
    for (var i = 1; i < stroke.length - 1; i++) {
      final before = stroke[i - 1];
      final current = stroke[i];
      final after = stroke[i + 1];
      smoothed[i] = ui.Offset(
        (before.dx + current.dx * 2 + after.dx) / 4,
        (before.dy + current.dy * 2 + after.dy) / 4,
      );
    }
    stroke
      ..clear()
      ..addAll(smoothed);
  }

  Widget _buildPreviewStep() {
    final address = [
      _subCityController.text.trim(),
      _woredaController.text.trim(),
      _houseNumberController.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    final pickups = [
      for (var i = 0; i < _pickupPeople.length; i++)
        ('Pickup ${i + 1}', '${_pickupPeople[i].name} · ${_pickupPeople[i].phone}'),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registration preview', style: AppText.sectionTitle),
          const SizedBox(height: 4),
          Text('Check these details before saving.', style: AppText.caption),
          const SizedBox(height: 16),
          _previewSection('Child', [
            ('Name', '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'),
            ('Gender', _gender == Gender.male ? 'Male' : 'Female'),
            ('Date of birth', _dob == null ? '' : _ethiopianDateLabel(_dob!)),
            ('Allergies', _allergiesController.text.trim().isEmpty ? 'None recorded' : _allergiesController.text.trim()),
            ('Health', _healthController.text.trim().isEmpty ? 'None recorded' : _healthController.text.trim()),
            ('Diet', _dietController.text.trim().isEmpty ? 'None recorded' : _dietController.text.trim()),
            ('Special notes', _specialController.text.trim().isEmpty ? 'None recorded' : _specialController.text.trim()),
          ]),
          const SizedBox(height: 12),
          _previewSection('Guardian', [
            ('Name', _guardianNameController.text.trim()),
            ('Relationship', _guardianRelationship ?? ''),
            ('Phone', _phoneController.text.trim()),
            ('Email', _emailController.text.trim()),
            ('Address', address),
          ]),
          if (_hasSecondGuardian) ...[
            const SizedBox(height: 12),
            _previewSection('Second guardian', [
              ('Name', _secondGuardianNameController.text.trim()),
              ('Relationship', _secondRelationshipController.text.trim()),
              ('Phone', _secondPhoneController.text.trim()),
              ('Email', _secondEmailController.text.trim()),
              ('Address', [
                _secondSubCityController.text.trim(),
                _secondWoredaController.text.trim(),
                _secondHouseNumberController.text.trim(),
              ].where((part) => part.isNotEmpty).join(', ')),
            ]),
          ],
          const SizedBox(height: 12),
          _previewSection(
            'Authorized pickup',
            pickups.isEmpty ? [('Additional people', 'None')] : pickups,
          ),
          const SizedBox(height: 12),
          _previewSection('Documents', [
            ('Guardian ID', _guardianIdImagePath == null ? 'Not captured' : 'Captured'),
            (
              'Immunization pages',
              _immunizationPagePaths.isEmpty
                  ? 'Not captured'
                  : '${_immunizationPagePaths.length} captured',
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Photos', style: AppText.bodyMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _previewPhoto('Guardian', _parentPhotoPath),
                    const SizedBox(width: 16),
                    _previewPhoto('Child', _childPhotoPath),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Agreement', style: AppText.bodyMedium),
                const SizedBox(height: 6),
                Text(_agreementText, style: AppText.bodyRegular.copyWith(height: 1.5)),
                const SizedBox(height: 12),
                Text('Signature', style: AppText.caption),
                const SizedBox(height: 6),
                Container(
                  height: 88,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    painter: _SignaturePainter(
                      _signatureStrokes,
                      sourceSize: _signatureAreaSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _previewSection(String title, List<(String, String)> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.bodyMedium),
          const SizedBox(height: 8),
          for (final row in rows)
            if (row.$2.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 104, child: Text(row.$1, style: AppText.caption)),
                    Expanded(child: Text(row.$2, style: AppText.bodyRegular)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _previewPhoto(String label, String? path) {
    return Expanded(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 96,
              child: path == null
                  ? const ColoredBox(
                      color: AppColors.muted,
                      child: Icon(Icons.person_outline, color: AppColors.mutedForeground),
                    )
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.muted,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }

  Future<DateTime?> _pickEthiopianDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year - 12, today.month, today.day);
    final initial = _dob == null
        ? ETDateTime.now()
        : _dob!.convertToEthiopian();

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => _EthiopianDatePickerDialog(
        initialDate: initial,
        firstDate: firstDate,
        lastDate: today,
      ),
    );
  }

  String _ethiopianDateLabel(DateTime date) {
    final etDate = date.convertToEthiopian();
    return '${etDate.day} ${amharicMonths[etDate.month - 1]} '
        '${etDate.year} (${DateFormat('MMM d, yyyy').format(date)})';
  }

  // ---------------------------------------------------------------------
  // Camera capture
  // ---------------------------------------------------------------------
  Future<void> _captureImage({required void Function(String path) onCaptured}) async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final files = await FilePicker.pickFiles(type: FileType.image);
        if (files.isNotEmpty && files.single.path != null) {
          setState(() => onCaptured(files.single.path!));
        }
        return;
      }
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;
      setState(() => onCaptured(file.path));
    } catch (e) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not select photo. Check permission and try again.',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () => _captureImage(onCaptured: onCaptured),
      );
    }
  }

  Future<void> _openImmunizationGallery() async {
    final pages = await showImmunizationGallery(
      context,
      initialPages: [
        for (final path in _immunizationPagePaths) ImmunizationPage(path: path),
      ],
    );
    if (pages != null) {
      setState(() {
        _immunizationPagePaths
          ..clear()
          ..addAll(pages.map((page) => page.path));
      });
    }
  }

  // ---------------------------------------------------------------------
  // Completion — builds real Documents (from captured photos) and a
  // signed, tamper-evident PDF, then saves an actual Child to the store.
  // ---------------------------------------------------------------------
  Future<void> _completeRegistration() async {
    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      const uuid = Uuid();
      final documents = <ChildDocument>[];
        final guardianPhotoBytes = _parentPhotoPath == null
          ? null
          : await File(_parentPhotoPath!).readAsBytes();
        final childPhotoBytes = _childPhotoPath == null
          ? null
          : await File(_childPhotoPath!).readAsBytes();
          final guardianPhotoLabel = _guardianRelationship == 'Father'
            ? 'Father photo'
            : 'Primary guardian photo';

      // Guardian ID
      if (_guardianIdImagePath != null) {
        final bytes = await File(_guardianIdImagePath!).readAsBytes();
        final (path, hash) = await DocumentStorage.save(
          bytes: bytes,
          filename: 'id_$timestamp.jpg',
        );
        documents.add(ChildDocument(
          id: uuid.v4(),
          label: "Guardian's ID copy",
          type: DocumentType.id,
          uploadedAt: now,
          status: DocumentStatus.onFile,
          filePath: path,
          sha256: hash,
        ));
      } else {
        documents.add(ChildDocument(
          id: uuid.v4(),
          label: "Guardian's ID copy",
          type: DocumentType.id,
          uploadedAt: now,
          status: DocumentStatus.pending,
        ));
      }

      // Parent photo
      if (guardianPhotoBytes != null) {
        final (path, hash) = await DocumentStorage.save(
          bytes: guardianPhotoBytes,
          filename: 'guardian_photo_$timestamp.jpg',
        );
        documents.add(ChildDocument(
          id: uuid.v4(),
          label: guardianPhotoLabel,
          type: DocumentType.photo,
          uploadedAt: now,
          status: DocumentStatus.onFile,
          filePath: path,
          sha256: hash,
        ));
      } else {
        documents.add(ChildDocument(
          id: uuid.v4(),
          label: guardianPhotoLabel,
          type: DocumentType.photo,
          uploadedAt: now,
          status: DocumentStatus.pending,
        ));
      }

      // Child photo
      if (childPhotoBytes != null) {
        final (path, hash) = await DocumentStorage.save(
          bytes: childPhotoBytes,
          filename: 'child_photo_$timestamp.jpg',
        );
        documents.add(ChildDocument(
          id: uuid.v4(),
          label: 'Child photo',
          type: DocumentType.photo,
          uploadedAt: now,
          status: DocumentStatus.onFile,
          filePath: path,
          sha256: hash,
        ));
      } else {
        documents.add(ChildDocument(
          id: uuid.v4(),
          label: 'Child photo',
          type: DocumentType.photo,
          uploadedAt: now,
          status: DocumentStatus.pending,
        ));
      }

      // Immunization pages — one Document per captured page
      if (_immunizationPagePaths.isEmpty) {
        documents.add(ChildDocument(
          id: uuid.v4(),
          label: 'Immunization record',
          type: DocumentType.immunization,
          uploadedAt: now,
          status: DocumentStatus.pending,
        ));
      } else {
        for (var i = 0; i < _immunizationPagePaths.length; i++) {
          final bytes = await File(_immunizationPagePaths[i]).readAsBytes();
          final (path, hash) = await DocumentStorage.save(
            bytes: bytes,
            filename: 'immunization_${timestamp}_${i + 1}.jpg',
          );
          documents.add(ChildDocument(
            id: uuid.v4(),
            label: 'Immunization record — page ${i + 1}',
            type: DocumentType.immunization,
            uploadedAt: now,
            status: DocumentStatus.onFile,
            filePath: path,
            sha256: hash,
          ));
        }
      }

      // Signed registration PDF — built from the actual form data and
      // the real signature strokes, then written once and never
      // rewritten (tamper-evidence relies on that).
      final allergies = _allergiesController.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList();

      final guardians = <Guardian>[
        Guardian(
          id: uuid.v4(),
          name: _guardianNameController.text.trim(),
          relationship: _guardianRelationship!,
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          isPrimary: true,
          authorizedPickup: true,
          subCity: _subCityController.text.trim(),
          woreda: _woredaController.text.trim(),
          houseNumber: _houseNumberController.text.trim(),
        ),
      ];

      if (_hasSecondGuardian &&
          _secondGuardianNameController.text.trim().isNotEmpty &&
          _secondRelationshipController.text.trim().isNotEmpty &&
          _secondPhoneController.text.trim().isNotEmpty) {
        guardians.add(
          Guardian(
            id: uuid.v4(),
            name: _secondGuardianNameController.text.trim(),
            relationship: _secondRelationshipController.text.trim(),
            phone: _secondPhoneController.text.trim(),
            email: _secondEmailController.text.trim(),
            isPrimary: false,
            authorizedPickup: true,
            subCity: _secondSubCityController.text.trim(),
            woreda: _secondWoredaController.text.trim(),
            houseNumber: _secondHouseNumberController.text.trim(),
          ),
        );
      }

      final pdfBytes = await buildRegistrationPdf(
        RegistrationPdfData(
          childFirstName: _firstNameController.text.trim(),
          childLastName: _lastNameController.text.trim(),
          gender: _gender!,
          childDob: _dob!,
          guardians: guardians,
          healthCondition: _healthController.text.trim(),
          dietaryNotes: _dietController.text.trim(),
          specialCharacteristics: _specialController.text.trim(),
          pickupPeople: List.of(_pickupPeople),
          agreementText: _agreementText,
          guardianPhotoBytes: guardianPhotoBytes,
          childPhotoBytes: childPhotoBytes,
          signatureStrokes: _signatureStrokes,
          signatureAreaSize: _signatureAreaSize,
          signedAt: now,
        ),
      );
      final (pdfPath, pdfHash) = await DocumentStorage.save(
        bytes: pdfBytes,
        filename: 'registration_$timestamp.pdf',
      );
      documents.add(ChildDocument(
        id: uuid.v4(),
        label: 'Signed registration form',
        type: DocumentType.registration,
        uploadedAt: now,
        status: DocumentStatus.onFile,
        filePath: pdfPath,
        sha256: pdfHash,
        // Made on desktop → she's next to the printer, nothing to queue.
        // Made on the phone → it needs a first print at the desktop.
        printed: SettingsStore.instance.isDesktop,
      ));

      final child = Child(
        id: uuid.v4(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _gender!,
        dob: _dob!,
        allergies: allergies,
        healthCondition: _healthController.text.trim(),
        dietaryNotes: _dietController.text.trim(),
        specialCharacteristics: _specialController.text.trim(),
        enrollmentStatus: EnrollmentStatus.enrolled,
        enrolledSince: now,
        guardians: guardians,
        documents: documents,
        attendance: const [],
        payments: const [],
        synced: false, // created locally on mobile, not yet synced to desktop
        additionalPickupPeople: List.of(_pickupPeople),
      );

      await ChildrenStore.instance.addChild(child);

      if (!mounted) return;
      Navigator.of(context).pop(child.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showAppFeedback(
        context,
        message: 'Could not complete registration. Your details are still here. $e',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: _completeRegistration,
      );
    }
  }
}

class _EthiopianDatePickerDialog extends StatefulWidget {
  final ETDateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _EthiopianDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_EthiopianDatePickerDialog> createState() =>
      _EthiopianDatePickerDialogState();
}

class _EthiopianDatePickerDialogState
    extends State<_EthiopianDatePickerDialog> {
  late int _year;
  late int _month;

  ETDateTime get _firstEthiopian => widget.firstDate.convertToEthiopian();

  ETDateTime get _lastEthiopian => widget.lastDate.convertToEthiopian();

  List<int> get _availableYears => [
        for (var year = _firstEthiopian.year;
            year <= _lastEthiopian.year;
            year++)
          year,
      ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
    _showableMonth = _clampMonth(_year, _month);
    _year = _showableMonth.$1;
    _month = _showableMonth.$2;
  }

  late (int, int) _showableMonth;

  (int, int) _clampMonth(int year, int month) {
    if (_compareMonth(year, month, _firstEthiopian.year, _firstEthiopian.month) < 0) {
      return (_firstEthiopian.year, _firstEthiopian.month);
    }
    if (_compareMonth(year, month, _lastEthiopian.year, _lastEthiopian.month) > 0) {
      return (_lastEthiopian.year, _lastEthiopian.month);
    }
    return (year, month);
  }

  int _compareMonth(int yearA, int monthA, int yearB, int monthB) {
    return (yearA * 13 + monthA).compareTo(yearB * 13 + monthB);
  }

  int get _daysInMonth =>
      _month == 13 ? (_year % 4 == 3 ? 6 : 5) : 30;

  bool _isSelectable(int day) {
    final date = ETDateTime(_year, _month, day).convertToGregorian();
    return !_dateOnly(date).isBefore(_dateOnly(widget.firstDate)) &&
        !_dateOnly(date).isAfter(_dateOnly(widget.lastDate));
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSelected(int day) {
    final selected = widget.initialDate.convertToGregorian();
    final date = ETDateTime(_year, _month, day).convertToGregorian();
    return selected.year == date.year &&
        selected.month == date.month &&
        selected.day == date.day;
  }

  void _changeMonth(int amount) {
    var year = _year;
    var month = _month + amount;
    if (month < 1) {
      month = 13;
      year--;
    } else if (month > 13) {
      month = 1;
      year++;
    }
    final clamped = _clampMonth(year, month);
    setState(() {
      _year = clamped.$1;
      _month = clamped.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = ETDateTime(_year, _month, 1).weekday;
    final gridCount = (firstWeekday - 1) + _daysInMonth;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Date of birth', style: AppText.sectionTitle),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close calendar',
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _compareMonth(_year, _month,
                                _firstEthiopian.year, _firstEthiopian.month) >
                            0
                        ? () => _changeMonth(-1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                  ),
                  Expanded(
                    child: Text(
                      '${amharicMonths[_month - 1]} $_year',
                      textAlign: TextAlign.center,
                      style: AppText.bodyMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _compareMonth(_year, _month,
                                _lastEthiopian.year, _lastEthiopian.month) <
                            0
                        ? () => _changeMonth(1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                  ),
                ],
              ),
              DropdownButton<int>(
                value: _year,
                underline: const SizedBox.shrink(),
                items: _availableYears
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text('$year', style: AppText.bodyMedium),
                      ),
                    )
                    .toList(),
                onChanged: (year) {
                  if (year == null) return;
                  final clamped = _clampMonth(year, _month);
                  setState(() {
                    _year = clamped.$1;
                    _month = clamped.$2;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children:
                    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map(
                          (day) => Expanded(
                            child: Center(child: Text(day)),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gridCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final day = index - firstWeekday + 2;
                  if (day < 1 || day > _daysInMonth) return const SizedBox();
                  final selectable = _isSelectable(day);
                  final selected = _isSelected(day);
                  return InkWell(
                    onTap: selectable
                        ? () => Navigator.of(context).pop(
                              ETDateTime(_year, _month, day)
                                  .convertToGregorian(),
                            )
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$day',
                        style: AppText.bodyRegular.copyWith(
                          color: !selectable
                              ? AppColors.mutedForeground
                                  .withValues(alpha: 0.4)
                              : selected
                                  ? Colors.white
                                  : AppColors.foreground,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationshipDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _RelationshipDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text('Select relationship', style: AppText.bodyRegular),
          items: _guardianRelationships
              .map(
                (relationship) => DropdownMenuItem<String>(
                  value: relationship,
                  child: Text(relationship, style: AppText.bodyRegular),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  const _FormField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: AppText.bodyRegular,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool captured;
  final String statusLabel;
  final VoidCallback onTap;

  const _DocumentButton({
    required this.label,
    required this.icon,
    required this.captured,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: captured ? AppColors.syncSoft : AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                captured ? Icons.check : icon,
                color: captured ? AppColors.sync : AppColors.mutedForeground,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.bodyMedium),
                  const SizedBox(height: 2),
                  Text(statusLabel, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<ui.Offset>> strokes;

  /// The size of the pad the strokes were captured on. When the painter is
  /// asked to draw into a differently-sized box (the smaller preview
  /// rendition), points are scaled to fit instead of overflowing.
  final ui.Size? sourceSize;

  _SignaturePainter(this.strokes, {this.sourceSize});

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final source = sourceSize;
    final scaleX = (source != null && source.width > 0)
        ? size.width / source.width
        : 1.0;
    final scaleY = (source != null && source.height > 0)
        ? size.height / source.height
        : 1.0;
    ui.Offset map(ui.Offset p) => ui.Offset(p.dx * scaleX, p.dy * scaleY);

    final strokePaint = Paint()
      ..color = AppColors.foreground
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.5;
    final dotPaint = Paint()
      ..color = AppColors.foreground
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        // A tap with no drag — draw a small dot so it's not invisible.
        canvas.drawCircle(map(stroke.first), strokePaint.strokeWidth / 2, dotPaint);
        continue;
      }
      if (stroke.length == 2) {
        canvas.drawLine(map(stroke[0]), map(stroke[1]), strokePaint);
        continue;
      }
      // Smooth the raw touch points into a curve: each point becomes the
      // control point of a quadratic Bezier ending at the midpoint to
      // the next point. Straight lineTo segments between raw points is
      // what makes freehand strokes look jagged — this rounds them out.
      final first = map(stroke[0]);
      final path = ui.Path()..moveTo(first.dx, first.dy);
      for (var i = 1; i < stroke.length - 1; i++) {
        final control = map(stroke[i]);
        final next = map(stroke[i + 1]);
        final midpoint = ui.Offset(
          (control.dx + next.dx) / 2,
          (control.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(control.dx, control.dy, midpoint.dx, midpoint.dy);
      }
      final last = map(stroke.last);
      path.lineTo(last.dx, last.dy);
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
