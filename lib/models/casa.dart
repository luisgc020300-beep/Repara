// lib/models/casa.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MiembroCasa {
  const MiembroCasa({required this.displayName, this.photoUrl});

  final String displayName;
  final String? photoUrl;

  factory MiembroCasa.fromMap(Map<String, dynamic> map) => MiembroCasa(
        displayName: map['displayName'] as String? ?? '',
        photoUrl: map['photoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {'displayName': displayName, if (photoUrl != null) 'photoUrl': photoUrl};
}

class Casa {
  const Casa({
    required this.id,
    required this.nombre,
    required this.ownerUid,
    required this.members,
    required this.memberProfiles,
    this.joinCode,
    this.createdAt,
  });

  final String id;
  final String nombre;
  final String ownerUid;
  final List<String> members;
  final Map<String, MiembroCasa> memberProfiles;
  final String? joinCode;
  final DateTime? createdAt;

  factory Casa.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final profilesRaw = (data['memberProfiles'] as Map<String, dynamic>?) ?? {};
    return Casa(
      id: doc.id,
      nombre: data['nombre'] as String? ?? 'Mi casa',
      ownerUid: data['ownerUid'] as String? ?? '',
      members: List<String>.from(data['members'] as List? ?? []),
      memberProfiles: profilesRaw.map(
        (k, v) => MapEntry(k, MiembroCasa.fromMap(Map<String, dynamic>.from(v as Map))),
      ),
      joinCode: data['joinCode'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
