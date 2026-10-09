import 'dart:convert';

import 'authorized_pickup.dart';

enum EnrollmentStatus { enrolled, withdrawn }

enum Gender { male, female }

extension GenderLabel on Gender {
  /// Amharic label matching the paper form's ፆታ field.
  String get amharicLabel => this == Gender.male ? 'ወንድ' : 'ሴት';
}

enum DocumentType { id, photo, immunization, registration, other }

enum DocumentStatus { onFile, pending, expired }

enum AttendanceStatus { present, absent }

enum PaymentStatus { pending, paid, cancelled }

/// A pending charge counts as overdue once it's this many days past its
/// due date without being marked paid.
const overdueGraceDays = 5;

class Guardian {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final bool isPrimary;
  final bool authorizedPickup;
  final String subCity;
  final String woreda;
  final String houseNumber;

  const Guardian({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.isPrimary,
    required this.authorizedPickup,
    this.subCity = '',
    this.woreda = '',
    this.houseNumber = '',
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// "Sub-city, Woreda, House No." combined for compact display, omitting
  /// any parts that weren't collected.
  String get addressSummary {
    final parts = [
      if (subCity.isNotEmpty) subCity,
      if (woreda.isNotEmpty) 'Woreda $woreda',
      if (houseNumber.isNotEmpty) 'House $houseNumber',
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toMap(String childId) => {
        'id': id,
        'child_id': childId,
        'name': name,
        'relationship': relationship,
        'phone': phone,
        'email': email,
        'is_primary': isPrimary ? 1 : 0,
        'authorized_pickup': authorizedPickup ? 1 : 0,
        'sub_city': subCity,
        'woreda': woreda,
        'house_number': houseNumber,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Guardian copyWith({
    String? name,
    String? relationship,
    String? phone,
    String? email,
    bool? isPrimary,
    bool? authorizedPickup,
    String? subCity,
    String? woreda,
    String? houseNumber,
  }) {
    return Guardian(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
      authorizedPickup: authorizedPickup ?? this.authorizedPickup,
      subCity: subCity ?? this.subCity,
      woreda: woreda ?? this.woreda,
      houseNumber: houseNumber ?? this.houseNumber,
    );
  }

  factory Guardian.fromMap(Map<String, dynamic> map) => Guardian(
        id: map['id'] as String,
        name: map['name'] as String,
        relationship: map['relationship'] as String,
        phone: map['phone'] as String,
        email: map['email'] as String,
        isPrimary: (map['is_primary'] as int) == 1,
        authorizedPickup: (map['authorized_pickup'] as int) == 1,
        subCity: map['sub_city'] as String? ?? '',
        woreda: map['woreda'] as String? ?? '',
        houseNumber: map['house_number'] as String? ?? '',
      );
}

class ChildDocument {
  final String id;
  final String label;
  final DocumentType type;
  final DateTime uploadedAt;
  final DocumentStatus status;
  final String? filePath;
  final String? sha256;
  final bool printed;

  const ChildDocument({
    required this.id,
    required this.label,
    required this.type,
    required this.uploadedAt,
    required this.status,
    this.filePath,
    this.sha256,
    this.printed = true,
  });

  ChildDocument copyWith({
    String? label,
    DocumentType? type,
    DocumentStatus? status,
    bool? printed,
    String? filePath,
    String? sha256,
  }) => ChildDocument(
        id: id,
        label: label ?? this.label,
        type: type ?? this.type,
        uploadedAt: uploadedAt,
        status: status ?? this.status,
        filePath: filePath ?? this.filePath,
        sha256: sha256 ?? this.sha256,
        printed: printed ?? this.printed,
      );

  Map<String, dynamic> toMap(String childId) => {
        'id': id,
        'child_id': childId,
        'label': label,
        'type': type.name,
        'uploaded_at': uploadedAt.toIso8601String(),
        'status': status.name,
        'file_path': filePath,
        'sha256': sha256,
        'printed': printed ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory ChildDocument.fromMap(Map<String, dynamic> map) => ChildDocument(
        id: map['id'] as String,
        label: map['label'] as String,
        type: DocumentType.values.byName(map['type'] as String),
        uploadedAt: DateTime.parse(map['uploaded_at'] as String),
        status: DocumentStatus.values.byName(map['status'] as String),
        filePath: map['file_path'] as String?,
        sha256: map['sha256'] as String?,
        printed: (map['printed'] as int?) != 0,
      );
}

class AttendanceRecord {
  final String id;
  final DateTime date;
  final String? checkIn;
  final String? checkOut;
  final AttendanceStatus status;

  const AttendanceRecord({
    required this.id,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
  });

  Map<String, dynamic> toMap(String childId) => {
        'id': id,
        'child_id': childId,
        'date': date.toIso8601String(),
        'check_in': checkIn,
        'check_out': checkOut,
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) =>
      AttendanceRecord(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        checkIn: map['check_in'] as String?,
        checkOut: map['check_out'] as String?,
        status: AttendanceStatus.values.byName(map['status'] as String),
      );
}

class PaymentRecord {
  final String id;
  final String feeTypeName;
  final String description;
  final double amount;
  final PaymentStatus status;
  final DateTime dueDate;
  final DateTime? paidAt;
  // e.g. "Meskerem 2018" — which billing cycle this charge is for.
  // Null for one-off charges (registration fee, a late-pickup fee).
  final String? cycleLabel;

  const PaymentRecord({
    required this.id,
    required this.feeTypeName,
    required this.description,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.paidAt,
    this.cycleLabel,
  });

  /// A pending charge more than [overdueGraceDays] past its due date.
  /// Not stored — computed at read time so it's never stale.
  bool get isOverdue =>
      status == PaymentStatus.pending &&
      DateTime.now().isAfter(dueDate.add(const Duration(days: overdueGraceDays)));

  PaymentRecord copyWith({
    String? feeTypeName,
    String? description,
    double? amount,
    PaymentStatus? status,
    DateTime? dueDate,
    DateTime? paidAt,
    bool clearPaidAt = false,
    String? cycleLabel,
  }) {
    return PaymentRecord(
      id: id,
      feeTypeName: feeTypeName ?? this.feeTypeName,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      cycleLabel: cycleLabel ?? this.cycleLabel,
    );
  }

  Map<String, dynamic> toMap(String childId) => {
        'id': id,
        'child_id': childId,
        'fee_type_name': feeTypeName,
        'description': description,
        'amount': amount,
        'status': status.name,
        'due_date': dueDate.toIso8601String(),
        'paid_at': paidAt?.toIso8601String(),
        'cycle_label': cycleLabel,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
        id: map['id'] as String,
        feeTypeName: map['fee_type_name'] as String,
        description: map['description'] as String,
        amount: (map['amount'] as num).toDouble(),
        status: PaymentStatus.values.byName(map['status'] as String),
        dueDate: DateTime.parse(map['due_date'] as String),
        paidAt: map['paid_at'] == null ? null : DateTime.parse(map['paid_at'] as String),
        cycleLabel: map['cycle_label'] as String?,
      );
}

class Child {
  final String id;
  final String firstName;
  final String lastName;
  final Gender gender;
  final DateTime dob;
  final List<String> allergies;
  final String healthCondition;
  final String dietaryNotes;
  final String specialCharacteristics;
  final EnrollmentStatus enrollmentStatus;
  final DateTime enrolledSince;
  // Ethiopian-calendar day-of-month tuition is billed on. Null means
  // "use enrolledSince's Ethiopian day" (the default rule); set to
  // override it for one child without changing their registration date.
  final int? billingDayOverride;
  final List<Guardian> guardians;
  final List<ChildDocument> documents;
  final List<AttendanceRecord> attendance;
  final List<PaymentRecord> payments;
  final bool synced;
  final List<AuthorizedPickup> additionalPickupPeople;

  const Child({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dob,
    required this.allergies,
    this.healthCondition = '',
    this.dietaryNotes = '',
    this.specialCharacteristics = '',
    required this.enrollmentStatus,
    required this.enrolledSince,
    this.billingDayOverride,
    required this.guardians,
    required this.documents,
    required this.attendance,
    required this.payments,
    this.synced = true,
    this.additionalPickupPeople = const [],
  });

  Child copyWith({
    String? firstName,
    String? lastName,
    Gender? gender,
    DateTime? dob,
    List<String>? allergies,
    String? healthCondition,
    String? dietaryNotes,
    String? specialCharacteristics,
    List<Guardian>? guardians,
    List<ChildDocument>? documents,
    List<AttendanceRecord>? attendance,
    List<PaymentRecord>? payments,
    bool? synced,
    List<AuthorizedPickup>? additionalPickupPeople,
    EnrollmentStatus? enrollmentStatus,
    DateTime? enrolledSince,
    int? billingDayOverride,
  }) {
    return Child(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      allergies: allergies ?? this.allergies,
      healthCondition: healthCondition ?? this.healthCondition,
      dietaryNotes: dietaryNotes ?? this.dietaryNotes,
      specialCharacteristics:
          specialCharacteristics ?? this.specialCharacteristics,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      enrolledSince: enrolledSince ?? this.enrolledSince,
      billingDayOverride: billingDayOverride ?? this.billingDayOverride,
      guardians: guardians ?? this.guardians,
      documents: documents ?? this.documents,
      attendance: attendance ?? this.attendance,
      payments: payments ?? this.payments,
      synced: synced ?? this.synced,
      additionalPickupPeople:
          additionalPickupPeople ?? this.additionalPickupPeople,
    );
  }

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return (f + l).toUpperCase();
  }

  /// Path to the child's own photo on file, if one has been captured and
  /// stored locally. Falls back to null so callers can show initials.
  String? get photoPath {
    for (final document in documents) {
      if (document.type == DocumentType.photo &&
          document.label.toLowerCase().contains('child') &&
          document.status == DocumentStatus.onFile) {
        return document.filePath;
      }
    }
    return null;
  }

  /// Age in whole months — used for age-based fee rate lookups.
  int get ageInMonths {
    final now = DateTime.now();
    var months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  /// Matches the `getAge` helper from data.ts — years-and-months style
  /// age string used across the dashboard, list, and profile.
  String get ageLabel {
    final now = DateTime.now();
    var years = now.year - dob.year;
    var months = now.month - dob.month;
    if (now.day < dob.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years < 1) return '${months}mo';
    if (months == 0) return '${years}y';
    return '${years}y ${months}mo';
  }

  /// Only the child's own scalar columns — the `children` table row.
  /// Nested lists (guardians, documents, attendance, payments) are
  /// stored in their own tables, keyed by child_id.
  Map<String, dynamic> toMap() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'gender': gender.name,
        'dob': dob.toIso8601String(),
        'allergies': allergies.join(','),
        'health_condition': healthCondition,
        'dietary_notes': dietaryNotes,
        'special_characteristics': specialCharacteristics,
        'enrollment_status': enrollmentStatus.name,
        'enrolled_since': enrolledSince.toIso8601String(),
        'billing_day_override': billingDayOverride,
        'synced': synced ? 1 : 0,
        'additional_pickup_people': jsonEncode(
          additionalPickupPeople.map((person) => person.toMap()).toList(),
        ),
        'updated_at': DateTime.now().toIso8601String(),
      };

  /// Builds a Child from its own row plus its already-queried nested
  /// lists (see ChildrenRepository, which does the joining).
  factory Child.fromMap(
    Map<String, dynamic> map, {
    required List<Guardian> guardians,
    required List<ChildDocument> documents,
    required List<AttendanceRecord> attendance,
    required List<PaymentRecord> payments,
  }) {
    final pickupRaw = map['additional_pickup_people'] as String? ?? '';
    final pickupPeople = _decodePickupPeople(pickupRaw);
    return Child(
      id: map['id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      gender: Gender.values.byName(map['gender'] as String? ?? 'male'),
      dob: DateTime.parse(map['dob'] as String),
      allergies: (map['allergies'] as String).isEmpty
          ? const []
          : (map['allergies'] as String).split(','),
      healthCondition: map['health_condition'] as String? ?? '',
      dietaryNotes: map['dietary_notes'] as String? ?? '',
      specialCharacteristics: map['special_characteristics'] as String? ?? '',
      enrollmentStatus:
          EnrollmentStatus.values.byName(map['enrollment_status'] as String),
      enrolledSince: DateTime.parse(map['enrolled_since'] as String),
      billingDayOverride: map['billing_day_override'] as int?,
      guardians: guardians,
      documents: documents,
      attendance: attendance,
      payments: payments,
      synced: (map['synced'] as int) == 1,
      additionalPickupPeople: pickupPeople,
    );
  }

  static List<AuthorizedPickup> _decodePickupPeople(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => AuthorizedPickup.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      }
    } on FormatException {
      // Older versions stored pickup names as pipe-delimited strings.
    }
    return raw
        .split('|')
        .where((name) => name.isNotEmpty)
        .map((name) => AuthorizedPickup(name: name, phone: ''))
        .toList();
  }
}
