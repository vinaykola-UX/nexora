import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora/services/rag_service.dart';

void main() {
  group('RAG Models Tests', () {
    test('RagDocument parses JSON correctly', () {
      final json = {
        'id': 1,
        'title': 'Data Structures - Unit II: Linked Lists',
        'subject': 'Data Structures',
        'unit': 2,
      };

      final doc = RagDocument.fromJson(json);
      expect(doc.id, 1);
      expect(doc.title, 'Data Structures - Unit II: Linked Lists');
      expect(doc.subject, 'Data Structures');
      expect(doc.unit, 2);
      expect(doc.toJson()['id'], 1);
    });

    test('RagChunk parses JSON correctly', () {
      final json = {
        'content': 'DOUBLY LINKED LIST  A doubly linked list contains nodes with three parts...',
        'title': 'Data Structures - Unit II: Linked Lists',
        'subject': 'Data Structures',
        'unit': 2,
      };

      final chunk = RagChunk.fromJson(json);
      expect(chunk.title, 'Data Structures - Unit II: Linked Lists');
      expect(chunk.subject, 'Data Structures');
      expect(chunk.unit, 2);
      expect(chunk.content, contains('DOUBLY LINKED LIST'));
      expect(chunk.toJson()['subject'], 'Data Structures');
    });

    test('RagSearchResponse formats content and sourceLabel correctly', () {
      final chunk = RagChunk(
        content: 'DOUBLY LINKED LIST\n\nPoints:\n1. Previous pointer\n2. Data\n3. Next pointer',
        title: 'Data Structures - Unit II: Linked Lists',
        subject: 'Data Structures',
        unit: 2,
      );

      final response = RagSearchResponse(
        query: 'doubly',
        results: [chunk],
        success: true,
      );

      expect(response.hasResults, true);
      expect(response.sourceLabel, 'Data Structures • Unit II');
      expect(response.toFormattedContent(), contains('DOUBLY LINKED LIST'));
    });

    test('RagSearchResponse failure constructor works', () {
      final failure = RagSearchResponse.failure('test', 'Network error');
      expect(failure.success, false);
      expect(failure.hasResults, false);
      expect(failure.error, 'Network error');
      expect(failure.sourceLabel, isNull);
    });
  });

  group('RagService Unit Tests', () {
    test('getDocuments calls /documents and parses document list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/documents');
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'title': 'Data Structures - Unit II: Linked Lists',
              'subject': 'Data Structures',
              'unit': 2,
            }
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = RagService(client: mockClient);
      final docs = await service.getDocuments();

      expect(docs.length, 1);
      expect(docs.first['title'], 'Data Structures - Unit II: Linked Lists');
    });

    test('searchDocuments properly encodes query parameters', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/search');
        expect(request.url.queryParameters['q'], 'doubly linked list');
        return http.Response(
          jsonEncode({
            'query': 'doubly linked list',
            'results': [
              {
                'content': 'DOUBLY LINKED LIST info...',
                'title': 'Data Structures - Unit II: Linked Lists',
                'subject': 'Data Structures',
                'unit': 2,
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = RagService(client: mockClient);
      final results = await service.searchDocuments('doubly linked list');

      expect(results.length, 1);
      expect(results.first['subject'], 'Data Structures');
    });

    test('searchDocumentsStructured handles empty queries safely', () async {
      final service = RagService();
      final response = await service.searchDocumentsStructured('   ');

      expect(response.success, false);
      expect(response.error, contains('Please enter a question'));
    });

    test('searchDocumentsStructured handles HTTP 500 gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = RagService(client: mockClient);
      final response = await service.searchDocumentsStructured('test query');

      expect(response.success, false);
      expect(response.error, contains('server encountered an error'));
    });
  });
}
