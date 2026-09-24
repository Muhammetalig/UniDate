import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/guest_access.dart';
import 'chat/chat_service.dart';
import 'chat/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationWrapper();
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  Future<void> _navigateToChat(BuildContext context, String activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => const GuestAccountPrompt(title: 'Sohbete Katıl'),
      ));
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;
    final university = doc.data()?[ 'university' ] as String?;
    if (university == null || university.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen önce profilinizden üniversitenizi seçin.')),
        );
      }
      return;
    }

    final roomId = await ChatService.instance.getOrCreateRoom(
      university: university,
      activity: activity,
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            roomId: roomId,
            activity: activity,
            titleSuffix: university,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
          title: const Text('UniHub'),
          centerTitle: true,
          automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Content section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sosyalleşme Aktiviteleri',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Quick access cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          context: context,
                          icon: FontAwesomeIcons.book,
                          title: 'Kitap Okuma',
                          subtitle: 'Kitap okuma arkadaşı bul',
                          onTap: () => _navigateToChat(context, 'Kitap Okuma'),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          context: context,
                          icon: FontAwesomeIcons.school,
                          title: 'Ders Çalışma',
                          subtitle: 'Ders çalışma arkadaşı bul',
                          onTap: () => _navigateToChat(context, 'Ders Çalışma'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          context: context,
                          icon: FontAwesomeIcons.film,
                          title: 'Sinema',
                          subtitle: 'Film izleme arkadaşı bul',
                          onTap: () => _navigateToChat(context, 'Sinema'),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          context: context,
                          icon: FontAwesomeIcons.mugSaucer,
                          title: 'Kahve',
                          subtitle: 'Kahve içme arkadaşı bul',
                          onTap: () => _navigateToChat(context, 'Kahve'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          context: context,
                          icon: FontAwesomeIcons.utensils,
                          title: 'Yemek',
                          subtitle: 'Yemek yeme arkadaşı bul',
                          onTap: () => _navigateToChat(context, 'Yemek'),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          context: context,
                          icon: FontAwesomeIcons.dumbbell,
                          title: 'Spor',
                          subtitle: 'Spor yapma arkadaşı bul',
                          onTap: () => _navigateToChat(context, 'Spor'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          
                          context: context,
                          icon: FontAwesomeIcons.gamepad,
                          title: 'Oyun',
                          subtitle: 'Oyun oynama arkadaşı bul',
                          onTap: () => _navigateToChat(context, 'Oyun'),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          context: context,
                          icon: FontAwesomeIcons.personWalking,
                          title: 'Yürüyüş',
                          subtitle: 'Yürüyüş arkadaşı bul',
                          onTap: () => _navigateToChat(context, 'Yürüyüş'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 160, // Sabit yükseklik eklendi
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2563EB),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}