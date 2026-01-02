"""
Seed Database
=============
This script populates the database with initial data for testing.
Run this after setting up the database to have sample data.

Usage: python seed.py
"""

from sqlalchemy.orm import Session
from database import SessionLocal, engine
from models import Base, User, Airport, Airplane, Flight, Seat, Announcement
from auth import get_password_hash
from datetime import datetime, timedelta
from models import UserRole, SeatStatus, FlightStatus, SeatCategory
import random

# Create tables
Base.metadata.create_all(bind=engine)

# Get database session
db = SessionLocal()


def seed_database():
    """Populate database with initial data"""
    
    print("=" * 50)
    print("SEEDING DATABASE")
    print("=" * 50)
    
    # ============ CREATE USERS ============
    print("\n📝 Creating users...")
    
    # Create passenger users
    passengers = [
        {"email": "passenger@example.com", "password": "password123"},
        {"email": "john.doe@email.com", "password": "password123"},
        {"email": "jane.smith@email.com", "password": "password123"},
        {"email": "alex.kim@email.com", "password": "password123"},
    ]
    
    for p in passengers:
        user = User(
            email=p["email"],
            password_hash=get_password_hash(p["password"]),
            role=UserRole.PASSENGER
        )
        db.add(user)
    
    # Create staff users
    staff_members = [
        {"email": "staff@example.com", "password": "password123"},
        {"email": "admin@airline.com", "password": "admin123"},
    ]
    
    for s in staff_members:
        user = User(
            email=s["email"],
            password_hash=get_password_hash(s["password"]),
            role=UserRole.STAFF
        )
        db.add(user)
    
    db.commit()
    print(f"   ✓ {len(passengers)} passengers created")
    print(f"   ✓ {len(staff_members)} staff members created")
    
    # ============ CREATE AIRPORTS ============
    print("\n✈️  Creating airports...")
    
    airports_data = [
        # Central Asia - Kyrgyzstan
        {"code": "FRU", "name": "Manas International Airport", "city": "Bishkek", "country": "Kyrgyzstan"},
        {"code": "OSS", "name": "Osh Airport", "city": "Osh", "country": "Kyrgyzstan"},
        
        # Central Asia - Kazakhstan
        {"code": "ALA", "name": "Almaty International Airport", "city": "Almaty", "country": "Kazakhstan"},
        {"code": "NQZ", "name": "Nursultan Nazarbayev International Airport", "city": "Astana", "country": "Kazakhstan"},
        {"code": "SCO", "name": "Aktau Airport", "city": "Aktau", "country": "Kazakhstan"},
        
        # Central Asia - Uzbekistan
        {"code": "TAS", "name": "Islam Karimov Tashkent International Airport", "city": "Tashkent", "country": "Uzbekistan"},
        {"code": "SKD", "name": "Samarkand International Airport", "city": "Samarkand", "country": "Uzbekistan"},
        
        # East Asia
        {"code": "PEK", "name": "Beijing Capital International Airport", "city": "Beijing", "country": "China"},
        {"code": "PVG", "name": "Shanghai Pudong International Airport", "city": "Shanghai", "country": "China"},
        {"code": "HKG", "name": "Hong Kong International Airport", "city": "Hong Kong", "country": "China"},
        {"code": "NRT", "name": "Narita International Airport", "city": "Tokyo", "country": "Japan"},
        {"code": "HND", "name": "Tokyo Haneda Airport", "city": "Tokyo", "country": "Japan"},
        {"code": "ICN", "name": "Incheon International Airport", "city": "Seoul", "country": "South Korea"},
        
        # South Asia
        {"code": "DEL", "name": "Indira Gandhi International Airport", "city": "New Delhi", "country": "India"},
        {"code": "BOM", "name": "Chhatrapati Shivaji Maharaj International Airport", "city": "Mumbai", "country": "India"},
        
        # Southeast Asia
        {"code": "SIN", "name": "Singapore Changi Airport", "city": "Singapore", "country": "Singapore"},
        {"code": "BKK", "name": "Suvarnabhumi Airport", "city": "Bangkok", "country": "Thailand"},
        {"code": "KUL", "name": "Kuala Lumpur International Airport", "city": "Kuala Lumpur", "country": "Malaysia"},
        
        # Middle East
        {"code": "DXB", "name": "Dubai International Airport", "city": "Dubai", "country": "UAE"},
        {"code": "AUH", "name": "Abu Dhabi International Airport", "city": "Abu Dhabi", "country": "UAE"},
        {"code": "DOH", "name": "Hamad International Airport", "city": "Doha", "country": "Qatar"},
        {"code": "IST", "name": "Istanbul Airport", "city": "Istanbul", "country": "Turkey"},
        {"code": "SAW", "name": "Sabiha Gökçen International Airport", "city": "Istanbul", "country": "Turkey"},
        
        # Russia
        {"code": "SVO", "name": "Sheremetyevo International Airport", "city": "Moscow", "country": "Russia"},
        {"code": "DME", "name": "Domodedovo International Airport", "city": "Moscow", "country": "Russia"},
        {"code": "LED", "name": "Pulkovo Airport", "city": "Saint Petersburg", "country": "Russia"},
        
        # Europe
        {"code": "LHR", "name": "London Heathrow Airport", "city": "London", "country": "United Kingdom"},
        {"code": "CDG", "name": "Charles de Gaulle Airport", "city": "Paris", "country": "France"},
        {"code": "FRA", "name": "Frankfurt Airport", "city": "Frankfurt", "country": "Germany"},
        {"code": "AMS", "name": "Amsterdam Airport Schiphol", "city": "Amsterdam", "country": "Netherlands"},
        {"code": "FCO", "name": "Leonardo da Vinci–Fiumicino Airport", "city": "Rome", "country": "Italy"},
        {"code": "MAD", "name": "Adolfo Suárez Madrid–Barajas Airport", "city": "Madrid", "country": "Spain"},
        
        # North America
        {"code": "JFK", "name": "John F. Kennedy International Airport", "city": "New York", "country": "USA"},
        {"code": "LAX", "name": "Los Angeles International Airport", "city": "Los Angeles", "country": "USA"},
        {"code": "ORD", "name": "O'Hare International Airport", "city": "Chicago", "country": "USA"},
        {"code": "SFO", "name": "San Francisco International Airport", "city": "San Francisco", "country": "USA"},
        {"code": "YYZ", "name": "Toronto Pearson International Airport", "city": "Toronto", "country": "Canada"},
    ]
    
    airports = {}
    for airport_data in airports_data:
        airport = Airport(**airport_data)
        db.add(airport)
        airports[airport_data["code"]] = airport
    
    db.commit()
    # Refresh to get IDs
    for code in airports:
        db.refresh(airports[code])
    
    print(f"   ✓ {len(airports)} airports created")
    
    # ============ CREATE AIRPLANES ============
    print("\n🛫 Creating airplanes...")
    
    airplanes_data = [
        # Narrow-body (regional/short-haul)
        {"model": "Airbus A320neo", "total_seats": 180, "rows": 30, "seats_per_row": 6},
        {"model": "Airbus A321neo", "total_seats": 220, "rows": 37, "seats_per_row": 6},
        {"model": "Boeing 737 MAX 8", "total_seats": 178, "rows": 30, "seats_per_row": 6},
        {"model": "Boeing 737-800", "total_seats": 162, "rows": 27, "seats_per_row": 6},
        {"model": "Embraer E190", "total_seats": 100, "rows": 25, "seats_per_row": 4},
        
        # Wide-body (long-haul)
        {"model": "Boeing 777-300ER", "total_seats": 396, "rows": 44, "seats_per_row": 9},
        {"model": "Boeing 787-9 Dreamliner", "total_seats": 290, "rows": 33, "seats_per_row": 9},
        {"model": "Airbus A350-900", "total_seats": 325, "rows": 37, "seats_per_row": 9},
        {"model": "Airbus A380-800", "total_seats": 525, "rows": 60, "seats_per_row": 9},
    ]
    
    airplanes = []
    for airplane_data in airplanes_data:
        airplane = Airplane(**airplane_data)
        db.add(airplane)
        airplanes.append(airplane)
    
    db.commit()
    for ap in airplanes:
        db.refresh(ap)
    
    print(f"   ✓ {len(airplanes)} airplanes created")
    
    # ============ CREATE FLIGHTS ============
    print("\n🛩️  Creating flights...")
    
    # Helper to get airplane by type
    narrow_body = airplanes[:5]  # A320, A321, 737 MAX, 737-800, E190
    wide_body = airplanes[5:]    # 777, 787, A350, A380
    
    flights_data = [
        # ===== Central Asia Routes =====
        # Bishkek hub connections
        {"number": "KC101", "origin": "FRU", "dest": "ALA", "airplane": narrow_body[0], "days": 1, "dep_hour": 8, "duration": 1.5, "price": 150},
        {"number": "KC102", "origin": "ALA", "dest": "FRU", "airplane": narrow_body[0], "days": 1, "dep_hour": 12, "duration": 1.5, "price": 150},
        {"number": "KC103", "origin": "FRU", "dest": "NQZ", "airplane": narrow_body[1], "days": 2, "dep_hour": 7, "duration": 2, "price": 180},
        {"number": "KC104", "origin": "NQZ", "dest": "FRU", "airplane": narrow_body[1], "days": 2, "dep_hour": 14, "duration": 2, "price": 180},
        {"number": "KC105", "origin": "FRU", "dest": "TAS", "airplane": narrow_body[3], "days": 1, "dep_hour": 9, "duration": 1, "price": 120},
        {"number": "KC106", "origin": "TAS", "dest": "FRU", "airplane": narrow_body[3], "days": 1, "dep_hour": 15, "duration": 1, "price": 120},
        {"number": "KC107", "origin": "FRU", "dest": "OSS", "airplane": narrow_body[4], "days": 3, "dep_hour": 10, "duration": 0.75, "price": 80},
        {"number": "KC108", "origin": "OSS", "dest": "FRU", "airplane": narrow_body[4], "days": 3, "dep_hour": 14, "duration": 0.75, "price": 80},
        
        # Bishkek to International
        {"number": "KC201", "origin": "FRU", "dest": "IST", "airplane": wide_body[1], "days": 2, "dep_hour": 6, "duration": 5.5, "price": 350},
        {"number": "KC202", "origin": "IST", "dest": "FRU", "airplane": wide_body[1], "days": 2, "dep_hour": 16, "duration": 5, "price": 350},
        {"number": "KC203", "origin": "FRU", "dest": "SVO", "airplane": narrow_body[1], "days": 1, "dep_hour": 5, "duration": 4, "price": 280},
        {"number": "KC204", "origin": "SVO", "dest": "FRU", "airplane": narrow_body[1], "days": 1, "dep_hour": 22, "duration": 4.5, "price": 280},
        {"number": "KC205", "origin": "FRU", "dest": "DXB", "airplane": wide_body[1], "days": 3, "dep_hour": 4, "duration": 4, "price": 400},
        {"number": "KC206", "origin": "DXB", "dest": "FRU", "airplane": wide_body[1], "days": 3, "dep_hour": 14, "duration": 4, "price": 400},
        {"number": "KC207", "origin": "FRU", "dest": "DEL", "airplane": narrow_body[0], "days": 4, "dep_hour": 8, "duration": 3.5, "price": 320},
        {"number": "KC208", "origin": "DEL", "dest": "FRU", "airplane": narrow_body[0], "days": 4, "dep_hour": 16, "duration": 3.5, "price": 320},
        {"number": "KC209", "origin": "FRU", "dest": "PEK", "airplane": wide_body[2], "days": 5, "dep_hour": 10, "duration": 4.5, "price": 450},
        {"number": "KC210", "origin": "PEK", "dest": "FRU", "airplane": wide_body[2], "days": 5, "dep_hour": 18, "duration": 5, "price": 450},
        
        # Almaty connections
        {"number": "KC301", "origin": "ALA", "dest": "IST", "airplane": wide_body[0], "days": 1, "dep_hour": 7, "duration": 6, "price": 380},
        {"number": "KC302", "origin": "IST", "dest": "ALA", "airplane": wide_body[0], "days": 1, "dep_hour": 18, "duration": 5.5, "price": 380},
        {"number": "KC303", "origin": "ALA", "dest": "SVO", "airplane": narrow_body[0], "days": 2, "dep_hour": 6, "duration": 4.5, "price": 300},
        {"number": "KC304", "origin": "SVO", "dest": "ALA", "airplane": narrow_body[0], "days": 2, "dep_hour": 20, "duration": 5, "price": 300},
        {"number": "KC305", "origin": "ALA", "dest": "DXB", "airplane": wide_body[1], "days": 3, "dep_hour": 3, "duration": 4.5, "price": 420},
        {"number": "KC306", "origin": "DXB", "dest": "ALA", "airplane": wide_body[1], "days": 3, "dep_hour": 12, "duration": 4.5, "price": 420},
        {"number": "KC307", "origin": "ALA", "dest": "ICN", "airplane": wide_body[2], "days": 4, "dep_hour": 9, "duration": 6, "price": 500},
        {"number": "KC308", "origin": "ICN", "dest": "ALA", "airplane": wide_body[2], "days": 4, "dep_hour": 20, "duration": 6.5, "price": 500},
        
        # ===== Asia to Europe Routes =====
        {"number": "TK501", "origin": "IST", "dest": "LHR", "airplane": wide_body[0], "days": 1, "dep_hour": 8, "duration": 4, "price": 320},
        {"number": "TK502", "origin": "LHR", "dest": "IST", "airplane": wide_body[0], "days": 1, "dep_hour": 15, "duration": 3.5, "price": 320},
        {"number": "TK503", "origin": "IST", "dest": "CDG", "airplane": narrow_body[1], "days": 2, "dep_hour": 10, "duration": 3.5, "price": 280},
        {"number": "TK504", "origin": "CDG", "dest": "IST", "airplane": narrow_body[1], "days": 2, "dep_hour": 17, "duration": 3, "price": 280},
        
        # ===== Middle East Hub Routes =====
        {"number": "EK601", "origin": "DXB", "dest": "LHR", "airplane": wide_body[3], "days": 1, "dep_hour": 7, "duration": 7, "price": 550},
        {"number": "EK602", "origin": "LHR", "dest": "DXB", "airplane": wide_body[3], "days": 1, "dep_hour": 20, "duration": 6.5, "price": 550},
        {"number": "EK603", "origin": "DXB", "dest": "JFK", "airplane": wide_body[3], "days": 2, "dep_hour": 3, "duration": 14, "price": 950},
        {"number": "EK604", "origin": "JFK", "dest": "DXB", "airplane": wide_body[3], "days": 2, "dep_hour": 22, "duration": 12, "price": 950},
        {"number": "EK605", "origin": "DXB", "dest": "SIN", "airplane": wide_body[0], "days": 3, "dep_hour": 2, "duration": 7, "price": 480},
        {"number": "EK606", "origin": "SIN", "dest": "DXB", "airplane": wide_body[0], "days": 3, "dep_hour": 14, "duration": 7.5, "price": 480},
        {"number": "EK607", "origin": "DXB", "dest": "BKK", "airplane": wide_body[1], "days": 4, "dep_hour": 4, "duration": 6, "price": 420},
        {"number": "EK608", "origin": "BKK", "dest": "DXB", "airplane": wide_body[1], "days": 4, "dep_hour": 15, "duration": 6.5, "price": 420},
        
        # ===== East Asia Routes =====
        {"number": "CA701", "origin": "PEK", "dest": "NRT", "airplane": wide_body[1], "days": 1, "dep_hour": 9, "duration": 3.5, "price": 380},
        {"number": "CA702", "origin": "NRT", "dest": "PEK", "airplane": wide_body[1], "days": 1, "dep_hour": 16, "duration": 4, "price": 380},
        {"number": "CA703", "origin": "PEK", "dest": "ICN", "airplane": narrow_body[0], "days": 2, "dep_hour": 8, "duration": 2, "price": 220},
        {"number": "CA704", "origin": "ICN", "dest": "PEK", "airplane": narrow_body[0], "days": 2, "dep_hour": 14, "duration": 2.5, "price": 220},
        {"number": "CA705", "origin": "PVG", "dest": "HKG", "airplane": narrow_body[1], "days": 1, "dep_hour": 10, "duration": 2.5, "price": 180},
        {"number": "CA706", "origin": "HKG", "dest": "PVG", "airplane": narrow_body[1], "days": 1, "dep_hour": 15, "duration": 2.5, "price": 180},
        
        # ===== Europe to Americas =====
        {"number": "BA801", "origin": "LHR", "dest": "JFK", "airplane": wide_body[0], "days": 1, "dep_hour": 10, "duration": 8, "price": 680},
        {"number": "BA802", "origin": "JFK", "dest": "LHR", "airplane": wide_body[0], "days": 1, "dep_hour": 21, "duration": 7, "price": 680},
        {"number": "BA803", "origin": "LHR", "dest": "LAX", "airplane": wide_body[3], "days": 2, "dep_hour": 11, "duration": 11, "price": 780},
        {"number": "BA804", "origin": "LAX", "dest": "LHR", "airplane": wide_body[3], "days": 2, "dep_hour": 18, "duration": 10, "price": 780},
        {"number": "AF805", "origin": "CDG", "dest": "JFK", "airplane": wide_body[2], "days": 3, "dep_hour": 9, "duration": 8.5, "price": 650},
        {"number": "AF806", "origin": "JFK", "dest": "CDG", "airplane": wide_body[2], "days": 3, "dep_hour": 22, "duration": 7.5, "price": 650},
        
        # ===== US Domestic =====
        {"number": "AA901", "origin": "JFK", "dest": "LAX", "airplane": narrow_body[2], "days": 1, "dep_hour": 8, "duration": 6, "price": 299},
        {"number": "AA902", "origin": "LAX", "dest": "JFK", "airplane": narrow_body[2], "days": 1, "dep_hour": 17, "duration": 5.5, "price": 299},
        {"number": "AA903", "origin": "JFK", "dest": "ORD", "airplane": narrow_body[3], "days": 2, "dep_hour": 7, "duration": 2.5, "price": 180},
        {"number": "AA904", "origin": "ORD", "dest": "JFK", "airplane": narrow_body[3], "days": 2, "dep_hour": 14, "duration": 2.5, "price": 180},
        {"number": "AA905", "origin": "LAX", "dest": "SFO", "airplane": narrow_body[4], "days": 1, "dep_hour": 9, "duration": 1.5, "price": 120},
        {"number": "AA906", "origin": "SFO", "dest": "LAX", "airplane": narrow_body[4], "days": 1, "dep_hour": 14, "duration": 1.5, "price": 120},
        
        # ===== Southeast Asia =====
        {"number": "SQ1001", "origin": "SIN", "dest": "BKK", "airplane": narrow_body[0], "days": 1, "dep_hour": 8, "duration": 2.5, "price": 150},
        {"number": "SQ1002", "origin": "BKK", "dest": "SIN", "airplane": narrow_body[0], "days": 1, "dep_hour": 14, "duration": 2.5, "price": 150},
        {"number": "SQ1003", "origin": "SIN", "dest": "KUL", "airplane": narrow_body[4], "days": 2, "dep_hour": 10, "duration": 1, "price": 80},
        {"number": "SQ1004", "origin": "KUL", "dest": "SIN", "airplane": narrow_body[4], "days": 2, "dep_hour": 15, "duration": 1, "price": 80},
        {"number": "SQ1005", "origin": "SIN", "dest": "HKG", "airplane": wide_body[1], "days": 3, "dep_hour": 9, "duration": 4, "price": 280},
        {"number": "SQ1006", "origin": "HKG", "dest": "SIN", "airplane": wide_body[1], "days": 3, "dep_hour": 17, "duration": 4, "price": 280},
        
        # ===== Additional Check-in Test Flights (departing in 12-20 hours) =====
        {"number": "KC999", "origin": "FRU", "dest": "ALA", "airplane": narrow_body[0], "days": 0, "dep_hour": 18, "duration": 1.5, "price": 150},
        {"number": "KC998", "origin": "ALA", "dest": "FRU", "airplane": narrow_body[0], "days": 0, "dep_hour": 20, "duration": 1.5, "price": 150},
    ]
    
    flights = []
    for f in flights_data:
        dep_time = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=f["days"], hours=f["dep_hour"])
        arr_time = dep_time + timedelta(hours=f["duration"])
        
        flight = Flight(
            flight_number=f["number"],
            origin_airport_id=airports[f["origin"]].id,
            destination_airport_id=airports[f["dest"]].id,
            airplane_id=f["airplane"].id,
            departure_time=dep_time,
            arrival_time=arr_time,
            base_price=f["price"],
            status=FlightStatus.SCHEDULED
        )
        db.add(flight)
        flights.append(flight)
    
    db.commit()
    for fl in flights:
        db.refresh(fl)
    
    print(f"   ✓ {len(flights)} flights created")
    
    # ============ CREATE SEATS FOR FLIGHTS ============
    print("\n💺 Creating seats for flights...")
    
    total_seats = 0
    for flight in flights:
        airplane = flight.airplane
        seats_for_flight = []
        
        # Determine seat configuration based on airplane type
        if airplane.seats_per_row == 6:
            # Narrow body: ABC DEF
            seat_letters = ['A', 'B', 'C', 'D', 'E', 'F']
            business_rows = 4
            # Removed premium class - only ECONOMY and BUSINESS
            premium_rows = 0
        else:
            # Wide body: ABC DEFG HJK (skip I)
            seat_letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J'][:airplane.seats_per_row]
            business_rows = 6
            # Removed premium class - only ECONOMY and BUSINESS
            premium_rows = 0
        
        # Define exit rows (extra legroom) - typically rows 10, 11 for narrow body
        exit_rows = [10, 11] if airplane.seats_per_row == 6 else [14, 15, 28, 29]
        
        for row in range(1, airplane.rows + 1):
            for seat_letter in seat_letters:
                seat_class = "ECONOMY"
                seat_category = SeatCategory.STANDARD
                price_multiplier = 1.0
                
                # Business class (first rows)
                if row <= business_rows:
                    seat_class = "BUSINESS"
                    price_multiplier = 2.5
                # Removed premium class - all other rows are economy
                # Extra legroom (exit rows)
                elif row in exit_rows:
                    seat_category = SeatCategory.EXTRA_LEGROOM
                    price_multiplier = 1.3  # Extra legroom costs more
                
                seat = Seat(
                    flight_id=flight.id,
                    airplane_id=airplane.id,
                    row_number=row,
                    seat_letter=seat_letter,
                    seat_class=seat_class,
                    seat_category=seat_category,
                    price_multiplier=price_multiplier,
                    status=SeatStatus.AVAILABLE
                )
                seats_for_flight.append(seat)
                total_seats += 1
        
        db.add_all(seats_for_flight)
    
    db.commit()
    print(f"   ✓ {total_seats} seats created")
    
    # ============ CREATE ANNOUNCEMENTS ============
    print("\n📢 Creating announcements...")
    
    announcements_data = [
        {
            "title": "Welcome to AirAsia Central",
            "message": "Thank you for choosing our airline. Complete your profile to start booking flights!"
        },
        {
            "title": "Online Check-in Available",
            "message": "Check in online from 24 hours to 1 hour before your flight departure. Save time at the airport!"
        },
        {
            "title": "Baggage Allowance",
            "message": "Economy: 1 carry-on (7kg) + 1 checked bag (23kg). Business: 2 carry-on + 2 checked bags (32kg each)."
        },
        {
            "title": "New Routes Announced!",
            "message": "We're expanding! New direct flights from Bishkek to Dubai and Istanbul now available."
        },
        {
            "title": "Mobile App Update",
            "message": "Download our updated mobile app for the best booking experience. Now with boarding pass integration!"
        },
        {
            "title": "Winter Schedule 2024",
            "message": "Our winter schedule is now live. Book early for the best prices on holiday travel."
        },
        {
            "title": "Loyalty Program",
            "message": "Join our frequent flyer program and earn miles on every flight. Sign up in the app today!"
        },
    ]
    
    announcements = []
    for announcement_data in announcements_data:
        announcement = Announcement(**announcement_data)
        db.add(announcement)
        announcements.append(announcement)
    
    db.commit()
    print(f"   ✓ {len(announcements)} announcements created")
    
    # ============ SUMMARY ============
    print("\n" + "=" * 50)
    print("✅ DATABASE SEEDED SUCCESSFULLY!")
    print("=" * 50)
    print("\n📊 Summary:")
    print(f"   • {len(passengers) + len(staff_members)} users")
    print(f"   • {len(airports)} airports")
    print(f"   • {len(airplanes)} airplanes")
    print(f"   • {len(flights)} flights")
    print(f"   • {total_seats} seats")
    print(f"   • {len(announcements)} announcements")
    
    print("\n🔑 Test Accounts:")
    print("   Staff:")
    print("     • staff@example.com / password123")
    print("     • admin@airline.com / admin123")
    print("   Passengers:")
    print("     • passenger@example.com / password123")
    print("     • john.doe@email.com / password123")
    print("     • jane.smith@email.com / password123")
    
    print("\n🌍 Featured Routes from Bishkek (FRU):")
    print("   • FRU → ALA (Almaty) - 1h 30m")
    print("   • FRU → NQZ (Astana) - 2h")
    print("   • FRU → TAS (Tashkent) - 1h")
    print("   • FRU → IST (Istanbul) - 5h 30m")
    print("   • FRU → SVO (Moscow) - 4h")
    print("   • FRU → DXB (Dubai) - 4h")
    print("   • FRU → PEK (Beijing) - 4h 30m")


if __name__ == "__main__":
    try:
        seed_database()
    except Exception as e:
        print(f"\n❌ Error seeding database: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()
