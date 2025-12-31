# Airline Booking & Operations System

A complete, beginner-friendly airline booking system built with **FastAPI** (backend) and **Flutter** (mobile app).

## 📁 Project Structure

```
airlines/
├── backend/          # FastAPI backend server
│   ├── main.py       # API endpoints
│   ├── database.py   # Database setup
│   ├── models.py     # Database models
│   ├── schemas.py    # API schemas
│   ├── auth.py       # Authentication
│   ├── seed.py       # Sample data
│   └── README.md     # Backend documentation
│
└── mobile/           # Flutter mobile app
    ├── lib/
    │   ├── main.dart
    │   ├── models.dart
    │   ├── api_service.dart
    │   └── screens/   # All app screens
    └── README.md     # Mobile app documentation
```

## 🚀 Quick Start

### 1. Backend Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

The API will be available at: http://127.0.0.1:8000
API Documentation: http://127.0.0.1:8000/docs

**Seed the database:**
```bash
python seed.py
```

### 2. Mobile App Setup

```bash
cd mobile
flutter pub get
```

**Update API URL** in `lib/api_service.dart`:
- Android Emulator: `http://10.0.2.2:8000`
- iOS Simulator: `http://127.0.0.1:8000`
- Physical Device: `http://YOUR_COMPUTER_IP:8000`

**Run the app:**
```bash
flutter run
```

## 📚 Documentation

- **Backend**: See [backend/README.md](backend/README.md)
- **Mobile App**: See [mobile/README.md](mobile/README.md)

## ✨ Features

### Passenger Features
- ✅ User registration and login
- ✅ Flight search (origin, destination, date)
- ✅ Flight details and seat selection
- ✅ Booking creation
- ✅ Mock payment processing
- ✅ Check-in for flights
- ✅ Boarding pass generation
- ✅ View announcements

### Staff Features
- ✅ Create airports and airplanes
- ✅ Create flights
- ✅ Update flight status
- ✅ Create announcements
- ✅ View all bookings

## 🧪 Test Accounts

After running `seed.py`:
- **Passenger**: `passenger@example.com` / `password123`
- **Staff**: `staff@example.com` / `password123`

## 🛠️ Tech Stack

### Backend
- **FastAPI** - Modern Python web framework
- **SQLite** - Simple file-based database
- **SQLAlchemy** - Database ORM
- **JWT** - Authentication tokens
- **Pydantic** - Data validation

### Mobile
- **Flutter** - Cross-platform mobile framework
- **HTTP** - API communication
- **Shared Preferences** - Local storage

## 📖 Learning Path

### For FastAPI Beginners:
1. Start with `database.py` - Understand database setup
2. Read `models.py` - Learn database table structure
3. Check `schemas.py` - See API data formats
4. Explore `main.py` - Understand API endpoints
5. Review `auth.py` - Learn authentication

### For Flutter Beginners:
1. Start with `main.dart` - App entry point
2. Read `models.dart` - Data structures
3. Check `api_service.dart` - API communication
4. Explore `screens/` - UI screens one by one

## 🎯 Key Concepts Explained

### Backend (FastAPI)
- **Models**: Database tables (SQLAlchemy)
- **Schemas**: API request/response formats (Pydantic)
- **Dependencies**: Reusable functions (like `get_current_user`)
- **JWT Tokens**: Secure authentication without storing sessions

### Mobile (Flutter)
- **Widgets**: Everything is a widget (UI components)
- **State**: Data that changes (using `setState`)
- **async/await**: Handle time-consuming operations (API calls)
- **Navigation**: Moving between screens

## 🔧 Common Issues

### Backend won't start
- Check Python version (3.8+)
- Activate virtual environment
- Install dependencies: `pip install -r requirements.txt`

### Mobile app can't connect
- Backend must be running
- Check API URL in `api_service.dart`
- For physical device: Use computer's IP address
- Both devices must be on same network

### Database errors
- Delete `airline.db` and restart server
- Run `seed.py` again

## 📝 Next Steps

1. ✅ Set up backend and run seed script
2. ✅ Set up Flutter app and update API URL
3. ✅ Test login and registration
4. ✅ Search for flights
5. ✅ Complete a booking
6. ✅ Customize UI and add features

## 🎓 Beginner Tips

1. **Read the code comments** - They explain WHY things are done
2. **Test one feature at a time** - Don't try everything at once
3. **Use the API docs** - Visit `/docs` to test endpoints
4. **Check error messages** - They usually tell you what's wrong
5. **Start simple** - Understand basics before adding complexity

## 📄 License

This is an educational project. Feel free to use and modify as needed.

## 🤝 Support

If you get stuck:
1. Check the README files in `backend/` and `mobile/`
2. Review error messages carefully
3. Check that both backend and mobile are running
4. Verify API URL is correct

---

**Happy Learning!** 🚀

This project is designed to be simple and educational. Every file has comments explaining what it does and why. Start with the README files in each folder, then explore the code!



# AIT-airlines
