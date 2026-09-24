// First-gen Cloud Functions (Spark plan uyumlu) versiyon
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Kullanıcının tüm FCM token'larını al (çoklu cihaz desteği)
 * Önce fcmTokens alt koleksiyonuna bakar, yoksa ana dokümandaki fcmToken'ı kullanır
 */
async function getUserTokens(userId) {
  const tokens = [];
  
  try {
    // Önce fcmTokens alt koleksiyonundan token'ları al
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('fcmTokens')
      .get();
    
    if (!tokensSnapshot.empty) {
      tokensSnapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.token) {
          tokens.push({
            token: data.token,
            deviceId: doc.id,
            platform: data.platform || 'unknown'
          });
        }
      });
    }
    
    // Eğer alt koleksiyonda token yoksa, ana dokümandaki token'ı kullan (geriye uyumluluk)
    if (tokens.length === 0) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData.fcmToken) {
          tokens.push({
            token: userData.fcmToken,
            deviceId: 'legacy',
            platform: 'unknown'
          });
        }
      }
    }
  } catch (e) {
    console.warn('Token alma hatası:', e);
  }
  
  return tokens;
}

/**
 * Geçersiz token'ları temizle
 */
async function removeInvalidToken(userId, deviceId) {
  try {
    if (deviceId === 'legacy') {
      // Eski format token'ı sil
      await admin.firestore().collection('users').doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete()
      });
    } else {
      // Yeni format token'ı sil
      await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('fcmTokens')
        .doc(deviceId)
        .delete();
    }
    console.log('Geçersiz token silindi:', userId, deviceId);
  } catch (e) {
    console.warn('Token silme hatası:', e);
  }
}

/**
 * chat_rooms/{roomId}/messages/{messageId} -> onCreate trigger
 * Amaç: Gönderen dışındaki katılımcıların TÜM cihazlarına push gönder.
 * Bildirim: "Zonguldak Bülent Ecevit Üniversitesi - Kitap Okuma" grubuna mesaj geldiğinde
 * o gruba katılan kullanıcılara bildirim gönderir.
 */
exports.onChatMessageCreate = functions.firestore
  .document('chat_rooms/{roomId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message) return null;

    const roomId = context.params.roomId;
    const senderId = message.senderId;
    const senderEmail = message.senderEmail || 'Birisi';
    const text = message.text || '';

    try {
      const roomDoc = await admin.firestore().collection('chat_rooms').doc(roomId).get();
      if (!roomDoc.exists) return null;
      const roomData = roomDoc.data();

      // Gönderenin adını al
      let senderName = senderEmail.split('@')[0]; // Varsayılan olarak email'in @ öncesi
      try {
        const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
        if (senderDoc.exists) {
          const senderData = senderDoc.data();
          if (senderData.firstName) {
            senderName = senderData.firstName;
            if (senderData.lastName) {
              senderName += ' ' + senderData.lastName;
            }
          } else if (senderData.name) {
            senderName = senderData.name;
          } else if (senderData.displayName) {
            senderName = senderData.displayName;
          }
        }
      } catch (e) {
        console.warn('Gönderen bilgisi alınamadı:', e);
      }

      // Katılımcılar
      const participantsSnap = await admin
        .firestore()
        .collection('chat_rooms')
        .doc(roomId)
        .collection('participants')
        .get();

      const targetUserIds = participantsSnap.docs
        .map((d) => d.id)
        .filter((id) => id !== senderId);
      if (!targetUserIds.length) {
        console.log('Bildirim gönderilecek kullanıcı yok');
        return null;
      }

      // Tüm kullanıcıların tüm cihazlarından token'ları çek
      const allTokens = [];
      for (const userId of targetUserIds) {
        const userTokens = await getUserTokens(userId);
        userTokens.forEach(tokenData => {
          allTokens.push({
            ...tokenData,
            userId: userId
          });
        });
      }
      
      if (!allTokens.length) {
        console.log('Geçerli FCM token bulunamadı');
        return null;
      }

      // Bildirim başlığı: "Üniversite - Aktivite"
      const notificationTitle = `${roomData.university || 'Sohbet'} - ${roomData.activity || 'Grup'}`;
      // Bildirim içeriği: "Gönderen: Mesaj"
      const notificationBody = `${senderName}: ${text.length > 50 ? text.substring(0, 47) + '...' : text}`;

      console.log('Bildirim gönderiliyor:', {
        roomId,
        title: notificationTitle,
        body: notificationBody,
        tokenCount: allTokens.length,
        devices: allTokens.map(t => `${t.platform}:${t.deviceId.substring(0, 10)}...`),
      });

      // Her token için ayrı mesaj gönder (daha güvenilir)
      const messages = allTokens.map(tokenData => ({
        token: tokenData.token,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: 'chat_message',
          roomId: roomId,
          senderId: senderId,
          activity: roomData.activity || '',
          university: roomData.university || '',
        },
        android: { 
          notification: { 
            channelId: 'chat_messages', 
            sound: 'default',
            priority: 'high',
          } 
        },
        apns: { 
          payload: { 
            aps: { 
              sound: 'default',
              badge: 1,
            } 
          } 
        },
      }));

      // sendEach kullan (firebase-admin v12+)
      const response = await admin.messaging().sendEach(messages);
      console.log('Bildirim sonucu:', response.successCount, 'başarılı /', allTokens.length, 'toplam');

      // Başarısız token'ları temizle
      if (response.failureCount > 0) {
        for (let idx = 0; idx < response.responses.length; idx++) {
          const r = response.responses[idx];
          if (!r.success) {
            const tokenData = allTokens[idx];
            const errorCode = r.error?.code;
            console.warn('Başarısız:', tokenData.platform, tokenData.deviceId.substring(0, 10), 'Hata:', r.error?.message);
            
            // Geçersiz token hatalarında token'ı sil
            if (errorCode === 'messaging/invalid-registration-token' ||
                errorCode === 'messaging/registration-token-not-registered') {
              await removeInvalidToken(tokenData.userId, tokenData.deviceId);
            }
          }
        }
      }
      return null;
    } catch (e) {
      console.error('onChatMessageCreate hatası:', e);
      return null;
    }
  });
