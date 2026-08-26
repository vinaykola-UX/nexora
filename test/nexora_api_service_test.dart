import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora/models/search_response_model.dart';
import 'package:nexora/services/nexora_api_service.dart';

void main() {
  group('NexoraSearchResponse Model Tests', () {
    test('Correctly parses successful search response JSON', () {
      final json = {
        'success': true,
        'query': 'BR23',
        'results': [
          {
            'title': 'I B.TECH II SEMESTER (BR23) Regular Examinations, June 2026',
            'url': 'https://bvcec.edu.in/i-b-tech-ii-semester-br23-regular-examinations-june-202/',
            'source': 'BVC Engineering College',
            'snippet': 'Official BVC Engineering College portal information for BR23.',
            'publishedDate': 'August 4, 2026',
          }
        ],
        'sources': [
          {
            'title': 'BVC Engineering College Official Portal',
            'url': 'https://bvcec.edu.in',
          }
        ],
      };

      final response = NexoraSearchResponse.fromJson(json);

      expect(response.success, true);
      expect(response.query, 'BR23');
      expect(response.results.length, 1);
      expect(response.results.first.title, 'I B.TECH II SEMESTER (BR23) Regular Examinations, June 2026');
      expect(response.results.first.url, 'https://bvcec.edu.in/i-b-tech-ii-semester-br23-regular-examinations-june-202/');
      expect(response.results.first.source, 'BVC Engineering College');
      expect(response.results.first.publishedDate, 'August 4, 2026');
      expect(response.sources.length, 1);
      expect(response.sources.first.url, 'https://bvcec.edu.in');
    });

    test('Correctly handles empty results response', () {
      final json = {
        'success': true,
        'query': 'xyz non-existent query',
        'results': [],
        'sources': [],
        'message': 'No relevant information was found from the currently configured official BVC sources.',
      };

      final response = NexoraSearchResponse.fromJson(json);

      expect(response.success, true);
      expect(response.results.isEmpty, true);
      expect(response.message, contains('No relevant information was found'));
    });

    test('Failure constructor sets error and success=false', () {
      final failure = NexoraSearchResponse.failure('test', 'Network timeout');
      expect(failure.success, false);
      expect(failure.error, 'Network timeout');
    });
  });

  group('NexoraApiService Unit Tests', () {
    test('searchOfficialSources properly URL-encodes query and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['q'], 'BR23 exam');
        return http.Response(
          jsonEncode({
            'success': true,
            'query': 'BR23 exam',
            'results': [
              {
                'title': 'BR23 Supplementary Exam Notice',
                'url': 'https://bvcec.edu.in/notice-1',
                'source': 'BVC Engineering College',
                'snippet': 'Exam notice details',
                'publishedDate': 'June 2026',
              }
            ],
            'sources': [
              {
                'title': 'BVC Official Portal',
                'url': 'https://bvcec.edu.in',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = NexoraApiService(client: mockClient);
      final response = await service.searchOfficialSources('BR23 exam');

      expect(response.success, true);
      expect(response.results.length, 1);
      expect(response.results.first.title, 'BR23 Supplementary Exam Notice');
    });

    test('searchOfficialSources handles empty query locally without calling network', () async {
      final service = NexoraApiService();
      final response = await service.searchOfficialSources('   ');

      expect(response.success, false);
      expect(response.error, contains('Please enter a question'));
    });

    test('searchOfficialSources handles HTTP 500 error gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = NexoraApiService(client: mockClient);
      final response = await service.searchOfficialSources('valid query');

      expect(response.success, false);
      expect(response.error, contains('college server or retrieval service encountered an error'));
    });
  });
}
