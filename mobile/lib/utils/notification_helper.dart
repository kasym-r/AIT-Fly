// """
// Notification Helper
// ===================
// Helper class to track unread announcements and show notification badges.
// """

import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class NotificationHelper {
  static const String _lastSeenKey = 'announcements_last_seen';

  /// Get the count of unread announcements
  static Future<int> getUnreadCount(List<Announcement> announcements) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenTimestamp = prefs.getString(_lastSeenKey);
    
    if (lastSeenTimestamp == null) {
      // First time - all announcements are unread
      return announcements.where((a) => a.isActive).length;
    }
    
    final lastSeen = DateTime.parse(lastSeenTimestamp);
    
    // Count announcements created after last seen
    return announcements.where((a) => 
      a.isActive && a.createdAt.isAfter(lastSeen)
    ).length;
  }

  /// Mark all current announcements as seen
  static Future<void> markAsSeen(List<Announcement> announcements) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (announcements.isEmpty) {
      return;
    }
    
    // Find the most recent announcement timestamp
    final mostRecent = announcements
        .map((a) => a.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    
    // Store the most recent timestamp
    await prefs.setString(_lastSeenKey, mostRecent.toIso8601String());
  }

  /// Clear the last seen timestamp (for testing or reset)
  static Future<void> clearLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSeenKey);
  }
}

