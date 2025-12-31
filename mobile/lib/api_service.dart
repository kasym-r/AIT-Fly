// """
// API Service
// ===========
// This file handles all communication with the backend API.

// It's a central place for all HTTP requests, so if the API URL changes,
// you only need to update it in one place.

// Key concepts:
// - Base URL: Where the API server is running
// - Headers: Include JWT token for authenticated requests
// - Error handling: Convert HTTP errors to user-friendly messages
// """

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class ApiService {
  // Base URL of the API
  // For web: http://127.0.0.1:8000 or http://localhost:8000
  // For Android emulator: http://10.0.2.2:8000
  // For iOS simulator/macOS: http://127.0.0.1:8000
  // For physical device: http://YOUR_COMPUTER_IP:8000
  static const String baseUrl = 'http://127.0.0.1:8000';  // For web, use 127.0.0.1 or localhost android: 10.0.2.2

  // Key for storing token in shared preferences
  static const String _tokenKey = 'auth_token';

  // Get stored authentication token
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Public method to check if user is logged in (for splash screen)
  static Future<String?> getToken() async {
    return _getToken();
  }

  // Save authentication token
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Clear stored token (for logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Helper method to make authenticated requests
  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Helper method to handle errors
  static void _handleError(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Unauthorized. Please login again.');
    } else if (response.statusCode == 403) {
      throw Exception('Access denied.');
    } else if (response.statusCode == 404) {
      throw Exception('Resource not found.');
    } else if (response.statusCode >= 400) {
      // Try to parse error message from response
      try {
        final error = json.decode(response.body);
        final detail = error['detail'] ?? error['message'] ?? 'An error occurred';
        throw Exception(detail);
      } catch (e) {
        if (e is Exception) {
          rethrow;
        }
        throw Exception('An error occurred: ${response.statusCode} - ${response.reasonPhrase}');
      }
    }
  }

  // ============ AUTHENTICATION ============

  /// Register a new user
  static Future<TokenResponse> register(RegisterRequest request) async {
    final url = Uri.parse('$baseUrl/register');
    final response = await http.post(
      url,
      headers: await _getHeaders(includeAuth: false),
      body: json.encode(request.toJson()),
    );

    _handleError(response);

    final tokenResponse = TokenResponse.fromJson(json.decode(response.body));
    await _saveToken(tokenResponse.accessToken);
    return tokenResponse;
  }

  /// Login with email and password
  static Future<TokenResponse> login(LoginRequest request) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: await _getHeaders(includeAuth: false),
      body: json.encode(request.toJson()),
    );

    _handleError(response);

    final tokenResponse = TokenResponse.fromJson(json.decode(response.body));
    await _saveToken(tokenResponse.accessToken);
    return tokenResponse;
  }

  /// Get current user information
  static Future<User> getCurrentUser() async {
    final url = Uri.parse('$baseUrl/me');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    _handleError(response);
    return User.fromJson(json.decode(response.body));
  }

  /// Change user password
  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final url = Uri.parse('$baseUrl/me/password');
    final response = await http.patch(
      url,
      headers: await _getHeaders(),
      body: json.encode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    _handleError(response);
  }

  /// Logout - clear stored token
  static Future<void> logout() async {
    await clearToken();
  }

  // ============ AIRPORTS ============

  /// Get all airports
  static Future<List<Airport>> getAirports() async {
    final url = Uri.parse('$baseUrl/airports');
    final response = await http.get(
      url,
      headers: await _getHeaders(includeAuth: false),
    );

    _handleError(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Airport.fromJson(json)).toList();
  }

  // ============ FLIGHTS ============

  /// Search flights
  static Future<List<Flight>> searchFlights({
    int? originAirportId,
    int? destinationAirportId,
    DateTime? date,
  }) async {
    final uri = Uri.parse('$baseUrl/flights').replace(queryParameters: {
      if (originAirportId != null) 'origin_airport_id': originAirportId.toString(),
      if (destinationAirportId != null)
        'destination_airport_id': destinationAirportId.toString(),
      if (date != null) 'date': date.toIso8601String(),
    });

    final response = await http.get(
      uri,
      headers: await _getHeaders(includeAuth: false),
    );

    _handleError(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Flight.fromJson(json)).toList();
  }

  /// Get flight details
  static Future<Flight> getFlightDetails(int flightId) async {
    final url = Uri.parse('$baseUrl/flights/$flightId');
    final response = await http.get(
      url,
      headers: await _getHeaders(includeAuth: false),
    );

    _handleError(response);
    return Flight.fromJson(json.decode(response.body));
  }

  /// Get seats for a flight
  static Future<List<Seat>> getFlightSeats(int flightId) async {
    final url = Uri.parse('$baseUrl/flights/$flightId/seats');
    final response = await http.get(
      url,
      headers: await _getHeaders(includeAuth: false),
    );

    _handleError(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Seat.fromJson(json)).toList();
  }

  /// Hold a seat (temporary reservation)
  static Future<void> holdSeat(int flightId, int seatId) async {
    final url = Uri.parse('$baseUrl/flights/$flightId/seats/$seatId/hold');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
    );

    _handleError(response);
  }

  // ============ BOOKINGS ============

  /// Create a booking
  static Future<Booking> createBooking(BookingCreate request) async {
    final url = Uri.parse('$baseUrl/bookings');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: json.encode(request.toJson()),
    );

    _handleError(response);
    return Booking.fromJson(json.decode(response.body));
  }

  /// Get user's bookings
  static Future<List<Booking>> getMyBookings() async {
    final url = Uri.parse('$baseUrl/bookings');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    _handleError(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Booking.fromJson(json)).toList();
  }

  /// Get booking details
  static Future<Booking> getBooking(int bookingId) async {
    final url = Uri.parse('$baseUrl/bookings/$bookingId');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    _handleError(response);
    return Booking.fromJson(json.decode(response.body));
  }

  /// Cancel a pending booking and release the seat
  static Future<void> cancelBooking(int bookingId) async {
    final url = Uri.parse('$baseUrl/bookings/$bookingId');
    final response = await http.delete(
      url,
      headers: await _getHeaders(),
    );

    _handleError(response);
  }

  // ============ PAYMENTS ============

  /// Get payment history
  static Future<List<PaymentHistory>> getPaymentHistory() async {
    final url = Uri.parse('$baseUrl/payments/history');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    _handleError(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => PaymentHistory.fromJson(json)).toList();
  }

  /// Process payment
  static Future<Payment> createPayment(PaymentCreate request) async {
    final url = Uri.parse('$baseUrl/payments');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: json.encode(request.toJson()),
    );

    _handleError(response);
    return Payment.fromJson(json.decode(response.body));
  }

  // ============ CHECK-IN ============

  /// Check in for a flight
  static Future<CheckIn> checkIn(int bookingId) async {
    final url = Uri.parse('$baseUrl/check-in');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: json.encode({'booking_id': bookingId}),
    );

    _handleError(response);
    return CheckIn.fromJson(json.decode(response.body));
  }

  /// Get boarding pass
  static Future<BoardingPass> getBoardingPass(int bookingId) async {
    final url = Uri.parse('$baseUrl/bookings/$bookingId/boarding-pass');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    _handleError(response);
    return BoardingPass.fromJson(json.decode(response.body));
  }

  // ============ ANNOUNCEMENTS ============

  /// Get announcements for current user (general + their booked flights)
  static Future<List<Announcement>> getAnnouncements() async {
    final url = Uri.parse('$baseUrl/announcements');
    final response = await http.get(
      url,
      headers: await _getHeaders(),  // Now requires auth to filter by user's flights
    );

    _handleError(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Announcement.fromJson(json)).toList();
  }

  // ============ PASSENGER PROFILE ============

  /// Get passenger profile
  static Future<PassengerProfile> getPassengerProfile() async {
    final url = Uri.parse('$baseUrl/passenger/profile');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    _handleError(response);
    return PassengerProfile.fromJson(json.decode(response.body));
  }

  /// Create or update passenger profile
  static Future<PassengerProfile> createPassengerProfile(
      PassengerProfileCreate request) async {
    final url = Uri.parse('$baseUrl/passenger/profile');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: json.encode(request.toJson()),
    );

    _handleError(response);
    return PassengerProfile.fromJson(json.decode(response.body));
  }

}



