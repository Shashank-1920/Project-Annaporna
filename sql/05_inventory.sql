-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Module 5: Inventory and Suppliers
-- Owner: Member 5
-- ========================================================

DROP TABLE IF EXISTS "StockUsage" CASCADE;
DROP TABLE IF EXISTS "PurchaseItem" CASCADE;
DROP TABLE IF EXISTS "Purchase" CASCADE;
DROP TABLE IF EXISTS "Supplier" CASCADE;
DROP TABLE IF EXISTS "InventoryItem" CASCADE;

-- 1. Raw Materials and Inventory Item Table
CREATE TABLE "InventoryItem" (
    inventory_item_id SERIAL PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL UNIQUE,
    unit VARCHAR(20) NOT NULL, -- e.g. 'kg', 'liter', 'packet', 'dozen'
    current_stock NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (current_stock >= 0),
    reorder_level NUMERIC(10, 2) NOT NULL DEFAULT 10.00 CHECK (reorder_level >= 0),
    unit_cost NUMERIC(8, 2) NOT NULL DEFAULT 0.00 CHECK (unit_cost >= 0),
    is_low_stock BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Supplier Details Table
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

-- 3. Purchase Batch Table (Header)
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

-- 4. Purchase Line Item Table (Resolves M:N between Purchase & InventoryItem)
CREATE TABLE "PurchaseItem" (
    purchase_item_id SERIAL PRIMARY KEY,
    purchase_id INT NOT NULL REFERENCES "Purchase"(purchase_id) ON DELETE CASCADE,
    inventory_item_id INT NOT NULL REFERENCES "InventoryItem"(inventory_item_id) ON DELETE RESTRICT,
    quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(8, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT uq_purchase_inv_item UNIQUE (purchase_id, inventory_item_id)
);

-- 5. Daily Stock Usage & Wastage Table
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

-- Indexes for Module 5
CREATE INDEX idx_inv_low_stock ON "InventoryItem"(is_low_stock);
CREATE INDEX idx_purchase_supplier ON "Purchase"(supplier_id);
CREATE INDEX idx_purchase_date ON "Purchase"(purchase_date);
CREATE INDEX idx_stock_usage_date ON "StockUsage"(usage_date);
