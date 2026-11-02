import os
import sqlite3
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

def get_db_connection():
    """
    Returns a database connection.
    If DATABASE_URL is configured for PostgreSQL/Supabase and connects successfully,
    it returns a psycopg2 connection with RealDictCursor.
    Otherwise, it transparently provides a local SQLite database with full M1 schema & seed data
    so the entire application remains fully interactive and testable immediately.
    """
    if DATABASE_URL and ("postgres" in DATABASE_URL or "postgresql" in DATABASE_URL) and "your-project-ref" not in DATABASE_URL:
        try:
            conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
            return {"type": "postgres", "conn": conn}
        except Exception as e:
            print(f"[WARN] Failed to connect to PostgreSQL/Supabase ({e}). Using local fallback database.")

    # Local fallback SQLite connection
    db_path = os.path.join(os.path.dirname(__file__), "mess_local.db")
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    init_sqlite_m1(conn)
    return {"type": "sqlite", "conn": conn}

def init_sqlite_m1(conn):
    """Initializes tables and seeds data in fallback SQLite if not already present."""
    cursor = conn.cursor()
    cursor.executescript('''
    CREATE TABLE IF NOT EXISTS Hostel (
        hostel_id INTEGER PRIMARY KEY AUTOINCREMENT,
        hostel_name TEXT UNIQUE NOT NULL,
        warden_name TEXT NOT NULL,
        warden_phone TEXT,
        total_rooms INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS Student (
        student_id INTEGER PRIMARY KEY AUTOINCREMENT,
        roll_number TEXT UNIQUE NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT NOT NULL,
        hostel_id INTEGER NOT NULL REFERENCES Hostel(hostel_id),
        room_number TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS MessEnrollment (
        enrollment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES Student(student_id),
        academic_term TEXT NOT NULL,
        enrollment_status TEXT DEFAULT 'Active',
        enrolled_at DATE DEFAULT CURRENT_DATE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(student_id, academic_term)
    );

    CREATE TABLE IF NOT EXISTS LeaveRequest (
        leave_id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES Student(student_id),
        start_date DATE NOT NULL,
        end_date DATE NOT NULL,
        reason TEXT NOT NULL,
        status TEXT DEFAULT 'Pending',
        approved_by TEXT,
        approved_at DATETIME,
        rejection_reason TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    -- Seed hostels if empty
    INSERT OR IGNORE INTO Hostel (hostel_id, hostel_name, warden_name, warden_phone, total_rooms) VALUES
    (1, 'Cauvery Hostel', 'Dr. Ramesh Kumar', '9876543210', 120),
    (2, 'Ganga Hostel', 'Prof. Sunita Sharma', '9876543211', 150),
    (3, 'Yamuna Hostel', 'Dr. Arvind Verma', '9876543212', 100),
    (4, 'Krishna Hostel', 'Prof. Priya Nair', '9876543213', 130);

    -- Seed students if empty
    INSERT OR IGNORE INTO Student (student_id, roll_number, first_name, last_name, email, phone, hostel_id, room_number) VALUES
    (1, 'CS24B001', 'Aarav', 'Patel', 'aarav.patel@college.edu', '9123456780', 1, 'C-101'),
    (2, 'CS24B002', 'Diya', 'Iyer', 'diya.iyer@college.edu', '9123456781', 2, 'G-204'),
    (3, 'EE24B015', 'Rohan', 'Deshmukh', 'rohan.d@college.edu', '9123456782', 1, 'C-215'),
    (4, 'ME24B030', 'Ananya', 'Sen', 'ananya.sen@college.edu', '9123456783', 3, 'Y-108'),
    (5, 'EC24B045', 'Kabir', 'Reddy', 'kabir.reddy@college.edu', '9123456784', 4, 'K-302'),
    (6, 'CS24B055', 'Isha', 'Mehta', 'isha.mehta@college.edu', '9123456785', 2, 'G-312');

    -- Seed enrollments if empty
    INSERT OR IGNORE INTO MessEnrollment (enrollment_id, student_id, academic_term, enrollment_status) VALUES
    (1, 1, 'Fall 2026', 'Active'),
    (2, 2, 'Fall 2026', 'Active'),
    (3, 3, 'Fall 2026', 'Active'),
    (4, 4, 'Fall 2026', 'Active'),
    (5, 5, 'Fall 2026', 'Active'),
    (6, 6, 'Fall 2026', 'Active');

    -- Seed leave requests
    INSERT OR IGNORE INTO LeaveRequest (leave_id, student_id, start_date, end_date, reason, status, approved_by, approved_at) VALUES
    (1, 2, DATE('now'), DATE('now', '+2 days'), 'Attending cousin wedding in Mumbai', 'Approved', 'Dr. Sunita Sharma', CURRENT_TIMESTAMP),
    (2, 3, DATE('now', '+5 days'), DATE('now', '+7 days'), 'Family emergency', 'Pending', NULL, NULL);
    ''')
    conn.commit()

def execute_query(query, params=None, fetch=True, commit=False):
    """Executes a query across either PostgreSQL/Supabase or SQLite."""
    db = get_db_connection()
    conn = db["conn"]
    db_type = db["type"]

    # Adapt quotes/table names if SQLite
    exec_query = query
    if db_type == "sqlite":
        exec_query = exec_query.replace('"Hostel"', 'Hostel')
        exec_query = exec_query.replace('"Student"', 'Student')
        exec_query = exec_query.replace('"MessEnrollment"', 'MessEnrollment')
        exec_query = exec_query.replace('"LeaveRequest"', 'LeaveRequest')
        exec_query = exec_query.replace('%s', '?')
        exec_query = exec_query.replace('CURRENT_DATE', "DATE('now')")
        exec_query = exec_query.replace("|| ' ' ||", "|| ' ' ||")

    try:
        cursor = conn.cursor()
        cursor.execute(exec_query, params or ())
        
        result = None
        if fetch:
            rows = cursor.fetchall()
            if db_type == "sqlite":
                result = [dict(row) for row in rows]
            else:
                result = [dict(r) for r in rows]

        if commit:
            conn.commit()
            
        cursor.close()
        conn.close()
        return result
    except Exception as e:
        if commit:
            conn.rollback()
        conn.close()
        raise e
