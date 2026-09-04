import 'dart:convert';

/// Represents an in-app student notification record from Nexora Backend
class NotificationModel {
  final int id;
  final String firebaseUid;
  final String type; // RESULT, EVENT, ATTENDANCE, TIMETABLE, EXAM, FEE, CIRCULAR, GENERAL, SYSTEM
  final String title;
  final String body;
  final String? dataJson;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationModel({
    required this.id,
    required this.firebaseUid,
    required this.type,
    required this.title,
    required this.body,
    this.dataJson,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  Map<String, dynamic> get parsedData {
    if (dataJson == null || dataJson!.isEmpty) return {};
    try {
      return jsonDecode(dataJson!) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String get route {
    final d = parsedData;
    if (d.containsKey('route') && d['route'] is String) {
      return d['route'] as String;
    }
    if (type == 'RESULT') return '/results';
    return '/notifications';
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      firebaseUid: json['firebase_uid']?.toString() ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      dataJson: json['data_json']?.toString(),
      referenceId: json['reference_id']?.toString(),
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
    );
  }
}

class NotificationCountModel {
  final int unreadCount;
  final int totalCount;

  NotificationCountModel({
    required this.unreadCount,
    required this.totalCount,
  });

  factory NotificationCountModel.fromJson(Map<String, dynamic> json) {
    return NotificationCountModel(
      unreadCount: json['unread_count'] is int
          ? json['unread_count']
          : int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
      totalCount: json['total_count'] is int
          ? json['total_count']
          : int.tryParse(json['total_count']?.toString() ?? '0') ?? 0,
    );
  }
}
