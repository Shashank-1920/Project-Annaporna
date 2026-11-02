-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Module 7: Core Views Across All Modules
-- ========================================================

-- M1 View: Students on approved leave today
CREATE OR REPLACE VIEW v_students_on_leave_today AS
SELECT 
    s.student_id,
    s.roll_number,
    s.first_name || ' ' || s.last_name AS student_name,
    h.hostel_name,
    s.room_number,
    lr.leave_id,
    lr.start_date,
    lr.end_date,
    lr.reason,
    lr.approved_by
FROM "LeaveRequest" lr
JOIN "Student" s ON lr.student_id = s.student_id
JOIN "Hostel" h ON s.hostel_id = h.hostel_id
WHERE lr.status = 'Approved'
  AND CURRENT_DATE BETWEEN lr.start_date AND lr.end_date;

-- M2 View: Daily plates served per meal slot
CREATE OR REPLACE VIEW v_daily_plates AS
SELECT 
    ma.meal_date,
    ms.slot_id,
    ms.meal_type,
    COUNT(ma.meal_att_id) AS plates_served
FROM "MealAttendance" ma
JOIN "MealSlot" ms ON ma.slot_id = ms.slot_id
GROUP BY ma.meal_date, ms.slot_id, ms.meal_type
ORDER BY ma.meal_date DESC, ms.slot_id;

-- M2 View: Meal Anomalies (Eaten while on leave OR eaten with no hostel night record)
CREATE OR REPLACE VIEW v_meal_anomalies AS
SELECT 
    ma.meal_att_id,
    ma.meal_date,
    ms.meal_type,
    s.student_id,
    s.roll_number,
    s.first_name || ' ' || s.last_name AS student_name,
    h.hostel_name,
    CASE 
        WHEN lr.leave_id IS NOT NULL THEN 'Ate while on approved leave'
        WHEN ha.hostel_att_id IS NULL THEN 'No hostel night attendance recorded'
        WHEN ha.status <> 'Present' THEN 'Marked absent in hostel but marked for meal'
        ELSE 'Unspecified Anomaly'
    END AS anomaly_type,
    ma.scanned_at
FROM "MealAttendance" ma
JOIN "Student" s ON ma.student_id = s.student_id
JOIN "Hostel" h ON s.hostel_id = h.hostel_id
JOIN "MealSlot" ms ON ma.slot_id = ms.slot_id
LEFT JOIN "LeaveRequest" lr 
    ON lr.student_id = ma.student_id 
    AND lr.status = 'Approved' 
    AND ma.meal_date BETWEEN lr.start_date AND lr.end_date
LEFT JOIN "HostelAttendance" ha 
    ON ha.student_id = ma.student_id 
    AND ha.attendance_date = ma.meal_date
WHERE lr.leave_id IS NOT NULL 
   OR ha.hostel_att_id IS NULL 
   OR ha.status <> 'Present';

-- M3 View: Caterer Invoice Summary
CREATE OR REPLACE VIEW v_invoice_summary AS
SELECT 
    ci.invoice_id,
    ci.invoice_number,
    ci.billing_period_start,
    ci.billing_period_end,
    ci.total_plates,
    ci.total_amount,
    ci.status,
    ci.generated_by,
    ci.generated_at,
    ci.verified_by,
    ci.approved_by,
    COALESCE(SUM(cp.amount_paid), 0.00) AS total_paid,
    (ci.total_amount - COALESCE(SUM(cp.amount_paid), 0.00)) AS balance_payable
FROM "CatererInvoice" ci
LEFT JOIN "CatererPayment" cp ON ci.invoice_id = cp.invoice_id
GROUP BY ci.invoice_id, ci.invoice_number, ci.billing_period_start, ci.billing_period_end, 
         ci.total_plates, ci.total_amount, ci.status, ci.generated_by, ci.generated_at, 
         ci.verified_by, ci.approved_by;

-- M4 View: Daily Canteen Sales
CREATE OR REPLACE VIEW v_daily_canteen_sales AS
SELECT 
    DATE(o.order_date) AS sales_date,
    COUNT(o.order_id) AS total_orders,
    SUM(o.total_amount) AS gross_sales,
    SUM(CASE WHEN o.payment_mode = 'UPI' THEN o.total_amount ELSE 0 END) AS upi_sales,
    SUM(CASE WHEN o.payment_mode = 'Cash' THEN o.total_amount ELSE 0 END) AS cash_sales,
    SUM(CASE WHEN o.payment_mode = 'Wallet' THEN o.total_amount ELSE 0 END) AS wallet_sales
FROM "Orders" o
WHERE o.order_status <> 'Cancelled'
GROUP BY DATE(o.order_date)
ORDER BY sales_date DESC;

-- M4 View: Top Selling Canteen Items
CREATE OR REPLACE VIEW v_top_items AS
SELECT 
    mi.item_id,
    mi.item_name,
    c.category_name,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.subtotal) AS total_revenue
FROM "OrderItem" oi
JOIN "MenuItem" mi ON oi.item_id = mi.item_id
JOIN "Category" c ON mi.category_id = c.category_id
JOIN "Orders" o ON oi.order_id = o.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY mi.item_id, mi.item_name, c.category_name
ORDER BY total_quantity_sold DESC;

-- M5 View: Low Stock Alerts
CREATE OR REPLACE VIEW v_low_stock AS
SELECT 
    inventory_item_id,
    item_name,
    unit,
    current_stock,
    reorder_level,
    unit_cost,
    (reorder_level - current_stock) AS shortage_qty,
    ((reorder_level - current_stock) * unit_cost) AS estimated_restock_cost
FROM "InventoryItem"
WHERE current_stock <= reorder_level
ORDER BY shortage_qty DESC;

-- M5 View: Supplier Outstanding Dues
CREATE OR REPLACE VIEW v_supplier_dues AS
SELECT 
    s.supplier_id,
    s.supplier_name,
    s.contact_person,
    s.phone,
    COUNT(p.purchase_id) AS total_purchases,
    SUM(p.total_amount) AS total_purchase_amount,
    SUM(p.amount_paid) AS total_amount_paid,
    SUM(p.total_amount - p.amount_paid) AS net_dues
FROM "Supplier" s
LEFT JOIN "Purchase" p ON s.supplier_id = p.supplier_id
GROUP BY s.supplier_id, s.supplier_name, s.contact_person, s.phone
ORDER BY net_dues DESC;

-- M6 View: Average Meal Ratings per Meal Type
CREATE OR REPLACE VIEW v_meal_ratings AS
SELECT 
    ms.meal_type,
    f.meal_date,
    COUNT(f.feedback_id) AS total_reviews,
    ROUND(AVG(f.rating), 2) AS avg_overall_rating,
    ROUND(AVG(f.taste_rating), 2) AS avg_taste_rating,
    ROUND(AVG(f.hygiene_rating), 2) AS avg_hygiene_rating
FROM "Feedback" f
JOIN "MealSlot" ms ON f.slot_id = ms.slot_id
GROUP BY ms.meal_type, f.meal_date
ORDER BY f.meal_date DESC, ms.meal_type;

-- M6 View: Open Complaints Aging (unresolved tracking)
CREATE OR REPLACE VIEW v_open_complaints_aging AS
SELECT 
    c.complaint_id,
    c.student_id,
    s.roll_number,
    s.first_name || ' ' || s.last_name AS student_name,
    c.category,
    c.subject,
    c.status,
    c.created_at,
    CURRENT_DATE - DATE(c.created_at) AS days_open,
    c.assigned_to_staff_id,
    st.first_name || ' ' || st.last_name AS assigned_staff_name
FROM "Complaint" c
JOIN "Student" s ON c.student_id = s.student_id
LEFT JOIN "Staff" st ON c.assigned_to_staff_id = st.staff_id
WHERE c.status NOT IN ('Resolved', 'Rejected')
ORDER BY days_open DESC;
