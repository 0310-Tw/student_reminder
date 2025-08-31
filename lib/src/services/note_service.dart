import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/models/note.dart';

class NotesService {
  NotesService._();
  static final instance = NotesService._();
  final _db = FirebaseFirestore.instance;

  // Notes collection per user
  CollectionReference<Map<String, dynamic>> _notesCol(String uid) =>
      _db.collection('users').doc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> _binCol(String uid) =>
      _db.collection('users').doc(uid).collection('bin');

  // Stream of user's notes (not deleted)
  Stream<List<Note>> watchMyNotes(String uid) {
    return _notesCol(uid)
        .where('isDeleted', isEqualTo: false)
        .orderBy('aud_dt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Note.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Stream of user's public notes (not deleted)
  Stream<List<Note>> watchPublicNotes(String uid) {
    return _notesCol(uid)
        .where('visibility', isEqualTo: 'public')
        .where('isDeleted', isEqualTo: false)
        .orderBy('aud_dt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Note.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Stream of deleted notes (bin) for user
  Stream<List<Note>> watchBinNotes(String uid) {
    return _binCol(uid)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Note.fromMap(doc.id, doc.data())).toList());
  }

  // Create a note
  Future<String> createNote(
    String uid, {
    required String title,
    required String body,
    required String visibility,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final data = {
      'title': title,
      'body': body,
      'visibility': visibility,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'tags': tags ?? [],
      'aud_dt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    };
    final doc = await _notesCol(uid).add(data);
    return doc.id;
  }

  // Create a note from a Note model
  Future<void> createNoteModel(String uid, Note note) async {
    await _notesCol(uid).doc(note.id).set(note.toMap());
  }

  // Update note with field validation
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
    if (dueDate != null) data['dueDate'] = Timestamp.fromDate(dueDate);
    if (tags != null) data['tags'] = tags;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _notesCol(uid).doc(noteId).update(data);
  }

  // Update entire note (from Note model)
  Future<void> updateNoteModel(String uid, Note note) async {
    final updateData = note.toMap();
    updateData['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _notesCol(uid).doc(note.id).update(updateData);
  }

  // Soft delete - move to bin
  Future<void> softDeleteNote(String uid, String noteId) async {
    final doc = await _notesCol(uid).doc(noteId).get();
    if (doc.exists) {
      final noteData = doc.data()!;
      // Move to bin
      await _binCol(uid).doc(noteId).set({
        ...noteData,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
        'originalCollection': 'notes',
      });
      // Mark as deleted in notes collection
      await _notesCol(uid).doc(noteId).update({
        'isDeleted': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  // Restore note from bin
  Future<void> restoreNote(String uid, String noteId) async {
    final binDoc = await _binCol(uid).doc(noteId).get();
    if (binDoc.exists) {
      // Remove from bin
      await _binCol(uid).doc(noteId).delete();
      // Mark as not deleted in notes
      await _notesCol(uid).doc(noteId).update({
        'isDeleted': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  // Permanent delete from bin
  Future<void> permanentDeleteNote(String uid, String noteId) async {
    await _binCol(uid).doc(noteId).delete();
    // Optionally, you could also remove from notes collection
    // await _notesCol(uid).doc(noteId).delete();
  }

  // Hard delete from notes (not bin)
  Future<void> deleteNote(String uid, String noteId) {
    return _notesCol(uid).doc(noteId).delete();
  }
}