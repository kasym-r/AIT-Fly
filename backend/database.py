"""
Database Configuration
======================
This file sets up the SQLite database connection using SQLAlchemy.
SQLite is perfect for learning - it's a file-based database, no server needed.
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# SQLite database file will be created in the backend folder
# This is a simple file-based database - perfect for learning
SQLALCHEMY_DATABASE_URL = "sqlite:///./airline.db"

# Create the database engine
# connect_args={"check_same_thread": False} is needed for SQLite with FastAPI
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    connect_args={"check_same_thread": False}
)

# SessionLocal is a factory for creating database sessions
# Each request will get its own session
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for all our database models
# All models will inherit from this
Base = declarative_base()


def get_db():
    """
    Dependency function for FastAPI routes.
    This creates a database session, yields it to the route, then closes it.
    This ensures the database connection is properly closed after each request.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()



