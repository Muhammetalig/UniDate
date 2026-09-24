import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import "package:unihub/home/home_page.dart";
import 'package:unihub/profile/profile_page.dart';
import 'package:unihub/friends/friends_page.dart';
import 'package:unihub/home/chat/private_chats_page.dart';
import 'guest_access.dart';

class CustomBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNavigation> createState() => _CustomBottomNavigationState();
}

class _CustomBottomNavigationState extends State<CustomBottomNavigation> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  List<StreamSubscription>? _roomSubs;
  String? _uid;
  String? _avatarUrl;
  ImageProvider? _avatarProvider;
  int _totalUnreadCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _startAvatarListener();
    _startUnreadCountListener();
    // Her 3 saniyede bir okunmamis mesaj sayisini guncelle
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshUnreadCount();
    });
  }

  @override
  void didUpdateWidget(covariant CustomBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sayfa degistiginde hemen guncelle
    _refreshUnreadCount();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _roomSubs?.forEach((s) => s.cancel());
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Okunmamis mesaj sayisini yenile
  Future<void> _refreshUnreadCount() async {
    if (_uid == null || _uid!.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: _uid)
          .get();

      int totalUnread = 0;

      for (final doc in snapshot.docs) {
        if (!doc.id.startsWith('private_')) continue;

        final unreadCount = await _getUnreadCountForRoom(doc.id);
        totalUnread += unreadCount;
      }

      if (mounted && totalUnread != _totalUnreadCount) {
        setState(() {
          _totalUnreadCount = totalUnread;
        });
      }
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  /// Okunmamis mesaj sayisini dinle
  void _startUnreadCountListener() {
    if (_uid == null || _uid!.isEmpty) return;

    // Ilk yukleme
    _refreshUnreadCount();
  }

  Future<int> _getUnreadCountForRoom(String roomId) async {
    if (_uid == null) return 0;

    try {
      final participantDoc = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(roomId)
          .collection('participants')
          .doc(_uid)
          .get();

      final lastSeenAt = participantDoc.data()?['lastSeenAt'] as Timestamp?;

      final allMessages = await FirebaseFirestore.instance
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

        if (senderId == _uid) continue;

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

  void _startAvatarListener() {
    if (_uid == null || _uid!.isEmpty) return;
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen((snap) async {
      final data = snap.data();
      if (data == null) return;

      String? url;
      if (data['profileImages'] is List &&
          (data['profileImages'] as List).isNotEmpty) {
        url = (data['profileImages'] as List).first as String?;
      } else if (data['profileImageUrl'] is String) {
        url = data['profileImageUrl'] as String?;
      }

      if (url != null && url.isNotEmpty && url != _avatarUrl) {
        final provider = NetworkImage(url);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          precacheImage(provider, context);
        });
        setState(() {
          _avatarUrl = url;
          _avatarProvider = provider;
        });
      } else if ((url == null || url.isEmpty) && _avatarUrl != null) {
        setState(() {
          _avatarUrl = null;
          _avatarProvider = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.cardColor,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          const BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.house),
            activeIcon: FaIcon(FontAwesomeIcons.house),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: _buildChatIcon(false),
            activeIcon: _buildChatIcon(true),
            label: 'Sohbetler',
          ),
          const BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.users),
            activeIcon: FaIcon(FontAwesomeIcons.users),
            label: 'Arkadaslar',
          ),
          BottomNavigationBarItem(
            icon: _AvatarIcon(
              provider: _avatarProvider,
              isActive: false,
              size: 26,
            ),
            activeIcon: _AvatarIcon(
              provider: _avatarProvider,
              isActive: true,
              size: 28,
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildChatIcon(bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isActive ? Icons.forum : Icons.forum_outlined,
        ),
        if (_totalUnreadCount > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _totalUnreadCount > 99 ? '99+' : '$_totalUnreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  List<Widget> get _pages {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return const [
        HomeContent(),
        GuestAccountPrompt(title: 'Mesajlar'),
        GuestAccountPrompt(title: 'Arkadaşlar'),
        GuestAccountPrompt(title: 'Misafir Profil'),
      ];
    }
    return [
      const HomeContent(),
      const PrivateChatsPage(),
      const FriendsPage(),
      ProfilePage(userId: userId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _AvatarIcon extends StatelessWidget {
  final ImageProvider? provider;
  final bool isActive;
  final double size;

  const _AvatarIcon({
    required this.provider,
    required this.isActive,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive ? const Color(0xFF2563EB) : Colors.grey.shade300;
    final borderColor = isActive ? Colors.white : Colors.transparent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: isActive ? 2 : 0),
      ),
      child: ClipOval(
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: bgColor,
          backgroundImage: provider,
          child: provider == null
              ? FaIcon(
                  FontAwesomeIcons.user,
                  size: size * 0.6,
                  color: isActive ? Colors.white : const Color(0xFF2563EB),
                )
              : null,
        ),
      ),
    );
  }
}
