import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String? title;
  final String? body;
  final String? visibility; // 'public' | 'private'
  final DateTime? dueDate;
  final DateTime? aud_dt;
  final List<String>? tags;
  final bool? isDeleted;

  Note({
    required this.id,
    this.title,
    this.body,
    this.visibility,
    this.dueDate,
    this.aud_dt,
    this.tags,
    this.isDeleted,
  });

  // From Firestore
  factory Note.fromMap(String id, Map<String, dynamic> data) {
    return Note(
      id: id,
      title: data['title'] as String?,
      body: data['body'] as String?,
      visibility: data['visibility'] as String?,
      dueDate: data['dueDate'] is Timestamp
          ? (data['dueDate'] as Timestamp).toDate()
          : data['dueDate'] as DateTime?,
      aud_dt: data['aud_dt'] is Timestamp
          ? (data['aud_dt'] as Timestamp).toDate()
          : data['aud_dt'] as DateTime?,
      tags: (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'visibility': visibility,
        'dueDate': dueDate,
        'aud_dt': aud_dt,
        'tags': tags ?? [],
        'isDeleted': isDeleted ?? false,
      };
}