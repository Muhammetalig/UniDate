import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../home/chat/chat_page.dart';
import '../main.dart' show navigatorKey;

/// Arka plan mesaj işleyicisi - main.dart dışında top-level olmalı
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka planda gelen mesajları işle
  debugPrint('Arka plan mesajı alındı: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialized = false;
  String? _currentToken;

  /// Bildirim servisini başlat
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // İzin iste
    await _requestPermission();

    // FCM token'ı kaydet
    await _saveToken();

    // Token yenilendiğinde güncelle
    _messaging.onTokenRefresh.listen(_updateToken);

    // Ön plan bildirimleri dinle
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Bildirime tıklanarak açılan mesajları dinle
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Uygulama kapalıyken bildirime tıklanarak açıldıysa
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Uygulama başladığında biraz daha bekle
      _navigateToChatDelayed(initialMessage.data, delay: 1500);
    }

    debugPrint('NotificationService initialized');
  }

  /// Bildirim izni iste
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    debugPrint('Bildirim izni durumu: ${settings.authorizationStatus}');
  }

  /// Cihaz için benzersiz bir ID oluştur (token'ın hash'i)
  String _getDeviceId(String token) {
    // Token'ın ilk 32 karakterini cihaz ID olarak kullan
    return token.length > 32 ? token.substring(0, 32) : token;
  }

  /// FCM token'ı Firestore'a kaydet (çoklu cihaz desteği)
  Future<void> _saveToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      _currentToken = token;
      final deviceId = _getDeviceId(token);
      final platform = Platform.isIOS ? 'ios' : 'android';

      // Her cihaz için ayrı bir döküman oluştur (fcmTokens alt koleksiyonu)
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(deviceId)
          .set({
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Geriye uyumluluk için ana dokümanda da sakla
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM token kaydedildi (deviceId: $deviceId, platform: $platform)');
    } catch (e) {
      debugPrint('FCM token kaydetme hatası: $e');
    }
  }

  /// Token yenilendiğinde güncelle
  Future<void> _updateToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Eski token'ı sil
      if (_currentToken != null) {
        final oldDeviceId = _getDeviceId(_currentToken!);
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(oldDeviceId)
            .delete();
      }

      _currentToken = token;
      final deviceId = _getDeviceId(token);
      final platform = Platform.isIOS ? 'ios' : 'android';

      // Yeni token'ı kaydet
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(deviceId)
          .set({
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Geriye uyumluluk için ana dokümanda da güncelle
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM token güncellendi (deviceId: $deviceId)');
    } catch (e) {
      debugPrint('FCM token güncelleme hatası: $e');
    }
  }

  /// Ön planda gelen mesajları işle
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Ön plan mesajı alındı: ${message.notification?.title}');
    
    // Ön planda bildirim göster (isteğe bağlı - flutter_local_notifications ile)
    // Şu an sadece log'luyoruz, sistem bildirimi otomatik gösterilecek
  }

  /// Bildirime tıklanarak uygulama açıldığında
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Bildirim tıklandı: ${message.data}');
    _navigateToChat(message.data);
  }

  /// Chat sayfasına yönlendir (gecikmeli)
  void _navigateToChatDelayed(Map<String, dynamic> data, {int delay = 500}) {
    if (data['type'] == 'chat_message' && data['roomId'] != null) {
      final roomId = data['roomId'] as String;
      final activity = data['activity'] as String? ?? 'Sohbet';
      final university = data['university'] as String?;

      debugPrint('Chat odasına yönlendiriliyor: $roomId');

      // Navigator key ile yönlendirme yap
      Future.delayed(Duration(milliseconds: delay), () {
        final context = navigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatPage(
                roomId: roomId,
                activity: activity,
                titleSuffix: university,
              ),
            ),
          );
        }
      });
    }
  }

  /// Chat sayfasına yönlendir
  void _navigateToChat(Map<String, dynamic> data) {
    _navigateToChatDelayed(data, delay: 500);
  }

  /// Kullanıcı çıkış yaptığında sadece bu cihazdaki token'ı sil
  Future<void> clearToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Sadece bu cihazın token'ını sil
      if (_currentToken != null) {
        final deviceId = _getDeviceId(_currentToken!);
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(deviceId)
            .delete();
        debugPrint('FCM token silindi (deviceId: $deviceId)');
      }

      _currentToken = null;
    } catch (e) {
      debugPrint('FCM token silme hatası: $e');
    }
  }

  /// Kullanıcı giriş yaptığında token'ı yeniden kaydet
  Future<void> onUserLogin() async {
    await _saveToken();
  }

  /// Eski/geçersiz token'ları temizle (opsiyonel - periyodik olarak çağrılabilir)
  Future<void> cleanupOldTokens() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 30 günden eski token'ları sil
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final oldTokens = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .where('updatedAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (final doc in oldTokens.docs) {
        await doc.reference.delete();
      }

      if (oldTokens.docs.isNotEmpty) {
        debugPrint('${oldTokens.docs.length} eski FCM token temizlendi');
      }
    } catch (e) {
      debugPrint('Eski token temizleme hatası: $e');
    }
  }
}
