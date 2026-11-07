import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/hod_models.dart';

/// Repository for HOD department analytics, faculty profiles, and college academic data
class HodRepository {
  /// Supported departments at BVC Engineering College
  static const List<Map<String, String>> departments = [
    {
      'code': 'CSE',
      'name': 'Computer Science & Engineering',
      'icon': 'computer',
    },
    {
      'code': 'CSM',
      'name': 'CSE (AI & Machine Learning)',
      'icon': 'psychology',
    },
    {
      'code': 'CAD',
      'name': 'CSE (AI & Data Science)',
      'icon': 'analytics',
    },
    {
      'code': 'ECE',
      'name': 'Electronics & Communication',
      'icon': 'memory',
    },
    {
      'code': 'IT',
      'name': 'Information Technology',
      'icon': 'devices',
    },
    {
      'code': 'EEE',
      'name': 'Electrical & Electronics',
      'icon': 'bolt',
    },
    {
      'code': 'MECH',
      'name': 'Mechanical Engineering',
      'icon': 'build',
    },
    {
      'code': 'CIVIL',
      'name': 'Civil Engineering',
      'icon': 'apartment',
    },
  ];

  // In-memory notices broadcast list
  final List<DepartmentNotice> _notices = [
    DepartmentNotice(
      id: 'NOT_001',
      title: 'Mid-Term Exam Question Bank Submission',
      description:
          'All faculty handling 2nd & 3rd B.Tech subjects are requested to upload Unit 1-3 model question banks on Nexora before Friday 5:00 PM.',
      postedAt: DateTime.now().subtract(const Duration(hours: 3)),
      senderName: 'Dr. K. Srinivas Rao (HOD - CSE)',
      priority: NoticePriority.urgent,
      targetAudience: 'Department Faculty',
    ),
    DepartmentNotice(
      id: 'NOT_002',
      title: 'AI Study Material Verification & Duplication Audit',
      description:
          'Nexora deduplication system reported 100% verification for CADS and OS notes. Ensure handwritten notes are scanned with high contrast.',
      postedAt: DateTime.now().subtract(const Duration(days: 1)),
      senderName: 'Nexora Academic Admin',
      priority: NoticePriority.academic,
      targetAudience: 'Faculty & Lab Coordinators',
    ),
    DepartmentNotice(
      id: 'NOT_003',
      title: 'Department Faculty Meeting - NAAC & Curriculum Review',
      description:
          'Monthly departmental review meeting will be held in the Department Seminar Hall on Wednesday at 3:30 PM.',
      postedAt: DateTime.now().subtract(const Duration(days: 3)),
      senderName: 'Dr. K. Srinivas Rao (HOD)',
      priority: NoticePriority.normal,
      targetAudience: 'All Staff Members',
    ),
  ];

  /// Get summary metrics for the given department
  Future<DepartmentSummary> getDepartmentSummary(String departmentCode) async {
    // Simulated network delay
    await Future.delayed(const Duration(milliseconds: 150));

    switch (departmentCode.toUpperCase()) {
      case 'CSE':
        return DepartmentSummary(
          code: 'CSE',
          name: 'Computer Science & Engineering',
          hodName: 'Dr. K. Srinivas Rao, Ph.D.',
          hodEmail: 'hod.cse@bvcgroup.in',
          totalFaculty: 24,
          activeFacultyToday: 21,
          totalStudents: 740,
          totalSubjects: 18,
          averageSyllabusProgress: 0.82,
          totalAppMaterials: 148,
          totalStudentInteractions: 4890,
          aiQueriesHandled: 2340,
          facultyAdoptionRate: 0.95,
          topConceptBottlenecks: const [
            ConceptBottleneck(
              concept: 'B-Trees & Multi-Way Indexing',
              subjectCode: 'CS501PC',
              subjectName: 'Advanced Data Structures (CADS)',
              studentQueryCount: 384,
              difficultyLevel: 'High',
              recommendedAction: 'Schedule extra doubt clearing session on B-tree rotations',
            ),
            ConceptBottleneck(
              concept: "Banker's Algorithm & Deadlock Avoidance",
              subjectCode: 'CS502PC',
              subjectName: 'Operating Systems',
              studentQueryCount: 295,
              difficultyLevel: 'Moderate',
              recommendedAction: 'Share step-by-step state matrix video walk-through',
            ),
            ConceptBottleneck(
              concept: 'TCP Congestion Window & Tahoe vs Reno',
              subjectCode: 'CS503PC',
              subjectName: 'Computer Networks',
              studentQueryCount: 240,
              difficultyLevel: 'Moderate',
              recommendedAction: 'Provide visual timing diagram sheet',
            ),
          ],
        );

      case 'CSM':
        return DepartmentSummary(
          code: 'CSM',
          name: 'CSE (AI & Machine Learning)',
          hodName: 'Dr. M. V. Rajesh, Ph.D.',
          hodEmail: 'hod.csm@bvcgroup.in',
          totalFaculty: 16,
          activeFacultyToday: 15,
          totalStudents: 420,
          totalSubjects: 14,
          averageSyllabusProgress: 0.78,
          totalAppMaterials: 104,
          totalStudentInteractions: 3120,
          aiQueriesHandled: 1850,
          facultyAdoptionRate: 0.93,
          topConceptBottlenecks: const [
            ConceptBottleneck(
              concept: 'Backpropagation Gradient Derivation',
              subjectCode: 'AIM301PC',
              subjectName: 'Deep Learning Architectures',
              studentQueryCount: 260,
              difficultyLevel: 'High',
              recommendedAction: 'Distribute vector calculus review sheet',
            ),
            ConceptBottleneck(
              concept: 'Support Vector Machine Kernel Trick',
              subjectCode: 'AIM302PC',
              subjectName: 'Statistical Machine Learning',
              studentQueryCount: 198,
              difficultyLevel: 'Moderate',
              recommendedAction: 'Add 3D hyper-plane visualization to app notes',
            ),
          ],
        );

      case 'ECE':
        return DepartmentSummary(
          code: 'ECE',
          name: 'Electronics & Communication',
          hodName: 'Dr. G. Rama Murthy, Ph.D.',
          hodEmail: 'hod.ece@bvcgroup.in',
          totalFaculty: 22,
          activeFacultyToday: 19,
          totalStudents: 680,
          totalSubjects: 16,
          averageSyllabusProgress: 0.75,
          totalAppMaterials: 118,
          totalStudentInteractions: 3450,
          aiQueriesHandled: 1420,
          facultyAdoptionRate: 0.88,
          topConceptBottlenecks: const [
            ConceptBottleneck(
              concept: 'Nyquist Plot Stability Criteria',
              subjectCode: 'EC401PC',
              subjectName: 'Control Systems',
              studentQueryCount: 215,
              difficultyLevel: 'High',
              recommendedAction: 'Conduct lab demonstration with MATLAB simulation',
            ),
          ],
        );

      default:
        return DepartmentSummary(
          code: departmentCode,
          name: '$departmentCode Department',
          hodName: 'Dr. Faculty In-Charge, Ph.D.',
          hodEmail: 'hod.${departmentCode.toLowerCase()}@bvcgroup.in',
          totalFaculty: 14,
          activeFacultyToday: 12,
          totalStudents: 360,
          totalSubjects: 12,
          averageSyllabusProgress: 0.70,
          totalAppMaterials: 72,
          totalStudentInteractions: 1680,
          aiQueriesHandled: 820,
          facultyAdoptionRate: 0.85,
          topConceptBottlenecks: const [
            ConceptBottleneck(
              concept: 'Core Subject Fundamentals & Numerical Problem Solving',
              subjectCode: 'ENG201',
              subjectName: 'Engineering Mathematics & Core Fundamentals',
              studentQueryCount: 140,
              difficultyLevel: 'Moderate',
              recommendedAction: 'Upload solved previous question paper solutions',
            ),
          ],
        );
    }
  }

  /// Get list of faculty profiles for a specific department
  Future<List<FacultyProfile>> getDepartmentFaculty(String departmentCode) async {
    await Future.delayed(const Duration(milliseconds: 150));

    if (departmentCode.toUpperCase() == 'CSE') {
      return [
        FacultyProfile(
          id: 'BVC_FAC_CSE_001',
          name: 'Dr. K. Srinivas Rao',
          designation: 'Head of Department & Professor',
          department: 'Computer Science & Engineering',
          email: 'hod.cse@bvcgroup.in',
          phone: '+91 98480 23145',
          cabin: 'R&D Block, Level 3, Room 301',
          qualification: 'Ph.D. (IIT Roorkee), M.Tech (CSE)',
          experienceYears: 18,
          specialization: 'Artificial Intelligence, Distributed Databases',
          status: FacultyStatus.active,
          isHod: true,
          rating: 4.9,
          totalMaterialsUploaded: 24,
          totalStudentViews: 1420,
          lastActiveDate: DateTime.now().subtract(const Duration(minutes: 42)),
          subjects: const [
            FacultySubject(
              code: 'CS501PC',
              name: 'Advanced Data Structures (CADS)',
              yearSemester: '3rd B.Tech, 1st Sem',
              sections: ['CSE-A', 'CSE-B'],
              unitsCompleted: 4,
              totalUnits: 5,
              materialsUploaded: 14,
            ),
            FacultySubject(
              code: 'CS702PE',
              name: 'Distributed Cloud Architecture',
              yearSemester: '4th B.Tech, 1st Sem',
              sections: ['CSE-A'],
              unitsCompleted: 5,
              totalUnits: 5,
              materialsUploaded: 10,
            ),
          ],
        ),
        FacultyProfile(
          id: 'BVC_FAC_CSE_002',
          name: 'Mr. Vinay Kola',
          designation: 'Assistant Professor & AI Lead',
          department: 'Computer Science & Engineering',
          email: 'vinaybvcec@bvcgroup.in',
          phone: '+91 94901 88722',
          cabin: 'Aryabhata Block, Room 208',
          qualification: 'M.Tech (CSE), B.Tech (CSE)',
          experienceYears: 7,
          specialization: 'Machine Learning, RAG Grounding & Mobile Architecture',
          status: FacultyStatus.active,
          rating: 4.95,
          totalMaterialsUploaded: 32,
          totalStudentViews: 2150,
          lastActiveDate: DateTime.now().subtract(const Duration(minutes: 15)),
          subjects: const [
            FacultySubject(
              code: 'CS501PC',
              name: 'Advanced Data Structures & Algorithms',
              yearSemester: '3rd B.Tech, 1st Sem',
              sections: ['CSE-A', 'CSE-C'],
              unitsCompleted: 4,
              totalUnits: 5,
              materialsUploaded: 18,
            ),
            FacultySubject(
              code: 'CS603PC',
              name: 'Artificial Intelligence & Neural Systems',
              yearSemester: '3rd B.Tech, 2nd Sem',
              sections: ['CSE-B', 'CSE-C'],
              unitsCompleted: 3,
              totalUnits: 5,
              materialsUploaded: 14,
            ),
          ],
        ),
        FacultyProfile(
          id: 'BVC_FAC_CSE_003',
          name: 'Dr. V. Lakshmi Devi',
          designation: 'Associate Professor',
          department: 'Computer Science & Engineering',
          email: 'lakshmidevi.cse@bvcgroup.in',
          phone: '+91 98492 54321',
          cabin: 'Aryabhata Block, Room 212',
          qualification: 'Ph.D. (JNTUK), M.Tech',
          experienceYears: 14,
          specialization: 'Operating Systems & System Virtualization',
          status: FacultyStatus.inClass,
          rating: 4.8,
          totalMaterialsUploaded: 18,
          totalStudentViews: 980,
          lastActiveDate: DateTime.now().subtract(const Duration(hours: 1)),
          subjects: const [
            FacultySubject(
              code: 'CS502PC',
              name: 'Operating Systems',
              yearSemester: '3rd B.Tech, 1st Sem',
              sections: ['CSE-A', 'CSE-B', 'CSE-C'],
              unitsCompleted: 4,
              totalUnits: 5,
              materialsUploaded: 12,
            ),
          ],
        ),
        FacultyProfile(
          id: 'BVC_FAC_CSE_004',
          name: 'Prof. P. Ramana Murthy',
          designation: 'Professor & Dean Academics',
          department: 'Computer Science & Engineering',
          email: 'ramanamurthy.cse@bvcgroup.in',
          phone: '+91 94403 67890',
          cabin: 'Administrative Wing, Room 104',
          qualification: 'Ph.D. (AU), M.E. (Computer Engg)',
          experienceYears: 22,
          specialization: 'Database Management Systems & Information Retrieval',
          status: FacultyStatus.inMeeting,
          rating: 4.75,
          totalMaterialsUploaded: 16,
          totalStudentViews: 840,
          lastActiveDate: DateTime.now().subtract(const Duration(hours: 3)),
          subjects: const [
            FacultySubject(
              code: 'CS401PC',
              name: 'Database Management Systems',
              yearSemester: '2nd B.Tech, 2nd Sem',
              sections: ['CSE-A', 'CSE-B'],
              unitsCompleted: 5,
              totalUnits: 5,
              materialsUploaded: 16,
            ),
          ],
        ),
        FacultyProfile(
          id: 'BVC_FAC_CSE_005',
          name: 'Mrs. S. Radhika',
          designation: 'Assistant Professor',
          department: 'Computer Science & Engineering',
          email: 'radhika.cse@bvcgroup.in',
          phone: '+91 97011 22334',
          cabin: 'Aryabhata Block, Room 215',
          qualification: 'M.Tech (Software Engg)',
          experienceYears: 8,
          specialization: 'Computer Networks, Network Security',
          status: FacultyStatus.active,
          rating: 4.7,
          totalMaterialsUploaded: 15,
          totalStudentViews: 690,
          lastActiveDate: DateTime.now().subtract(const Duration(hours: 2)),
          subjects: const [
            FacultySubject(
              code: 'CS503PC',
              name: 'Computer Networks',
              yearSemester: '3rd B.Tech, 1st Sem',
              sections: ['CSE-A', 'CSE-C'],
              unitsCompleted: 3,
              totalUnits: 5,
              materialsUploaded: 15,
            ),
          ],
        ),
        FacultyProfile(
          id: 'BVC_FAC_CSE_006',
          name: 'Mr. B. Suresh Kumar',
          designation: 'Assistant Professor & Lab In-Charge',
          department: 'Computer Science & Engineering',
          email: 'sureshkumar.cse@bvcgroup.in',
          phone: '+91 98850 77665',
          cabin: 'Computing Lab 3, Ground Floor',
          qualification: 'M.Tech (CSE)',
          experienceYears: 6,
          specialization: 'Web Technologies, Full Stack Frameworks',
          status: FacultyStatus.onLeave,
          rating: 4.65,
          totalMaterialsUploaded: 12,
          totalStudentViews: 520,
          lastActiveDate: DateTime.now().subtract(const Duration(days: 1)),
          subjects: const [
            FacultySubject(
              code: 'CS504PC',
              name: 'Web Technologies & Cloud Services',
              yearSemester: '3rd B.Tech, 1st Sem',
              sections: ['CSE-B'],
              unitsCompleted: 3,
              totalUnits: 5,
              materialsUploaded: 12,
            ),
          ],
        ),
      ];
    } else {
      // Generic faculty list for other departments
      return [
        FacultyProfile(
          id: 'BVC_FAC_${departmentCode}_001',
          name: 'Dr. Head of Department',
          designation: 'HOD & Professor',
          department: departmentCode,
          email: 'hod.${departmentCode.toLowerCase()}@bvcgroup.in',
          phone: '+91 98480 00001',
          cabin: 'Department Block, Room 201',
          qualification: 'Ph.D., M.Tech',
          experienceYears: 16,
          specialization: '$departmentCode Core Research & Advanced Systems',
          status: FacultyStatus.active,
          isHod: true,
          rating: 4.85,
          totalMaterialsUploaded: 22,
          totalStudentViews: 1100,
          lastActiveDate: DateTime.now().subtract(const Duration(hours: 1)),
          subjects: [
            FacultySubject(
              code: '${departmentCode}501',
              name: '$departmentCode Core Systems & Design',
              yearSemester: '3rd B.Tech, 1st Sem',
              sections: ['Section A', 'Section B'],
              unitsCompleted: 4,
              totalUnits: 5,
              materialsUploaded: 14,
            ),
          ],
        ),
        FacultyProfile(
          id: 'BVC_FAC_${departmentCode}_002',
          name: 'Prof. Senior Lecturer',
          designation: 'Associate Professor',
          department: departmentCode,
          email: 'senior.${departmentCode.toLowerCase()}@bvcgroup.in',
          phone: '+91 98480 00002',
          cabin: 'Department Block, Room 204',
          qualification: 'M.Tech',
          experienceYears: 11,
          specialization: '$departmentCode Applications & Lab Design',
          status: FacultyStatus.active,
          rating: 4.7,
          totalMaterialsUploaded: 16,
          totalStudentViews: 750,
          lastActiveDate: DateTime.now().subtract(const Duration(hours: 4)),
          subjects: [
            FacultySubject(
              code: '${departmentCode}502',
              name: '$departmentCode Analytical Applications',
              yearSemester: '3rd B.Tech, 1st Sem',
              sections: ['Section A'],
              unitsCompleted: 3,
              totalUnits: 5,
              materialsUploaded: 10,
            ),
          ],
        ),
      ];
    }
  }

  /// Get active department notices
  Future<List<DepartmentNotice>> getNotices(String departmentCode) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_notices);
  }

  /// Post a new department notice
  Future<bool> postNotice({
    required String title,
    required String description,
    required String senderName,
    required NoticePriority priority,
    required String targetAudience,
  }) async {
    final notice = DepartmentNotice(
      id: 'NOT_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      postedAt: DateTime.now(),
      senderName: senderName,
      priority: priority,
      targetAudience: targetAudience,
    );
    _notices.insert(0, notice);
    return true;
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final hodRepositoryProvider = Provider<HodRepository>((ref) {
  return HodRepository();
});

/// Selected department state provider (defaults to CSE)
final selectedDepartmentProvider = StateProvider<String>((ref) => 'CSE');

/// Future provider for the department summary
final departmentSummaryProvider =
    FutureProvider.family<DepartmentSummary, String>((ref, departmentCode) async {
  final repo = ref.watch(hodRepositoryProvider);
  return repo.getDepartmentSummary(departmentCode);
});

/// Future provider for the faculty list
final departmentFacultyProvider =
    FutureProvider.family<List<FacultyProfile>, String>((ref, departmentCode) async {
  final repo = ref.watch(hodRepositoryProvider);
  return repo.getDepartmentFaculty(departmentCode);
});

/// Future provider for department notices
final departmentNoticesProvider =
    FutureProvider.family<List<DepartmentNotice>, String>((ref, departmentCode) async {
  final repo = ref.watch(hodRepositoryProvider);
  return repo.getNotices(departmentCode);
});

