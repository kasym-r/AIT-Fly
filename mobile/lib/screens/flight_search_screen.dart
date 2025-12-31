// '''
// Flight Search Screen
// ====================
// This is the main screen where users can search for flights.
// Users can filter by origin, destination, and date.
// '''

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import '../utils/notification_helper.dart';
import 'flight_details_screen.dart';
import 'my_trips_screen.dart';
import 'announcements_screen.dart';
import 'profile_screen.dart';

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key});

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen> with WidgetsBindingObserver {
  // Data
  List<Airport> _airports = [];
  List<Flight> _flights = [];
  List<Announcement> _announcements = [];
  
  // Selected filters
  Airport? _selectedOrigin;
  Airport? _selectedDestination;
  DateTime? _selectedDate;
  
  // UI state
  bool _isLoadingAirports = true;
  bool _isLoadingFlights = false;
  String? _errorMessage;
  int _unreadCount = 0;
  
  // Auto-refresh timer
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAirports();
    _searchFlights(); // Load all flights initially
    _loadAnnouncements();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _loadAnnouncements();
    }
  }

  // Start auto-refresh timer (every 30 seconds)
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadAnnouncements();
      }
    });
  }

  // Load announcements and update unread count
  Future<void> _loadAnnouncements() async {
    try {
      final announcements = await ApiService.getAnnouncements();
      final unreadCount = await NotificationHelper.getUnreadCount(announcements);
      if (mounted) {
        setState(() {
          _announcements = announcements;
          _unreadCount = unreadCount;
        });
      }
    } catch (e) {
      // Silently fail - announcements are not critical
    }
  }

  // Refresh unread count when returning from announcements screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh unread count when screen becomes visible
    _loadAnnouncements();
  }

  // Load airports for dropdown
  Future<void> _loadAirports() async {
    try {
      final airports = await ApiService.getAirports();
      setState(() {
        _airports = airports;
        _isLoadingAirports = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load airports: ${e.toString()}';
        _isLoadingAirports = false;
      });
    }
  }

  // Search flights based on filters
  Future<void> _searchFlights() async {
    setState(() {
      _isLoadingFlights = true;
      _errorMessage = null;
    });

    try {
      final flights = await ApiService.searchFlights(
        originAirportId: _selectedOrigin?.id,
        destinationAirportId: _selectedDestination?.id,
        date: _selectedDate,
      );
      
      setState(() {
        _flights = flights;
        _isLoadingFlights = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to search flights: ${e.toString()}';
        _isLoadingFlights = false;
      });
    }
  }

  // Show date picker
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _searchFlights();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return Colors.blue;
      case 'BOARDING':
        return Colors.orange;
      case 'DEPARTED':
        return Colors.purple;
      case 'ARRIVED':
        return Colors.green;
      case 'DELAYED':
        return Colors.amber.shade700;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Flights'),
        actions: [
          // Profile button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            tooltip: 'My Profile',
          ),
          // My Trips button
          IconButton(
            icon: const Icon(Icons.flight),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyTripsScreen()),
              );
            },
            tooltip: 'My Trips',
          ),
          // Announcements button with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
                  );
                  // Refresh unread count after returning
                  _loadAnnouncements();
                },
                tooltip: 'Announcements',
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
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
          ),
        ],
      ),
      body: Column(
        children: [
          // Search filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                // Origin dropdown
                DropdownButtonFormField<Airport>(
                  initialValue: _selectedOrigin,
                  decoration: const InputDecoration(
                    labelText: 'From',
                    prefixIcon: Icon(Icons.flight_takeoff),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _airports.map((airport) {
                    return DropdownMenuItem(
                      value: airport,
                      child: Text(airport.displayName),
                    );
                  }).toList(),
                  onChanged: (airport) {
                    setState(() {
                      _selectedOrigin = airport;
                    });
                    _searchFlights();
                  },
                ),
                const SizedBox(height: 12),
                
                // Destination dropdown
                DropdownButtonFormField<Airport>(
                  initialValue: _selectedDestination,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    prefixIcon: Icon(Icons.flight_land),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _airports.map((airport) {
                    return DropdownMenuItem(
                      value: airport,
                      child: Text(airport.displayName),
                    );
                  }).toList(),
                  onChanged: (airport) {
                    setState(() {
                      _selectedDestination = airport;
                    });
                    _searchFlights();
                  },
                ),
                const SizedBox(height: 12),
                
                // Date picker
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    child: Text(
                      _selectedDate == null
                          ? 'Select date'
                          : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                      style: TextStyle(
                        color: _selectedDate == null
                            ? Colors.grey.shade600
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Clear filters button
                if (_selectedOrigin != null ||
                    _selectedDestination != null ||
                    _selectedDate != null)
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedOrigin = null;
                        _selectedDestination = null;
                        _selectedDate = null;
                      });
                      _searchFlights();
                    },
                    child: const Text('Clear Filters'),
                  ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoadingFlights
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
                              onPressed: _searchFlights,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _flights.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No flights found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your search filters',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _flights.length,
                            itemBuilder: (context, index) {
                              final flight = _flights[index];
                              final hasAvailableSeats = flight.availableSeats != null && flight.availableSeats! > 0;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: hasAvailableSeats ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FlightDetailsScreen(
                                          flightId: flight.id,
                                        ),
                                      ),
                                    );
                                  } : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Flight number and status
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.flight, color: Colors.blue, size: 24),
                                                const SizedBox(width: 8),
                                                Text(
                                                  flight.flightNumber,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(flight.status).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: _getStatusColor(flight.status)),
                                              ),
                                              child: Text(
                                                flight.status,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: _getStatusColor(flight.status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Route
                                        Text(
                                          flight.route,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Text(
                                          '${flight.originAirport.city} → ${flight.destinationAirport.city}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Time info row
                                        Row(
                                          children: [
                                            // Departure
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    DateFormat('HH:mm').format(flight.departureTime),
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('MMM dd').format(flight.departureTime),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Duration
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    flight.durationFormatted,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Arrival
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    DateFormat('HH:mm').format(flight.arrivalTime),
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('MMM dd').format(flight.arrivalTime),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        
                                        // Bottom row: Price and Available seats
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Available seats
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.event_seat,
                                                  size: 18,
                                                  color: hasAvailableSeats ? Colors.green : Colors.red,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  flight.availableSeats != null
                                                      ? '${flight.availableSeats} seats available'
                                                      : 'Check availability',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: hasAvailableSeats ? Colors.green.shade700 : Colors.red.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Price
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'from',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${flight.basePrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}



