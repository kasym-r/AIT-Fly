# Airline Booking System - Backend

This is the FastAPI backend for the Airline Booking & Operations System.

## What is FastAPI?

FastAPI is a modern Python web framework for building APIs. It's fast, easy to use, and automatically generates API documentation.

## Project Structure

```
backend/
├── main.py          # Main FastAPI application with all API routes
├── database.py      # Database connection setup
├── models.py        # Database table definitions (SQLAlchemy models)
├── schemas.py       # Data validation schemas (Pydantic models)
├── auth.py          # Authentication and authorization logic
├── seed.py          # Script to populate database with sample data
├── requirements.txt # Python dependencies
└── README.md        # This file
```

## Setup Instructions

### 1. Install Python

Make sure you have Python 3.8 or higher installed. Check by running:
```bash
python3 --version
```

### 2. Create Virtual Environment (Recommended)

A virtual environment keeps your project dependencies separate from other projects.

```bash
cd backend
python3 -m venv venv
```

**Activate the virtual environment:**

On macOS/Linux:
```bash
source venv/bin/activate
```

On Windows:
```bash
venv\Scripts\activate
```

You should see `(venv)` in your terminal prompt.

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Run the Application

```bash
uvicorn main:app --reload
```

The `--reload` flag automatically restarts the server when you make code changes.

You should see:
```
INFO:     Uvicorn running on http://127.0.0.1:8000
```

### 5. Access API Documentation

Open your browser and go to:
- **Swagger UI**: http://127.0.0.1:8000/docs
- **ReDoc**: http://127.0.0.1:8000/redoc

The Swagger UI lets you test all API endpoints directly from your browser!

### 6. Seed the Database (Optional)

To populate the database with sample data:

```bash
python seed.py
```

This creates:
- Test users (passenger and staff accounts)
- Sample airports
- Sample airplanes
- Sample flights
- Sample announcements

**Test Accounts:**
- Passenger: `passenger@example.com` / `password123`
- Staff: `staff@example.com` / `password123`

## How It Works

### Database

- **SQLite**: A simple file-based database (no server needed)
- Database file: `airline.db` (created automatically)
- **SQLAlchemy**: Python library for working with databases

### Authentication

- **JWT (JSON Web Token)**: Used for authentication
- When you login, you get a token
- Include this token in the `Authorization` header for protected routes
- Format: `Authorization: Bearer <your-token>`

### API Endpoints

#### Public Endpoints (No authentication required)
- `POST /register` - Register new user
- `POST /login` - Login and get token
- `GET /airports` - Get all airports
- `GET /airplanes` - Get all airplanes
- `GET /flights` - Search flights
- `GET /flights/{id}` - Get flight details
- `GET /flights/{id}/seats` - Get seat map
- `GET /announcements` - Get announcements

#### Passenger Endpoints (Require passenger login)
- `GET /me` - Get current user info
- `POST /passenger/profile` - Create/update profile
- `GET /passenger/profile` - Get profile
- `POST /flights/{id}/seats/{seat_id}/hold` - Hold a seat
- `POST /bookings` - Create booking
- `GET /bookings` - Get my bookings
- `POST /payments` - Process payment
- `POST /check-in` - Check in for flight
- `GET /bookings/{id}/boarding-pass` - Get boarding pass

#### Staff Endpoints (Require staff login)
- `POST /airports` - Create airport
- `POST /airplanes` - Create airplane
- `POST /flights` - Create flight
- `PATCH /flights/{id}/status` - Update flight status
- `POST /announcements` - Create announcement
- `GET /staff/bookings` - Get all bookings

## Testing the API

### Using Swagger UI

1. Go to http://127.0.0.1:8000/docs
2. Click on an endpoint
3. Click "Try it out"
4. Fill in the parameters
5. Click "Execute"
6. See the response

### Using curl (Command Line)

**Register a user:**
```bash
curl -X POST "http://127.0.0.1:8000/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password123", "role": "PASSENGER"}'
```

**Login:**
```bash
curl -X POST "http://127.0.0.1:8000/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password123"}'
```

**Get flights (with token):**
```bash
curl -X GET "http://127.0.0.1:8000/flights" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## Common Issues

### Port Already in Use

If port 8000 is already in use:
```bash
uvicorn main:app --reload --port 8001
```

### Database Errors

If you get database errors:
1. Delete `airline.db` file
2. Restart the server (tables will be recreated)
3. Run `python seed.py` again

### Import Errors

Make sure you're in the `backend` directory and have activated the virtual environment.

## Connecting Flutter App

The Flutter app will connect to:
```
http://127.0.0.1:8000
```

For testing on a physical device:
1. Find your computer's IP address
2. Use that IP instead of 127.0.0.1
3. Make sure both devices are on the same network

## Next Steps

1. Run the backend server
2. Test endpoints using Swagger UI
3. Set up the Flutter app to connect to this API
4. Start building your mobile app!

## Key Concepts Explained

### Models vs Schemas

- **Models** (`models.py`): Define database tables and relationships
- **Schemas** (`schemas.py`): Define what data the API accepts/returns

### Dependencies

- `Depends(get_db)`: Gets a database session
- `Depends(get_current_user)`: Gets the logged-in user
- `Depends(get_current_passenger_user)`: Ensures user is a passenger
- `Depends(get_current_staff_user)`: Ensures user is staff

### Seat Hold Logic

When a user selects a seat:
1. Seat status changes to "HELD"
2. Hold expires in 10 minutes
3. If payment is completed, seat becomes "BOOKED"
4. If payment fails or times out, seat becomes "AVAILABLE" again

This prevents multiple users from booking the same seat simultaneously.



