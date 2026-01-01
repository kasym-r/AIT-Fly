// """
// Announcements Screen
// ====================
// This screen displays all active announcements from the airline.
// """

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../utils/notification_helper.dart';
import 'profile_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement> _announcements = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final announcements = await ApiService.getAnnouncements();
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
      
      // Mark announcements as seen when user views the screen
      await NotificationHelper.markAsSeen(announcements);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => AITFlyTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'AIT Fly',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            tooltip: 'My Profile',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnnouncements,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: AITFlyTheme.gradientBackground,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AITFlyTheme.primaryPurple),
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AITFlyTheme.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AITFlyTheme.cardShadow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: AITFlyTheme.error),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: AITFlyTheme.bodyLarge.copyWith(color: AITFlyTheme.error),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: AITFlyTheme.purpleGradientButton,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _loadAnnouncements,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _announcements.isEmpty
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AITFlyTheme.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AITFlyTheme.cardShadow,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.notifications_off,
                                  size: 64, color: AITFlyTheme.mediumGray),
                              const SizedBox(height: 16),
                              Text(
                                'No announcements',
                                style: AITFlyTheme.heading3.copyWith(
                                  color: AITFlyTheme.darkGray,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check back later for updates',
                                style: AITFlyTheme.bodyMedium.copyWith(
                                  color: AITFlyTheme.mediumGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAnnouncements,
                        color: AITFlyTheme.primaryPurple,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _announcements.length,
                          itemBuilder: (context, index) {
                            final announcement = _announcements[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AITFlyTheme.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: AITFlyTheme.cardShadow,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getColorForType(announcement.announcementType).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getIconForType(announcement.announcementType),
                                        size: 32,
                                        color: _getColorForType(announcement.announcementType),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  announcement.title,
                                                  style: AITFlyTheme.heading3,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getColorForType(announcement.announcementType).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  announcement.typeLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getColorForType(announcement.announcementType),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            announcement.message,
                                            style: AITFlyTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            DateFormat('MMM dd, yyyy HH:mm')
                                                .format(announcement.createdAt),
                                            style: AITFlyTheme.bodySmall.copyWith(
                                              color: AITFlyTheme.mediumGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'DELAY':
        return Icons.schedule;
      case 'CANCELLATION':
        return Icons.cancel;
      case 'GATE_CHANGE':
        return Icons.directions_walk;
      case 'BOARDING':
        return Icons.flight_takeoff;
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'DELAY':
        return Colors.orange;
      case 'CANCELLATION':
        return Colors.red;
      case 'GATE_CHANGE':
        return Colors.blue;
      case 'BOARDING':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}



