import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialMediaTab extends StatelessWidget {
  final Map<String, dynamic> userData;

  const SocialMediaTab({
    super.key,
    required this.userData,
  });

  bool _hasSocialMedias() {
    if (userData['socialMedias'] == null) return false;
    final socialMedias = userData['socialMedias'] as Map;
    return socialMedias.values
        .any((value) => value != null && value.toString().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final firstName = userData['firstName'] ?? 'Kullanıcı';

    if (!_hasSocialMedias()) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                FontAwesomeIcons.shareNodes,
                size: 48,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '$firstName herhangi bir sosyal medya hesabı eklemedi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: _buildSocialMediaGridItems(isDark),
      ),
    );
  }

  List<Widget> _buildSocialMediaGridItems(bool isDark) {
    final socialMedias = userData['socialMedias'] as Map;
    final platforms = {
      'instagram': {
        'icon': FontAwesomeIcons.instagram,
        'color': const Color(0xFFE4405F),
        'name': 'Instagram',
      },
      'facebook': {
        'icon': FontAwesomeIcons.facebook,
        'color': const Color(0xFF1877F2),
        'name': 'Facebook',
      },
      'twitter': {
        'icon': FontAwesomeIcons.x,
        'color': const Color(0xFF1DA1F2),
        'name': 'Twitter',
      },
      'telegram': {
        'icon': FontAwesomeIcons.telegram,
        'color': const Color(0xFF0088CC),
        'name': 'Telegram',
      },
      'linkedin': {
        'icon': FontAwesomeIcons.linkedin,
        'color': const Color(0xFF0A66C2),
        'name': 'LinkedIn',
      },
    };

    List<Widget> items = [];

    platforms.forEach((key, value) {
      if (socialMedias[key] != null && socialMedias[key].toString().isNotEmpty) {
        items.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: (value['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (value['color'] as Color).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FaIcon(
                  value['icon'] as IconData,
                  color: value['color'] as Color,
                  size: 22,
                ),
                const SizedBox(height: 8),
                Text(
                  socialMedias[key],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF2D3748),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
    });

    return items;
  }
}