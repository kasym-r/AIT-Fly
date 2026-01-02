# ✈️ AIT Airlines – Setup Guide

## Step 1: Backend Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python seed.py
uvicorn main:app --reload
```

✅ Backend running at: http://127.0.0.1:8000/docs
✅ Admin panel: http://127.0.0.1:8000/admin

**Keep this terminal open!**

---

## Step 2: Mobile App Setup

Open a **new terminal** window:

```bash
cd mobile
flutter pub get
flutter run
```

✅ App will launch automatically!

---

## 👤 Test Accounts

**Passenger:** `passenger@example.com` / `password123`  
**Admin:** `admin@airline.com` / `admin123`

---

## ⚠️ Important

- Backend must be running before starting the app
- Don't close the backend terminal
- API URL is automatically detected (no configuration needed)

---

## 🐛 Troubleshooting

**Backend won't start?**
- Check Python version: `python3 --version` (need 3.8+)
- Make sure virtual environment is activated

**App won't connect?**
- Make sure backend is running
- Check http://127.0.0.1:8000/docs in browser

**Flutter errors?**
```bash
flutter clean
flutter pub get
flutter run
```
