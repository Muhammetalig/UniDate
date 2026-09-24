import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'friends_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0: Arkadaşlar, 1: İstekler

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kullanıcı çevrimiçi olarak işaretle
    FriendsService.instance.updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Kullanıcı çevrimdışı olarak işaretle
    FriendsService.instance.updateOnlineStatus(false);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      FriendsService.instance.updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive) {
      FriendsService.instance.updateOnlineStatus(false);
    }
  }

  Future<void> _showAddFriendDialog() async {
    final controller = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Arkadaş Ekle'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'E-posta Adresi',
              hintText: 'arkadas@example.com',
              prefixIcon: Icon(FontAwesomeIcons.envelope),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('friends_page: Lütfen bir e-posta adresi girin')),
                  );
                  return;
                }

                try {
                  final userDoc = await FriendsService.instance.searchUserByEmail(email);
                  if (userDoc == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('friends_page: Kullanıcı bulunamadı')),
                      );
                    }
                    return;
                  }

                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (userDoc.id == currentUser?.uid) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('friends_page: Kendinize istek gönderemezsiniz')),
                      );
                    }
                    return;
                  }

                  await FriendsService.instance.sendFriendRequest(userDoc.id);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('friends_page: Arkadaşlık isteği gönderildi')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('friends_page: Hata: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.userPlus),
            onPressed: _showAddFriendDialog,
            tooltip: 'Arkadaş Ekle',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: theme.appBarTheme.backgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    title: 'Arkadaşlar',
                    index: 0,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    title: 'İstekler',
                    index: 1,
                    isDark: isDark,
                  ),
                ), // Sağ boşluk
              ],
            ),
          ),
        ),
      ),
      body: _selectedTab == 0 ? _buildFriendsList() : _buildRequestsList(),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FriendsService.instance.getFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.peopleGroup,
            title: 'Henüz Arkadaşınız Yok',
            subtitle: 'Sağ üstteki + butonuna tıklayarak arkadaş ekleyin',
          );
        }

        final friendships = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendships.length,
          itemBuilder: (context, index) {
            final friendship = friendships[index];
            final users = List<String>.from(friendship['users']);
            final friendId = users.firstWhere((id) => id != currentUserId);

            return FutureBuilder<DocumentSnapshot>(
              future: FriendsService.instance.getUserInfo(friendId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                final isOnline = userData['isOnline'] ?? false;
                final email = userData['email'] ?? 'Bilinmeyen';
                final username = userData['username'] ?? email.split('@')[0];

                return _buildFriendCard(
                  friendId: friendId,
                  friendshipId: friendship.id,
                  username: username,
                  email: email,
                  isOnline: isOnline,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsList() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FriendsService.instance.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.inbox,
            title: 'Bekleyen İstek Yok',
            subtitle: 'Arkadaşlık istekleriniz burada görünecek',
          );
        }

        final requests = snapshot.data!.docs.where((doc) {
          return doc['requesterId'] != currentUserId;
        }).toList();

        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: FontAwesomeIcons.inbox,
            title: 'Bekleyen İstek Yok',
            subtitle: 'Arkadaşlık istekleriniz burada görünecek',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final requesterId = request['requesterId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FriendsService.instance.getUserInfo(requesterId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                final email = userData['email'] ?? 'Bilinmeyen';
                final username = userData['username'] ?? email.split('@')[0];

                return _buildRequestCard(
                  requestId: request.id,
                  username: username,
                  email: email,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendCard({
    required String friendId,
    required String friendshipId,
    required String username,
    required String email,
    required bool isOnline,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
              child: Text(
                username[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.cardColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          username,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF2D3748),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
              style: TextStyle(
                fontSize: 12,
                color: isOnline ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(FontAwesomeIcons.ellipsis),
          onSelected: (value) async {
            if (value == 'message') {
              // Mesaj gönderme özelliği eklenebilir
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('friends_page: Mesajlaşma özelliği yakında eklenecek')),
              );
            } else if (value == 'remove') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Arkadaşlığı Kaldır'),
                  content: Text('$username ile arkadaşlığınızı kaldırmak istediğinizden emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Kaldır'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FriendsService.instance.removeFriend(friendshipId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('friends_page: Arkadaşlık kaldırıldı')),
                  );
                }
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'message',
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.message, size: 20),
                  SizedBox(width: 12),
                  Text('Mesaj Gönder'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.userXmark, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Arkadaşlığı Kaldır', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required String requestId,
    required String username,
    required String email,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
          child: Text(
            username[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2563EB),
            ),
          ),
        ),
        title: Text(
          username,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF2D3748),
          ),
        ),
        subtitle: Text(
          email,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.red, size: 18),
              onPressed: () async {
                await FriendsService.instance.rejectFriendRequest(requestId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('friends_page: İstek reddedildi')),
                  );
                }
              },
              tooltip: 'Reddet',
            ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.check, color: Colors.green, size: 18),
              onPressed: () async {
                await FriendsService.instance.acceptFriendRequest(requestId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('friends_page: İstek kabul edildi')),
                  );
                }
              },
              tooltip: 'Kabul Et',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

