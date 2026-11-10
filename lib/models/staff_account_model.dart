/// Model for HOD and Faculty staff accounts managed by Admin
class StaffAccount {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'hod' or 'faculty'
  final String department;
  final String? designation;
  final String? phone;
  final String? cabin;
  final String? qualification;
  final String? specialization;
  final bool isActive;
  final DateTime? createdAt;

  const StaffAccount({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.department,
    this.designation,
    this.phone,
    this.cabin,
    this.qualification,
    this.specialization,
    this.isActive = true,
    this.createdAt,
  });

  bool get isHod => role.toLowerCase() == 'hod';
  bool get isFaculty => role.toLowerCase() == 'faculty';

  factory StaffAccount.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return StaffAccount(
      id: json['id'] as String? ?? '',
      email: (json['email'] as String? ?? '').toLowerCase().trim(),
      fullName: json['fullName'] as String? ?? json['full_name'] as String? ?? '',
      role: (json['role'] as String? ?? 'faculty').toLowerCase().trim(),
      department: (json['department'] as String? ?? 'CSE').toUpperCase().trim(),
      designation: json['designation'] as String?,
      phone: json['phone'] as String?,
      cabin: json['cabin'] as String?,
      qualification: json['qualification'] as String?,
      specialization: json['specialization'] as String?,
      isActive: json['isActive'] as bool? ?? json['is_active'] == 1 || json['is_active'] == true,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role,
      'department': department,
      'designation': designation,
      'phone': phone,
      'cabin': cabin,
      'qualification': qualification,
      'specialization': specialization,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  StaffAccount copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? department,
    String? designation,
    String? phone,
    String? cabin,
    String? qualification,
    String? specialization,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return StaffAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      cabin: cabin ?? this.cabin,
      qualification: qualification ?? this.qualification,
      specialization: specialization ?? this.specialization,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
