-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Module 1: Students, Enrollment and Leave
-- Owner: Member 1
-- ========================================================

-- Drop existing tables if re-running
DROP TABLE IF EXISTS "LeaveRequest" CASCADE;
DROP TABLE IF EXISTS "MessEnrollment" CASCADE;
DROP TABLE IF EXISTS "Student" CASCADE;
DROP TABLE IF EXISTS "Hostel" CASCADE;

-- 1. Hostel Table
CREATE TABLE "Hostel" (
    hostel_id SERIAL PRIMARY KEY,
    hostel_name VARCHAR(50) NOT NULL UNIQUE,
    warden_name VARCHAR(100) NOT NULL,
    warden_phone VARCHAR(20),
    total_rooms INT NOT NULL CHECK (total_rooms > 0),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Student Table
CREATE TABLE "Student" (
    student_id SERIAL PRIMARY KEY,
    roll_number VARCHAR(30) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    hostel_id INT NOT NULL REFERENCES "Hostel"(hostel_id) ON DELETE RESTRICT,
    room_number VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Mess Enrollment Table
CREATE TABLE "MessEnrollment" (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE CASCADE,
    academic_term VARCHAR(20) NOT NULL, -- e.g. 'Fall 2026', 'Spring 2026'
    enrollment_status VARCHAR(20) NOT NULL DEFAULT 'Active' 
        CHECK (enrollment_status IN ('Active', 'Suspended', 'Terminated', 'Completed')),
    enrolled_at DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_student_term UNIQUE (student_id, academic_term)
);

-- 4. Leave Request Table
CREATE TABLE "LeaveRequest" (
    leave_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending' 
        CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Cancelled')),
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_leave_dates CHECK (end_date >= start_date)
);

-- Indexes for Module 1
CREATE INDEX idx_student_roll ON "Student"(roll_number);
CREATE INDEX idx_student_hostel ON "Student"(hostel_id);
CREATE INDEX idx_leave_student_dates ON "LeaveRequest"(student_id, start_date, end_date);
CREATE INDEX idx_leave_status ON "LeaveRequest"(status);
