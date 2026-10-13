import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Service for faculty study material management with anti-spam deduplication.
///
/// Communicates with the Nexora Worker API endpoints:
/// - POST /faculty/materials/check-duplicate
/// - POST /faculty/materials/upload
/// - GET  /faculty/materials
/// - DELETE /faculty/materials/:id
/// - GET  /faculty/analytics/materials/:id/students
/// - GET  /faculty/analytics/subject/:code/insights
class FacultyMaterialsService {
  static const String defaultBaseUrl =
      'https://nexora-bvc-api-2026.vkola306.workers.dev';

  final String baseUrl;
  final http.Client _client;

  FacultyMaterialsService({
    this.baseUrl = defaultBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // SHA-256 Hash (client-side pre-flight)
  // ---------------------------------------------------------------------------

  /// Computes SHA-256 hash of file bytes for deduplication pre-flight check.
  String computeSHA256(Uint8List fileBytes) {
    final digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  // ---------------------------------------------------------------------------
  // API Calls
  // ---------------------------------------------------------------------------

  /// Pre-flight duplicate check before uploading.
  Future<Map<String, dynamic>> checkDuplicate({
    required String firebaseToken,
    required String fileSha256,
    required String subjectCode,
    String? textContent,
  }) async {
    final url = Uri.parse('$baseUrl/faculty/materials/check-duplicate');
    try {
      final body = <String, dynamic>{
        'file_sha256': fileSha256,
        'subject_code': subjectCode,
      };
      if (textContent != null && textContent.isNotEmpty) {
        body['text_content'] = textContent;
      }

      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $firebaseToken',
              'User-Agent': 'Nexora-Flutter-App/1.0',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[FacultyMaterials] checkDuplicate error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Upload study material with automatic deduplication.
  Future<Map<String, dynamic>> uploadMaterial({
    required String firebaseToken,
    required String title,
    required String subjectCode,
    required String subjectName,
    required int unit,
    required String fileSha256,
    required int fileSizeBytes,
    required List<String> chunks,
    String? topic,
    String? textContent,
    String? fileType,
    String? facultyName,
    String? department,
    String? academicYear,
    String? sections,
    bool force = false,
  }) async {
    final url = Uri.parse('$baseUrl/faculty/materials/upload');
    try {
      final body = <String, dynamic>{
        'title': title,
        'subject_code': subjectCode,
        'subject_name': subjectName,
        'unit': unit,
        'file_sha256': fileSha256,
        'file_size_bytes': fileSizeBytes,
        'chunks': chunks,
        'force': force,
      };
      if (topic != null) body['topic'] = topic;
      if (textContent != null) body['text_content'] = textContent;
      if (fileType != null) body['file_type'] = fileType;
      if (facultyName != null) body['faculty_name'] = facultyName;
      if (department != null) body['department'] = department;
      if (academicYear != null) body['academic_year'] = academicYear;
      if (sections != null) body['sections'] = sections;

      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $firebaseToken',
              'User-Agent': 'Nexora-Flutter-App/1.0',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[FacultyMaterials] uploadMaterial error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get all materials uploaded/linked by the authenticated faculty.
  Future<Map<String, dynamic>> getMaterials({
    required String firebaseToken,
  }) async {
    final url = Uri.parse('$baseUrl/faculty/materials');
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $firebaseToken',
              'User-Agent': 'Nexora-Flutter-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[FacultyMaterials] getMaterials error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Delete (unlink) a faculty material share.
  Future<Map<String, dynamic>> deleteMaterial({
    required String firebaseToken,
    required int shareId,
  }) async {
    final url = Uri.parse('$baseUrl/faculty/materials/$shareId');
    try {
      final response = await _client
          .delete(
            url,
            headers: {
              'Authorization': 'Bearer $firebaseToken',
              'User-Agent': 'Nexora-Flutter-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[FacultyMaterials] deleteMaterial error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get student flow analytics for a specific material.
  Future<Map<String, dynamic>> getStudentFlow({
    required String firebaseToken,
    required int canonicalDocId,
  }) async {
    final url = Uri.parse('$baseUrl/faculty/analytics/materials/$canonicalDocId/students');
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $firebaseToken',
              'User-Agent': 'Nexora-Flutter-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[FacultyMaterials] getStudentFlow error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get subject-level analytics and concept difficulty insights.
  Future<Map<String, dynamic>> getSubjectInsights({
    required String firebaseToken,
    required String subjectCode,
  }) async {
    final url = Uri.parse(
        '$baseUrl/faculty/analytics/subject/${Uri.encodeComponent(subjectCode)}/insights');
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $firebaseToken',
              'User-Agent': 'Nexora-Flutter-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[FacultyMaterials] getSubjectInsights error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  void dispose() {
    _client.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final facultyMaterialsServiceProvider = Provider<FacultyMaterialsService>((ref) {
  final service = FacultyMaterialsService();
  ref.onDispose(() => service.dispose());
  return service;
});
