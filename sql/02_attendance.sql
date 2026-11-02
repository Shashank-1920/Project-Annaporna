-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Module 2: Attendance & Anomaly Checks
-- Owner: Member 2
-- ========================================================

DROP TABLE IF EXISTS "MealAttendance" CASCADE;
DROP TABLE IF EXISTS "HostelAttendance" CASCADE;
DROP TABLE IF EXISTS "MealSlot" CASCADE;

-- 1. Meal Slot Table
CREATE TABLE "MealSlot" (
    slot_id SERIAL PRIMARY KEY,
    meal_type VARCHAR(20) NOT NULL UNIQUE 
        CHECK (meal_type IN ('Breakfast', 'Lunch', 'Snacks', 'Dinner')),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    cutoff_time TIME NOT NULL, -- e.g. 30 mins after end_time or specific cutoff
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 2. Hostel Attendance Table (Warden night roll-call)
CREATE TABLE "HostelAttendance" (
    hostel_att_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Present' 
        CHECK (status IN ('Present', 'Absent', 'On Leave')),
    scanned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    recorded_by VARCHAR(100),
    CONSTRAINT uq_hostel_student_date UNIQUE (student_id, attendance_date)
);

-- 3. Mess Meal Attendance Table (Counter scan - basis for billing)
CREATE TABLE "MealAttendance" (
    meal_att_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE RESTRICT,
    slot_id INT NOT NULL REFERENCES "MealSlot"(slot_id) ON DELETE RESTRICT,
    meal_date DATE NOT NULL DEFAULT CURRENT_DATE,
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    staff_id INT, -- Refers to Staff table in M6
    is_invoiced BOOLEAN NOT NULL DEFAULT FALSE,
    invoice_id INT, -- Updated once invoiced in M3
    CONSTRAINT uq_student_meal_date UNIQUE (student_id, slot_id, meal_date)
);

-- Indexes for Module 2
CREATE INDEX idx_meal_att_date_slot ON "MealAttendance"(meal_date, slot_id);
CREATE INDEX idx_meal_att_student ON "MealAttendance"(student_id);
CREATE INDEX idx_hostel_att_date ON "HostelAttendance"(attendance_date);
