"""
FastAPI Main Application
=========================
This is the main file that sets up the FastAPI application and all API routes.

FastAPI automatically creates API documentation at /docs
"""

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
import os
from sqlalchemy import and_, or_
from datetime import datetime, timedelta, timezone
import secrets
from typing import List, Optional
import asyncio
from contextlib import asynccontextmanager

from database import Base, engine, get_db
from models import (
    User, PassengerProfile, Airport, Airplane, Flight, Seat, Booking,
    Payment, Ticket, CheckIn, Announcement,
    UserRole, PaymentMethod, PaymentStatus, SeatStatus, FlightStatus, BookingStatus,
    AnnouncementType, SeatCategory
)
from schemas import (
    UserRegister, UserLogin, Token, UserResponse, PasswordChange,
    PassengerProfileCreate, PassengerProfileResponse,
    AirportCreate, AirportResponse,
    AirplaneCreate, AirplaneResponse,
    FlightCreate, FlightResponse, FlightSearch, FlightWithDetailsResponse,
    SeatResponse, SeatUpdate, BookingCreate, BookingResponse,
    PaymentCreate, PaymentResponse,
    CheckInCreate, CheckInResponse,
    AnnouncementCreate, AnnouncementResponse
)
from auth import (
    get_password_hash, verify_password, create_access_token,
    get_current_user, get_current_passenger_user, get_current_staff_user,
    oauth2_scheme
)
from jose import jwt, JWTError

# Create database tables
# This creates all tables defined in models.py
Base.metadata.create_all(bind=engine)

# Migrate existing database: Add announcement_type column if it doesn't exist
# This handles the case where the database was created before announcement_type was added
from sqlalchemy import text, inspect
with engine.connect() as conn:
    inspector = inspect(engine)
    columns = [col['name'] for col in inspector.get_columns('announcements')]
    if 'announcement_type' not in columns:
        try:
            # SQLite doesn't support ALTER TABLE ADD COLUMN with DEFAULT for enums
            # So we'll add it as TEXT and set default values
            conn.execute(text("ALTER TABLE announcements ADD COLUMN announcement_type TEXT DEFAULT 'GENERAL'"))
            conn.commit()
            print("✓ Added announcement_type column to announcements table")
        except Exception as e:
            print(f"Note: Could not add announcement_type column (may already exist): {e}")
            conn.rollback()
    if 'user_id' not in columns:
        try:
            conn.execute(text("ALTER TABLE announcements ADD COLUMN user_id INTEGER"))
            conn.commit()
            print("✓ Added user_id column to announcements table")
        except Exception as e:
            print(f"Note: Could not add user_id column (may already exist): {e}")
            conn.rollback()
    
    # Migrate bookings table: Add passenger data columns if they don't exist
    bookings_columns = [col['name'] for col in inspector.get_columns('bookings')]
    passenger_columns = [
        'passenger_first_name', 'passenger_last_name', 'passenger_phone',
        'passenger_passport_number', 'passenger_nationality', 'passenger_date_of_birth'
    ]
    for col_name in passenger_columns:
        if col_name not in bookings_columns:
            try:
                if col_name == 'passenger_date_of_birth':
                    conn.execute(text(f"ALTER TABLE bookings ADD COLUMN {col_name} DATETIME"))
                else:
                    conn.execute(text(f"ALTER TABLE bookings ADD COLUMN {col_name} TEXT"))
                conn.commit()
                print(f"✓ Added {col_name} column to bookings table")
            except Exception as e:
                print(f"Note: Could not add {col_name} column (may already exist): {e}")
                conn.rollback()

# Background task to automatically update flight statuses
async def auto_update_flight_statuses():
    """Background task that checks and updates flight statuses based on time"""
    while True:
        try:
            # Get a database session
            db_gen = get_db()
            db = next(db_gen)
            
            try:
                now = datetime.now()
                
                # Find flights that should be updated
                # 1. Flights that should be DEPARTED (departure time has passed, status is SCHEDULED or BOARDING)
                flights_to_depart = db.query(Flight).filter(
                    and_(
                        Flight.departure_time <= now,
                        Flight.status.in_([FlightStatus.SCHEDULED, FlightStatus.BOARDING, FlightStatus.DELAYED]),
                        Flight.status != FlightStatus.CANCELLED
                    )
                ).all()
                
                for flight in flights_to_depart:
                    old_status = flight.status
                    flight.status = FlightStatus.DEPARTED
                    db.commit()
                    
                    # Create announcement for passengers
                    bookings = db.query(Booking).filter(
                        and_(
                            Booking.flight_id == flight.id,
                            Booking.status == BookingStatus.CONFIRMED
                        )
                    ).all()
                    
                    if bookings:
                        announcement = Announcement(
                            title=f"Flight {flight.flight_number} Status Update",
                            message=f"Flight {flight.flight_number} has departed. Safe travels!",
                            announcement_type=AnnouncementType.GENERAL,
                            flight_id=flight.id,
                            is_active=True
                        )
                        db.add(announcement)
                        db.commit()
                
                # 2. Flights that should be ARRIVED (arrival time has passed, status is DEPARTED)
                flights_to_arrive = db.query(Flight).filter(
                    and_(
                        Flight.arrival_time <= now,
                        Flight.status == FlightStatus.DEPARTED
                    )
                ).all()
                
                for flight in flights_to_arrive:
                    flight.status = FlightStatus.ARRIVED
                    db.commit()
                    
                    # Create announcement for passengers
                    bookings = db.query(Booking).filter(
                        and_(
                            Booking.flight_id == flight.id,
                            Booking.status == BookingStatus.CONFIRMED
                        )
                    ).all()
                    
                    if bookings:
                        announcement = Announcement(
                            title=f"Flight {flight.flight_number} Status Update",
                            message=f"Flight {flight.flight_number} has arrived. Thank you for flying with us!",
                            announcement_type=AnnouncementType.GENERAL,
                            flight_id=flight.id,
                            is_active=True
                        )
                        db.add(announcement)
                        db.commit()
            finally:
                db.close()
            
        except Exception as e:
            print(f"Error in auto_update_flight_statuses: {e}")
        
        # Check every minute
        await asyncio.sleep(60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start background task
    task = asyncio.create_task(auto_update_flight_statuses())
    yield
    # Shutdown: Cancel background task
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


# Create FastAPI app
app = FastAPI(
    title="Airline Booking API",
    description="Simple airline booking system API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware - allows Flutter app to call this API
# Without this, browsers/apps from different origins can't make requests
# For development, we allow all origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=False,  # Must be False when using wildcard origins
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
    allow_headers=["*"],  # Allow all headers including Authorization
    expose_headers=["*"],  # Expose all headers to client
)


# ============ AUTHENTICATION ROUTES ============

@app.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """
    Register a new user (passenger).
    Creates a new user account and returns a JWT token.
    """
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create new user
    hashed_password = get_password_hash(user_data.password)
    new_user = User(
        email=user_data.email,
        password_hash=hashed_password,
        role=user_data.role
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Create JWT token
    # JWT "sub" (subject) must be a string, so convert user.id to string
    access_token = create_access_token(data={"sub": str(new_user.id)})
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/login", response_model=Token)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    """
    Login with email and password.
    Returns a JWT token if credentials are correct.
    """
    # Find user by email
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Verify password
    if not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Create JWT token
    # JWT "sub" (subject) must be a string, so convert user.id to string
    access_token = create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token, "token_type": "bearer"}


@app.get("/me", response_model=UserResponse)
def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current logged-in user information"""
    return current_user


@app.patch("/me/password")
def change_password(
    password_data: PasswordChange,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Change user password"""
    from auth import verify_password, get_password_hash
    
    # Verify current password
    if not verify_password(password_data.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    # Validate new password
    if len(password_data.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 6 characters"
        )
    
    # Update password
    current_user.password_hash = get_password_hash(password_data.new_password)
    db.commit()
    
    return {"message": "Password changed successfully"}


# Debug endpoint to test token
@app.get("/debug/token")
def debug_token(token: str = Depends(oauth2_scheme)):
    """Debug endpoint to see if token is being received"""
    from auth import SECRET_KEY, ALGORITHM
    from jose import JWTError
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return {"status": "valid", "payload": payload}
    except JWTError as e:
        return {"status": "invalid", "error": str(e)}


# ============ PASSENGER PROFILE ROUTES ============

@app.post("/passenger/profile", response_model=PassengerProfileResponse, status_code=status.HTTP_201_CREATED)
def create_passenger_profile(
    profile_data: PassengerProfileCreate,
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """
    Create or update passenger profile.
    Passengers must complete this before booking.
    """
    # Check if profile already exists
    existing_profile = db.query(PassengerProfile).filter(
        PassengerProfile.user_id == current_user.id
    ).first()
    
    if existing_profile:
        # Update existing profile
        for key, value in profile_data.dict().items():
            setattr(existing_profile, key, value)
        db.commit()
        db.refresh(existing_profile)
        return existing_profile
    else:
        # Create new profile
        new_profile = PassengerProfile(
            user_id=current_user.id,
            **profile_data.dict()
        )
        db.add(new_profile)
        db.commit()
        db.refresh(new_profile)
        return new_profile


@app.get("/passenger/profile", response_model=PassengerProfileResponse)
def get_passenger_profile(
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """Get current passenger's profile"""
    profile = db.query(PassengerProfile).filter(
        PassengerProfile.user_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found. Please create your profile first."
        )
    
    return profile


# ============ AIRPORT ROUTES ============

@app.get("/airports", response_model=List[AirportResponse])
def get_airports(db: Session = Depends(get_db)):
    """Get all airports - public endpoint"""
    airports = db.query(Airport).all()
    return airports


@app.post("/airports", response_model=AirportResponse, status_code=status.HTTP_201_CREATED)
def create_airport(
    airport_data: AirportCreate,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Create a new airport - staff only"""
    # Check for duplicate airport code
    existing_airport = db.query(Airport).filter(Airport.code == airport_data.code.upper()).first()
    if existing_airport:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Airport with code {airport_data.code.upper()} already exists"
        )
    
    # Ensure code is uppercase
    airport_dict = airport_data.dict()
    airport_dict['code'] = airport_dict['code'].upper()
    
    new_airport = Airport(**airport_dict)
    db.add(new_airport)
    db.commit()
    db.refresh(new_airport)
    return new_airport


# ============ AIRPLANE ROUTES ============

@app.get("/airplanes", response_model=List[AirplaneResponse])
def get_airplanes(db: Session = Depends(get_db)):
    """Get all airplanes - public endpoint"""
    airplanes = db.query(Airplane).all()
    return airplanes


@app.post("/airplanes", response_model=AirplaneResponse, status_code=status.HTTP_201_CREATED)
def create_airplane(
    airplane_data: AirplaneCreate,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """
    Create a new airplane - staff only.
    After creating, seats should be created for flights using this airplane.
    """
    # Validate: rows × seats_per_row must equal total_seats
    if airplane_data.rows * airplane_data.seats_per_row != airplane_data.total_seats:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Rows ({airplane_data.rows}) × Seats per row ({airplane_data.seats_per_row}) must equal total seats ({airplane_data.total_seats})"
        )
    
    # Check for duplicate airplane (same model and configuration)
    existing_airplane = db.query(Airplane).filter(
        and_(
            Airplane.model == airplane_data.model,
            Airplane.rows == airplane_data.rows,
            Airplane.seats_per_row == airplane_data.seats_per_row,
            Airplane.total_seats == airplane_data.total_seats
        )
    ).first()
    if existing_airplane:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Airplane with model {airplane_data.model} and same configuration already exists"
        )
    
    airplane_dict = airplane_data.dict()
    seat_config = airplane_dict.pop('seat_config', None)
    
    new_airplane = Airplane(**airplane_dict)
    if seat_config:
        import json
        new_airplane.seat_config = json.dumps(seat_config)
    
    db.add(new_airplane)
    db.commit()
    db.refresh(new_airplane)
    return new_airplane


# ============ FLIGHT ROUTES ============

@app.get("/flights")
def search_flights(
    origin_airport_id: int = None,
    destination_airport_id: int = None,
    date: datetime = None,
    db: Session = Depends(get_db)
):
    """
    Search flights by origin, destination, and/or date.
    Public endpoint - anyone can search flights.
    Returns: flight number, departure/arrival time, duration, price, available seats, status
    """
    query = db.query(Flight)
    
    # Filter by origin
    if origin_airport_id:
        query = query.filter(Flight.origin_airport_id == origin_airport_id)
    
    # Filter by destination
    if destination_airport_id:
        query = query.filter(Flight.destination_airport_id == destination_airport_id)
    
    # Filter by date (match the day, ignore time)
    if date:
        start_of_day = date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = start_of_day + timedelta(days=1)
        query = query.filter(
            and_(
                Flight.departure_time >= start_of_day,
                Flight.departure_time < end_of_day
            )
        )
    
    flights = query.all()
    
    # Build response with available seats count and duration
    result = []
    for flight in flights:
        # Count available seats for this flight
        available_seats = db.query(Seat).filter(
            and_(
                Seat.flight_id == flight.id,
                Seat.status == SeatStatus.AVAILABLE
            )
        ).count()
        
        # Calculate duration in minutes
        duration_minutes = int((flight.arrival_time - flight.departure_time).total_seconds() / 60)
        
        result.append({
            "id": flight.id,
            "flight_number": flight.flight_number,
            "origin_airport": flight.origin_airport,
            "destination_airport": flight.destination_airport,
            "airplane": flight.airplane,
            "departure_time": flight.departure_time,
            "arrival_time": flight.arrival_time,
            "base_price": flight.base_price,
            "status": flight.status,
            "available_seats": available_seats,
            "duration_minutes": duration_minutes,
        })
    
    return result


@app.get("/flights/{flight_id}", response_model=FlightWithDetailsResponse)
def get_flight_details(flight_id: int, db: Session = Depends(get_db)):
    """Get detailed information about a specific flight"""
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    return flight


@app.post("/flights", response_model=FlightResponse, status_code=status.HTTP_201_CREATED)
def create_flight(
    flight_data: FlightCreate,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """
    Create a new flight - staff only.
    After creating, seats should be created for this flight.
    """
    # Check if airplane exists
    airplane = db.query(Airplane).filter(Airplane.id == flight_data.airplane_id).first()
    if not airplane:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Airplane not found"
        )
    
    # Validate: arrival must be after departure
    if flight_data.arrival_time <= flight_data.departure_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Arrival time must be after departure time"
        )
    
    # Validate: origin and destination must be different
    if flight_data.origin_airport_id == flight_data.destination_airport_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Origin and destination airports cannot be the same"
        )
    
    # Ensure departure and arrival times are naive UTC (database stores naive datetime as UTC)
    # If times are timezone-aware, convert to UTC naive. If naive, assume they're already UTC.
    departure_time = flight_data.departure_time
    arrival_time = flight_data.arrival_time
    
    if departure_time.tzinfo is not None:
        departure_time = departure_time.astimezone(timezone.utc).replace(tzinfo=None)
    if arrival_time.tzinfo is not None:
        arrival_time = arrival_time.astimezone(timezone.utc).replace(tzinfo=None)
    
    # Create flight with normalized times
    flight_dict = flight_data.dict()
    flight_dict['departure_time'] = departure_time
    flight_dict['arrival_time'] = arrival_time
    new_flight = Flight(**flight_dict)
    db.add(new_flight)
    db.commit()
    db.refresh(new_flight)
    
    # Create seats for this flight
    # This creates a seat map based on the airplane configuration
    seats = []
    
    # Load seat configuration from airplane if available
    seat_config = {}
    if airplane.seat_config:
        import json
        try:
            seat_config = json.loads(airplane.seat_config)
        except:
            seat_config = {}
    
    for row in range(1, airplane.rows + 1):
        for seat_num in range(airplane.seats_per_row):
            seat_letter = chr(65 + seat_num)  # A, B, C, D...
            seat_key = f"{row}{seat_letter}"
            
            # Use configured seat properties if available, otherwise use defaults
            if seat_key in seat_config:
                config = seat_config[seat_key]
                seat_class = config.get('seat_class', 'ECONOMY')
                seat_category = SeatCategory(config.get('seat_category', 'STANDARD'))
                price_multiplier = config.get('price_multiplier', 1.0)
            else:
                # Default logic: first 3 rows are business class
                seat_class = "BUSINESS" if row <= 3 else "ECONOMY"
                seat_category = SeatCategory.STANDARD
                price_multiplier = 2.0 if row <= 3 else 1.0
            
            seat = Seat(
                flight_id=new_flight.id,
                airplane_id=airplane.id,
                row_number=row,
                seat_letter=seat_letter,
                seat_class=seat_class,
                seat_category=seat_category,
                price_multiplier=price_multiplier,
                status=SeatStatus.AVAILABLE
            )
            seats.append(seat)
    
    db.add_all(seats)
    db.commit()
    
    return new_flight


@app.patch("/flights/{flight_id}/status")
def update_flight_status(
    flight_id: int,
    new_status: FlightStatus,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """
    Update flight status - staff only.
    Automatically creates announcements for all passengers who booked this flight.
    """
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    old_status = flight.status
    flight.status = new_status
    db.commit()
    
    # Create automatic announcement for passengers when status changes
    if old_status != new_status:
        # Get all confirmed bookings for this flight
        bookings = db.query(Booking).filter(
            and_(
                Booking.flight_id == flight_id,
                Booking.status == BookingStatus.CONFIRMED
            )
        ).all()
        
        if bookings:
            # Create status-specific announcement messages and types
            status_config = {
                FlightStatus.SCHEDULED: {
                    "type": AnnouncementType.GENERAL,
                    "message": f"Flight {flight.flight_number} is now scheduled. Please check your booking details for departure time."
                },
                FlightStatus.BOARDING: {
                    "type": AnnouncementType.BOARDING,
                    "message": f"Flight {flight.flight_number} is now boarding! Please proceed to your gate immediately."
                },
                FlightStatus.DEPARTED: {
                    "type": AnnouncementType.GENERAL,
                    "message": f"Flight {flight.flight_number} has departed. Safe travels!"
                },
                FlightStatus.ARRIVED: {
                    "type": AnnouncementType.GENERAL,
                    "message": f"Flight {flight.flight_number} has arrived. Thank you for flying with us!"
                },
                FlightStatus.DELAYED: {
                    "type": AnnouncementType.DELAY,
                    "message": f"Flight {flight.flight_number} has been delayed. Please check the updated departure time and stay near your gate."
                },
                FlightStatus.CANCELLED: {
                    "type": AnnouncementType.CANCELLATION,
                    "message": f"Flight {flight.flight_number} has been cancelled. Please contact customer service for rebooking options."
                }
            }
            
            config = status_config.get(new_status, {
                "type": AnnouncementType.GENERAL,
                "message": f"Flight {flight.flight_number} status has been updated to {new_status.value}."
            })
            
            title = f"Flight {flight.flight_number} Status Update"
            
            # Create flight-specific announcement for all passengers
            announcement = Announcement(
                title=title,
                message=config["message"],
                announcement_type=config["type"],
                flight_id=flight_id,  # Flight-specific announcement
                is_active=True
            )
            db.add(announcement)
            db.commit()
    
    return {"message": "Flight status updated", "status": new_status}


@app.patch("/flights/{flight_id}/schedule")
def update_flight_schedule(
    flight_id: int,
    departure_time: Optional[datetime] = None,
    arrival_time: Optional[datetime] = None,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Update flight schedule (departure/arrival times) - staff only"""
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    if departure_time:
        flight.departure_time = departure_time
    if arrival_time:
        flight.arrival_time = arrival_time
    
    db.commit()
    
    # Create announcement if schedule changed
    if departure_time or arrival_time:
        bookings = db.query(Booking).filter(
            and_(
                Booking.flight_id == flight_id,
                Booking.status == BookingStatus.CONFIRMED
            )
        ).all()
        
        if bookings:
            dept_msg = f"New departure: {departure_time.strftime('%Y-%m-%d %H:%M')}" if departure_time else ""
            arr_msg = f"New arrival: {arrival_time.strftime('%Y-%m-%d %H:%M')}" if arrival_time else ""
            message = f"Flight {flight.flight_number} schedule has been updated. {dept_msg} {arr_msg}".strip()
            
            announcement = Announcement(
                title=f"Flight {flight.flight_number} Schedule Update",
                message=message,
                announcement_type=AnnouncementType.DELAY,
                flight_id=flight_id,
                is_active=True
            )
            db.add(announcement)
            db.commit()
    
    return {"message": "Flight schedule updated", "flight": flight}


@app.patch("/flights/{flight_id}/gate")
def update_flight_gate(
    flight_id: int,
    gate: Optional[str] = None,
    terminal: Optional[str] = None,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Update flight gate and/or terminal - staff only. Creates gate change announcement if gate changed."""
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    old_gate = flight.gate
    old_terminal = flight.terminal
    
    if gate is not None:
        flight.gate = gate
    if terminal is not None:
        flight.terminal = terminal
    
    db.commit()
    
    # Update check-in records for this flight to reflect the new gate
    # This ensures boarding passes show the current gate even if check-in happened before gate change
    if gate is not None and gate != old_gate:
        check_ins = db.query(CheckIn).join(Booking).filter(
            Booking.flight_id == flight_id
        ).all()
        for check_in in check_ins:
            # Update boarding gate in check-in record to match new flight gate
            check_in.boarding_gate = gate if gate.startswith("Gate") else f"Gate {gate}"
        db.commit()
    
    # Create gate change announcement if gate changed
    if gate and gate != old_gate:
        bookings = db.query(Booking).filter(
            and_(
                Booking.flight_id == flight_id,
                Booking.status == BookingStatus.CONFIRMED
            )
        ).all()
        
        if bookings:
            gate_msg = f"Gate changed to {gate}"
            terminal_msg = f"Terminal {terminal}" if terminal else ""
            message = f"Flight {flight.flight_number} gate change: {gate_msg}. {terminal_msg}".strip()
            if old_gate:
                message = f"Flight {flight.flight_number} gate has changed from {old_gate} to {gate}. {terminal_msg}".strip()
            
            announcement = Announcement(
                title=f"Flight {flight.flight_number} Gate Change",
                message=message,
                announcement_type=AnnouncementType.GATE_CHANGE,
                flight_id=flight_id,
                is_active=True
            )
            db.add(announcement)
            db.commit()
    
    return {"message": "Flight gate/terminal updated", "flight": flight}


# ============ DELETE ENDPOINTS (Staff Only) ============

@app.delete("/flights/{flight_id}")
def delete_flight(
    flight_id: int,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Delete a flight - staff only"""
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    # Check if flight has bookings
    bookings_count = db.query(Booking).filter(Booking.flight_id == flight_id).count()
    if bookings_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete flight with {bookings_count} booking(s). Cancel bookings first."
        )
    
    # Delete seats first (cascade)
    db.query(Seat).filter(Seat.flight_id == flight_id).delete()
    
    # Delete flight
    db.delete(flight)
    db.commit()
    return {"message": "Flight deleted successfully"}


@app.delete("/airports/{airport_id}")
def delete_airport(
    airport_id: int,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Delete an airport - staff only"""
    airport = db.query(Airport).filter(Airport.id == airport_id).first()
    if not airport:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Airport not found"
        )
    
    # Check if airport is used in flights
    flights_count = db.query(Flight).filter(
        or_(
            Flight.origin_airport_id == airport_id,
            Flight.destination_airport_id == airport_id
        )
    ).count()
    
    if flights_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete airport used in {flights_count} flight(s)"
        )
    
    db.delete(airport)
    db.commit()
    return {"message": "Airport deleted successfully"}


@app.delete("/airplanes/{airplane_id}")
def delete_airplane(
    airplane_id: int,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Delete an airplane - staff only"""
    airplane = db.query(Airplane).filter(Airplane.id == airplane_id).first()
    if not airplane:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Airplane not found"
        )
    
    # Check if airplane is used in flights
    flights_count = db.query(Flight).filter(Flight.airplane_id == airplane_id).count()
    if flights_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete airplane used in {flights_count} flight(s)"
        )
    
    db.delete(airplane)
    db.commit()
    return {"message": "Airplane deleted successfully"}


@app.delete("/announcements/{announcement_id}")
def delete_announcement(
    announcement_id: int,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Delete an announcement - staff only"""
    announcement = db.query(Announcement).filter(Announcement.id == announcement_id).first()
    if not announcement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Announcement not found"
        )
    
    db.delete(announcement)
    db.commit()
    return {"message": "Announcement deleted successfully"}


# ============ USER MANAGEMENT (Staff Only) ============

@app.get("/staff/users")
def get_all_users(
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Get all users with their profiles - staff only"""
    users = db.query(User).all()
    result = []
    for user in users:
        user_data = {
            "id": user.id,
            "email": user.email,
            "role": user.role.value if hasattr(user.role, 'value') else str(user.role),
            "created_at": user.created_at.isoformat() if user.created_at else None
        }
        # Add passenger profile if exists
        if user.role == UserRole.PASSENGER:
            profile = db.query(PassengerProfile).filter(PassengerProfile.user_id == user.id).first()
            if profile:
                user_data["profile"] = {
                    "first_name": profile.first_name,
                    "last_name": profile.last_name,
                    "phone": profile.phone,
                    "passport_number": profile.passport_number,
                    "nationality": profile.nationality,
                    "date_of_birth": profile.date_of_birth.isoformat() if profile.date_of_birth else None
                }
        result.append(user_data)
    return result


@app.post("/staff/users", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    user_data: UserRegister,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Create a new user (staff or passenger) - staff only"""
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create new user
    hashed_password = get_password_hash(user_data.password)
    new_user = User(
        email=user_data.email,
        password_hash=hashed_password,
        role=user_data.role
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user


# ============ SEAT ROUTES ============

@app.get("/flights/{flight_id}/seats", response_model=List[SeatResponse])
def get_flight_seats(flight_id: int, db: Session = Depends(get_db)):
    """
    Get all seats for a flight with their current status.
    This is used to display the seat map.
    """
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    seats = db.query(Seat).filter(Seat.flight_id == flight_id).all()
    
    # Calculate price for each seat and check for expired holds or orphaned holds
    now = datetime.utcnow()
    needs_commit = False
    result = []
    for seat in seats:
        # Release expired holds or orphaned holds (HELD but no booking)
        if seat.status == SeatStatus.HELD:
            if seat.hold_expires_at and seat.hold_expires_at < now:
                # Hold expired
                seat.status = SeatStatus.AVAILABLE
                seat.hold_expires_at = None
                needs_commit = True
            else:
                # Check if there's a corresponding CREATED booking for this seat
                # If not, it's an orphaned hold - release it
                has_booking = db.query(Booking).filter(
                    and_(
                        Booking.seat_id == seat.id,
                        Booking.status == BookingStatus.CREATED
                    )
                ).first()
                if not has_booking:
                    # Orphaned hold - no booking exists, release it
                    seat.status = SeatStatus.AVAILABLE
                    seat.hold_expires_at = None
                    needs_commit = True
        
        # Calculate price
        price = flight.base_price * seat.price_multiplier
        
        seat_dict = {
            "id": seat.id,
            "flight_id": seat.flight_id,
            "row_number": seat.row_number,
            "seat_letter": seat.seat_letter,
            "seat_class": seat.seat_class,
            "seat_category": seat.seat_category,
            "price_multiplier": seat.price_multiplier,
            "status": seat.status,
            "price": price
        }
        result.append(seat_dict)
    
    # Commit once after all updates
    if needs_commit:
        db.commit()
    
    return result


@app.post("/flights/{flight_id}/seats/{seat_id}/hold")
def hold_seat(
    flight_id: int,
    seat_id: int,
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """
    Hold a seat temporarily (10 minutes).
    This reserves the seat while the user completes booking.
    """
    seat = db.query(Seat).filter(
        and_(Seat.id == seat_id, Seat.flight_id == flight_id)
    ).first()
    
    if not seat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Seat not found"
        )
    
    # Check if seat is available
    if seat.status != SeatStatus.AVAILABLE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Seat is not available"
        )
    
    # Check for expired holds
    if seat.hold_expires_at and seat.hold_expires_at < datetime.utcnow():
        seat.status = SeatStatus.AVAILABLE
        seat.hold_expires_at = None
    
    # Hold the seat for 10 minutes
    seat.status = SeatStatus.HELD
    seat.hold_expires_at = datetime.utcnow() + timedelta(minutes=10)
    db.commit()
    
    return {"message": "Seat held for 10 minutes", "expires_at": seat.hold_expires_at}


@app.patch("/staff/flights/{flight_id}/seats/{seat_id}")
def update_seat(
    flight_id: int,
    seat_id: int,
    seat_update: SeatUpdate,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Update seat properties (class, category, price multiplier) - staff only"""
    seat = db.query(Seat).filter(
        and_(
            Seat.id == seat_id,
            Seat.flight_id == flight_id
        )
    ).first()
    
    if not seat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Seat not found"
        )
    
    # Update seat properties
    if seat_update.seat_class is not None:
        seat.seat_class = seat_update.seat_class
    if seat_update.seat_category is not None:
        seat.seat_category = seat_update.seat_category
    if seat_update.price_multiplier is not None:
        seat.price_multiplier = seat_update.price_multiplier
    
    db.commit()
    db.refresh(seat)
    
    # Calculate price for response
    flight = seat.flight
    price = flight.base_price * seat.price_multiplier
    
    from schemas import SeatResponse
    return SeatResponse(
        id=seat.id,
        flight_id=seat.flight_id,
        row_number=seat.row_number,
        seat_letter=seat.seat_letter,
        seat_class=seat.seat_class,
        seat_category=seat.seat_category,
        price_multiplier=seat.price_multiplier,
        status=seat.status,
        price=price
    )


@app.delete("/flights/{flight_id}/seats/{seat_id}/hold")
def release_seat(
    flight_id: int,
    seat_id: int,
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """
    Release a held seat.
    This is called when user deselects a seat before creating a booking.
    """
    seat = db.query(Seat).filter(
        and_(Seat.id == seat_id, Seat.flight_id == flight_id)
    ).first()
    
    if not seat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Seat not found"
        )
    
    # Only allow releasing if seat is HELD and not booked
    if seat.status == SeatStatus.HELD:
        # Check if there's a CREATED booking for this seat by this user
        existing_booking = db.query(Booking).filter(
            and_(
                Booking.seat_id == seat_id,
                Booking.user_id == current_user.id,
                Booking.status == BookingStatus.CREATED
            )
        ).first()
        
        if existing_booking:
            # Don't release if there's a booking - user should cancel booking instead
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot release seat with existing booking. Cancel the booking instead."
            )
        
        # Release the hold
        seat.status = SeatStatus.AVAILABLE
        seat.hold_expires_at = None
        db.commit()
        return {"message": "Seat released"}
    elif seat.status == SeatStatus.BOOKED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot release a booked seat"
        )
    else:
        # Seat is already available
        return {"message": "Seat is already available"}


# ============ BOOKING ROUTES ============

@app.post("/bookings", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
def create_booking(
    booking_data: BookingCreate,
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """
    Create a booking.
    Rules:
    - Requires passenger profile to be completed first
    - Cannot book cancelled or departed flights
    - Seats cannot be double-booked
    - Booking starts with CREATED status, becomes CONFIRMED after payment
    """
    # Check if profile exists OR if passenger data is provided in booking
    profile = db.query(PassengerProfile).filter(
        PassengerProfile.user_id == current_user.id
    ).first()
    
    # If no passenger data provided in booking AND no profile exists, require profile
    has_passenger_data = any([
        booking_data.passenger_first_name,
        booking_data.passenger_last_name,
        booking_data.passenger_phone,
        booking_data.passenger_passport_number,
        booking_data.passenger_nationality,
        booking_data.passenger_date_of_birth
    ])
    
    if not has_passenger_data and not profile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please complete your profile before booking, or provide passenger data for this booking"
        )
    
    # If passenger data is provided, validate all required fields are present
    if has_passenger_data:
        required_fields = [
            booking_data.passenger_first_name,
            booking_data.passenger_last_name,
            booking_data.passenger_phone,
            booking_data.passenger_passport_number,
            booking_data.passenger_nationality,
            booking_data.passenger_date_of_birth
        ]
        if not all(required_fields):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="If providing passenger data, all fields (first_name, last_name, phone, passport_number, nationality, date_of_birth) must be provided"
            )
    
    # Get flight and seat
    flight = db.query(Flight).filter(Flight.id == booking_data.flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    # Cannot book cancelled or departed flights
    if flight.status == FlightStatus.CANCELLED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot book a cancelled flight"
        )
    if flight.status == FlightStatus.DEPARTED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot book a departed flight"
        )
    if flight.status == FlightStatus.ARRIVED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot book a flight that has already arrived"
        )
    
    seat = db.query(Seat).filter(
        and_(
            Seat.id == booking_data.seat_id,
            Seat.flight_id == booking_data.flight_id
        )
    ).first()
    if not seat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Seat not found"
        )
    
    # Check if seat is already booked
    if seat.status == SeatStatus.BOOKED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Seat is already booked"
        )
    
    # Check for ANY existing booking for this seat (due to UNIQUE constraint on seat_id)
    existing_booking = db.query(Booking).filter(
        Booking.seat_id == seat.id
    ).first()
    
    if existing_booking:
        # There's already a booking for this seat
        if existing_booking.user_id == current_user.id:
            # User's own booking
            if existing_booking.status == BookingStatus.CREATED:
                # User already has a pending booking - they should pay for it
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"You already have a pending booking for this seat (Ref: {existing_booking.booking_reference}). Please complete payment for that booking instead of creating a new one."
                )
            elif existing_booking.status == BookingStatus.CONFIRMED:
                # User already has a confirmed booking - cannot create another
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"You already have a confirmed booking for this seat (Ref: {existing_booking.booking_reference})."
                )
            elif existing_booking.status == BookingStatus.CANCELLED:
                # User has a cancelled booking - delete it and allow new booking
                db.delete(existing_booking)
                db.commit()
        else:
            # Another user's booking
            if existing_booking.status == BookingStatus.CREATED:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Seat is currently held by another user. Please select another seat or wait for it to be released."
                )
            elif existing_booking.status == BookingStatus.CONFIRMED:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Seat is already booked by another user."
                )
            elif existing_booking.status == BookingStatus.CANCELLED:
                # Cancelled booking by another user - delete it and allow new booking
                db.delete(existing_booking)
                db.commit()
    
    # Handle HELD seats
    if seat.status == SeatStatus.HELD:
        # Check if hold expired
        if seat.hold_expires_at and seat.hold_expires_at < datetime.utcnow():
            # Hold expired, release the seat - allow booking
            seat.status = SeatStatus.AVAILABLE
            seat.hold_expires_at = None
    
    # Calculate price
    total_price = flight.base_price * seat.price_multiplier
    
    # Generate unique booking reference
    booking_reference = f"BK{secrets.token_hex(4).upper()}"
    
    # Create booking with CREATED status (not confirmed until payment)
    booking_dict = {
        "user_id": current_user.id,
        "flight_id": booking_data.flight_id,
        "seat_id": booking_data.seat_id,
        "booking_reference": booking_reference,
        "total_price": total_price,
        "status": BookingStatus.CREATED
    }
    
    # Add passenger data if provided
    if has_passenger_data:
        booking_dict.update({
            "passenger_first_name": booking_data.passenger_first_name,
            "passenger_last_name": booking_data.passenger_last_name,
            "passenger_phone": booking_data.passenger_phone,
            "passenger_passport_number": booking_data.passenger_passport_number,
            "passenger_nationality": booking_data.passenger_nationality,
            "passenger_date_of_birth": booking_data.passenger_date_of_birth
        })
    
    new_booking = Booking(**booking_dict)
    db.add(new_booking)
    
    # Mark seat as HELD (not BOOKED yet - only becomes BOOKED after payment)
    # Set hold expiry to 10 minutes from now
    seat.status = SeatStatus.HELD
    seat.hold_expires_at = datetime.utcnow() + timedelta(minutes=10)
    
    db.commit()
    db.refresh(new_booking)
    
    # Reload booking with relationships
    db.refresh(new_booking)
    
    # Return booking - FastAPI will serialize using BookingResponse
    # But we need to manually add price to seat
    # Create a custom response that includes calculated seat price
    from schemas import BookingResponse, SeatResponse
    
    seat_price = flight.base_price * seat.price_multiplier
    seat_response = SeatResponse(
        id=seat.id,
        flight_id=seat.flight_id,
        row_number=seat.row_number,
        seat_letter=seat.seat_letter,
        seat_class=seat.seat_class,
        seat_category=seat.seat_category,
        price_multiplier=seat.price_multiplier,
        status=seat.status,
        price=seat_price
    )
    
    # Build booking response manually
    booking_response = BookingResponse(
        id=new_booking.id,
        user_id=new_booking.user_id,
        flight_id=new_booking.flight_id,
        seat_id=new_booking.seat_id,
        booking_reference=new_booking.booking_reference,
        total_price=new_booking.total_price,
        status=new_booking.status,
        created_at=new_booking.created_at,
        flight=new_booking.flight,
        seat=seat_response,
        passenger_first_name=new_booking.passenger_first_name,
        passenger_last_name=new_booking.passenger_last_name,
        passenger_phone=new_booking.passenger_phone,
        passenger_passport_number=new_booking.passenger_passport_number,
        passenger_nationality=new_booking.passenger_nationality,
        passenger_date_of_birth=new_booking.passenger_date_of_birth
    )
    
    return booking_response


@app.get("/bookings", response_model=List[BookingResponse])
def get_my_bookings(
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """Get all bookings for the current passenger"""
    bookings = db.query(Booking).filter(Booking.user_id == current_user.id).all()
    
    # Clean up expired holds for CREATED bookings
    now = datetime.utcnow()
    needs_commit = False
    for booking in bookings:
        if booking.status == BookingStatus.CREATED:
            seat = booking.seat
            # If hold expired, release the seat (booking remains but seat is available)
            if seat.status == SeatStatus.HELD and seat.hold_expires_at and seat.hold_expires_at < now:
                seat.status = SeatStatus.AVAILABLE
                seat.hold_expires_at = None
                needs_commit = True
    
    # Commit once after all updates
    if needs_commit:
        db.commit()
    
    # Convert to response format with calculated seat prices
    from schemas import BookingResponse, SeatResponse
    
    result = []
    for booking in bookings:
        # Calculate seat price
        seat_price = booking.flight.base_price * booking.seat.price_multiplier
        
        # Create seat response with calculated price
        seat_response = SeatResponse(
            id=booking.seat.id,
            flight_id=booking.seat.flight_id,
            row_number=booking.seat.row_number,
            seat_letter=booking.seat.seat_letter,
            seat_class=booking.seat.seat_class,
            seat_category=booking.seat.seat_category,
            price_multiplier=booking.seat.price_multiplier,
            status=booking.seat.status,
            price=seat_price
        )
        
        # Create booking response
        booking_response = BookingResponse(
            id=booking.id,
            user_id=booking.user_id,
            flight_id=booking.flight_id,
            seat_id=booking.seat_id,
            booking_reference=booking.booking_reference,
            total_price=booking.total_price,
            status=booking.status,
            created_at=booking.created_at,
            flight=booking.flight,
            seat=seat_response,
            passenger_first_name=booking.passenger_first_name,
            passenger_last_name=booking.passenger_last_name,
            passenger_phone=booking.passenger_phone,
            passenger_passport_number=booking.passenger_passport_number,
            passenger_nationality=booking.passenger_nationality,
            passenger_date_of_birth=booking.passenger_date_of_birth
        )
        result.append(booking_response)
    
    return result


@app.get("/bookings/{booking_id}", response_model=BookingResponse)
def get_booking(
    booking_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific booking"""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Check if user owns this booking or is staff
    if booking.user_id != current_user.id and current_user.role != UserRole.STAFF:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Calculate seat price
    seat_price = booking.flight.base_price * booking.seat.price_multiplier
    
    # Create seat response with calculated price
    from schemas import SeatResponse
    
    seat_response = SeatResponse(
        id=booking.seat.id,
        flight_id=booking.seat.flight_id,
        row_number=booking.seat.row_number,
        seat_letter=booking.seat.seat_letter,
        seat_class=booking.seat.seat_class,
        seat_category=booking.seat.seat_category,
        price_multiplier=booking.seat.price_multiplier,
        status=booking.seat.status,
        price=seat_price
    )
    
    # Create booking response
    from schemas import BookingResponse
    
    booking_response = BookingResponse(
        id=booking.id,
        user_id=booking.user_id,
        flight_id=booking.flight_id,
        seat_id=booking.seat_id,
        booking_reference=booking.booking_reference,
        total_price=booking.total_price,
        status=booking.status,
        created_at=booking.created_at,
        flight=booking.flight,
        seat=seat_response,
        passenger_first_name=booking.passenger_first_name,
        passenger_last_name=booking.passenger_last_name,
        passenger_phone=booking.passenger_phone,
        passenger_passport_number=booking.passenger_passport_number,
        passenger_nationality=booking.passenger_nationality,
        passenger_date_of_birth=booking.passenger_date_of_birth
    )
    
    return booking_response


@app.delete("/bookings/{booking_id}")
def cancel_booking(
    booking_id: int,
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """
    Cancel a booking and release the seat.
    Can cancel both CREATED (pending) and CONFIRMED (paid) bookings.
    No refund is provided for confirmed bookings.
    """
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Check if user owns this booking
    if booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Check if flight has already departed
    if booking.flight.status == FlightStatus.DEPARTED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot cancel booking for a flight that has already departed"
        )
    
    # Allow cancelling both CREATED and CONFIRMED bookings
    was_confirmed = booking.status == BookingStatus.CONFIRMED
    if booking.status not in [BookingStatus.CREATED, BookingStatus.CONFIRMED]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This booking cannot be cancelled"
        )
    
    # Release the seat
    seat = booking.seat
    seat.status = SeatStatus.AVAILABLE
    seat.hold_expires_at = None
    
    # Update booking status to CANCELLED
    booking.status = BookingStatus.CANCELLED
    
    db.commit()
    
    message = "Booking cancelled and seat released"
    if was_confirmed:
        message += ". Note: No refund will be provided for cancelled confirmed bookings."
    
    return {"message": message}


# ============ PAYMENT ROUTES ============

@app.get("/payments/history")
def get_payment_history(
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """Get payment history for the current user"""
    payments = db.query(Payment).join(Booking).filter(
        Booking.user_id == current_user.id
    ).order_by(Payment.created_at.desc()).all()
    
    result = []
    for payment in payments:
        booking = payment.booking
        result.append({
            "id": payment.id,
            "booking_id": payment.booking_id,
            "booking_reference": booking.booking_reference,
            "flight_number": booking.flight.flight_number,
            "route": f"{booking.flight.origin_airport.code} → {booking.flight.destination_airport.code}",
            "amount": payment.amount,
            "method": payment.method,
            "status": payment.status,
            "transaction_id": payment.transaction_id,
            "created_at": payment.created_at
        })
    
    return result


@app.post("/payments", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
def create_payment(
    payment_data: PaymentCreate,
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """
    Process payment for a booking.
    This is a MOCK payment - in real app, integrate with payment gateway.
    Payment endpoint is idempotent - calling multiple times won't charge twice.
    """
    # Get booking
    booking = db.query(Booking).filter(Booking.id == payment_data.booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Check if user owns this booking
    if booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Check if booking is expired (10 minutes from creation)
    if booking.status == BookingStatus.CREATED:
        expiry_time = booking.created_at + timedelta(minutes=10)
        if datetime.utcnow() > expiry_time:
            # Booking expired - cancel it and release the seat
            booking.status = BookingStatus.CANCELLED
            seat = booking.seat
            seat.status = SeatStatus.AVAILABLE
            seat.hold_expires_at = None
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Booking has expired. The seat has been released. Please create a new booking."
            )
    
    # Check if payment already exists
    existing_payment = db.query(Payment).filter(
        Payment.booking_id == payment_data.booking_id
    ).first()
    
    if existing_payment:
        # Payment already exists - return it (idempotent)
        if existing_payment.status == PaymentStatus.PAID:
            return existing_payment
        # If payment failed or pending, allow retry/process
        if existing_payment.status in [PaymentStatus.FAILED, PaymentStatus.PENDING]:
            # Simulate payment processing - retry failed/pending payment
            existing_payment.status = PaymentStatus.PAID
            existing_payment.transaction_id = f"TXN{secrets.token_hex(8).upper()}"
            
            # Update booking status to CONFIRMED
            booking.status = BookingStatus.CONFIRMED
            
            # Mark seat as BOOKED (payment confirmed)
            seat = booking.seat
            seat.status = SeatStatus.BOOKED
            seat.hold_expires_at = None
            
            db.commit()
            
            # Create ticket if it doesn't exist
            if not db.query(Ticket).filter(Ticket.booking_id == booking.id).first():
                ticket = Ticket(
                    booking_id=booking.id,
                    ticket_number=f"TK{secrets.token_hex(6).upper()}"
                )
                db.add(ticket)
                db.commit()
            
            return existing_payment
    
    # Create new payment
    # Mock payment - always succeeds
    new_payment = Payment(
        booking_id=payment_data.booking_id,
        amount=booking.total_price,
        method=payment_data.method,
        status=PaymentStatus.PAID,  # Mock - always succeeds
        transaction_id=f"TXN{secrets.token_hex(8).upper()}"
    )
    db.add(new_payment)
    
    # Update booking status to CONFIRMED after successful payment
    booking.status = BookingStatus.CONFIRMED
    
    # Mark seat as BOOKED (payment confirmed)
    seat = booking.seat
    seat.status = SeatStatus.BOOKED
    seat.hold_expires_at = None
    
    db.commit()
    db.refresh(new_payment)
    
    # Create ticket after successful payment (each passenger gets a ticket)
    ticket = Ticket(
        booking_id=booking.id,
        ticket_number=f"TK{secrets.token_hex(6).upper()}"
    )
    db.add(ticket)
    db.commit()
    
    return new_payment


# ============ CHECK-IN ROUTES ============

@app.post("/check-in", response_model=CheckInResponse, status_code=status.HTTP_201_CREATED)
def check_in(
    check_in_data: CheckInCreate,
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """
    Check in for a flight.
    Rules:
    - Allowed from 24 hours to 1 hour before departure
    - Only confirmed bookings (PAID payment) can be checked in
    - Check-in is done per ticket (per booking)
    """
    # Get booking
    booking = db.query(Booking).filter(Booking.id == check_in_data.booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Check if user owns this booking
    if booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Check if payment is completed (only confirmed bookings can check in)
    payment = db.query(Payment).filter(Payment.booking_id == booking.id).first()
    if not payment:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Payment not found. Please complete payment before check-in."
        )
    if payment.status != PaymentStatus.PAID:
        # If payment is PENDING or FAILED, try to process it automatically
        if payment.status in [PaymentStatus.PENDING, PaymentStatus.FAILED]:
            payment.status = PaymentStatus.PAID
            if not payment.transaction_id:
                payment.transaction_id = f"TXN{secrets.token_hex(8).upper()}"
            db.commit()
            
            # Create ticket if it doesn't exist
            if not db.query(Ticket).filter(Ticket.booking_id == booking.id).first():
                ticket = Ticket(
                    booking_id=booking.id,
                    ticket_number=f"TK{secrets.token_hex(6).upper()}"
                )
                db.add(ticket)
                db.commit()
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Only confirmed bookings can check in. Payment status: {payment.status.value}"
            )
    
    # Check time window: 24 hours to 1 hour before departure
    flight = booking.flight
    departure_time = flight.departure_time
    
    # Get current time in UTC
    now_utc = datetime.now(timezone.utc)
    
    # Handle timezone: database stores naive datetime
    # Convert both to naive UTC for comparison
    if departure_time.tzinfo is None:
        # Naive datetime from database - treat as UTC
        now_naive_utc = now_utc.replace(tzinfo=None)
        departure_naive = departure_time
    else:
        # Timezone-aware - convert both to UTC naive
        departure_naive = departure_time.astimezone(timezone.utc).replace(tzinfo=None)
        now_naive_utc = now_utc.replace(tzinfo=None)
    
    # Calculate time differences (both are naive, both in UTC)
    time_diff = departure_naive - now_naive_utc
    hours_until_departure = time_diff.total_seconds() / 3600
    
    # Debug: Log the times for troubleshooting
    print(f"[CHECK-IN DEBUG] Now (UTC): {now_utc}")
    print(f"[CHECK-IN DEBUG] Now (UTC naive): {now_naive_utc}")
    print(f"[CHECK-IN DEBUG] Departure (stored): {departure_time}")
    print(f"[CHECK-IN DEBUG] Departure (naive UTC): {departure_naive}")
    print(f"[CHECK-IN DEBUG] Hours until departure (raw): {hours_until_departure:.2f}")
    
    # Temporary fix: If time seems incorrect (likely timezone issue with old flights)
    # Try to correct by subtracting common timezone offsets (5-6 hours for Central Asia)
    if hours_until_departure > 24 and hours_until_departure < 30:
        # Try common timezone offsets
        for offset_hours in [6, 5, 7, 4, 8]:
            corrected_hours = hours_until_departure - offset_hours
            if 1 < corrected_hours <= 24:
                print(f"[CHECK-IN DEBUG] Applied timezone correction: -{offset_hours} hours")
                hours_until_departure = corrected_hours
                break
    
    print(f"[CHECK-IN DEBUG] Hours until departure (final): {hours_until_departure:.2f}")
    
    # Check-in is allowed from 24 hours to 1 hour before departure
    # Allowed: 1 < hours <= 24 (more than 1 hour, up to and including 24 hours)
    if hours_until_departure <= 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Check-in is only allowed up to 1 hour before departure. Check-in window has closed. (Time remaining: {hours_until_departure:.2f} hours)"
        )
    elif hours_until_departure > 24:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Check-in opens 24 hours before departure. Please check in later. (Time remaining: {hours_until_departure:.2f} hours)"
        )
    
    # Check if already checked in (per ticket/booking)
    existing_check_in = db.query(CheckIn).filter(
        CheckIn.booking_id == booking.id
    ).first()
    
    if existing_check_in:
        return existing_check_in
    
    # Create check-in - use flight's gate if set, otherwise use a default
    boarding_gate = flight.gate if flight.gate else f"Gate {secrets.randbelow(50) + 1}"
    # If gate doesn't start with "Gate", add it
    if boarding_gate and not boarding_gate.startswith("Gate"):
        boarding_gate = f"Gate {boarding_gate}"
    
    new_check_in = CheckIn(
        booking_id=booking.id,
        boarding_gate=boarding_gate,
        boarding_time=flight.departure_time - timedelta(minutes=30)  # 30 min before departure
    )
    db.add(new_check_in)
    db.commit()
    db.refresh(new_check_in)
    
    return new_check_in


@app.get("/bookings/{booking_id}/boarding-pass")
def get_boarding_pass(
    booking_id: int,
    current_user: User = Depends(get_current_passenger_user),
    db: Session = Depends(get_db)
):
    """
    Get boarding pass information.
    Requires check-in to be completed.
    """
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    if booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    check_in = db.query(CheckIn).filter(CheckIn.booking_id == booking.id).first()
    if not check_in:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please check in first"
        )
    
    ticket = db.query(Ticket).filter(Ticket.booking_id == booking.id).first()
    if not ticket:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ticket not found. Please ensure payment is completed."
        )
    
    profile = db.query(PassengerProfile).filter(
        PassengerProfile.user_id == current_user.id
    ).first()
    
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Passenger profile not found"
        )
    
    # Generate QR code payload (string format)
    # QR code contains: booking_reference, ticket_number, flight_number, seat
    qr_payload = f"{booking.booking_reference}|{ticket.ticket_number}|{booking.flight.flight_number}|{booking.seat.row_number}{booking.seat.seat_letter}"
    
    # Use current gate/terminal from flight (may have been updated after check-in)
    # Fall back to check-in gate if flight gate is not set
    current_gate = booking.flight.gate if booking.flight.gate else check_in.boarding_gate
    
    return {
        "booking_reference": booking.booking_reference,
        "ticket_number": ticket.ticket_number,
        "passenger_name": f"{profile.first_name} {profile.last_name}",
        "flight_number": booking.flight.flight_number,
        "seat": f"{booking.seat.row_number}{booking.seat.seat_letter}",
        "boarding_gate": current_gate,  # Use current flight gate (updated if changed)
        "boarding_time": check_in.boarding_time,
        "departure_time": booking.flight.departure_time,
        "origin": f"{booking.flight.origin_airport.code} - {booking.flight.origin_airport.name}",
        "destination": f"{booking.flight.destination_airport.code} - {booking.flight.destination_airport.name}",
        "terminal": booking.flight.terminal,  # Always use current terminal from flight
        "qr_code": qr_payload
    }


# ============ ANNOUNCEMENT ROUTES ============

@app.get("/announcements", response_model=List[AnnouncementResponse])
def get_announcements(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get announcements for the current user.
    Returns:
    - All general announcements (flight_id is None)
    - Flight-specific announcements only for flights the user has booked
    """
    # Get user's booked flight IDs
    user_flight_ids = db.query(Booking.flight_id).filter(
        Booking.user_id == current_user.id
    ).distinct().all()
    user_flight_ids = [f[0] for f in user_flight_ids]
    
    # Get general announcements + flight-specific announcements for user's flights + personal announcements
    announcements = db.query(Announcement).filter(
        Announcement.is_active == True,
        or_(
            and_(Announcement.flight_id == None, Announcement.user_id == None),  # General announcements
            and_(Announcement.flight_id.in_(user_flight_ids), Announcement.user_id == None),  # User's flight announcements (not personal)
            Announcement.user_id == current_user.id  # Personal announcements for this user
        )
    ).order_by(Announcement.created_at.desc()).all()
    
    # Convert to response format, handling missing announcement_type
    result = []
    for ann in announcements:
        # Handle case where announcement_type might not exist in DB yet
        ann_type = getattr(ann, 'announcement_type', None)
        if ann_type is None:
            ann_type = AnnouncementType.GENERAL
        elif isinstance(ann_type, AnnouncementType):
            ann_type = ann_type.value
        
        result.append(AnnouncementResponse(
            id=ann.id,
            title=ann.title,
            message=ann.message,
            announcement_type=ann_type,
            flight_id=ann.flight_id,
            user_id=getattr(ann, 'user_id', None),  # Handle case where user_id might not exist in DB yet
            created_at=ann.created_at,
            is_active=ann.is_active
        ))
    
    return result


@app.get("/announcements/public", response_model=List[AnnouncementResponse])
def get_public_announcements(db: Session = Depends(get_db)):
    """Get all general (public) announcements - no auth required"""
    announcements = db.query(Announcement).filter(
        Announcement.is_active == True,
        Announcement.flight_id == None
    ).order_by(Announcement.created_at.desc()).all()
    
    # Convert to response format, handling missing announcement_type
    result = []
    for ann in announcements:
        ann_type = getattr(ann, 'announcement_type', None)
        if ann_type is None:
            ann_type = AnnouncementType.GENERAL
        elif isinstance(ann_type, AnnouncementType):
            ann_type = ann_type.value
        
        result.append(AnnouncementResponse(
            id=ann.id,
            title=ann.title,
            message=ann.message,
            announcement_type=ann_type,
            flight_id=ann.flight_id,
            user_id=getattr(ann, 'user_id', None),  # Handle case where user_id might not exist in DB yet
            created_at=ann.created_at,
            is_active=ann.is_active
        ))
    
    return result


@app.get("/staff/announcements", response_model=List[AnnouncementResponse])
def get_all_announcements(
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Get all announcements (including flight-specific) - staff only"""
    announcements = db.query(Announcement).order_by(Announcement.created_at.desc()).all()
    
    # Convert to response format, handling missing announcement_type
    result = []
    for ann in announcements:
        ann_type = getattr(ann, 'announcement_type', None)
        if ann_type is None:
            ann_type = AnnouncementType.GENERAL
        elif isinstance(ann_type, AnnouncementType):
            ann_type = ann_type.value
        
        result.append(AnnouncementResponse(
            id=ann.id,
            title=ann.title,
            message=ann.message,
            announcement_type=ann_type,
            flight_id=ann.flight_id,
            user_id=getattr(ann, 'user_id', None),  # Handle case where user_id might not exist in DB yet
            created_at=ann.created_at,
            is_active=ann.is_active
        ))
    
    return result


@app.post("/announcements", response_model=AnnouncementResponse, status_code=status.HTTP_201_CREATED)
def create_announcement(
    announcement_data: AnnouncementCreate,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """
    Create a new announcement - staff only.
    Set flight_id to target specific flight passengers, or leave None for general announcement.
    """
    # Validate flight_id if provided
    if announcement_data.flight_id:
        flight = db.query(Flight).filter(Flight.id == announcement_data.flight_id).first()
        if not flight:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Flight not found"
            )
    
    # Convert announcement_type string to enum if provided
    announcement_dict = announcement_data.dict()
    if "announcement_type" in announcement_dict and announcement_dict["announcement_type"]:
        try:
            announcement_dict["announcement_type"] = AnnouncementType(announcement_dict["announcement_type"])
        except ValueError:
            announcement_dict["announcement_type"] = AnnouncementType.GENERAL
    else:
        announcement_dict["announcement_type"] = AnnouncementType.GENERAL
    
    new_announcement = Announcement(**announcement_dict)
    db.add(new_announcement)
    db.commit()
    db.refresh(new_announcement)
    return new_announcement


# ============ STAFF ROUTES ============

@app.get("/staff/bookings", response_model=List[BookingResponse])
def get_all_bookings(
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Get all bookings - staff only"""
    bookings = db.query(Booking).all()
    
    # Convert to response format with calculated seat prices
    from schemas import BookingResponse, SeatResponse
    
    result = []
    for booking in bookings:
        # Calculate seat price
        seat_price = booking.flight.base_price * booking.seat.price_multiplier
        
        # Create seat response with calculated price
        seat_response = SeatResponse(
            id=booking.seat.id,
            flight_id=booking.seat.flight_id,
            row_number=booking.seat.row_number,
            seat_letter=booking.seat.seat_letter,
            seat_class=booking.seat.seat_class,
            seat_category=booking.seat.seat_category,
            price_multiplier=booking.seat.price_multiplier,
            status=booking.seat.status,
            price=seat_price
        )
        
        # Create booking response
        booking_response = BookingResponse(
            id=booking.id,
            user_id=booking.user_id,
            flight_id=booking.flight_id,
            seat_id=booking.seat_id,
            booking_reference=booking.booking_reference,
            total_price=booking.total_price,
            status=booking.status,
            created_at=booking.created_at,
            flight=booking.flight,
            seat=seat_response,
            passenger_first_name=booking.passenger_first_name,
            passenger_last_name=booking.passenger_last_name,
            passenger_phone=booking.passenger_phone,
            passenger_passport_number=booking.passenger_passport_number,
            passenger_nationality=booking.passenger_nationality,
            passenger_date_of_birth=booking.passenger_date_of_birth
        )
        result.append(booking_response)
    
    return result


@app.get("/staff/bookings/flight/{flight_id}")
def get_bookings_by_flight(
    flight_id: int,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Get all bookings for a specific flight - staff only"""
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    bookings = db.query(Booking).filter(Booking.flight_id == flight_id).all()
    
    # Convert to response format
    from schemas import BookingResponse, SeatResponse
    
    result = []
    for booking in bookings:
        seat_price = booking.flight.base_price * booking.seat.price_multiplier
        seat_response = SeatResponse(
            id=booking.seat.id,
            flight_id=booking.seat.flight_id,
            row_number=booking.seat.row_number,
            seat_letter=booking.seat.seat_letter,
            seat_class=booking.seat.seat_class,
            seat_category=booking.seat.seat_category,
            price_multiplier=booking.seat.price_multiplier,
            status=booking.seat.status,
            price=seat_price
        )
        
        booking_response = BookingResponse(
            id=booking.id,
            user_id=booking.user_id,
            flight_id=booking.flight_id,
            seat_id=booking.seat_id,
            booking_reference=booking.booking_reference,
            total_price=booking.total_price,
            status=booking.status,
            created_at=booking.created_at,
            flight=booking.flight,
            seat=seat_response,
            passenger_first_name=booking.passenger_first_name,
            passenger_last_name=booking.passenger_last_name,
            passenger_phone=booking.passenger_phone,
            passenger_passport_number=booking.passenger_passport_number,
            passenger_nationality=booking.passenger_nationality,
            passenger_date_of_birth=booking.passenger_date_of_birth
        )
        result.append(booking_response)
    
    return result


@app.get("/staff/bookings/search")
def search_bookings_by_pnr(
    pnr: str,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Search bookings by PNR (booking reference) - staff only"""
    booking = db.query(Booking).filter(Booking.booking_reference == pnr.upper()).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Convert to response format
    from schemas import BookingResponse, SeatResponse
    
    seat_price = booking.flight.base_price * booking.seat.price_multiplier
    seat_response = SeatResponse(
        id=booking.seat.id,
        flight_id=booking.seat.flight_id,
        row_number=booking.seat.row_number,
        seat_letter=booking.seat.seat_letter,
        seat_class=booking.seat.seat_class,
        seat_category=booking.seat.seat_category,
        price_multiplier=booking.seat.price_multiplier,
        status=booking.seat.status,
        price=seat_price
    )
    
    booking_response = BookingResponse(
        id=booking.id,
        user_id=booking.user_id,
        flight_id=booking.flight_id,
        seat_id=booking.seat_id,
        booking_reference=booking.booking_reference,
        total_price=booking.total_price,
        status=booking.status,
        created_at=booking.created_at,
        flight=booking.flight,
        seat=seat_response,
        passenger_first_name=booking.passenger_first_name,
        passenger_last_name=booking.passenger_last_name,
        passenger_phone=booking.passenger_phone,
        passenger_passport_number=booking.passenger_passport_number,
        passenger_nationality=booking.passenger_nationality,
        passenger_date_of_birth=booking.passenger_date_of_birth
    )

    return booking_response


@app.delete("/staff/bookings/{booking_id}")
def cancel_booking_staff(
    booking_id: int,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Cancel a booking - staff only. Can cancel before departure."""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Check if flight has departed
    if booking.flight.status == FlightStatus.DEPARTED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot cancel booking for a flight that has already departed"
        )
    
    # Release the seat
    seat = booking.seat
    seat.status = SeatStatus.AVAILABLE
    seat.hold_expires_at = None
    
    # Update booking status to CANCELLED
    booking.status = BookingStatus.CANCELLED
    
    db.commit()
    
    return {"message": "Booking cancelled successfully"}


@app.patch("/staff/bookings/{booking_id}/reassign-seat")
def reassign_seat(
    booking_id: int,
    new_seat_id: int,
    current_user: User = Depends(get_current_staff_user),
    db: Session = Depends(get_db)
):
    """Reassign a seat for a booking - staff only. Overrides availability rules."""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Check if flight has departed
    if booking.flight.status == FlightStatus.DEPARTED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot reassign seat for a flight that has already departed"
        )
    
    # Get new seat
    new_seat = db.query(Seat).filter(
        and_(
            Seat.id == new_seat_id,
            Seat.flight_id == booking.flight_id
        )
    ).first()
    
    if not new_seat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="New seat not found"
        )
    
    # Check if new seat is already booked (unless it's the same seat)
    if new_seat.id != booking.seat_id:
        existing_booking = db.query(Booking).filter(
            and_(
                Booking.seat_id == new_seat_id,
                Booking.status != BookingStatus.CANCELLED
            )
        ).first()
        
        if existing_booking:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New seat is already booked"
            )
    
    # Release old seat
    old_seat = booking.seat
    old_seat.status = SeatStatus.AVAILABLE
    old_seat.hold_expires_at = None
    
    # Assign new seat
    booking.seat_id = new_seat_id
    new_seat.status = SeatStatus.BOOKED if booking.status == BookingStatus.CONFIRMED else SeatStatus.HELD
    new_seat.hold_expires_at = None
    
    # Recalculate price
    booking.total_price = booking.flight.base_price * new_seat.price_multiplier
    
    # Create a personal notification for the user about seat reassignment
    announcement = Announcement(
        title=f"Seat Reassignment - Flight {booking.flight.flight_number}",
        message=f"Your seat has been reassigned from {old_seat.row_number}{old_seat.seat_letter} to {new_seat.row_number}{new_seat.seat_letter} for flight {booking.flight.flight_number}. Please check your booking details.",
        announcement_type=AnnouncementType.GENERAL,
        flight_id=booking.flight_id,  # Flight-specific
        user_id=booking.user_id,  # Personal notification for this specific user
        is_active=True
    )
    db.add(announcement)
    
    db.commit()
    
    return {"message": f"Seat reassigned from {old_seat.row_number}{old_seat.seat_letter} to {new_seat.row_number}{new_seat.seat_letter}. User has been notified."}


# Root endpoint
@app.get("/")
def root():
    """Root endpoint - API information"""
    return {
        "message": "Airline Booking API",
        "docs": "/docs",
        "admin": "/admin",
        "version": "1.0.0"
    }


# Admin Panel - Serve HTML file
@app.get("/admin")
def admin_panel():
    """Serve admin panel HTML"""
    from fastapi.responses import FileResponse
    import os
    admin_path = os.path.join(os.path.dirname(__file__), "admin", "index.html")
    return FileResponse(admin_path)


# Serve static files for admin panel
from fastapi.staticfiles import StaticFiles
import os

admin_dir = os.path.join(os.path.dirname(__file__), "admin")
if os.path.exists(admin_dir):
    app.mount("/admin/static", StaticFiles(directory=admin_dir), name="admin_static")



