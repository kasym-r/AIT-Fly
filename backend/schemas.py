"""
Pydantic Schemas
================
These define the structure of data going IN and OUT of the API.
Pydantic validates the data automatically.

- Request schemas: What the API expects to receive
- Response schemas: What the API sends back
"""

from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from models import UserRole, PaymentMethod, PaymentStatus, SeatStatus, FlightStatus, BookingStatus, SeatCategory


# ============ AUTH SCHEMAS ============

class UserRegister(BaseModel):
    """Schema for user registration"""
    email: EmailStr
    password: str
    role: UserRole = UserRole.PASSENGER  # Default to passenger


class UserLogin(BaseModel):
    """Schema for user login"""
    email: EmailStr
    password: str


class Token(BaseModel):
    """Schema for JWT token response"""
    access_token: str
    token_type: str = "bearer"


# ============ USER SCHEMAS ============

class UserResponse(BaseModel):
    """Schema for user information in responses"""
    id: int
    email: str
    role: UserRole
    created_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True  # Allows conversion from SQLAlchemy models


class PasswordChange(BaseModel):
    """Schema for changing password"""
    current_password: str
    new_password: str


# ============ PASSENGER PROFILE SCHEMAS ============

class PassengerProfileCreate(BaseModel):
    """Schema for creating/updating passenger profile"""
    first_name: str
    last_name: str
    phone: str
    date_of_birth: datetime
    passport_number: str
    nationality: str


class PassengerProfileResponse(BaseModel):
    """Schema for passenger profile in responses"""
    id: int
    user_id: int
    first_name: str
    last_name: str
    phone: str
    date_of_birth: datetime
    passport_number: str
    nationality: str
    
    class Config:
        from_attributes = True


# ============ AIRPORT SCHEMAS ============

class AirportCreate(BaseModel):
    """Schema for creating airport"""
    code: str
    name: str
    city: str
    country: str


class AirportResponse(BaseModel):
    """Schema for airport in responses"""
    id: int
    code: str
    name: str
    city: str
    country: str
    
    class Config:
        from_attributes = True


# ============ AIRPLANE SCHEMAS ============

class AirplaneCreate(BaseModel):
    """Schema for creating airplane"""
    model: str
    total_seats: int
    rows: int
    seats_per_row: int
    seat_config: Optional[dict] = None  # Optional seat configuration: {"1A": {"seat_class": "BUSINESS", ...}, ...}


class AirplaneResponse(BaseModel):
    """Schema for airplane in responses"""
    id: int
    model: str
    total_seats: int
    rows: int
    seats_per_row: int
    
    class Config:
        from_attributes = True


# ============ FLIGHT SCHEMAS ============

class FlightCreate(BaseModel):
    """Schema for creating flight"""
    flight_number: str
    origin_airport_id: int
    destination_airport_id: int
    airplane_id: int
    departure_time: datetime
    arrival_time: datetime
    base_price: float
    status: FlightStatus = FlightStatus.SCHEDULED


class FlightResponse(BaseModel):
    """Schema for flight in responses"""
    id: int
    flight_number: str
    origin_airport_id: int
    destination_airport_id: int
    airplane_id: int
    departure_time: datetime
    arrival_time: datetime
    base_price: float
    status: FlightStatus
    gate: Optional[str] = None
    terminal: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class FlightSearch(BaseModel):
    """Schema for flight search"""
    origin_airport_id: Optional[int] = None
    destination_airport_id: Optional[int] = None
    date: Optional[datetime] = None


class FlightWithDetailsResponse(BaseModel):
    """Schema for flight with airport details"""
    id: int
    flight_number: str
    origin_airport: AirportResponse
    destination_airport: AirportResponse
    airplane: AirplaneResponse
    departure_time: datetime
    arrival_time: datetime
    base_price: float
    status: FlightStatus
    gate: Optional[str] = None
    terminal: Optional[str] = None
    
    class Config:
        from_attributes = True


class FlightSearchResultResponse(BaseModel):
    """Schema for flight search results with additional info"""
    id: int
    flight_number: str
    origin_airport: AirportResponse
    destination_airport: AirportResponse
    airplane: AirplaneResponse
    departure_time: datetime
    arrival_time: datetime
    base_price: float
    status: FlightStatus
    available_seats: int  # Count of available seats
    duration_minutes: int  # Flight duration in minutes
    
    class Config:
        from_attributes = True


# ============ SEAT SCHEMAS ============

class SeatResponse(BaseModel):
    """Schema for seat in responses"""
    id: int
    flight_id: int
    row_number: int
    seat_letter: str
    seat_class: str
    seat_category: SeatCategory  # STANDARD or EXTRA_LEGROOM
    price_multiplier: float
    status: SeatStatus
    price: float  # Calculated price (base_price * multiplier)
    
    class Config:
        from_attributes = True


class SeatUpdate(BaseModel):
    """Schema for updating seat properties"""
    seat_class: Optional[str] = None  # ECONOMY, BUSINESS
    seat_category: Optional[SeatCategory] = None  # STANDARD or EXTRA_LEGROOM
    price_multiplier: Optional[float] = None


# ============ BOOKING SCHEMAS ============

class BookingCreate(BaseModel):
    """Schema for creating booking"""
    flight_id: int
    seat_id: int
    # Optional passenger data for this specific seat (for multiple seat bookings)
    # If not provided, uses the logged-in user's PassengerProfile
    passenger_first_name: Optional[str] = None
    passenger_last_name: Optional[str] = None
    passenger_phone: Optional[str] = None
    passenger_passport_number: Optional[str] = None
    passenger_nationality: Optional[str] = None
    passenger_date_of_birth: Optional[datetime] = None


class BookingResponse(BaseModel):
    """Schema for booking in responses"""
    id: int
    user_id: int
    flight_id: int
    seat_id: int
    booking_reference: str  # Unique PNR code
    total_price: float
    status: BookingStatus  # CREATED, CONFIRMED, CANCELLED
    created_at: datetime
    flight: FlightWithDetailsResponse
    seat: SeatResponse
    # Optional passenger data for this specific booking (for multiple seat bookings)
    passenger_first_name: Optional[str] = None
    passenger_last_name: Optional[str] = None
    passenger_phone: Optional[str] = None
    passenger_passport_number: Optional[str] = None
    passenger_nationality: Optional[str] = None
    passenger_date_of_birth: Optional[datetime] = None
    
    class Config:
        from_attributes = True


# ============ PAYMENT SCHEMAS ============

class PaymentCreate(BaseModel):
    """Schema for creating payment"""
    booking_id: int
    method: PaymentMethod


class PaymentResponse(BaseModel):
    """Schema for payment in responses"""
    id: int
    booking_id: int
    amount: float
    method: PaymentMethod
    status: PaymentStatus
    transaction_id: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============ CHECK-IN SCHEMAS ============

class CheckInCreate(BaseModel):
    """Schema for check-in"""
    booking_id: int


class CheckInResponse(BaseModel):
    """Schema for check-in in responses"""
    id: int
    booking_id: int
    checked_in_at: datetime
    boarding_gate: Optional[str]
    boarding_time: Optional[datetime]
    
    class Config:
        from_attributes = True


# ============ ANNOUNCEMENT SCHEMAS ============

class AnnouncementCreate(BaseModel):
    """Schema for creating announcement"""
    title: str
    message: str
    announcement_type: Optional[str] = "GENERAL"  # DELAY, CANCELLATION, GATE_CHANGE, BOARDING, GENERAL
    flight_id: Optional[int] = None  # None = general announcement, set = flight-specific


class AnnouncementResponse(BaseModel):
    """Schema for announcement in responses"""
    id: int
    title: str
    message: str
    announcement_type: str
    flight_id: Optional[int]  # None = general, set = for specific flight
    user_id: Optional[int] = None  # None = not user-specific, set = personal notification
    created_at: datetime
    is_active: bool
    
    class Config:
        from_attributes = True


# ============ PAYMENT HISTORY SCHEMAS ============

class PaymentHistoryResponse(BaseModel):
    """Schema for payment history"""
    id: int
    booking_id: int
    booking_reference: str
    flight_number: str
    route: str
    amount: float
    method: PaymentMethod
    status: PaymentStatus
    transaction_id: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True



