import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  String buildRoomId({required String university, required String activity}) {
    return '${_normalize(university)}_${_normalize(activity)}';
  }

  Future<String> getOrCreateRoom({
    required String university,
    required String activity,
  }) async {
    final roomId = buildRoomId(university: university, activity: activity);
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final doc = await roomRef.get();

    if (!doc.exists) {
      await roomRef.set({
        'university': university,
        'activity': activity,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }

    // ensure participant exists
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await roomRef.collection('participants').doc(uid).set({
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return roomId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendMessage({
    required String roomId,
    required String text,
    Map<String, dynamic>? replyTo,
  }) async {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email;
    if (uid == null || text.trim().isEmpty) return;

    // Gönderen bilgilerini al
    String? senderName;
    String? senderPhoto;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        final firstName = userData['firstName'] as String?;
        final lastName = userData['lastName'] as String?;
        if (firstName != null && firstName.isNotEmpty) {
          senderName = lastName != null && lastName.isNotEmpty 
              ? '$firstName $lastName' 
              : firstName;
        }
        // Profil resmi
        if (userData['profileImages'] is List && 
            (userData['profileImages'] as List).isNotEmpty) {
          senderPhoto = (userData['profileImages'] as List).first as String?;
        } else if (userData['profileImageUrl'] is String) {
          senderPhoto = userData['profileImageUrl'] as String?;
        }
      }
    } catch (e) {
      // Hata durumunda devam et
    }

    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final msgRef = roomRef.collection('messages').doc();

    final messageData = {
      'id': msgRef.id,
      'senderId': uid,
      'senderEmail': email,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Eğer bir mesaja cevap veriyorsak, cevaplanan mesaj bilgisini ekle
    if (replyTo != null) {
      messageData['replyTo'] = {
        'id': replyTo['id'],
        'text': replyTo['text'],
        'senderId': replyTo['senderId'],
        'senderName': replyTo['senderName'],
      };
    }

    await msgRef.set(messageData);

    await roomRef.set({
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// İki kullanıcı arasında özel sohbet odası oluştur veya var olanı getir
  Future<String> getOrCreatePrivateRoom(String otherUserId) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw Exception('Kullanıcı giriş yapmamış');

    // Room ID'yi her zaman aynı şekilde oluştur (küçük id önce)
    final ids = [currentUid, otherUserId]..sort();
    final roomId = 'private_${ids[0]}_${ids[1]}';

    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final doc = await roomRef.get();

    if (!doc.exists) {
      // Diğer kullanıcının bilgilerini al
      final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
      final otherUserData = otherUserDoc.data() ?? {};
      
      // Mevcut kullanıcının bilgilerini al
      final currentUserDoc = await _firestore.collection('users').doc(currentUid).get();
      final currentUserData = currentUserDoc.data() ?? {};

      await roomRef.set({
        'type': 'private',
        'participants': [currentUid, otherUserId],
        'participantInfo': {
          currentUid: {
            'firstName': currentUserData['firstName'],
            'lastName': currentUserData['lastName'],
            'profileImage': _getProfileImageFromData(currentUserData),
          },
          otherUserId: {
            'firstName': otherUserData['firstName'],
            'lastName': otherUserData['lastName'],
            'profileImage': _getProfileImageFromData(otherUserData),
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      // Katılımcıları ekle
      await roomRef.collection('participants').doc(currentUid).set({
        'joinedAt': FieldValue.serverTimestamp(),
      });
      await roomRef.collection('participants').doc(otherUserId).set({
        'joinedAt': FieldValue.serverTimestamp(),
      });
    }

    return roomId;
  }

  String? _getProfileImageFromData(Map<String, dynamic> userData) {
    if (userData['profileImages'] is List && 
        (userData['profileImages'] as List).isNotEmpty) {
      return (userData['profileImages'] as List).first as String?;
    } else if (userData['profileImageUrl'] is String) {
      return userData['profileImageUrl'] as String?;
    }
    return null;
  }

  /// Özel sohbet için diğer kullanıcının bilgilerini getir
  Future<Map<String, dynamic>> getPrivateRoomInfo(String roomId) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return {};

    final roomDoc = await _firestore.collection('chat_rooms').doc(roomId).get();
    if (!roomDoc.exists) return {};

    final data = roomDoc.data() ?? {};
    final participantInfo = data['participantInfo'] as Map<String, dynamic>? ?? {};
    
    // Diğer kullanıcının bilgilerini bul
    for (final entry in participantInfo.entries) {
      if (entry.key != currentUid) {
        return entry.value as Map<String, dynamic>;
      }
    }
    return {};
  }
}
