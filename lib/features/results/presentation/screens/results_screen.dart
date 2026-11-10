import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../authentication/data/auth_service.dart';

class StudentResultsState {
  final String rollNumber;
  final List<Map<String, dynamic>> results;

  const StudentResultsState({
    required this.rollNumber,
    required this.results,
  });
}

final studentResultsProvider = FutureProvider.autoDispose<StudentResultsState>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final token = await authService.getIdToken();
  final currentUser = FirebaseAuth.instance.currentUser;

  String fallbackRoll = '';
  if (currentUser?.email != null) {
    fallbackRoll = currentUser!.email!.split('@').first.toUpperCase().trim();
  }

  final url = Uri.parse('${AppConstants.workerBaseUrl}/student/results');
  final res = await http.get(
    url,
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'Nexora-Flutter-App/1.0',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    },
  ).timeout(const Duration(seconds: 10));

  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    if (data['success'] == true && data['results'] is List) {
      final roll = data['roll_number']?.toString().toUpperCase() ?? fallbackRoll;
      final list = (data['results'] as List).cast<Map<String, dynamic>>();
      return StudentResultsState(rollNumber: roll, results: list);
    }
  }
  return StudentResultsState(rollNumber: fallbackRoll, results: []);
});

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(studentResultsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Academic Results',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: resultsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF818CF8)),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load results',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                ),
                onPressed: () => ref.invalidate(studentResultsProvider),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (data) {
          final results = data.results;

          if (results.isEmpty) {
            return RefreshIndicator(
              color: const Color(0xFF818CF8),
              backgroundColor: const Color(0xFF1E293B),
              onRefresh: () async => ref.invalidate(studentResultsProvider),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (data.rollNumber.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined, color: Color(0xFF818CF8), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Student Roll: ${data.rollNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            size: 52,
                            color: Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Published Results Yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.rollNumber.isNotEmpty
                              ? 'No examination marks released for roll ${data.rollNumber} yet. Results will appear here automatically as soon as published by the BVC examination cell.'
                              : 'Results will appear here automatically when uploaded by administration.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                          label: const Text('Check for Updates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          onPressed: () => ref.invalidate(studentResultsProvider),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Calculate latest SGPA and CGPA
          final double? latestSgpa = results.first['sgpa'] != null
              ? double.tryParse(results.first['sgpa'].toString())
              : null;
          final double? latestCgpa = results.first['cgpa'] != null
              ? double.tryParse(results.first['cgpa'].toString())
              : null;

          return RefreshIndicator(
            color: const Color(0xFF818CF8),
            backgroundColor: const Color(0xFF1E293B),
            onRefresh: () async => ref.invalidate(studentResultsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Roll Number & Verification Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF818CF8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Roll No: ${data.rollNumber.isNotEmpty ? data.rollNumber : "BVC Student"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'BVC Engineering College • Official Examination Record',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: const Text(
                          'VERIFIED',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Top SGPA Card
                if (latestSgpa != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latest Semester Performance',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SGPA: ${latestSgpa.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (latestCgpa != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Cumulative CGPA: ${latestCgpa.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.amberAccent,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Text(
                  'Course Breakdown',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                ...results.map((rec) {
                  final grade = rec['grade']?.toString() ?? '-';
                  final rawStatus = (rec['status'] ?? rec['result_status'] ?? '').toString().toUpperCase();
                  final isPass = rawStatus.isEmpty ? (grade != 'F') : (rawStatus == 'PASS');
                  final credits = rec['credits']?.toString() ?? '3';
                  final gradePoints = rec['grade_points']?.toString();
                  final examPeriod = rec['exam_month_year']?.toString();

                  Color gradeColor = const Color(0xFF10B981);
                  if (grade == 'F') {
                    gradeColor = Colors.redAccent;
                  } else if (grade.startsWith('B')) {
                    gradeColor = const Color(0xFF38BDF8);
                  } else if (grade.startsWith('C') || grade.startsWith('D')) {
                    gradeColor = const Color(0xFFFBBF24);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec['subject_name']?.toString() ?? 'Academic Subject',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    '${rec['subject_code'] ?? 'SUB'} • Sem ${rec['semester'] ?? 2}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.55),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '• $credits Credits',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.55),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (gradePoints != null)
                                    Text(
                                      '• $gradePoints GP',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.55),
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (examPeriod != null && examPeriod.isNotEmpty)
                                    Text(
                                      '• $examPeriod',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: gradeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: gradeColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                'Grade $grade',
                                style: TextStyle(
                                  color: gradeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPass ? 'PASS' : 'FAIL',
                              style: TextStyle(
                                color: isPass ? const Color(0xFF10B981) : Colors.redAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
