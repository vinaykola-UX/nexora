import 'package:flutter/material.dart';

/// Status of a faculty member for real-time monitoring
enum FacultyStatus {
  active,
  inClass,
  onLeave,
  inMeeting;

  String get displayName {
    switch (this) {
      case FacultyStatus.active:
        return 'Available';
      case FacultyStatus.inClass:
        return 'In Class';
      case FacultyStatus.onLeave:
        return 'On Leave';
      case FacultyStatus.inMeeting:
        return 'In Meeting';
    }
  }

  Color get color {
    switch (this) {
      case FacultyStatus.active:
        return const Color(0xFF2E7D32); // Green
      case FacultyStatus.inClass:
        return const Color(0xFF1976D2); // Blue
      case FacultyStatus.onLeave:
        return const Color(0xFFC62828); // Red
      case FacultyStatus.inMeeting:
        return const Color(0xFFE65100); // Orange
    }
  }

  Color get backgroundColor {
    switch (this) {
      case FacultyStatus.active:
        return const Color(0xFFE8F5E9);
      case FacultyStatus.inClass:
        return const Color(0xFFE3F2FD);
      case FacultyStatus.onLeave:
        return const Color(0xFFFFEBEE);
      case FacultyStatus.inMeeting:
        return const Color(0xFFFFF3E0);
    }
  }
}

/// Notice priority level
enum NoticePriority {
  urgent,
  normal,
  academic;

  String get displayName {
    switch (this) {
      case NoticePriority.urgent:
        return 'Urgent Alert';
      case NoticePriority.normal:
        return 'General Notice';
      case NoticePriority.academic:
        return 'Academic Circular';
    }
  }

  Color get color {
    switch (this) {
      case NoticePriority.urgent:
        return const Color(0xFFD32F2F);
      case NoticePriority.normal:
        return const Color(0xFF1976D2);
      case NoticePriority.academic:
        return const Color(0xFF7B1FA2);
    }
  }
}

/// Subject handled by a faculty member
class FacultySubject {
  final String code;
  final String name;
  final String yearSemester;
  final List<String> sections;
  final int unitsCompleted;
  final int totalUnits;
  final int materialsUploaded;

  const FacultySubject({
    required this.code,
    required this.name,
    required this.yearSemester,
    required this.sections,
    required this.unitsCompleted,
    this.totalUnits = 5,
    this.materialsUploaded = 0,
  });

  double get completionPercentage =>
      totalUnits > 0 ? (unitsCompleted / totalUnits).clamp(0.0, 1.0) : 0.0;
}

/// Full faculty profile model for HOD monitoring
class FacultyProfile {
  final String id;
  final String name;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final String cabin;
  final String qualification;
  final int experienceYears;
  final String specialization;
  final FacultyStatus status;
  final List<FacultySubject> subjects;
  final int totalMaterialsUploaded;
  final int totalStudentViews;
  final DateTime lastActiveDate;
  final double rating;
  final bool isHod;
  final String? avatarUrl;

  const FacultyProfile({
    required this.id,
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    required this.cabin,
    required this.qualification,
    required this.experienceYears,
    required this.specialization,
    required this.status,
    required this.subjects,
    this.totalMaterialsUploaded = 0,
    this.totalStudentViews = 0,
    required this.lastActiveDate,
    this.rating = 4.8,
    this.isHod = false,
    this.avatarUrl,
  });

  String get initials {
    final parts = name.replaceAll('Dr. ', '').replaceAll('Prof. ', '').replaceAll('Mr. ', '').replaceAll('Mrs. ', '').replaceAll('Ms. ', '').trim().split(' ');
    if (parts.isEmpty) return 'FC';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  int get totalSubjectsHandled => subjects.length;

  int get totalUnitsCompleted =>
      subjects.fold(0, (sum, sub) => sum + sub.unitsCompleted);

  int get totalUnitsRequired =>
      subjects.fold(0, (sum, sub) => sum + sub.totalUnits);

  double get averageSyllabusCoverage => totalUnitsRequired > 0
      ? (totalUnitsCompleted / totalUnitsRequired).clamp(0.0, 1.0)
      : 0.0;
}

/// AI-identified concept bottleneck where students struggle
class ConceptBottleneck {
  final String concept;
  final String subjectCode;
  final String subjectName;
  final int studentQueryCount;
  final String difficultyLevel;
  final String recommendedAction;

  const ConceptBottleneck({
    required this.concept,
    required this.subjectCode,
    required this.subjectName,
    required this.studentQueryCount,
    required this.difficultyLevel,
    required this.recommendedAction,
  });
}

/// Department summary for high-level monitoring
class DepartmentSummary {
  final String code;
  final String name;
  final String hodName;
  final String hodEmail;
  final String designation;
  final String phone;
  final String cabin;
  final String qualification;
  final String specialization;
  final int totalFaculty;
  final int activeFacultyToday;
  final int totalStudents;
  final int totalSubjects;
  final double averageSyllabusProgress;
  final int totalAppMaterials;
  final int totalStudentInteractions;
  final int aiQueriesHandled;
  final double facultyAdoptionRate;
  final List<ConceptBottleneck> topConceptBottlenecks;

  const DepartmentSummary({
    required this.code,
    required this.name,
    required this.hodName,
    required this.hodEmail,
    this.designation = 'Head of Department & Professor',
    this.phone = '+91 98480 23145',
    this.cabin = 'Department HOD Office',
    this.qualification = 'Ph.D., M.Tech',
    this.specialization = 'Advanced Engineering & Research',
    required this.totalFaculty,
    required this.activeFacultyToday,
    required this.totalStudents,
    required this.totalSubjects,
    required this.averageSyllabusProgress,
    required this.totalAppMaterials,
    required this.totalStudentInteractions,
    required this.aiQueriesHandled,
    required this.facultyAdoptionRate,
    required this.topConceptBottlenecks,
  });
}

/// Department broadcast announcement
class DepartmentNotice {
  final String id;
  final String title;
  final String description;
  final DateTime postedAt;
  final String senderName;
  final NoticePriority priority;
  final String targetAudience;

  const DepartmentNotice({
    required this.id,
    required this.title,
    required this.description,
    required this.postedAt,
    required this.senderName,
    this.priority = NoticePriority.normal,
    this.targetAudience = 'All Faculty & Students',
  });
}

