/// User role enumeration
enum UserRole {
  student,
  teacher,
  staff,
  admin,
  unknown;

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.staff:
        return 'Staff';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.unknown:
        return 'Unknown';
    }
  }

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.unknown;
    try {
      return UserRole.values.firstWhere(
        (role) => role.name.toLowerCase() == value.toLowerCase(),
        orElse: () => UserRole.unknown,
      );
    } catch (_) {
      return UserRole.unknown;
    }
  }
}

/// User model for authentication and profile
class User {
  final String uid;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? profileImageUrl;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool emailVerified;
  final bool isActive;

  User({
    required this.uid,
    required this.email,
    this.firstName,
    this.lastName,
    this.profileImageUrl,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.emailVerified = false,
    this.isActive = true,
  });

  /// Full name of the user
  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    return '$first $last'.trim();
  }

  /// Short name or initials for avatar
  String get displayName => firstName ?? email.split('@').first;

  /// Avatar initials
  String get initials {
    final parts = fullName.split(' ');
    if (parts.isEmpty) return email.substring(0, 2).toUpperCase();
    if (parts.length == 1) {
      return parts.first.substring(0, min(2, parts.first.length)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Copy with method for immutability
  User copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? profileImageUrl,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? emailVerified,
    bool? isActive,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      emailVerified: emailVerified ?? this.emailVerified,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'User(uid: $uid, email: $email, role: ${role.displayName})';
  }
}

// Helper function for min
int min(int a, int b) => a < b ? a : b;
