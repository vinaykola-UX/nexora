import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/search_response_model.dart';

/// Service for communicating with the Nexora Cloudflare Worker API
class NexoraApiService {
  static const String defaultBaseUrl =
      'https://nexora-bvc-api-2026.vkola306.workers.dev';

  final String baseUrl;
  final http.Client _client;

  NexoraApiService({
    this.baseUrl = defaultBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Searches official BVC Engineering College portals via the Cloudflare Worker retrieval backend.
  Future<NexoraSearchResponse> searchOfficialSources(String studentQuestion) async {
    final query = studentQuestion.trim();
    if (query.isEmpty) {
      return NexoraSearchResponse.failure(
        query,
        'Please enter a question to search.',
      );
    }

    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('$baseUrl/search?q=$encodedQuery');

    debugPrint('[NexoraApiService] Requesting: $url');

    try {
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Nexora-Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('[NexoraApiService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return NexoraSearchResponse.fromJson(json);
      } else if (response.statusCode == 400) {
        try {
          final Map<String, dynamic> json =
              jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final msg = json['message'] as String? ?? 'Invalid search query.';
          return NexoraSearchResponse.failure(query, msg);
        } catch (_) {
          return NexoraSearchResponse.failure(
            query,
            'Bad request. Please refine your query.',
          );
        }
      } else if (response.statusCode >= 500) {
        return NexoraSearchResponse.failure(
          query,
          'The college server or retrieval service encountered an error. Please try again in a few moments.',
        );
      } else {
        return NexoraSearchResponse.failure(
          query,
          'Unable to retrieve data (HTTP ${response.statusCode}).',
        );
      }
    } on SocketException catch (e) {
      debugPrint('[NexoraApiService] SocketException: $e');
      return NexoraSearchResponse.failure(
        query,
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException catch (e) {
      debugPrint('[NexoraApiService] TimeoutException: $e');
      return NexoraSearchResponse.failure(
        query,
        'The request timed out. The college portal may be responding slowly. Please try again.',
      );
    } on FormatException catch (e) {
      debugPrint('[NexoraApiService] FormatException: $e');
      return NexoraSearchResponse.failure(
        query,
        'Unexpected response format from retrieval server.',
      );
    } catch (e) {
      debugPrint('[NexoraApiService] General error: $e');
      return NexoraSearchResponse.failure(
        query,
        'An unexpected error occurred while contacting the college database.',
      );
    }
  }

  /// Verifies whether faculty email or similar identity data exists on official BVC Odalarevu college portals
  Future<Map<String, dynamic>> verifyFacultyOfficial(String facultyEmail) async {
    final cleanEmail = facultyEmail.trim().toLowerCase();
    final username = cleanEmail.split('@').first;

    try {
      final verifyUrl = Uri.parse('$baseUrl/faculty/verify?email=${Uri.encodeComponent(cleanEmail)}');
      final res = await _client.get(
        verifyUrl,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Nexora-Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return decoded;
      }
    } catch (e) {
      debugPrint('[NexoraApiService] Direct /faculty/verify notice: $e');
    }

    // Fallback: Query official college website search with faculty username
    try {
      final searchResult = await searchOfficialSources(username);
      final isBvc = cleanEmail.endsWith('@bvcgroup.in') || cleanEmail.endsWith('@bvcec.edu.in');
      return {
        'verified': isBvc,
        'email': cleanEmail,
        'username': username,
        'college': 'BVC Engineering College, Odalarevu',
        'officialPortalMatches': searchResult.results.length,
      };
    } catch (_) {
      return {
        'verified': cleanEmail.endsWith('@bvcgroup.in'),
        'email': cleanEmail,
        'username': username,
        'college': 'BVC Engineering College, Odalarevu',
        'officialPortalMatches': 0,
      };
    }
  }

  void dispose() {
    _client.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final nexoraApiServiceProvider = Provider<NexoraApiService>((ref) {
  final service = NexoraApiService();
  ref.onDispose(() => service.dispose());
  return service;
});
