-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Module 4: Menu and Canteen Orders
-- Owner: Member 4
-- ========================================================

DROP TABLE IF EXISTS "OrderItem" CASCADE;
DROP TABLE IF EXISTS "Orders" CASCADE;
DROP TABLE IF EXISTS "MessMenu" CASCADE;
DROP TABLE IF EXISTS "MenuItem" CASCADE;
DROP TABLE IF EXISTS "Category" CASCADE;

-- 1. Canteen Food Category Table
CREATE TABLE "Category" (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 2. Canteen Menu Item Table
CREATE TABLE "MenuItem" (
    item_id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES "Category"(category_id) ON DELETE RESTRICT,
    item_name VARCHAR(100) NOT NULL,
    description TEXT,
    price NUMERIC(8, 2) NOT NULL CHECK (price >= 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Mess Weekly Menu Table (Fixed routine for hostel mess)
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

-- 4. Canteen Order Header Table
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

-- 5. Order Item Table (Resolves M:N relationship between Orders and MenuItem)
CREATE TABLE "OrderItem" (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES "Orders"(order_id) ON DELETE CASCADE,
    item_id INT NOT NULL REFERENCES "MenuItem"(item_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(8, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT uq_order_item UNIQUE (order_id, item_id)
);

-- Indexes for Module 4
CREATE INDEX idx_orders_student ON "Orders"(student_id);
CREATE INDEX idx_orders_date ON "Orders"(order_date);
CREATE INDEX idx_orders_status ON "Orders"(order_status);
CREATE INDEX idx_orderitem_order ON "OrderItem"(order_id);
