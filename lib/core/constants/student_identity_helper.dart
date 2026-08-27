import 'app_constants.dart';

/// Representation of a BVC Engineering branch/class
class BvcBranch {
  final String code;
  final String name;

  const BvcBranch({required this.code, required this.name});

  String get displayName => '$code - $name';

  @override
  String toString() => '$code ($name)';
}

/// Official built-in list of branches offered at BVC Engineering College
const List<BvcBranch> kBvcBranches = [
  BvcBranch(code: 'CSE', name: 'Computer Science & Engineering'),
  BvcBranch(
      code: 'CSM', name: 'CSE - Artificial Intelligence & Machine Learning'),
  BvcBranch(code: 'CAD', name: 'CSE - Artificial Intelligence & Data Science'),
  BvcBranch(code: 'AIM', name: 'Artificial Intelligence & Machine Learning'),
  BvcBranch(code: 'ECE', name: 'Electronics & Communication Engineering'),
  BvcBranch(code: 'IT', name: 'Information Technology'),
  BvcBranch(code: 'EEE', name: 'Electrical & Electronics Engineering'),
  BvcBranch(code: 'MECH', name: 'Mechanical Engineering'),
  BvcBranch(code: 'CIVIL', name: 'Civil Engineering'),
];

/// Standard sections list
const List<String> kBvcSections = [
  'Section A',
  'Section B',
  'Section C',
  'Section D',
  'Section E',
];

/// Value object representing automatically extracted student identity
class StudentIdentity {
  final String rollNumber;
  final String batchCode;
  final int academicYear;
  final String academicYearLabel;
  final String email;
  final String college;

  const StudentIdentity({
    required this.rollNumber,
    required this.batchCode,
    required this.academicYear,
    required this.academicYearLabel,
    required this.email,
    this.college = AppConstants.collegeName,
  });

  @override
  String toString() {
    return 'StudentIdentity(rollNumber: $rollNumber, batchCode: $batchCode, year: $academicYearLabel, email: $email)';
  }
}

/// Helper class for validating BVC student emails and extracting student identity
class StudentIdentityHelper {
  StudentIdentityHelper._();

  static const String allowedDomain = 'bvcgroup.in';

  /// Supported starting prefixes and their corresponding B.Tech year mapping
  static const Map<String, ({int year, String label})> _batchMapping = {
    '26': (year: 1, label: '1st B.Tech'),
    '25': (year: 2, label: '2nd B.Tech'),
    '24': (year: 3, label: '3rd B.Tech'),
    '23': (year: 4, label: '4th B.Tech'),
  };

  /// Check if the email belongs to @bvcgroup.in and starts with a supported batch (26, 25, 24, 23)
  static bool isValidStudentEmail(String? email) {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    final parts = normalized.split('@');
    if (parts.length != 2) return false;

    final localPart = parts[0];
    final domain = parts[1];

    if (domain != allowedDomain) return false;
    if (localPart.length < 2) return false;

    final prefix = localPart.substring(0, 2);
    return _batchMapping.containsKey(prefix);
  }

  /// Extract the [StudentIdentity] from a verified student email.
  /// Returns `null` if the email is invalid or has an unsupported prefix.
  static StudentIdentity? extractFromEmail(String? email) {
    if (email == null) return null;
    final normalized = email.trim().toLowerCase();
    final parts = normalized.split('@');
    if (parts.length != 2) return null;

    final localPart = parts[0];
    final domain = parts[1];

    if (domain != allowedDomain) return null;
    if (localPart.length < 2) return null;

    final prefix = localPart.substring(0, 2);
    final batchInfo = _batchMapping[prefix];
    if (batchInfo == null) return null;

    // Preserve the complete local part, uppercase for standard roll number display
    final rollNumber = localPart.toUpperCase();

    return StudentIdentity(
      rollNumber: rollNumber,
      batchCode: prefix,
      academicYear: batchInfo.year,
      academicYearLabel: batchInfo.label,
      email: normalized,
      college: AppConstants.collegeName,
    );
  }
}
