import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FriendsService {
  static final FriendsService instance = FriendsService._internal();
  FriendsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Arkadaş ekleme isteği gönder
  Future<void> sendFriendRequest(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('friends_service: Kullanıcı giriş yapmamış');
    }

    // Zaten arkadaş mı kontrol et
    final existingFriendship = await _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUserId)
        .get();

    for (var doc in existingFriendship.docs) {
      final users = List<String>.from(doc.data()['users']);
      if (users.contains(targetUserId)) {
        throw Exception('friends_service: Zaten arkadaşsınız veya istek gönderilmiş');
      }
    }

    // Arkadaşlık isteği oluştur
    await _firestore.collection('friendships').add({
      'users': [currentUserId, targetUserId],
      'requesterId': currentUserId,
      'status': 'pending', // pending, accepted, rejected
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('friends_service: Arkadaşlık isteği gönderildi: $targetUserId');
  }

  // Arkadaşlık isteğini kabul et
  Future<void> acceptFriendRequest(String friendshipId) async {
    await _firestore.collection('friendships').doc(friendshipId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('friends_service: Arkadaşlık isteği kabul edildi: $friendshipId');
  }

  // Arkadaşlık isteğini reddet
  Future<void> rejectFriendRequest(String friendshipId) async {
    await _firestore.collection('friendships').doc(friendshipId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('friends_service: Arkadaşlık isteği reddedildi: $friendshipId');
  }

  // Arkadaşlığı kaldır
  Future<void> removeFriend(String friendshipId) async {
    await _firestore.collection('friendships').doc(friendshipId).delete();
    debugPrint('friends_service: Arkadaşlık kaldırıldı: $friendshipId');
  }

  // Tüm arkadaşları getir
  Stream<QuerySnapshot> getFriends() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  // Bekleyen arkadaşlık isteklerini getir (gelen)
  Stream<QuerySnapshot> getPendingRequests() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Kullanıcı bilgilerini getir
  Future<DocumentSnapshot> getUserInfo(String userId) async {
    return await _firestore.collection('users').doc(userId).get();
  }

  // Kullanıcının çevrimiçi durumunu güncelle
  Future<void> updateOnlineStatus(bool isOnline) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('users').doc(currentUserId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    debugPrint('friends_service: Online durum güncellendi: $isOnline');
  }

  // Email ile kullanıcı ara
  Future<DocumentSnapshot?> searchUserByEmail(String email) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    return querySnapshot.docs.first;
  }
}

