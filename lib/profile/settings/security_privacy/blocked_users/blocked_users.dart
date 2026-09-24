import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> blockedUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      final blockedUserIds = List<String>.from(userDoc.data()?['blockedUsers'] ?? []);

      if (blockedUserIds.isEmpty) {
        setState(() {
          blockedUsers = [];
          isLoading = false;
        });
        return;
      }

      // Engellenen kullanıcıların bilgilerini çek
      final blockedUsersList = <Map<String, dynamic>>[];
      for (final userId in blockedUserIds) {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userSnapshot.exists) {
          blockedUsersList.add({
            'uid': userId,
            ...userSnapshot.data()!,
          });
        }
      }

      setState(() {
        blockedUsers = blockedUsersList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('blocked_users: Engellenen kullanıcılar yüklenirken hata: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'blockedUsers': FieldValue.arrayRemove([userId]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı engeli kaldırıldı'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBlockedUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Engellenen Kullanıcılar'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            )
          : blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block_outlined,
                        size: 80,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Engellenen kullanıcı yok',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Engellediğiniz kullanıcılar burada görünecek',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: blockedUsers.length,
                  itemBuilder: (context, index) {
                    final blockedUser = blockedUsers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          backgroundImage: blockedUser['profileImageUrl'] != null
                              ? NetworkImage(blockedUser['profileImageUrl'])
                              : null,
                          child: blockedUser['profileImageUrl'] == null
                              ? Icon(
                                  Icons.person,
                                  size: 30,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                )
                              : null,
                        ),
                        title: Text(
                          '${blockedUser['firstName'] ?? ''} ${blockedUser['lastName'] ?? ''}'
                              .trim(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        subtitle: Text(
                          blockedUser['university'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Engeli Kaldır'),
                                content: Text(
                                  '${blockedUser['firstName']} ${blockedUser['lastName']} engelini kaldırmak istediğinizden emin misiniz?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('İptal'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Kaldır'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              _unblockUser(blockedUser['uid']);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                          child: const Text('Engeli Kaldır'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

