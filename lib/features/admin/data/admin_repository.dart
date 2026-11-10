import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../models/staff_account_model.dart';
import '../../../services/nexora_api_service.dart';

/// Repository for Administrator to create, list, and manage HOD & Faculty accounts
class AdminRepository {
  final String baseUrl;
  final http.Client _client;

  AdminRepository({
    this.baseUrl = NexoraApiService.defaultBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // Local in-memory cache of accounts for instant UI responsiveness
  final List<StaffAccount> _cachedAccounts = [
    StaffAccount(
      id: 'STAFF_001',
      email: 'hod.cse@bvcgroup.in',
      fullName: 'Dr. K. Srinivas Rao',
      role: 'hod',
      department: 'CSE',
      designation: 'Head of Department & Professor',
      phone: '+91 98480 23145',
      cabin: 'R&D Block, Level 3, Room 301',
      qualification: 'Ph.D. (IIT Roorkee), M.Tech',
      specialization: 'Artificial Intelligence, Distributed Databases',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    StaffAccount(
      id: 'STAFF_002',
      email: 'vinaybvcec@bvcgroup.in',
      fullName: 'Mr. Vinay Kola',
      role: 'faculty',
      department: 'CSE',
      designation: 'Assistant Professor & AI Lead',
      phone: '+91 94901 88722',
      cabin: 'Aryabhata Block, Room 208',
      qualification: 'M.Tech (CSE), B.Tech',
      specialization: 'Machine Learning, Mobile Architecture',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    StaffAccount(
      id: 'STAFF_003',
      email: 'hod.csm@bvcgroup.in',
      fullName: 'Dr. M. V. Rajesh',
      role: 'hod',
      department: 'CSM',
      designation: 'Head of Department & Professor',
      phone: '+91 98480 34567',
      cabin: 'Sir MV Block, Room 201',
      qualification: 'Ph.D. (JNTUK)',
      specialization: 'Deep Learning, Neural Systems',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
    ),
    StaffAccount(
      id: 'STAFF_004',
      email: 'hod.ece@bvcgroup.in',
      fullName: 'Dr. G. Rama Murthy',
      role: 'hod',
      department: 'ECE',
      designation: 'Head of Department & Professor',
      phone: '+91 98480 56789',
      cabin: 'Aryabhata Block, Room 101',
      qualification: 'Ph.D. (IIT Madras)',
      specialization: 'VLSI Design, Signal Processing',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 28)),
    ),
  ];

  /// Get admin auth header (Firebase ID token or admin secret)
  Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Admin-Key': 'bvc_admin_production_secret_2026',
    };
  }

  /// List all HOD and Faculty accounts
  Future<List<StaffAccount>> getAccounts({String? role, String? department}) async {
    try {
      final queryParams = <String, String>{};
      if (role != null) queryParams['role'] = role;
      if (department != null) queryParams['department'] = department;

      final uri = Uri.parse('$baseUrl/admin/accounts').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final headers = await _getHeaders();

      final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final list = (body['accounts'] as List<dynamic>? ?? [])
            .map((item) => StaffAccount.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          return list;
        }
      }
    } catch (e) {
      debugPrint('[AdminRepository] getAccounts network fallback: $e');
    }

    // Filter local cached accounts
    return _cachedAccounts.where((a) {
      final matchesRole = role == null || a.role.toLowerCase() == role.toLowerCase();
      final matchesDept = department == null || a.department.toUpperCase() == department.toUpperCase();
      return matchesRole && matchesDept && a.isActive;
    }).toList();
  }

  /// Create a new HOD or Faculty account and automatically trigger invitation / password setup email
  Future<StaffAccount> createAccount({
    required String email,
    required String fullName,
    required String role,
    required String department,
    String? designation,
    String? phone,
    String? cabin,
    String? qualification,
    String? specialization,
    bool sendInvitation = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanRole = role.trim().toLowerCase();

    // 1. Post to backend worker API
    try {
      final uri = Uri.parse('$baseUrl/admin/accounts');
      final headers = await _getHeaders();
      final payload = jsonEncode({
        'email': cleanEmail,
        'fullName': fullName.trim(),
        'role': cleanRole,
        'department': department.trim().toUpperCase(),
        'designation': designation?.trim(),
        'phone': phone?.trim(),
        'cabin': cabin?.trim(),
        'qualification': qualification?.trim(),
        'specialization': specialization?.trim(),
      });

      final res = await _client.post(uri, headers: headers, body: payload).timeout(const Duration(seconds: 10));
      debugPrint('[AdminRepository] createAccount response: ${res.statusCode}');
    } catch (e) {
      debugPrint('[AdminRepository] Backend account sync notice: $e');
    }

    // 2. Trigger Firebase password reset / setup email so HOD/Faculty can set their password
    if (sendInvitation) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
        debugPrint('[AdminRepository] Password invitation email sent to $cleanEmail');
      } catch (e) {
        debugPrint('[AdminRepository] Note on sending invitation email: $e');
      }
    }

    final newAccount = StaffAccount(
      id: 'STAFF_${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      fullName: fullName.trim(),
      role: cleanRole,
      department: department.trim().toUpperCase(),
      designation: designation?.trim() ?? (cleanRole == 'hod' ? 'Head of Department' : 'Faculty Member'),
      phone: phone?.trim(),
      cabin: cabin?.trim(),
      qualification: qualification?.trim(),
      specialization: specialization?.trim(),
      isActive: true,
      createdAt: DateTime.now(),
    );

    _cachedAccounts.insert(0, newAccount);
    return newAccount;
  }

  /// Deactivate an account
  Future<bool> deactivateAccount(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/admin/accounts/$id');
      final headers = await _getHeaders();
      await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 8));
    } catch (_) {}

    final idx = _cachedAccounts.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _cachedAccounts[idx] = _cachedAccounts[idx].copyWith(isActive: false);
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final staffAccountsProvider = FutureProvider.family<List<StaffAccount>, ({String? role, String? department})>(
  (ref, filters) async {
    final repo = ref.watch(adminRepositoryProvider);
    return repo.getAccounts(role: filters.role, department: filters.department);
  },
);
