import 'package:cloud_firestore/cloud_firestore.dart';

class NotesService {
  NotesService._();
  static final instance = NotesService._();
  final _db = FirebaseFirestore.instance;

  //Finding the destination for notes
  CollectionReference<Map<String, dynamic>> _notesCol(String uid) {
    return _db.collection('users').doc(uid).collection('notes');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyNotes(String uid) {
    return _notesCol(uid).orderBy('aud_dt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPublicNotes(String uid) {
    return _notesCol(uid)
        .where('visibility', isEqualTo: 'public')
        .orderBy('aud_dt', descending: true)
        .snapshots();
  }

  Future<String> createNote(
    String uid, {
    required String title,
    required String body,
    required String visibility,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final doc = await _notesCol(uid).add({
      'title': title,
      'body': body,
      'visibility': visibility,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'tags': tags ?? [],
      'aud_dt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateNote(
    String uid,
    String noteId, {
    String? title,
    String? body,
    String? visibility,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (body != null) data['body'] = body;
    if (visibility != null) data['visibility'] = visibility;
    if (dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(dueDate);
    }
    if (tags != null) data['tags'] = tags;
    await _notesCol(uid).doc(noteId).update(data);
  }

  Future<void> deleteNote(String uid, String noteId) {
    return _notesCol(uid).doc(noteId).delete();
  }
}
