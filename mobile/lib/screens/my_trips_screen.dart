// """
// My Trips Screen
// ===============
// This screen shows all bookings for the current user.
// Users can view booking details, check in, and view boarding passes.
// """

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api_service.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> with SingleTickerProviderStateMixin {
  List<Booking> _bookings = [];
  List<Announcement> _announcements = [];
  PassengerProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    // Start countdown timer for pending bookings
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _pendingBookings.isNotEmpty) {
        setState(() {
          // Trigger rebuild to update countdown timers
        });
      }
    });
  }

  Duration _getTimeRemaining(Booking booking) {
    // Handle UTC time properly - ensure both times are in UTC for comparison
    final createdAt = booking.createdAt.isUtc ? booking.createdAt : booking.createdAt.toUtc();
    final expiryTime = createdAt.add(const Duration(minutes: 10));
    final now = DateTime.now().toUtc();
    final remaining = expiryTime.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load bookings, announcements, and profile in parallel
      final results = await Future.wait([
        ApiService.getMyBookings(),
        ApiService.getAnnouncements(),
        _loadProfile(),
      ]);
      
      setState(() {
        _bookings = results[0] as List<Booking>;
        _announcements = results[1] as List<Announcement>;
        _profile = results[2] as PassengerProfile?;
        _isLoading = false;
      });
    } catch (e) {
      // Extract error message (remove "Exception: " prefix if present)
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<PassengerProfile?> _loadProfile() async {
    try {
      return await ApiService.getPassengerProfile();
    } catch (e) {
      return null; // Profile might not exist yet
    }
  }

  Future<void> _loadBookings() async {
    try {
      final bookings = await ApiService.getMyBookings();
      setState(() {
        _bookings = bookings;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pending bookings: CREATED status (not yet paid)
  List<Booking> get _pendingBookings {
    return _bookings.where((booking) {
      return booking.status.toUpperCase() == 'CREATED';
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Booking> get _upcomingTrips {
    // Upcoming trips: CONFIRMED bookings with flights that are scheduled, boarding, or delayed
    return _bookings.where((booking) {
      if (booking.status.toUpperCase() != 'CONFIRMED') return false;
      final status = booking.flight.status.toUpperCase();
      return status == 'SCHEDULED' || 
             status == 'BOARDING' || 
             status == 'DELAYED';
    }).toList()..sort((a, b) => a.flight.departureTime.compareTo(b.flight.departureTime));
  }

  List<Booking> get _pastTrips {
    // Past trips: Only CONFIRMED bookings with completed flights (exclude cancelled bookings)
    return _bookings.where((booking) {
      final bookingStatus = booking.status.toUpperCase();
      if (bookingStatus == 'CANCELLED') return false; // Don't show cancelled bookings in past trips
      if (bookingStatus != 'CONFIRMED') return false;
      final flightStatus = booking.flight.status.toUpperCase();
      return flightStatus == 'DEPARTED' || 
             flightStatus == 'ARRIVED' || 
             flightStatus == 'CANCELLED';
    }).toList()..sort((a, b) => b.flight.departureTime.compareTo(a.flight.departureTime));
  }

  List<Announcement> _getAnnouncementsForFlight(int flightId) {
    // Filter announcements: only flight-specific announcements for this flight (no general ones)
    return _announcements.where((a) => 
      a.isActive && a.flightId == flightId
    ).toList();
  }

  Future<void> _cancelPendingBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Text(
          'Are you sure you want to cancel this booking?\n\n'
          'Booking: ${booking.bookingReference}\n'
          'Flight: ${booking.flight.flightNumber}\n'
          'Seat: ${booking.seat.seatNumber}\n\n'
          'The seat will be released and made available for others.'
          '${booking.status == 'CONFIRMED' ? '\n\n⚠️ Note: No refund will be provided for confirmed bookings.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.cancelBooking(booking.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(booking.status == 'CONFIRMED' 
                ? 'Booking cancelled. Note: No refund will be provided.'
                : 'Booking cancelled. Seat has been released.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _cancelConfirmedBooking(Booking booking) async {
    await _cancelPendingBooking(booking);
  }

  Future<void> _checkIn(Booking booking) async {
    try {
      await ApiService.checkIn(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in successful!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBookings(); // Refresh to show updated status
      }
    } catch (e) {
      if (mounted) {
        // Extract error message (remove "Exception: " prefix if present)
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in failed: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showBoardingPass(Booking booking) async {
    try {
      final boardingPass = await ApiService.getBoardingPass(booking.id);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: AITFlyTheme.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AITFlyTheme.cardShadow,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: AITFlyTheme.primaryGradient,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AIT Fly',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            boardingPass.flightNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Passenger name
                          if (boardingPass.passengerName != null)
                            Text(
                              boardingPass.passengerName!,
                              style: AITFlyTheme.heading3,
                            ),
                          const SizedBox(height: 16),
                          
                          // Route
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'FROM',
                                      style: AITFlyTheme.bodySmall,
                                    ),
                                    Text(
                                      boardingPass.origin.split(' - ')[0],
                                      style: AITFlyTheme.heading3,
                                    ),
                                    if (boardingPass.origin.split(' - ').length > 1)
                                      Text(
                                        boardingPass.origin.split(' - ')[1],
                                        style: AITFlyTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.flight, color: AITFlyTheme.primaryPurple),
                              Expanded(
                                child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'TO',
                                    style: AITFlyTheme.bodySmall,
                                  ),
                                  Text(
                                    boardingPass.destination.split(' - ')[0],
                                    style: AITFlyTheme.heading3,
                                  ),
                                  if (boardingPass.destination.split(' - ').length > 1)
                                    Text(
                                      boardingPass.destination.split(' - ')[1],
                                      style: AITFlyTheme.bodySmall,
                                    ),
                                ],
                              ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Flight details
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('DEPARTURE', style: AITFlyTheme.bodySmall),
                                  Text(
                                    DateFormat('MMM dd, HH:mm').format(boardingPass.departureTime),
                                    style: AITFlyTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (boardingPass.boardingGate != null || boardingPass.terminal != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (boardingPass.terminal != null) ...[
                                      const Text('TERMINAL', style: AITFlyTheme.bodySmall),
                                      Text(
                                        boardingPass.terminal!,
                                        style: AITFlyTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    if (boardingPass.boardingGate != null) ...[
                                      const Text('GATE', style: AITFlyTheme.bodySmall),
                                      Text(
                                        boardingPass.boardingGate!,
                                        style: AITFlyTheme.heading3,
                                      ),
                                    ],
                                  ],
                                ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('SEAT', style: AITFlyTheme.bodySmall),
                                  Text(
                                    boardingPass.seat,
                                    style: AITFlyTheme.heading3,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // QR Code
                          if (boardingPass.qrCode != null) ...[
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AITFlyTheme.lightGray,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: QrImageView(
                                  data: boardingPass.qrCode!,
                                  version: QrVersions.auto,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text(
                                'Scan at the gate',
                                style: AITFlyTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Booking reference
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AITFlyTheme.lightPurple.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Booking Ref:', style: AITFlyTheme.bodyMedium),
                                Text(
                                  boardingPass.bookingReference,
                                  style: AITFlyTheme.bodyLarge.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (boardingPass.ticketNumber != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AITFlyTheme.lightPurple.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Ticket:', style: AITFlyTheme.bodyMedium),
                                  Text(
                                    boardingPass.ticketNumber!,
                                    style: AITFlyTheme.bodyLarge.copyWith(
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AITFlyTheme.lightPurple.withOpacity(0.3)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load boarding pass: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: _pendingBookings.isEmpty ? 'Pending' : 'Pending (${_pendingBookings.length})',
              icon: const Icon(Icons.pending_actions),
            ),
            const Tab(text: 'Upcoming', icon: Icon(Icons.flight_takeoff)),
            const Tab(text: 'Past', icon: Icon(Icons.flight_land)),
          ],
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
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingList(),
                    _buildTripsList(_upcomingTrips, isUpcoming: true),
                    _buildTripsList(_pastTrips, isUpcoming: false),
                  ],
                ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No pending payments',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All your bookings are paid',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingBookings.length,
        itemBuilder: (context, index) {
          final booking = _pendingBookings[index];
          final timeRemaining = _getTimeRemaining(booking);
          final isExpired = timeRemaining == Duration.zero;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isExpired ? AITFlyTheme.error.withOpacity(0.1) : AITFlyTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpired ? AITFlyTheme.error : AITFlyTheme.warning,
                width: 1.5,
              ),
              boxShadow: AITFlyTheme.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with warning and timer
                  Row(
                    children: [
                      Icon(
                        isExpired ? Icons.error_outline : Icons.pending_actions,
                        color: isExpired ? AITFlyTheme.error : AITFlyTheme.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isExpired ? 'Time Expired' : 'Payment Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isExpired ? AITFlyTheme.error : AITFlyTheme.warning,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isExpired 
                              ? LinearGradient(colors: [AITFlyTheme.error, AITFlyTheme.error.withOpacity(0.8)])
                              : LinearGradient(colors: [AITFlyTheme.warning, AITFlyTheme.warning.withOpacity(0.8)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isExpired 
                              ? 'EXPIRED'
                              : '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isExpired) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AITFlyTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AITFlyTheme.error, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your booking has expired. The seat has been released.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AITFlyTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  
                  // Booking info
                  Text(
                    'Ref: ${booking.bookingReference}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Flight details
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.flight.flightNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              booking.flight.route,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy · HH:mm').format(booking.flight.departureTime),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Seat ${booking.seat.seatNumber}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${booking.seat.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Warning about seat hold expiry
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Seat will be released if payment is not completed within 10 minutes of booking',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelPendingBooking(booking),
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _payForPendingBooking(booking),
                          icon: const Icon(Icons.payment),
                          label: const Text('Complete Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _payForPendingBooking(Booking booking) async {
    // Show payment method selection dialog
    final method = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Credit Card'),
              onTap: () => Navigator.of(context).pop('CARD'),
            ),
            ListTile(
              leading: const Icon(Icons.apple),
              title: const Text('Apple Pay'),
              onTap: () => Navigator.of(context).pop('APPLE_PAY'),
            ),
            ListTile(
              leading: const Icon(Icons.android),
              title: const Text('Google Pay'),
              onTap: () => Navigator.of(context).pop('GOOGLE_PAY'),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    try {
      await ApiService.createPayment(
        PaymentCreate(bookingId: booking.id, method: method),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Booking confirmed.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
        // Switch to upcoming tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTripsList(List<Booking> trips, {required bool isUpcoming}) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUpcoming ? Icons.flight_takeoff : Icons.flight_land,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming trips' : 'No past trips',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isUpcoming
                  ? 'Book a flight to see it here'
                  : 'Your completed trips will appear here',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final booking = trips[index];
          final flightAnnouncements = _getAnnouncementsForFlight(booking.flight.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: Icon(
                isUpcoming ? Icons.flight_takeoff : Icons.flight_land,
                color: _getStatusColor(booking.flight.status),
              ),
              title: Text(
                booking.flight.flightNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${booking.flight.originAirport.code} → ${booking.flight.destinationAirport.code}'),
                  Text(
                    DateFormat('MMM dd, yyyy HH:mm')
                        .format(booking.flight.departureTime),
                  ),
                  Chip(
                    label: Text(
                      booking.flight.status,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(booking.flight.status).withOpacity(0.2),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Booking Details Section
                      const Text(
                        'Booking Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Booking Reference', booking.bookingReference),
                      _buildDetailRow('Seat', booking.seat.seatNumber),
                      _buildDetailRow('Class', booking.seat.seatClass),
                      _buildDetailRow('Total Price', '\$${booking.totalPrice.toStringAsFixed(2)}'),
                      _buildDetailRow('Status', booking.flight.status),
                      
                      // Passenger Details Section
                      // Use booking's passenger data if available, otherwise use user profile
                      if (booking.hasCustomPassengerData || _profile != null) ...[
                        const Divider(height: 32),
                        const Text(
                          'Passenger Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (booking.hasCustomPassengerData) ...[
                          // Use booking's custom passenger data
                          _buildDetailRow('Name', '${booking.passengerFirstName ?? ''} ${booking.passengerLastName ?? ''}'.trim()),
                          if (booking.passengerPhone != null)
                            _buildDetailRow('Phone', booking.passengerPhone!),
                          if (booking.passengerPassportNumber != null)
                            _buildDetailRow('Passport', booking.passengerPassportNumber!),
                          if (booking.passengerNationality != null)
                            _buildDetailRow('Nationality', booking.passengerNationality!),
                          if (booking.passengerDateOfBirth != null)
                            _buildDetailRow('Date of Birth', DateFormat('yyyy-MM-dd').format(booking.passengerDateOfBirth!)),
                        ] else if (_profile != null) ...[
                          // Fall back to user profile
                          _buildDetailRow('Name', '${_profile!.firstName} ${_profile!.lastName}'),
                          _buildDetailRow('Phone', _profile!.phone),
                          _buildDetailRow('Passport', _profile!.passportNumber),
                          _buildDetailRow('Nationality', _profile!.nationality),
                        ],
                      ],

                      // Flight Details Section
                      const Divider(height: 32),
                      const Text(
                        'Flight Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Departure', 
                        '${DateFormat('MMM dd, yyyy HH:mm').format(booking.flight.departureTime)}\n${booking.flight.originAirport.name}'),
                      _buildDetailRow('Arrival',
                        '${DateFormat('MMM dd, yyyy HH:mm').format(booking.flight.arrivalTime)}\n${booking.flight.destinationAirport.name}'),
                      
                      // Announcements Section
                      if (flightAnnouncements.isNotEmpty && isUpcoming) ...[
                        const Divider(height: 32),
                        const Text(
                          'Announcements',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...flightAnnouncements.map((announcement) => Card(
                          color: Colors.blue.shade50,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  announcement.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  announcement.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],

                      // Action Buttons
                      if (isUpcoming) ...[
                        const Divider(height: 32),
                        // Cancel button for confirmed bookings
                        if (booking.status == 'CONFIRMED') ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _cancelConfirmedBooking(booking),
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text(
                                'Cancel Booking',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _checkIn(booking),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Check In'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showBoardingPass(booking),
                              icon: const Icon(Icons.airplane_ticket),
                              label: const Text('Boarding Pass'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return Colors.blue;
      case 'BOARDING':
        return Colors.orange;
      case 'DEPARTED':
        return Colors.grey;
      case 'ARRIVED':
        return Colors.green;
      case 'DELAYED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}



