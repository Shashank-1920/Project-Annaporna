-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Module 6: Users, Feedback, Complaints & Staff
-- Owner: Member 6 (Project Lead)
-- ========================================================

DROP TABLE IF EXISTS "ComplaintUpdate" CASCADE;
DROP TABLE IF EXISTS "Complaint" CASCADE;
DROP TABLE IF EXISTS "Feedback" CASCADE;
DROP TABLE IF EXISTS "AppUser" CASCADE;
DROP TABLE IF EXISTS "Staff" CASCADE;

-- 1. Staff Members Table
CREATE TABLE "Staff" (
    staff_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    role VARCHAR(30) NOT NULL 
        CHECK (role IN ('Caterer', 'Mess Staff', 'Canteen Staff', 'Warden', 'Admin')),
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100) UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Application Users Table (Authentication and Role Mapping)
CREATE TABLE "AppUser" (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL 
        CHECK (role IN ('Student', 'Caterer', 'Staff', 'Warden', 'Admin')),
    student_id INT REFERENCES "Student"(student_id) ON DELETE CASCADE,
    staff_id INT REFERENCES "Staff"(staff_id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_user_profile CHECK (
        (role = 'Student' AND student_id IS NOT NULL AND staff_id IS NULL) OR
        (role <> 'Student' AND staff_id IS NOT NULL AND student_id IS NULL) OR
        (role = 'Admin')
    )
);

-- 3. Student Meal Feedback Table
CREATE TABLE "Feedback" (
    feedback_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE CASCADE,
    slot_id INT NOT NULL REFERENCES "MealSlot"(slot_id) ON DELETE RESTRICT,
    meal_date DATE NOT NULL DEFAULT CURRENT_DATE,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    taste_rating INT CHECK (taste_rating BETWEEN 1 AND 5),
    hygiene_rating INT CHECK (hygiene_rating BETWEEN 1 AND 5),
    comments TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_feedback_meal UNIQUE (student_id, slot_id, meal_date)
);

-- 4. Grievance / Complaint Table
CREATE TABLE "Complaint" (
    complaint_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE CASCADE,
    category VARCHAR(30) NOT NULL 
        CHECK (category IN ('Hygiene', 'Food Quality', 'Staff Behavior', 'Quantity', 'Cleanliness', 'Billing', 'Other')),
    subject VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Submitted' 
        CHECK (status IN ('Submitted', 'Under Review', 'In Progress', 'Resolved', 'Rejected')),
    assigned_to_staff_id INT REFERENCES "Staff"(staff_id),
    resolution_note TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

-- 5. Complaint Audit Trail Table (Tracks full complaint lifecycle)
CREATE TABLE "ComplaintUpdate" (
    update_id SERIAL PRIMARY KEY,
    complaint_id INT NOT NULL REFERENCES "Complaint"(complaint_id) ON DELETE CASCADE,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    updated_by_user_id INT REFERENCES "AppUser"(user_id),
    action_note TEXT,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for Module 6
CREATE INDEX idx_feedback_date_slot ON "Feedback"(meal_date, slot_id);
CREATE INDEX idx_complaint_status ON "Complaint"(status);
CREATE INDEX idx_complaint_student ON "Complaint"(student_id);
CREATE INDEX idx_complaint_update_comp ON "ComplaintUpdate"(complaint_id);
