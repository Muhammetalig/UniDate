import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialMediaMenuPage extends StatefulWidget {
  const SocialMediaMenuPage({super.key});

  @override
  State<SocialMediaMenuPage> createState() => _SocialMediaMenuPageState();
}

class _SocialMediaMenuPageState extends State<SocialMediaMenuPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic> socialMedias = {};
  bool isLoading = true;

  final List<Map<String, dynamic>> platforms = [
    {
      'name': 'Instagram',
      'key': 'instagram',
      'icon': FontAwesomeIcons.instagram,
      'color': const Color(0xFFE4405F),
    },
    {
      'name': 'Facebook',
      'key': 'facebook',
      'icon': FontAwesomeIcons.facebook,
      'color': const Color(0xFF1877F2),
    },
    {
      'name': 'Twitter',
      'key': 'twitter',
      'icon': FontAwesomeIcons.x,
      'color': const Color(0xFF1DA1F2),
    },
    {
      'name': 'Telegram',
      'key': 'telegram',
      'icon': FontAwesomeIcons.telegram,
      'color': const Color(0xFF0088CC),
    },
    {
      'name': 'LinkedIn',
      'key': 'linkedin',
      'icon': FontAwesomeIcons.linkedin,
      'color': const Color(0xFF0A66C2),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSocialMedias();
  }

  Future<void> _loadSocialMedias() async {
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (mounted) {
          setState(() {
            socialMedias = doc.data()?['socialMedias'] ?? {};
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('SocialMedia: Error loading social medias: $e');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _addOrEditSocialMedia(String platform, String key) async {
    final controller = TextEditingController(text: socialMedias[key] ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            '$platform Kullanıcı Adı',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Kullanıcı adınızı girin',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              prefixIcon: Center(
                widthFactor: 1.0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: FaIcon(
                    FontAwesomeIcons.user,
                    color: const Color(0xFF2563EB),
                    size: 18,
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 2,
                ),
              ),
            ),
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          actions: [
            if (socialMedias[key] != null && socialMedias[key].toString().isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(context, 'DELETE'),
                child: const Text(
                  'Kaldır',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (result != null && user != null) {
      try {
        if (result == 'DELETE') {
          socialMedias.remove(key);
        } else if (result.isNotEmpty) {
          socialMedias[key] = result;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({
          'socialMedias': socialMedias,
        });

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result == 'DELETE' 
                    ? '$platform kaldırıldı' 
                    : '$platform kaydedildi',
              ),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
      } catch (e) {
        debugPrint('SocialMedia: Error updating social media: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata oluştu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
        title: const Text('Sosyal Medya Hesapları'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: FaIcon(
                                  FontAwesomeIcons.circleInfo,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sosyal medya hesaplarınız profilinizde görüntülenecektir.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF2D3748),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Social Media List Container
                      Container(
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
                          children: [
                            for (int i = 0; i < platforms.length; i++) ...[
                              _buildSocialMediaOption(
                                platforms[i]['name'] as String,
                                platforms[i]['key'] as String,
                                platforms[i]['icon'] as IconData,
                                platforms[i]['color'] as Color,
                              ),
                              if (i < platforms.length - 1)
                                _buildDivider(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSocialMediaOption(
    String name,
    String key,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final username = socialMedias[key]?.toString() ?? '';
    final hasUsername = username.isNotEmpty;

    return InkWell(
      onTap: () => _addOrEditSocialMedia(name, key),
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: FaIcon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 15),
            
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasUsername ? '@$username' : 'Ekle',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUsername
                          ? (isDark ? Colors.grey[400] : Colors.grey[600])
                          : Colors.grey[500],
                      fontStyle: hasUsername 
                          ? FontStyle.normal 
                          : FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Edit/Add icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: FaIcon(
                  hasUsername ? FontAwesomeIcons.pen : FontAwesomeIcons.plus,
                  color: const Color(0xFF2563EB),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: Theme.of(context).dividerColor,
    );
  }
}