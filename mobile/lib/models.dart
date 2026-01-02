// """
// Models
// ======
// These Dart classes represent the data structures from the API.
// They match the schemas defined in the backend.

// In Flutter, we use these models to:
// - Parse JSON responses from the API
// - Store data in the app
// - Pass data between screens
// """

// ============ USER MODELS ============

class User {
  final int id;
  final String email;
  final String role;

  User({required this.id, required this.email, required this.role});

  // Convert JSON from API to User object
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      role: json['role'],
    );
  }
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  // Convert User object to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class RegisterRequest {
  final String email;
  final String password;
  final String role;

  RegisterRequest({
    required this.email,
    required this.password,
    this.role = 'PASSENGER',
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'role': role,
    };
  }
}

class TokenResponse {
  final String accessToken;
  final String tokenType;

  TokenResponse({required this.accessToken, required this.tokenType});

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
    );
  }
}

// ============ AIRPORT MODELS ============

class Airport {
  final int id;
  final String code;
  final String name;
  final String city;
  final String country;

  Airport({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    required this.country,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    return Airport(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      city: json['city'],
      country: json['country'],
    );
  }

  // Display format: "JFK - New York"
  String get displayName => '$code - $city';
}

// ============ AIRPLANE MODELS ============

class Airplane {
  final int id;
  final String model;
  final int totalSeats;
  final int rows;
  final int seatsPerRow;

  Airplane({
    required this.id,
    required this.model,
    required this.totalSeats,
    required this.rows,
    required this.seatsPerRow,
  });

  factory Airplane.fromJson(Map<String, dynamic> json) {
    return Airplane(
      id: json['id'],
      model: json['model'],
      totalSeats: json['total_seats'],
      rows: json['rows'],
      seatsPerRow: json['seats_per_row'],
    );
  }
}

// ============ FLIGHT MODELS ============

class Flight {
  final int id;
  final String flightNumber;
  final Airport originAirport;
  final Airport destinationAirport;
  final Airplane? airplane;  // Aircraft information
  final DateTime departureTime;
  final DateTime arrivalTime;
  final double basePrice;
  final String status;
  final int? availableSeats;  // Available seats count (from search results)
  final int? durationMinutes;  // Flight duration in minutes (from search results)

  Flight({
    required this.id,
    required this.flightNumber,
    required this.originAirport,
    required this.destinationAirport,
    this.airplane,
    required this.departureTime,
    required this.arrivalTime,
    required this.basePrice,
    required this.status,
    this.availableSeats,
    this.durationMinutes,
  });

  factory Flight.fromJson(Map<String, dynamic> json) {
    return Flight(
      id: json['id'],
      flightNumber: json['flight_number'],
      originAirport: Airport.fromJson(json['origin_airport']),
      destinationAirport: Airport.fromJson(json['destination_airport']),
      airplane: json['airplane'] != null ? Airplane.fromJson(json['airplane']) : null,
      departureTime: DateTime.parse(json['departure_time']),
      arrivalTime: DateTime.parse(json['arrival_time']),
      basePrice: (json['base_price'] as num).toDouble(),
      status: json['status'],
      availableSeats: json['available_seats'],
      durationMinutes: json['duration_minutes'],
    );
  }

  // Format: "JFK → LAX"
  String get route => '${originAirport.code} → ${destinationAirport.code}';
  
  // Duration formatted as "2h 30m"
  String get durationFormatted {
    if (durationMinutes == null) {
      // Calculate from times if not provided
      final minutes = arrivalTime.difference(departureTime).inMinutes;
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    final hours = durationMinutes! ~/ 60;
    final mins = durationMinutes! % 60;
    return '${hours}h ${mins}m';
  }
}

// ============ SEAT MODELS ============

class Seat {
  final int id;
  final int flightId;
  final int rowNumber;
  final String seatLetter;
  final String seatClass;
  final String seatCategory;  // STANDARD or EXTRA_LEGROOM
  final double priceMultiplier;
  final String status;
  final double price;

  Seat({
    required this.id,
    required this.flightId,
    required this.rowNumber,
    required this.seatLetter,
    required this.seatClass,
    required this.seatCategory,
    required this.priceMultiplier,
    required this.status,
    required this.price,
  });

  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      id: json['id'],
      flightId: json['flight_id'],
      rowNumber: json['row_number'],
      seatLetter: json['seat_letter'],
      seatClass: json['seat_class'],
      seatCategory: json['seat_category'] ?? 'STANDARD',
      priceMultiplier: (json['price_multiplier'] as num).toDouble(),
      status: json['status'],
      price: (json['price'] as num).toDouble(),
    );
  }

  // Format: "12A"
  String get seatNumber => '$rowNumber$seatLetter';

  bool get isAvailable => status == 'AVAILABLE';
  
  bool get isBusiness => seatClass == 'BUSINESS';
  bool get isExtraLegroom => seatCategory == 'EXTRA_LEGROOM';
  bool get isHeld => status == 'HELD';
  bool get isBooked => status == 'BOOKED';
}

// ============ BOOKING MODELS ============

class Booking {
  final int id;
  final int userId;
  final int flightId;
  final int seatId;
  final String bookingReference;  // Unique PNR code
  final double totalPrice;
  final String status;  // CREATED, CONFIRMED, CANCELLED
  final DateTime createdAt;
  final Flight flight;
  final Seat seat;
  
  // Optional passenger data for this specific booking (for multiple seat bookings)
  final String? passengerFirstName;
  final String? passengerLastName;
  final String? passengerPhone;
  final String? passengerPassportNumber;
  final String? passengerNationality;
  final DateTime? passengerDateOfBirth;

  Booking({
    required this.id,
    required this.userId,
    required this.flightId,
    required this.seatId,
    required this.bookingReference,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.flight,
    required this.seat,
    this.passengerFirstName,
    this.passengerLastName,
    this.passengerPhone,
    this.passengerPassportNumber,
    this.passengerNationality,
    this.passengerDateOfBirth,
  });
  
  // Check if this booking has custom passenger data
  bool get hasCustomPassengerData =>
      passengerFirstName != null ||
      passengerLastName != null ||
      passengerPhone != null ||
      passengerPassportNumber != null ||
      passengerNationality != null ||
      passengerDateOfBirth != null;

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Parse date and ensure it's in UTC (backend sends UTC)
    final createdAtStr = json['created_at'] as String;
    DateTime createdAt = DateTime.parse(createdAtStr);
    // If the string doesn't have timezone info, assume it's UTC
    if (!createdAtStr.endsWith('Z') && !createdAtStr.contains('+') && !createdAtStr.contains('-', createdAtStr.length - 6)) {
      createdAt = DateTime.utc(
        createdAt.year,
        createdAt.month,
        createdAt.day,
        createdAt.hour,
        createdAt.minute,
        createdAt.second,
        createdAt.millisecond,
      );
    } else {
      createdAt = createdAt.toUtc();
    }
    
    // Parse passenger date of birth if available
    DateTime? passengerDateOfBirth;
    if (json['passenger_date_of_birth'] != null) {
      try {
        passengerDateOfBirth = DateTime.parse(json['passenger_date_of_birth'] as String);
      } catch (e) {
        passengerDateOfBirth = null;
      }
    }
    
    return Booking(
      id: json['id'],
      userId: json['user_id'],
      flightId: json['flight_id'],
      seatId: json['seat_id'],
      bookingReference: json['booking_reference'],
      totalPrice: (json['total_price'] as num).toDouble(),
      status: json['status'] ?? 'CREATED',
      createdAt: createdAt,
      flight: Flight.fromJson(json['flight']),
      seat: Seat.fromJson(json['seat']),
      passengerFirstName: json['passenger_first_name'] as String?,
      passengerLastName: json['passenger_last_name'] as String?,
      passengerPhone: json['passenger_phone'] as String?,
      passengerPassportNumber: json['passenger_passport_number'] as String?,
      passengerNationality: json['passenger_nationality'] as String?,
      passengerDateOfBirth: passengerDateOfBirth,
    );
  }
}

class BookingCreate {
  final int flightId;
  final int seatId;
  // Optional passenger data for this specific seat (for multiple seat bookings)
  final String? passengerFirstName;
  final String? passengerLastName;
  final String? passengerPhone;
  final String? passengerPassportNumber;
  final String? passengerNationality;
  final DateTime? passengerDateOfBirth;

  BookingCreate({
    required this.flightId,
    required this.seatId,
    this.passengerFirstName,
    this.passengerLastName,
    this.passengerPhone,
    this.passengerPassportNumber,
    this.passengerNationality,
    this.passengerDateOfBirth,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'flight_id': flightId,
      'seat_id': seatId,
    };
    
    // Only include passenger data if at least one field is provided
    if (passengerFirstName != null ||
        passengerLastName != null ||
        passengerPhone != null ||
        passengerPassportNumber != null ||
        passengerNationality != null ||
        passengerDateOfBirth != null) {
      json.addAll({
        'passenger_first_name': passengerFirstName,
        'passenger_last_name': passengerLastName,
        'passenger_phone': passengerPhone,
        'passenger_passport_number': passengerPassportNumber,
        'passenger_nationality': passengerNationality,
        'passenger_date_of_birth': passengerDateOfBirth?.toIso8601String(),
      });
    }
    
    return json;
  }
}

// ============ PAYMENT MODELS ============

class Payment {
  final int id;
  final int bookingId;
  final double amount;
  final String method;
  final String status;
  final String? transactionId;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.status,
    this.transactionId,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      bookingId: json['booking_id'],
      amount: (json['amount'] as num).toDouble(),
      method: json['method'],
      status: json['status'],
      transactionId: json['transaction_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isPaid => status == 'PAID';
}

class PaymentCreate {
  final int bookingId;
  final String method;

  PaymentCreate({required this.bookingId, required this.method});

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'method': method,
    };
  }
}

// Payment history for display
class PaymentHistory {
  final int id;
  final int bookingId;
  final String bookingReference;
  final String flightNumber;
  final String route;
  final double amount;
  final String method;
  final String status;
  final String? transactionId;
  final DateTime createdAt;

  PaymentHistory({
    required this.id,
    required this.bookingId,
    required this.bookingReference,
    required this.flightNumber,
    required this.route,
    required this.amount,
    required this.method,
    required this.status,
    this.transactionId,
    required this.createdAt,
  });

  factory PaymentHistory.fromJson(Map<String, dynamic> json) {
    return PaymentHistory(
      id: json['id'],
      bookingId: json['booking_id'],
      bookingReference: json['booking_reference'],
      flightNumber: json['flight_number'],
      route: json['route'],
      amount: (json['amount'] as num).toDouble(),
      method: json['method'],
      status: json['status'],
      transactionId: json['transaction_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isPaid => status == 'PAID';
}

// ============ CHECK-IN MODELS ============

class CheckIn {
  final int id;
  final int bookingId;
  final DateTime checkedInAt;
  final String? boardingGate;
  final DateTime? boardingTime;

  CheckIn({
    required this.id,
    required this.bookingId,
    required this.checkedInAt,
    this.boardingGate,
    this.boardingTime,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'],
      bookingId: json['booking_id'],
      checkedInAt: DateTime.parse(json['checked_in_at']),
      boardingGate: json['boarding_gate'],
      boardingTime: json['boarding_time'] != null
          ? DateTime.parse(json['boarding_time'])
          : null,
    );
  }
}

// ============ ANNOUNCEMENT MODELS ============

class Announcement {
  final int id;
  final String title;
  final String message;
  final String announcementType;  // DELAY, CANCELLATION, GATE_CHANGE, BOARDING, GENERAL
  final int? flightId;  // null = general announcement, set = flight-specific
  final DateTime createdAt;
  final bool isActive;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.announcementType,
    this.flightId,
    required this.createdAt,
    required this.isActive,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      announcementType: json['announcement_type'] ?? 'GENERAL',
      flightId: json['flight_id'],
      createdAt: DateTime.parse(json['created_at']),
      isActive: json['is_active'],
    );
  }

  bool get isGeneral => flightId == null;
  
  String get typeLabel {
    switch (announcementType) {
      case 'DELAY':
        return 'Delay';
      case 'CANCELLATION':
        return 'Cancellation';
      case 'GATE_CHANGE':
        return 'Gate Change';
      case 'BOARDING':
        return 'Boarding';
      default:
        return 'General';
    }
  }
}

// ============ PASSENGER PROFILE MODELS ============

class PassengerProfile {
  final int id;
  final int userId;
  final String firstName;
  final String lastName;
  final String phone;
  final DateTime dateOfBirth;
  final String passportNumber;
  final String nationality;

  PassengerProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.dateOfBirth,
    required this.passportNumber,
    required this.nationality,
  });

  factory PassengerProfile.fromJson(Map<String, dynamic> json) {
    return PassengerProfile(
      id: json['id'],
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phone: json['phone'],
      dateOfBirth: DateTime.parse(json['date_of_birth']),
      passportNumber: json['passport_number'],
      nationality: json['nationality'],
    );
  }

  String get fullName => '$firstName $lastName';
}

class PassengerProfileCreate {
  final String firstName;
  final String lastName;
  final String phone;
  final DateTime dateOfBirth;
  final String passportNumber;
  final String nationality;

  PassengerProfileCreate({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.dateOfBirth,
    required this.passportNumber,
    required this.nationality,
  });

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'passport_number': passportNumber,
      'nationality': nationality,
    };
  }
}

// ============ BOARDING PASS MODEL ============

class BoardingPass {
  final String bookingReference;
  final String? ticketNumber;
  final String? passengerName;
  final String flightNumber;
  final String seat;
  final String? boardingGate;
  final String? terminal;  // Optional terminal
  final DateTime? boardingTime;
  final DateTime departureTime;
  final String origin;
  final String destination;
  final String? qrCode;  // QR code payload

  BoardingPass({
    required this.bookingReference,
    this.ticketNumber,
    this.passengerName,
    required this.flightNumber,
    required this.seat,
    this.boardingGate,
    this.terminal,
    this.boardingTime,
    required this.departureTime,
    required this.origin,
    required this.destination,
    this.qrCode,
  });

  factory BoardingPass.fromJson(Map<String, dynamic> json) {
    return BoardingPass(
      bookingReference: json['booking_reference'],
      ticketNumber: json['ticket_number'],
      passengerName: json['passenger_name'],
      flightNumber: json['flight_number'],
      seat: json['seat'],
      boardingGate: json['boarding_gate'],
      terminal: json['terminal'],
      boardingTime: json['boarding_time'] != null
          ? DateTime.parse(json['boarding_time'])
          : null,
      departureTime: DateTime.parse(json['departure_time']),
      origin: json['origin'],
      destination: json['destination'],
      qrCode: json['qr_code'],
    );
  }
}



