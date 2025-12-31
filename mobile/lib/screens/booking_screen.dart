// """
// Booking Screen
// ==============
// This screen handles the booking process:
// 1. Shows booking summary
// 2. Processes payment
// 3. Shows confirmation
// """

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import 'my_trips_screen.dart';
import 'profile_screen.dart';

class BookingScreen extends StatefulWidget {
  final Flight flight;
  final List<Seat> seats;  // Changed to support multiple seats

  const BookingScreen({
    super.key,
    required this.flight,
    required this.seats,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  List<Booking> _bookings = [];  // Changed to support multiple bookings
  List<Payment> _payments = [];  // Changed to support multiple payments

  final List<String> _paymentMethods = ['CARD', 'APPLE_PAY', 'GOOGLE_PAY'];

  double get _totalPrice {
    return widget.seats.fold<double>(0, (sum, seat) => sum + seat.price);
  }

  bool get _allPaymentsPaid {
    return _payments.isNotEmpty && _payments.every((p) => p.isPaid);
  }

  Future<void> _createBooking() async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Check if profile exists first
      try {
        await ApiService.getPassengerProfile();
      } catch (e) {
        // Profile doesn't exist - navigate to profile screen
        setState(() {
          _isProcessing = false;
        });
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

      // Create bookings for all selected seats
      List<Booking> bookings = [];
      List<Payment> payments = [];
      
      try {
        for (final seat in widget.seats) {
          // Create booking for this seat
          final bookingRequest = BookingCreate(
            flightId: widget.flight.id,
            seatId: seat.id,
          );
          
          final booking = await ApiService.createBooking(bookingRequest);
          bookings.add(booking);
          
          // Process payment for this booking
          final paymentRequest = PaymentCreate(
            bookingId: booking.id,
            method: _selectedPaymentMethod!,
          );
          
          final payment = await ApiService.createPayment(paymentRequest);
          
          // Verify payment is PAID
          if (payment.status != 'PAID') {
            throw Exception('Payment failed for seat ${seat.seatNumber}. Status: ${payment.status}');
          }
          
          payments.add(payment);
        }
      } catch (e) {
        // If any booking/payment fails, show error
        setState(() {
          _isProcessing = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking error: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      setState(() {
        _bookings = bookings;
        _payments = payments;
        _isProcessing = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        // Extract error message (remove "Exception: " prefix if present)
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        
        // Show more helpful error for profile-related errors
        if (errorMessage.contains('profile') || errorMessage.contains('Profile')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Profile Required'),
              content: Text(
                'Please complete your passenger profile before booking a flight.\n\n'
                'Error: $errorMessage',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: const Text('Go to Profile'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking failed: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  void _goToMyTrips() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyTripsScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If all bookings are complete, show confirmation
    if (_bookings.isNotEmpty && _payments.isNotEmpty && _allPaymentsPaid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Confirmed')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Booking Confirmed!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Bookings', '${_bookings.length} ticket${_bookings.length > 1 ? 's' : ''}'),
                        const Divider(),
                        _buildInfoRow('Flight', widget.flight.flightNumber),
                        _buildInfoRow('Seats', widget.seats.map((s) => s.seatNumber).join(', ')),
                        _buildInfoRow('Total Paid', '\$${_payments.fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(2)}'),
                        _buildInfoRow('Payment Method', _payments.first.method),
                        if (_bookings.length == 1)
                          _buildInfoRow('Booking Reference', _bookings.first.bookingReference),
                        if (_bookings.length > 1) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Booking References:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ..._bookings.map((b) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('• ${b.bookingReference}'),
                          )),
                        ],
                        if (_payments.first.transactionId != null)
                          _buildInfoRow('Transaction ID', _payments.first.transactionId!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _goToMyTrips,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View My Trips'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Booking form
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow('Flight', widget.flight.flightNumber),
                    _buildSummaryRow(
                        'Route',
                        '${widget.flight.originAirport.code} → ${widget.flight.destinationAirport.code}'),
                    _buildSummaryRow(
                        'Departure',
                        DateFormat('MMM dd, yyyy HH:mm')
                            .format(widget.flight.departureTime)),
                    _buildSummaryRow(
                        'Arrival',
                        DateFormat('MMM dd, yyyy HH:mm')
                            .format(widget.flight.arrivalTime)),
                    _buildSummaryRow('Seats', widget.seats.map((s) => s.seatNumber).join(', ')),
                    _buildSummaryRow('Class', widget.seats.first.seatClass), // Assuming all same class
                    if (widget.seats.length > 1) ...[
                      const Divider(),
                      ...widget.seats.map((seat) => _buildSummaryRow(
                        'Seat ${seat.seatNumber}',
                        '\$${seat.price.toStringAsFixed(2)}',
                      )),
                    ],
                    const Divider(),
                    _buildSummaryRow(
                        'Total Price',
                        '\$${_totalPrice.toStringAsFixed(2)}',
                        isTotal: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payment method selection
            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._paymentMethods.map((method) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  title: Text(method.replaceAll('_', ' ')),
                  value: method,
                  groupValue: _selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  },
                ),
              );
            }),
            const SizedBox(height: 24),

            // Book button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _createBooking,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Confirm Booking - \$${_totalPrice.toStringAsFixed(2)} (${widget.seats.length} seat${widget.seats.length > 1 ? 's' : ''})',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.blue : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}



