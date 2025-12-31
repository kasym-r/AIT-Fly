// """
// Flight Details Screen
// =====================
// This screen shows detailed information about a flight and allows
// users to select a seat and proceed to booking.
// """

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import 'profile_screen.dart';
import 'my_trips_screen.dart';

class FlightDetailsScreen extends StatefulWidget {
  final int flightId;

  const FlightDetailsScreen({super.key, required this.flightId});

  @override
  State<FlightDetailsScreen> createState() => _FlightDetailsScreenState();
}

class _FlightDetailsScreenState extends State<FlightDetailsScreen> {
  Flight? _flight;
  List<Seat> _seats = [];
  final List<Seat> _selectedSeats = [];  // Changed to support multiple seats
  
  bool _isLoading = true;
  String? _errorMessage;

  @override 
  void initState() {
    super.initState();
    _loadFlightDetails();
  }

  Future<void> _loadFlightDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final flight = await ApiService.getFlightDetails(widget.flightId);
      final seats = await ApiService.getFlightSeats(widget.flightId);
      
      setState(() {
        _flight = flight;
        _seats = seats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSeat(Seat seat) async {
    if (!seat.isAvailable && seat.status != 'HELD') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This seat is not available')),
      );
      return;
    }

    // Check if seat is already selected
    final isSelected = _selectedSeats.any((s) => s.id == seat.id);
    
    if (isSelected) {
      // Deselect seat - release hold
      setState(() {
        _selectedSeats.removeWhere((s) => s.id == seat.id);
        // Update seat status back to available
        final index = _seats.indexWhere((s) => s.id == seat.id);
        if (index != -1) {
          _seats[index] = Seat(
            id: seat.id,
            flightId: seat.flightId,
            rowNumber: seat.rowNumber,
            seatLetter: seat.seatLetter,
            seatClass: seat.seatClass,
            seatCategory: seat.seatCategory,
            priceMultiplier: seat.priceMultiplier,
            status: 'AVAILABLE',
            price: seat.price,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seat ${seat.seatNumber} deselected'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      // Select seat - hold it
      try {
        // Hold the seat
        await ApiService.holdSeat(widget.flightId, seat.id);
        
        setState(() {
          _selectedSeats.add(seat);
          // Update seat status in local list
          final index = _seats.indexWhere((s) => s.id == seat.id);
          if (index != -1) {
            _seats[index] = Seat(
              id: seat.id,
              flightId: seat.flightId,
              rowNumber: seat.rowNumber,
              seatLetter: seat.seatLetter,
              seatClass: seat.seatClass,
              seatCategory: seat.seatCategory,
              priceMultiplier: seat.priceMultiplier,
              status: 'HELD',
              price: seat.price,
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seat ${seat.seatNumber} selected'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select seat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createBooking() async {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one seat')),
      );
      return;
    }

    // Check if profile exists
    try {
      await ApiService.getPassengerProfile();
    } catch (e) {
      // Profile doesn't exist - navigate to profile screen
      if (mounted) {
        final shouldCreateProfile = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Profile Required'),
            content: const Text(
              'Please complete your passenger profile before booking a flight.\n\n'
              'You need to provide your name and other details to make a booking.\n\n'
              'Would you like to create your profile now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create Profile'),
              ),
            ],
          ),
        );
        
        if (shouldCreateProfile == true) {
          // Navigate to profile screen
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
          // After returning from profile, try booking again
          _createBooking();
        }
      }
      return;
    }

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Create bookings for all selected seats
      List<Booking> createdBookings = [];
      for (final seat in _selectedSeats) {
        final booking = await ApiService.createBooking(
          BookingCreate(flightId: _flight!.id, seatId: seat.id),
        );
        createdBookings.add(booking);
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show confirmation dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 8),
                const Expanded(child: Text('Booking Created!')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your booking${createdBookings.length > 1 ? 's have' : ' has'} been created successfully!',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...createdBookings.map((booking) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Booking Reference: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                booking.bookingReference,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Seat: ${booking.seat.seatNumber}'),
                          Text('Price: \$${booking.totalPrice.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, color: Colors.orange.shade800, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Important:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You have 10 minutes to complete payment for your booking(s).',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Go to "My Trips" → "Pending" tab to complete payment.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Stay Here'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Navigate to My Trips
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MyTripsScreen()),
                    (route) => route.isFirst, // Keep only the first route (home)
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go to My Trips'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create booking: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flight Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _flight == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flight Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Failed to load flight details',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFlightDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Organize seats by row for display
    final seatsByRow = <int, List<Seat>>{};
    for (var seat in _seats) {
      if (!seatsByRow.containsKey(seat.rowNumber)) {
        seatsByRow[seat.rowNumber] = [];
      }
      seatsByRow[seat.rowNumber]!.add(seat);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flight information card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _flight!.flightNumber,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(
                          label: Text(_flight!.status),
                          backgroundColor: Colors.blue.shade100,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _flight!.originAirport.code,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(_flight!.originAirport.city),
                              Text(
                                DateFormat('MMM dd, HH:mm')
                                    .format(_flight!.departureTime),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward, size: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _flight!.destinationAirport.code,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                              ),
                              Text(
                                _flight!.destinationAirport.city,
                                textAlign: TextAlign.right,
                              ),
                              Text(
                                DateFormat('MMM dd, HH:mm')
                                    .format(_flight!.arrivalTime),
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    // Aircraft info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Aircraft:',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          _flight!.airplane?.model ?? 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Base Price:',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          '\$${_flight!.basePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Seat selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Your Seat',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedSeats.isEmpty
                        ? 'No seats selected'
                        : 'Selected: ${_selectedSeats.length} seat${_selectedSeats.length > 1 ? 's' : ''} (${_selectedSeats.map((s) => s.seatNumber).join(', ')})',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedSeats.isNotEmpty
                          ? Colors.green
                          : Colors.grey.shade600,
                      fontWeight: _selectedSeats.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Seat map
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: seatsByRow.entries.map((entry) {
                  final rowNumber = entry.key;
                  final seats = entry.value;
                  seats.sort((a, b) => a.seatLetter.compareTo(b.seatLetter));

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // Row number
                        SizedBox(
                          width: 40,
                          child: Text(
                            rowNumber.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Seats
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: seats.map((seat) {
                              final isSelected = _selectedSeats.any((s) => s.id == seat.id);
                              Color seatColor;
                              if (isSelected) {
                                seatColor = Colors.green;
                              } else if (seat.isBooked) {
                                seatColor = Colors.red.shade300;
                              } else if (seat.isHeld) {
                                seatColor = Colors.orange.shade300;
                              } else if (seat.isExtraLegroom) {
                                seatColor = Colors.purple.shade300;  // Extra legroom seats
                              } else {
                                seatColor = Colors.blue.shade300;
                              }

                              return GestureDetector(
                                onTap: () => _toggleSeat(seat),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: seatColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.green.shade700,
                                            width: 2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      seat.seatLetter,
                                      style: TextStyle(
                                        color: seat.isBooked
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        // Price
                        SizedBox(
                          width: 60,
                          child: Text(
                            '\$${seats.first.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildLegendItem(Colors.blue.shade300, 'Standard'),
                  _buildLegendItem(Colors.purple.shade300, 'Extra Legroom'),
                  _buildLegendItem(Colors.orange.shade300, 'Held'),
                  _buildLegendItem(Colors.red.shade300, 'Booked'),
                  _buildLegendItem(Colors.green, 'Selected'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Proceed to booking button
            if (_selectedSeats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createBooking,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Create Booking - \$${_selectedSeats.fold<double>(0, (sum, seat) => sum + seat.price).toStringAsFixed(2)} (${_selectedSeats.length} seat${_selectedSeats.length > 1 ? 's' : ''})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}



