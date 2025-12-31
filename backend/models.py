"""
Database Models
===============
These are the database table definitions using SQLAlchemy.
Each class represents a table, and each attribute represents a column.

Think of models as the structure of your data storage.
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from database import Base


# ============ ENUMS ============
# Enums define allowed values for certain fields

class UserRole(str, enum.Enum):
    """User can be either a passenger or staff member"""
    PASSENGER = "PASSENGER"
    STAFF = "STAFF"


class PaymentMethod(str, enum.Enum):
    """Payment methods supported"""
    CARD = "CARD"
    APPLE_PAY = "APPLE_PAY"
    GOOGLE_PAY = "GOOGLE_PAY"


class PaymentStatus(str, enum.Enum):
    """Payment can be pending, paid, or failed"""
    PENDING = "PENDING"
    PAID = "PAID"
    FAILED = "FAILED"


class SeatStatus(str, enum.Enum):
    """Seat can be available, held (temporarily reserved), or booked"""
    AVAILABLE = "AVAILABLE"
    HELD = "HELD"
    BOOKED = "BOOKED"


class FlightStatus(str, enum.Enum):
    """Flight status"""
    SCHEDULED = "SCHEDULED"
    BOARDING = "BOARDING"
    DEPARTED = "DEPARTED"
    ARRIVED = "ARRIVED"  # Same as LANDED
    LANDED = "ARRIVED"   # Alias for ARRIVED
    DELAYED = "DELAYED"
    CANCELLED = "CANCELLED"


class BookingStatus(str, enum.Enum):
    """Booking status - tracks booking lifecycle"""
    CREATED = "CREATED"      # Booking created, awaiting payment
    CONFIRMED = "CONFIRMED"  # Payment successful, booking confirmed
    CANCELLED = "CANCELLED"  # Booking cancelled


class SeatCategory(str, enum.Enum):
    """Seat categories"""
    STANDARD = "STANDARD"           # Regular seats
    EXTRA_LEGROOM = "EXTRA_LEGROOM" # Extra legroom seats (exit rows, front rows)


class AnnouncementType(str, enum.Enum):
    """Announcement types"""
    DELAY = "DELAY"
    CANCELLATION = "CANCELLATION"
    GATE_CHANGE = "GATE_CHANGE"
    BOARDING = "BOARDING"
    GENERAL = "GENERAL"


# ============ MODELS ============

class User(Base):
    """
    User table - stores login credentials and basic info
    Every user (passenger or staff) has an account here
    """
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)  # We'll store hashed passwords, never plain text
    role = Column(SQLEnum(UserRole), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships - connect to other tables
    passenger_profile = relationship("PassengerProfile", back_populates="user", uselist=False)
    bookings = relationship("Booking", back_populates="user")


class PassengerProfile(Base):
    """
    Passenger Profile - additional info for passengers
    Passengers must complete this before booking
    Required fields: full name, email (from user), phone, passport, nationality, date of birth
    """
    __tablename__ = "passenger_profiles"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    phone = Column(String, nullable=False)
    date_of_birth = Column(DateTime, nullable=False)
    passport_number = Column(String, nullable=False)
    nationality = Column(String, nullable=False)
    
    # Relationship back to user
    user = relationship("User", back_populates="passenger_profile")


class Airport(Base):
    """
    Airport table - stores airport information
    """
    __tablename__ = "airports"
    
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, nullable=False)  # e.g., "JFK", "LAX"
    name = Column(String, nullable=False)
    city = Column(String, nullable=False)
    country = Column(String, nullable=False)
    
    # Relationships
    departure_flights = relationship("Flight", foreign_keys="Flight.origin_airport_id", back_populates="origin_airport")
    arrival_flights = relationship("Flight", foreign_keys="Flight.destination_airport_id", back_populates="destination_airport")


class Airplane(Base):
    """
    Airplane table - stores airplane information and seat configuration
    """
    __tablename__ = "airplanes"
    
    id = Column(Integer, primary_key=True, index=True)
    model = Column(String, nullable=False)  # e.g., "Boeing 737"
    total_seats = Column(Integer, nullable=False)
    rows = Column(Integer, nullable=False)  # Number of rows
    seats_per_row = Column(Integer, nullable=False)  # Seats per row
    
    # Relationships
    flights = relationship("Flight", back_populates="airplane")
    seats = relationship("Seat", back_populates="airplane")


class Flight(Base):
    """
    Flight table - stores flight schedule information
    """
    __tablename__ = "flights"
    
    id = Column(Integer, primary_key=True, index=True)
    flight_number = Column(String, unique=True, nullable=False)  # e.g., "AA123"
    origin_airport_id = Column(Integer, ForeignKey("airports.id"), nullable=False)
    destination_airport_id = Column(Integer, ForeignKey("airports.id"), nullable=False)
    airplane_id = Column(Integer, ForeignKey("airplanes.id"), nullable=False)
    departure_time = Column(DateTime, nullable=False)
    arrival_time = Column(DateTime, nullable=False)
    base_price = Column(Float, nullable=False)  # Base price for economy seats
    status = Column(SQLEnum(FlightStatus), default=FlightStatus.SCHEDULED)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    origin_airport = relationship("Airport", foreign_keys=[origin_airport_id], back_populates="departure_flights")
    destination_airport = relationship("Airport", foreign_keys=[destination_airport_id], back_populates="arrival_flights")
    airplane = relationship("Airplane", back_populates="flights")
    seats = relationship("Seat", back_populates="flight")
    bookings = relationship("Booking", back_populates="flight")


class Seat(Base):
    """
    Seat table - stores individual seat information for each flight
    Each flight has many seats, each seat belongs to one flight
    Seat categories: STANDARD (regular), EXTRA_LEGROOM (exit rows, etc.)
    """
    __tablename__ = "seats"
    
    id = Column(Integer, primary_key=True, index=True)
    flight_id = Column(Integer, ForeignKey("flights.id"), nullable=False)
    airplane_id = Column(Integer, ForeignKey("airplanes.id"), nullable=False)
    row_number = Column(Integer, nullable=False)  # Row number (1, 2, 3...)
    seat_letter = Column(String, nullable=False)  # Seat letter (A, B, C, D...)
    seat_class = Column(String, default="ECONOMY")  # ECONOMY, BUSINESS, FIRST (for pricing tiers)
    seat_category = Column(SQLEnum(SeatCategory), default=SeatCategory.STANDARD)  # STANDARD or EXTRA_LEGROOM
    price_multiplier = Column(Float, default=1.0)  # Price multiplier (1.0 = economy, 2.0 = business, etc.)
    status = Column(SQLEnum(SeatStatus), default=SeatStatus.AVAILABLE)
    hold_expires_at = Column(DateTime, nullable=True)  # When the hold expires (for temporary reservations)
    
    # Relationships
    flight = relationship("Flight", back_populates="seats")
    airplane = relationship("Airplane", back_populates="seats")
    booking = relationship("Booking", back_populates="seat", uselist=False)


class Booking(Base):
    """
    Booking table - stores booking information
    A booking connects a user, flight, and seat together
    Each booking has a unique PNR code (booking_reference)
    """
    __tablename__ = "bookings"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    flight_id = Column(Integer, ForeignKey("flights.id"), nullable=False)
    seat_id = Column(Integer, ForeignKey("seats.id"), unique=True, nullable=False)
    booking_reference = Column(String, unique=True, nullable=False)  # Unique PNR code
    total_price = Column(Float, nullable=False)
    status = Column(SQLEnum(BookingStatus), default=BookingStatus.CREATED)  # Booking status
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="bookings")
    flight = relationship("Flight", back_populates="bookings")
    seat = relationship("Seat", back_populates="booking")
    payment = relationship("Payment", back_populates="booking", uselist=False)
    ticket = relationship("Ticket", back_populates="booking", uselist=False)
    check_in = relationship("CheckIn", back_populates="booking", uselist=False)


class Payment(Base):
    """
    Payment table - stores payment information
    Each booking has one payment
    """
    __tablename__ = "payments"
    
    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), unique=True, nullable=False)
    amount = Column(Float, nullable=False)
    method = Column(SQLEnum(PaymentMethod), nullable=False)
    status = Column(SQLEnum(PaymentStatus), default=PaymentStatus.PENDING)
    transaction_id = Column(String, unique=True)  # Mock transaction ID
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationship
    booking = relationship("Booking", back_populates="payment")


class Ticket(Base):
    """
    Ticket table - stores ticket information (generated after payment)
    """
    __tablename__ = "tickets"
    
    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), unique=True, nullable=False)
    ticket_number = Column(String, unique=True, nullable=False)
    issued_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationship
    booking = relationship("Booking", back_populates="ticket")


class CheckIn(Base):
    """
    CheckIn table - stores check-in information
    Passengers can check in before the flight
    """
    __tablename__ = "check_ins"
    
    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), unique=True, nullable=False)
    checked_in_at = Column(DateTime, default=datetime.utcnow)
    boarding_gate = Column(String)  # Gate number
    boarding_time = Column(DateTime)  # When to board
    
    # Relationship
    booking = relationship("Booking", back_populates="check_in")


class Announcement(Base):
    """
    Announcement table - stores announcements (created by staff)
    Can be general (flight_id=None) or flight-specific (flight_id set)
    """
    __tablename__ = "announcements"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    message = Column(String, nullable=False)
    announcement_type = Column(SQLEnum(AnnouncementType), default=AnnouncementType.GENERAL)
    flight_id = Column(Integer, ForeignKey("flights.id"), nullable=True)  # None = general announcement
    created_at = Column(DateTime, default=datetime.utcnow)
    is_active = Column(Boolean, default=True)  # Staff can deactivate announcements
    
    # Relationship
    flight = relationship("Flight")



