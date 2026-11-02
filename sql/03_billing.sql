-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Module 3: Caterer Billing and Payments
-- Owner: Member 3
-- ========================================================

DROP TABLE IF EXISTS "CatererPayment" CASCADE;
DROP TABLE IF EXISTS "InvoiceLine" CASCADE;
DROP TABLE IF EXISTS "CatererInvoice" CASCADE;
DROP TABLE IF EXISTS "MealRate" CASCADE;

-- 1. Temporal Meal Rate Table
CREATE TABLE "MealRate" (
    rate_id SERIAL PRIMARY KEY,
    slot_id INT NOT NULL REFERENCES "MealSlot"(slot_id) ON DELETE RESTRICT,
    rate_per_plate NUMERIC(8, 2) NOT NULL CHECK (rate_per_plate > 0),
    effective_from DATE NOT NULL,
    effective_to DATE, -- NULL indicates current active rate
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rate_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

-- 2. Caterer Invoice Header Table
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

-- 3. Invoice Line Items (Weak entity resolving 1:N breakdown per meal type)
CREATE TABLE "InvoiceLine" (
    line_id SERIAL PRIMARY KEY,
    invoice_id INT NOT NULL REFERENCES "CatererInvoice"(invoice_id) ON DELETE CASCADE,
    slot_id INT NOT NULL REFERENCES "MealSlot"(slot_id) ON DELETE RESTRICT,
    plate_count INT NOT NULL CHECK (plate_count >= 0),
    rate_applied NUMERIC(8, 2) NOT NULL CHECK (rate_applied > 0),
    line_total NUMERIC(10, 2) NOT NULL CHECK (line_total >= 0),
    CONSTRAINT uq_invoice_slot UNIQUE (invoice_id, slot_id)
);

-- 4. Caterer Payment Record Table
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

-- Indexes for Module 3
CREATE INDEX idx_invoice_period ON "CatererInvoice"(billing_period_start, billing_period_end);
CREATE INDEX idx_invoice_status ON "CatererInvoice"(status);
CREATE INDEX idx_meal_rate_temporal ON "MealRate"(slot_id, effective_from, effective_to);
