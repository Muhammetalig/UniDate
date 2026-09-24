import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';
import '../../profile/profile_page.dart';

class ChatPage extends StatefulWidget {
  final String roomId;
  final String activity;
  final String? titleSuffix; // e.g., university name
  const ChatPage({
    super.key,
    required this.roomId,
    required this.activity,
    this.titleSuffix,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final _service = ChatService.instance;
  final _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Kullanıcı bilgilerini cache'le
  final Map<String, Map<String, dynamic>> _userCache = {};
  // Görüldü olarak işaretlenen mesajları takip et
  final Set<String> _markedAsSeen = {};

  // Cevaplanan mesaj bilgisi
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    // Sohbete girildiginde lastSeenAt guncelle
    _updateLastSeenAt();
  }

  @override
  void dispose() {
    // Sohbetten cikildiginda da lastSeenAt guncelle
    _updateLastSeenAt();
    _messageController.dispose();
    super.dispose();
  }

  /// Kullanicinin son goruntuleme zamanini guncelle
  Future<void> _updateLastSeenAt() async {
    if (_currentUserId == null) return;

    try {
      await _firestore
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('participants')
          .doc(_currentUserId)
          .set({
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('lastSeenAt guncelleme hatasi: $e');
    }
  }

  /// Mesajı cevapla
  void _setReplyingTo(Map<String, dynamic> messageData) {
    setState(() {
      _replyingTo = messageData;
    });
  }

  /// Cevaplamayı iptal et
  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  /// Mesajı görüldü olarak işaretle
  Future<void> _markMessageAsSeen(String messageId, String senderId) async {
    if (_currentUserId == null) return;
    if (_currentUserId == senderId) return; // Kendi mesajımızı işaretleme
    if (_markedAsSeen.contains(messageId)) return; // Zaten işaretledik

    _markedAsSeen.add(messageId);

    try {
      await _firestore
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .doc(messageId)
          .collection('seenBy')
          .doc(_currentUserId)
          .set({
            'seenAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Görüldü işaretleme hatası: $e');
    }
  }

  /// Kullanıcı bilgilerini getir (cache'li)
  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _userCache[userId] = data;
        return data;
      }
    } catch (e) {
      debugPrint('Kullanıcı bilgisi alınamadı: $e');
    }

    return {};
  }

  /// Kullanıcı adını oluştur
  String _buildUserName(Map<String, dynamic> userData, String? fallbackEmail) {
    final firstName = userData['firstName'] as String?;
    final lastName = userData['lastName'] as String?;

    if (firstName != null && firstName.isNotEmpty) {
      if (lastName != null && lastName.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName;
    }

    if (fallbackEmail != null) {
      return fallbackEmail.split('@').first;
    }

    return 'Kullanıcı';
  }

  /// Profil resmi URL'sini al
  String? _getProfileImage(Map<String, dynamic> userData) {
    if (userData['profileImages'] is List &&
        (userData['profileImages'] as List).isNotEmpty) {
      return (userData['profileImages'] as List).first as String?;
    } else if (userData['profileImageUrl'] is String) {
      return userData['profileImageUrl'] as String?;
    }
    return null;
  }

  /// Sadece saat formatlama
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate().toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Tarih etiketi oluştur (Bugün, Dün, veya tarih)
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Bugün';
    } else if (messageDate == yesterday) {
      return 'Dün';
    } else {
      final months = [
        'Ocak',
        'Şubat',
        'Mart',
        'Nisan',
        'Mayıs',
        'Haziran',
        'Temmuz',
        'Ağustos',
        'Eylül',
        'Ekim',
        'Kasım',
        'Aralık',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  /// İki mesaj arasında tarih değişikliği var mı kontrol et
  bool _shouldShowDateSeparator(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int index,
  ) {
    if (index == docs.length - 1) return true; // İlk mesaj (liste ters)

    final currentTimestamp = docs[index].data()['createdAt'] as Timestamp?;
    final previousTimestamp = docs[index + 1].data()['createdAt'] as Timestamp?;

    if (currentTimestamp == null) return false;
    if (previousTimestamp == null) return true;

    final currentDate = currentTimestamp.toDate().toLocal();
    final previousDate = previousTimestamp.toDate().toLocal();

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  /// Mesaj bilgi dialog'unu göster (sadece kendi mesajlarımız için)
  void _showMessageInfo(BuildContext context, Map<String, dynamic> data) {
    final messageId = data['id'] as String?;
    final senderId = data['senderId'] as String?;
    final timestamp = data['createdAt'] as Timestamp?;

    // Sadece kendi mesajlarımızın bilgisini görebiliriz
    if (senderId != _currentUserId) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MessageInfoSheet(
        messageId: messageId ?? '',
        roomId: widget.roomId,
        senderId: senderId ?? '',
        timestamp: timestamp,
        firestore: _firestore,
        getUserInfo: _getUserInfo,
        buildUserName: _buildUserName,
        getProfileImage: _getProfileImage,
      ),
    );
  }

  /// Özel sohbet başlat
  Future<void> _startPrivateChat(
    BuildContext context,
    String otherUserId,
  ) async {
    try {
      // Kullanıcı bilgilerini al
      final userData = await _getUserInfo(otherUserId);
      final userName = _buildUserName(userData, null);

      // Özel sohbet odasını oluştur veya getir
      final roomId = await _service.getOrCreatePrivateRoom(otherUserId);

      if (!context.mounted) return;

      // Özel sohbet sayfasına git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            roomId: roomId,
            activity: userName,
            titleSuffix: 'Özel Sohbet',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Özel sohbet başlatma hatası: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Özel sohbet başlatılamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _updateLastSeenAt();
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D1117)
            : const Color(0xFFF0F2F5),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.activity,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (widget.titleSuffix != null)
                Text(
                  widget.titleSuffix!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                // Grup bilgileri
              },
            ),
          ],
        ),
        body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.messagesStream(widget.roomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz mesaj yok',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'İlk mesajı sen gönder! 👋',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final messageId = data['id'] as String?;
                    final senderId = data['senderId'] as String? ?? '';
                    final isMe = senderId == _currentUserId;
                    final showDateSeparator = _shouldShowDateSeparator(
                      docs,
                      index,
                    );
                    final timestamp = data['createdAt'] as Timestamp?;

                    // Mesajı görüldü olarak işaretle
                    if (messageId != null && !isMe) {
                      _markMessageAsSeen(messageId, senderId);
                    }

                    return Column(
                      children: [
                        if (showDateSeparator && timestamp != null)
                          _buildDateSeparator(
                            timestamp.toDate().toLocal(),
                            isDark,
                          ),
                        _MessageBubble(
                          data: data,
                          isMe: isMe,
                          getUserInfo: _getUserInfo,
                          buildUserName: _buildUserName,
                          getProfileImage: _getProfileImage,
                          formatTime: _formatTime,
                          isDark: isDark,
                          currentUserId: _currentUserId,
                          // Sadece kendi mesajlarımızda bilgi göster
                          onLongPress: isMe
                              ? () => _showMessageInfo(context, data)
                              : null,
                          // Başkalarının mesajlarını sola kaydırarak özel sohbet başlat
                          // (zaten özel sohbetteysek bu özellik kapalı)
                          onSwipeToPrivateChat:
                              !isMe && !widget.roomId.startsWith('private_')
                                  ? (userId) =>
                                      _startPrivateChat(context, userId)
                                  : null,
                          // Tüm mesajlara cevap verilebilir
                          onSwipeToReply: (messageData) =>
                              _setReplyingTo(messageData),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(isDark),
        ],
      ),
    ),
    );
  }

  /// Tarih ayırıcı widget
  Widget _buildDateSeparator(DateTime date, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getDateLabel(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cevaplanan mesaj gösterimi
        if (_replyingTo != null) _buildReplyPreview(isDark),
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 8,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? 'Cevap yaz...'
                          : 'Mesaj yaz...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () async {
                    final text = _messageController.text.trim();
                    if (text.isEmpty) return;
                    await _service.sendMessage(
                      roomId: widget.roomId,
                      text: text,
                      replyTo: _replyingTo,
                    );
                    _messageController.clear();
                    _cancelReply();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Cevaplanan mesaj önizlemesi
  Widget _buildReplyPreview(bool isDark) {
    final replyText = _replyingTo?['text'] as String? ?? '';
    final replySenderName = _replyingTo?['senderName'] as String?;
    final replySenderId = _replyingTo?['senderId'] as String? ?? '';
    final isMyMessage = replySenderId == _currentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMyMessage
                      ? 'Kendinize cevap'
                      : (replySenderName ?? 'Kullanıcı'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyText.length > 50
                      ? '${replyText.substring(0, 47)}...'
                      : replyText,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  final Future<Map<String, dynamic>> Function(String) getUserInfo;
  final String Function(Map<String, dynamic>, String?) buildUserName;
  final String? Function(Map<String, dynamic>) getProfileImage;
  final String Function(Timestamp?) formatTime;
  final bool isDark;
  final VoidCallback? onLongPress;
  final void Function(String senderId)? onSwipeToPrivateChat;
  final void Function(Map<String, dynamic> messageData)? onSwipeToReply;
  final String? currentUserId;

  const _MessageBubble({
    required this.data,
    required this.isMe,
    required this.getUserInfo,
    required this.buildUserName,
    required this.getProfileImage,
    required this.formatTime,
    required this.isDark,
    this.onLongPress,
    this.onSwipeToPrivateChat,
    this.onSwipeToReply,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final text = data['text'] as String? ?? '';
    final senderId = data['senderId'] as String? ?? '';
    final senderEmail = data['senderEmail'] as String?;
    final senderName =
        data['senderName'] as String?; // Mesajla birlikte gelen isim
    final senderPhoto =
        data['senderPhoto'] as String?; // Mesajla birlikte gelen fotoğraf
    final timestamp = data['createdAt'] as Timestamp?;
    final time = formatTime(timestamp);
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    // Mesaj içeriğini oluştur
    Widget messageContent = _buildMessageContent(
      context,
      text,
      senderId,
      senderEmail,
      senderName,
      senderPhoto,
      time,
      replyTo,
    );

    // Swipe desteği
    if (onSwipeToReply != null || onSwipeToPrivateChat != null) {
      // Swipe yönünü belirle
      DismissDirection swipeDirection;
      if (onSwipeToPrivateChat != null && !isMe) {
        // Hem cevapla hem özel sohbet aktif
        swipeDirection = DismissDirection.horizontal;
      } else {
        // Sadece cevapla aktif (sağa kaydır)
        swipeDirection = DismissDirection.startToEnd;
      }

      return Dismissible(
        key: Key('${data['id'] ?? UniqueKey().toString()}_swipe'),
        direction: swipeDirection,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Sağa kaydır = Cevapla
            onSwipeToReply?.call(data);
          } else if (direction == DismissDirection.endToStart &&
              !isMe &&
              onSwipeToPrivateChat != null) {
            // Sola kaydır = Özel sohbet (sadece başkalarının mesajları için)
            onSwipeToPrivateChat!(senderId);
          }
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.reply, color: Color(0xFF2563EB), size: 24),
          ),
        ),
        secondaryBackground: !isMe
            ? Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
              )
            : const SizedBox.shrink(),
        child: messageContent,
      );
    }

    return messageContent;
  }

  Widget _buildMessageContent(
    BuildContext context,
    String text,
    String senderId,
    String? senderEmail,
    String? senderName,
    String? senderPhoto,
    String time,
    Map<String, dynamic>? replyTo,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              // Önce mesajdaki fotoğrafı kullan, yoksa Firestore'dan çek
              if (senderPhoto != null)
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _getAvatarColor(senderId),
                  backgroundImage: NetworkImage(senderPhoto),
                )
              else
                FutureBuilder<Map<String, dynamic>>(
                  future: getUserInfo(senderId),
                  builder: (context, snapshot) {
                    final userData = snapshot.data ?? {};
                    final imageUrl = getProfileImage(userData);

                    return CircleAvatar(
                      radius: 16,
                      backgroundColor: _getAvatarColor(senderId),
                      backgroundImage: imageUrl != null
                          ? NetworkImage(imageUrl)
                          : null,
                      child: imageUrl == null
                          ? Text(
                              _getInitial(userData, senderEmail),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF262628) : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cevaplanan mesaj varsa göster
                    if (replyTo != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.15)
                              : (isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.grey.withOpacity(0.12)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe
                                  ? Colors.white.withOpacity(0.5)
                                  : const Color(0xFF2563EB),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replyTo['senderName'] ?? 'Kullanıcı',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isMe
                                    ? Colors.white.withOpacity(0.9)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              replyTo['text'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : (isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!isMe)
                      // Önce mesajdaki ismi kullan, yoksa Firestore'dan çek
                      senderName != null
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                senderName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getNameColor(senderId),
                                ),
                              ),
                            )
                          : FutureBuilder<Map<String, dynamic>>(
                              future: getUserInfo(senderId),
                              builder: (context, snapshot) {
                                final userData = snapshot.data ?? {};
                                final name = buildUserName(
                                  userData,
                                  senderEmail,
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _getNameColor(senderId),
                                    ),
                                  ),
                                );
                              },
                            ),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe
                                ? Colors.white70
                                : (isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600]),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: Colors.white70),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  String _getInitial(Map<String, dynamic> userData, String? email) {
    final firstName = userData['firstName'] as String?;
    if (firstName != null && firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  Color _getAvatarColor(String userId) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFFDC2626),
      const Color(0xFFEA580C),
      const Color(0xFF16A34A),
      const Color(0xFF0891B2),
      const Color(0xFF4F46E5),
    ];
    final index = userId.hashCode.abs() % colors.length;
    return colors[index];
  }

  Color _getNameColor(String userId) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFFDC2626),
      const Color(0xFFEA580C),
      const Color(0xFF16A34A),
      const Color(0xFF0891B2),
      const Color(0xFF4F46E5),
    ];
    final index = userId.hashCode.abs() % colors.length;
    return colors[index];
  }
}

/// Mesaj bilgi sheet'i - mesajı görenleri gösterir
class _MessageInfoSheet extends StatelessWidget {
  final String messageId;
  final String roomId;
  final String senderId;
  final Timestamp? timestamp;
  final FirebaseFirestore firestore;
  final Future<Map<String, dynamic>> Function(String) getUserInfo;
  final String Function(Map<String, dynamic>, String?) buildUserName;
  final String? Function(Map<String, dynamic>) getProfileImage;

  const _MessageInfoSheet({
    required this.messageId,
    required this.roomId,
    required this.senderId,
    required this.timestamp,
    required this.firestore,
    required this.getUserInfo,
    required this.buildUserName,
    required this.getProfileImage,
  });

  String _formatFullTime(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate().toLocal();
    final months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Başlık
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 12),
                Text(
                  'Mesaj Bilgisi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

          // Gönderilme zamanı
          ListTile(
            leading: Icon(
              Icons.access_time,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            title: Text(
              'Gönderilme Zamanı',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            subtitle: Text(
              _formatFullTime(timestamp),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),

          Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

          // Görenler başlığı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.visibility,
                  size: 20,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Mesajı Görenler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Görenler listesi
          Flexible(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('chat_rooms')
                  .doc(roomId)
                  .collection('messages')
                  .doc(messageId)
                  .collection('seenBy')
                  .orderBy('seenAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final seenDocs = snapshot.data?.docs ?? [];

                if (seenDocs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Henüz kimse görmedi',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: seenDocs.length,
                  itemBuilder: (context, index) {
                    final seenData =
                        seenDocs[index].data() as Map<String, dynamic>;
                    final userId = seenDocs[index].id;
                    final seenAt = seenData['seenAt'] as Timestamp?;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: getUserInfo(userId),
                      builder: (context, userSnapshot) {
                        final userData = userSnapshot.data ?? {};
                        final name = buildUserName(userData, null);
                        final imageUrl = getProfileImage(userData);
                        final seenTime = seenAt != null
                            ? '${seenAt.toDate().toLocal().hour.toString().padLeft(2, '0')}:${seenAt.toDate().toLocal().minute.toString().padLeft(2, '0')}'
                            : '';

                        return ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              // Resme tıklanınca büyük resim göster
                              if (imageUrl != null) {
                                _showFullImage(context, imageUrl, name);
                              }
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: _getAvatarColor(userId),
                              backgroundImage: imageUrl != null
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: imageUrl == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          title: GestureDetector(
                            onTap: () {
                              // İsme tıklanınca profil sayfasına git
                              Navigator.pop(context); // Sheet'i kapat
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProfilePage(userId: userId),
                                ),
                              );
                            },
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          trailing: Text(
                            seenTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Color _getAvatarColor(String userId) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFFDC2626),
      const Color(0xFFEA580C),
      const Color(0xFF16A34A),
      const Color(0xFF0891B2),
      const Color(0xFF4F46E5),
    ];
    final index = userId.hashCode.abs() % colors.length;
    return colors[index];
  }

  /// Tam ekran resim göster
  void _showFullImage(BuildContext context, String imageUrl, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık ve kapat butonu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Resim
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 300,
                      height: 300,
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 300,
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 48),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
