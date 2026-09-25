import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import '../../services/chat_photo_visibility.dart';

class PrivateChatsPage extends StatefulWidget {
  const PrivateChatsPage({super.key});

  @override
  State<PrivateChatsPage> createState() => _PrivateChatsPageState();
}

class _PrivateChatsPageState extends State<PrivateChatsPage> {
  final _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Set<String> _friendIds = <String>{};
  StreamSubscription<Set<String>>? _friendSubscription;

  @override
  void initState() {
    super.initState();
    _friendSubscription = ChatPhotoVisibility.friendsOf(_currentUserId).listen((
      ids,
    ) {
      if (mounted) setState(() => _friendIds = ids);
    });
  }

  @override
  void dispose() {
    _friendSubscription?.cancel();
    super.dispose();
  }

  String _buildUserName(Map<String, dynamic> userData, String? email) {
    final firstName = userData['firstName'] as String? ?? '';
    final lastName = userData['lastName'] as String? ?? '';

    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Kullanıcı';
  }

  Color _getAvatarColor(String oderId) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFFDC2626),
      const Color(0xFFEA580C),
      const Color(0xFF16A34A),
      const Color(0xFF0891B2),
    ];
    return colors[oderId.hashCode.abs() % colors.length];
  }

  String _formatLastMessageTime(Timestamp timestamp) {
    final date = timestamp.toDate().toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      final days = ['Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt'];
      return days[date.weekday % 7];
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  /// Bir odadaki okunmamis mesaj sayisini getir
  Future<int> _getUnreadCount(String roomId) async {
    if (_currentUserId == null) return 0;

    try {
      final participantDoc = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('participants')
          .doc(_currentUserId)
          .get();

      final lastSeenAt = participantDoc.data()?['lastSeenAt'] as Timestamp?;

      final allMessages = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .get();

      int count = 0;
      for (final msg in allMessages.docs) {
        final data = msg.data();
        final senderId = data['senderId'] as String?;
        final createdAt = data['createdAt'] as Timestamp?;

        if (senderId == _currentUserId) continue;

        if (lastSeenAt == null) {
          count++;
        } else if (createdAt != null && createdAt.compareTo(lastSeenAt) > 0) {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF0F2F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: const Text(
          'Özel Sohbetler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('chat_rooms')
            .where('participants', arrayContains: _currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          // Sadece private_ ile başlayan odaları filtrele ve son mesaja göre sırala
          final allDocs = snapshot.data?.docs ?? [];
          final rooms =
              allDocs.where((doc) => doc.id.startsWith('private_')).toList()
                ..sort((a, b) {
                  final aTime = a.data()['lastMessageAt'] as Timestamp?;
                  final bTime = b.data()['lastMessageAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Henüz özel sohbet yok',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Aktivite sohbetlerinde bir mesajı sola kaydırarak özel sohbet başlatabilirsin',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index].data();
              final roomId = rooms[index].id;
              final participants = List<String>.from(
                room['participants'] ?? [],
              );
              final otherUserId = participants.firstWhere(
                (id) => id != _currentUserId,
                orElse: () => '',
              );
              final lastMessage = room['lastMessage'] as String? ?? '';
              final lastMessageAt = room['lastMessageAt'] as Timestamp?;

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('users')
                    .doc(otherUserId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data?.data() ?? {};
                  final userName = _buildUserName(userData, null);
                  final profileImage = ChatPhotoVisibility.visibleUrl(
                    userData,
                    ownerId: otherUserId,
                    viewerId: _currentUserId,
                    friendIds: _friendIds,
                  );

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: _getAvatarColor(otherUserId),
                        backgroundImage: profileImage != null
                            ? NetworkImage(profileImage)
                            : null,
                        child: profileImage == null
                            ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      trailing: FutureBuilder<int>(
                        future: _getUnreadCount(roomId),
                        builder: (context, unreadSnapshot) {
                          final unreadCount = unreadSnapshot.data ?? 0;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (lastMessageAt != null)
                                Text(
                                  _formatLastMessageTime(lastMessageAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: unreadCount > 0
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey[500],
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              if (unreadCount > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      onTap: () {
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
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
