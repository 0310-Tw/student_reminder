import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/note_service.dart';
import 'package:students_reminder/src/services/user_service.dart';
import 'package:students_reminder/src/models/note.dart';

class StudentProfilePage extends StatelessWidget {
  final String uid;
  const StudentProfilePage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Profile')),
      body: StreamBuilder(
        stream: UserService.instance.getUser(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data();
          if (data == null) return Center(child: Text('No data found'));
          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
          final group = (data['courseGroup'] ?? '').toString() == 'mobile'
              ? 'Mobile App Development'
              : 'Web App Development';
          final bio = (data['bio'] ?? '') as String? ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(group),
                leading: data['photoUrl'] != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(data['photoUrl']),
                      )
                    : CircleAvatar(child: Icon(Icons.person)),
              ),
              if (bio.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(bio),
                ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Public Notes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Note>>(
                  stream: NotesService.instance.watchPublicNotes(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text('Error loading notes: ${snap.error}'),
                      );
                    }
                    final notes = snap.data ?? [];
                    if (notes.isEmpty) {
                      return Center(child: Text('No public notes'));
                    }
                    return ListView.separated(
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => Divider(height: 2),
                      itemBuilder: (context, i) {
                        final note = notes[i];
                        return ListTile(
                          title: Text(note.title ?? ''),
                          subtitle: Text(
                            note.body ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // If you want to show tags as chips under each note:
                          isThreeLine: note.tags != null && note.tags!.isNotEmpty,
                          trailing: note.tags != null && note.tags!.isNotEmpty
                              ? Wrap(
                                  spacing: 4,
                                  children: note.tags!
                                      .map((tag) => Chip(
                                            label: Text(
                                              tag,
                                              style: TextStyle(fontSize: 10),
                                            ),
                                            backgroundColor: Colors.blue[50],
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ))
                                      .toList(),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}