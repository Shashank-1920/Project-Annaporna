-- ====================================================================
-- MESS AND CANTEEN MANAGEMENT SYSTEM - MASTER DATABASE SCHEMA
-- Target Engine: PostgreSQL 14+ / Supabase
-- Team of 6: M1 (Students/Leave), M2 (Attendance), M3 (Billing),
--            M4 (Menu/Orders), M5 (Inventory), M6 (Users/Complaints)
-- ====================================================================

BEGIN;

-- Drop dependent views first
DROP VIEW IF EXISTS v_students_on_leave_today CASCADE;
DROP VIEW IF EXISTS v_daily_plates CASCADE;
DROP VIEW IF EXISTS v_meal_anomalies CASCADE;
DROP VIEW IF EXISTS v_invoice_summary CASCADE;
DROP VIEW IF EXISTS v_daily_canteen_sales CASCADE;
DROP VIEW IF EXISTS v_top_items CASCADE;
DROP VIEW IF EXISTS v_low_stock CASCADE;
DROP VIEW IF EXISTS v_supplier_dues CASCADE;
DROP VIEW IF EXISTS v_meal_ratings CASCADE;
DROP VIEW IF EXISTS v_open_complaints_aging CASCADE;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS "ComplaintUpdate" CASCADE;
DROP TABLE IF EXISTS "Complaint" CASCADE;
DROP TABLE IF EXISTS "Feedback" CASCADE;
DROP TABLE IF EXISTS "AppUser" CASCADE;
DROP TABLE IF EXISTS "StockUsage" CASCADE;
DROP TABLE IF EXISTS "PurchaseItem" CASCADE;
DROP TABLE IF EXISTS "Purchase" CASCADE;
DROP TABLE IF EXISTS "InventoryItem" CASCADE;
DROP TABLE IF EXISTS "Supplier" CASCADE;
DROP TABLE IF EXISTS "OrderItem" CASCADE;
DROP TABLE IF EXISTS "Orders" CASCADE;
DROP TABLE IF EXISTS "MessMenu" CASCADE;
DROP TABLE IF EXISTS "MenuItem" CASCADE;
DROP TABLE IF EXISTS "Category" CASCADE;
DROP TABLE IF EXISTS "CatererPayment" CASCADE;
DROP TABLE IF EXISTS "InvoiceLine" CASCADE;
DROP TABLE IF EXISTS "CatererInvoice" CASCADE;
DROP TABLE IF EXISTS "MealRate" CASCADE;
DROP TABLE IF EXISTS "MealAttendance" CASCADE;
DROP TABLE IF EXISTS "HostelAttendance" CASCADE;
DROP TABLE IF EXISTS "Staff" CASCADE;
DROP TABLE IF EXISTS "MealSlot" CASCADE;
DROP TABLE IF EXISTS "LeaveRequest" CASCADE;
DROP TABLE IF EXISTS "MessEnrollment" CASCADE;
DROP TABLE IF EXISTS "Student" CASCADE;
DROP TABLE IF EXISTS "Hostel" CASCADE;

-- ====================================================================
-- 1. BASE TABLES
-- ====================================================================

-- 1.1 Hostel (M1)
CREATE TABLE "Hostel" (
    hostel_id SERIAL PRIMARY KEY,
    hostel_name VARCHAR(50) NOT NULL UNIQUE,
    warden_name VARCHAR(100) NOT NULL,
    warden_phone VARCHAR(20),
    total_rooms INT NOT NULL CHECK (total_rooms > 0),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.2 Student (M1)
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

-- 1.3 Mess Enrollment (M1)
CREATE TABLE "MessEnrollment" (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE CASCADE,
    academic_term VARCHAR(20) NOT NULL,
    enrollment_status VARCHAR(20) NOT NULL DEFAULT 'Active' 
        CHECK (enrollment_status IN ('Active', 'Suspended', 'Terminated', 'Completed')),
    enrolled_at DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_student_term UNIQUE (student_id, academic_term)
);

-- 1.4 Leave Request (M1)
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

-- 1.5 Meal Slot (M2)
CREATE TABLE "MealSlot" (
    slot_id SERIAL PRIMARY KEY,
    meal_type VARCHAR(20) NOT NULL UNIQUE 
        CHECK (meal_type IN ('Breakfast', 'Lunch', 'Snacks', 'Dinner')),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    cutoff_time TIME NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 1.6 Staff (M6)
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

-- 1.7 Hostel Attendance (M2)
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

-- 1.8 Meal Attendance (M2)
CREATE TABLE "MealAttendance" (
    meal_att_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE RESTRICT,
    slot_id INT NOT NULL REFERENCES "MealSlot"(slot_id) ON DELETE RESTRICT,
    meal_date DATE NOT NULL DEFAULT CURRENT_DATE,
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    staff_id INT REFERENCES "Staff"(staff_id),
    is_invoiced BOOLEAN NOT NULL DEFAULT FALSE,
    invoice_id INT,
    CONSTRAINT uq_student_meal_date UNIQUE (student_id, slot_id, meal_date)
);

-- 1.9 Meal Rate (M3)
CREATE TABLE "MealRate" (
    rate_id SERIAL PRIMARY KEY,
    slot_id INT NOT NULL REFERENCES "MealSlot"(slot_id) ON DELETE RESTRICT,
    rate_per_plate NUMERIC(8, 2) NOT NULL CHECK (rate_per_plate > 0),
    effective_from DATE NOT NULL,
    effective_to DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rate_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

-- 1.10 Caterer Invoice Header (M3)
CREATE TABLE "CatererInvoice" (
    invoice_id SERIAL PRIMARY KEY,
    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    total_plates INT NOT NULL DEFAULT 0 CHECK (total_plates >= 0),
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'Generated' 
        CHECK (status IN ('Generated', 'Verified', 'Approved', 'Paid')),
    generated_by VARCHAR(100) NOT NULL,
    generated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    verified_by VARCHAR(100),
    verified_at TIMESTAMPTZ,
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    remarks TEXT,
    CONSTRAINT chk_period_dates CHECK (billing_period_end >= billing_period_start)
);

-- 1.11 Invoice Line Items (M3)
CREATE TABLE "InvoiceLine" (
    line_id SERIAL PRIMARY KEY,
    invoice_id INT NOT NULL REFERENCES "CatererInvoice"(invoice_id) ON DELETE CASCADE,
    slot_id INT NOT NULL REFERENCES "MealSlot"(slot_id) ON DELETE RESTRICT,
    plate_count INT NOT NULL CHECK (plate_count >= 0),
    rate_applied NUMERIC(8, 2) NOT NULL CHECK (rate_applied > 0),
    line_total NUMERIC(10, 2) NOT NULL CHECK (line_total >= 0),
    CONSTRAINT uq_invoice_slot UNIQUE (invoice_id, slot_id)
);

-- 1.12 Caterer Payment (M3)
CREATE TABLE "CatererPayment" (
    payment_id SERIAL PRIMARY KEY,
    invoice_id INT NOT NULL REFERENCES "CatererInvoice"(invoice_id) ON DELETE RESTRICT,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount_paid NUMERIC(12, 2) NOT NULL CHECK (amount_paid > 0),
    payment_mode VARCHAR(30) NOT NULL CHECK (payment_mode IN ('Bank Transfer', 'NEFT', 'RTGS', 'Cheque')),
    transaction_ref VARCHAR(100) NOT NULL UNIQUE,
    paid_by VARCHAR(100) NOT NULL,
    payment_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.13 Canteen Category (M4)
CREATE TABLE "Category" (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 1.14 Canteen Menu Item (M4)
CREATE TABLE "MenuItem" (
    item_id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES "Category"(category_id) ON DELETE RESTRICT,
    item_name VARCHAR(100) NOT NULL,
    description TEXT,
    price NUMERIC(8, 2) NOT NULL CHECK (price >= 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.15 Mess Weekly Menu (M4)
CREATE TABLE "MessMenu" (
    menu_id SERIAL PRIMARY KEY,
    slot_id INT NOT NULL REFERENCES "MealSlot"(slot_id) ON DELETE RESTRICT,
    day_of_week VARCHAR(15) NOT NULL 
        CHECK (day_of_week IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')),
    menu_items TEXT NOT NULL,
    special_notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_day_slot UNIQUE (day_of_week, slot_id)
);

-- 1.16 Canteen Orders Header (M4)
CREATE TABLE "Orders" (
    order_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES "Student"(student_id) ON DELETE RESTRICT,
    order_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
    payment_mode VARCHAR(20) NOT NULL 
        CHECK (payment_mode IN ('Cash', 'UPI', 'Wallet')),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'Pending' 
        CHECK (payment_status IN ('Pending', 'Completed', 'Failed', 'Refunded')),
    order_status VARCHAR(20) NOT NULL DEFAULT 'Received' 
        CHECK (order_status IN ('Received', 'Preparing', 'Ready', 'Collected', 'Cancelled'))
);

-- 1.17 Canteen Order Line Items (M4)
CREATE TABLE "OrderItem" (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES "Orders"(order_id) ON DELETE CASCADE,
    item_id INT NOT NULL REFERENCES "MenuItem"(item_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(8, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT uq_order_item UNIQUE (order_id, item_id)
);

-- 1.18 Supplier (M5)
CREATE TABLE "Supplier" (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL UNIQUE,
    contact_person VARCHAR(100),
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    address TEXT,
    outstanding_dues NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (outstanding_dues >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.19 Inventory Item (M5)
CREATE TABLE "InventoryItem" (
    inventory_item_id SERIAL PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL UNIQUE,
    unit VARCHAR(20) NOT NULL,
    current_stock NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (current_stock >= 0),
    reorder_level NUMERIC(10, 2) NOT NULL DEFAULT 10.00 CHECK (reorder_level >= 0),
    unit_cost NUMERIC(8, 2) NOT NULL DEFAULT 0.00 CHECK (unit_cost >= 0),
    is_low_stock BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.20 Purchase Batch Header (M5)
CREATE TABLE "Purchase" (
    purchase_id SERIAL PRIMARY KEY,
    supplier_id INT NOT NULL REFERENCES "Supplier"(supplier_id) ON DELETE RESTRICT,
    purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
    supplier_bill_number VARCHAR(50),
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
    amount_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (amount_paid >= 0),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'Unpaid' 
        CHECK (payment_status IN ('Unpaid', 'Partially Paid', 'Paid')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.21 Purchase Line Item (M5)
CREATE TABLE "PurchaseItem" (
    purchase_item_id SERIAL PRIMARY KEY,
    purchase_id INT NOT NULL REFERENCES "Purchase"(purchase_id) ON DELETE CASCADE,
    inventory_item_id INT NOT NULL REFERENCES "InventoryItem"(inventory_item_id) ON DELETE RESTRICT,
    quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(8, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT uq_purchase_inv_item UNIQUE (purchase_id, inventory_item_id)
);

-- 1.22 Stock Usage and Wastage (M5)
CREATE TABLE "StockUsage" (
    usage_id SERIAL PRIMARY KEY,
    inventory_item_id INT NOT NULL REFERENCES "InventoryItem"(inventory_item_id) ON DELETE RESTRICT,
    usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
    quantity_used NUMERIC(10, 2) NOT NULL CHECK (quantity_used >= 0),
    quantity_wasted NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (quantity_wasted >= 0),
    slot_id INT REFERENCES "MealSlot"(slot_id),
    recorded_by VARCHAR(100) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.23 AppUser (M6)
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

-- 1.24 Feedback (M6)
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

-- 1.25 Complaint (M6)
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

-- 1.26 ComplaintUpdate (M6 Audit Log)
CREATE TABLE "ComplaintUpdate" (
    update_id SERIAL PRIMARY KEY,
    complaint_id INT NOT NULL REFERENCES "Complaint"(complaint_id) ON DELETE CASCADE,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    updated_by_user_id INT REFERENCES "AppUser"(user_id),
    action_note TEXT,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================
-- 2. INDEXES
-- ====================================================================
CREATE INDEX idx_student_roll ON "Student"(roll_number);
CREATE INDEX idx_student_hostel ON "Student"(hostel_id);
CREATE INDEX idx_leave_student_dates ON "LeaveRequest"(student_id, start_date, end_date);
CREATE INDEX idx_leave_status ON "LeaveRequest"(status);
CREATE INDEX idx_meal_att_date_slot ON "MealAttendance"(meal_date, slot_id);
CREATE INDEX idx_meal_att_student ON "MealAttendance"(student_id);
CREATE INDEX idx_hostel_att_date ON "HostelAttendance"(attendance_date);
CREATE INDEX idx_invoice_period ON "CatererInvoice"(billing_period_start, billing_period_end);
CREATE INDEX idx_invoice_status ON "CatererInvoice"(status);
CREATE INDEX idx_meal_rate_temporal ON "MealRate"(slot_id, effective_from, effective_to);
CREATE INDEX idx_orders_student ON "Orders"(student_id);
CREATE INDEX idx_orders_date ON "Orders"(order_date);
CREATE INDEX idx_orders_status ON "Orders"(order_status);
CREATE INDEX idx_orderitem_order ON "OrderItem"(order_id);
CREATE INDEX idx_inv_low_stock ON "InventoryItem"(is_low_stock);
CREATE INDEX idx_purchase_supplier ON "Purchase"(supplier_id);
CREATE INDEX idx_purchase_date ON "Purchase"(purchase_date);
CREATE INDEX idx_stock_usage_date ON "StockUsage"(usage_date);
CREATE INDEX idx_feedback_date_slot ON "Feedback"(meal_date, slot_id);
CREATE INDEX idx_complaint_status ON "Complaint"(status);
CREATE INDEX idx_complaint_student ON "Complaint"(student_id);
CREATE INDEX idx_complaint_update_comp ON "ComplaintUpdate"(complaint_id);

COMMIT;
