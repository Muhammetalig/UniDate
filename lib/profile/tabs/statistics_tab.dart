import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class StatisticsTab extends StatelessWidget {
  final Map<String, dynamic> userData;

  const StatisticsTab({
    super.key,
    required this.userData,
  });

  String _getJoinedRoomsCount() {
    try {
      if (userData['joinedRooms'] != null) {
        if (userData['joinedRooms'] is List) {
          return (userData['joinedRooms'] as List).length.toString();
        }
      }
      return '0';
    } catch (e) {
      debugPrint('StatisticsTab: Error getting joined rooms count: $e');
      return '0';
    }
  }

  String _getActiveHours() {
    try {
      if (userData['activeHours'] != null) {
        final activeHours = userData['activeHours'];
        if (activeHours is Map &&
            activeHours['start'] != null &&
            activeHours['end'] != null) {
          return '${activeHours['start']}-${activeHours['end']}';
        }
      }
      return 'Belirsiz';
    } catch (e) {
      debugPrint('StatisticsTab: Error getting active hours: $e');
      return 'Belirsiz';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Katıldığı Oda',
                  _getJoinedRoomsCount(),
                  FontAwesomeIcons.doorOpen,
                  isDark,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  'Aktif Zaman',
                  _getActiveHours(),
                  FontAwesomeIcons.clock,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Center(
            child: FaIcon(icon, color: const Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}