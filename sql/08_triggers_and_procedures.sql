-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Module 8: Triggers and Stored Procedures (M1 to M6)
-- ========================================================

-- ========================================================
-- MODULE 1: Students and Leave
-- ========================================================

-- Trigger 1: trg_leave_overlap (Rejects overlapping leave requests for same student)
CREATE OR REPLACE FUNCTION fn_check_leave_overlap()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM "LeaveRequest"
        WHERE student_id = NEW.student_id
          AND leave_id <> COALESCE(NEW.leave_id, 0)
          AND status IN ('Pending', 'Approved')
          AND (NEW.start_date <= end_date AND NEW.end_date >= start_date)
    ) THEN
        RAISE EXCEPTION 'Student ID % already has an overlapping active or pending leave request for the given dates.', NEW.student_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_leave_overlap ON "LeaveRequest";
CREATE TRIGGER trg_leave_overlap
BEFORE INSERT OR UPDATE ON "LeaveRequest"
FOR EACH ROW EXECUTE FUNCTION fn_check_leave_overlap();

-- Stored Procedure: sp_approve_leave
CREATE OR REPLACE PROCEDURE sp_approve_leave(
    p_leave_id INT,
    p_approver VARCHAR
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM "LeaveRequest" WHERE leave_id = p_leave_id) THEN
        RAISE EXCEPTION 'Leave request ID % does not exist.', p_leave_id;
    END IF;

    UPDATE "LeaveRequest"
    SET status = 'Approved',
        approved_by = p_approver,
        approved_at = CURRENT_TIMESTAMP
    WHERE leave_id = p_leave_id;
END;
$$;


-- ========================================================
-- MODULE 2: Attendance Validation
-- ========================================================

-- Trigger 2: trg_attendance_validate (Blocks cutoff violations and edits to invoiced dates)
CREATE OR REPLACE FUNCTION fn_attendance_validate()
RETURNS TRIGGER AS $$
DECLARE
    v_cutoff TIME;
    v_is_already_invoiced BOOLEAN;
BEGIN
    -- Check if date is already invoiced
    IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
        IF OLD.is_invoiced THEN
            RAISE EXCEPTION 'Cannot modify or delete meal attendance for already invoiced records.';
        END IF;
    END IF;

    -- On INSERT: Check slot cutoff time if marking on current date
    IF TG_OP = 'INSERT' THEN
        SELECT cutoff_time INTO v_cutoff
        FROM "MealSlot"
        WHERE slot_id = NEW.slot_id;

        IF NEW.meal_date = CURRENT_DATE AND CURRENT_TIME > v_cutoff THEN
            RAISE EXCEPTION 'Meal slot cutoff time (%) has passed for this meal.', v_cutoff;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_attendance_validate ON "MealAttendance";
CREATE TRIGGER trg_attendance_validate
BEFORE INSERT OR UPDATE OR DELETE ON "MealAttendance"
FOR EACH ROW EXECUTE FUNCTION fn_attendance_validate();

-- Stored Procedure: sp_mark_attendance
CREATE OR REPLACE PROCEDURE sp_mark_attendance(
    p_student_id INT,
    p_slot_id INT,
    p_staff_id INT
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "MealAttendance" (student_id, slot_id, meal_date, staff_id, scanned_at)
    VALUES (p_student_id, p_slot_id, CURRENT_DATE, p_staff_id, CURRENT_TIMESTAMP);
END;
$$;


-- ========================================================
-- MODULE 3: Caterer Billing and Payments
-- ========================================================

-- Trigger 3: trg_invoice_status (Enforces Generated -> Verified -> Approved -> Paid)
CREATE OR REPLACE FUNCTION fn_invoice_status_order()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status <> NEW.status THEN
        IF OLD.status = 'Generated' AND NEW.status NOT IN ('Verified', 'Generated') THEN
            RAISE EXCEPTION 'Invalid status transition from Generated to % (Expected Verified)', NEW.status;
        ELSIF OLD.status = 'Verified' AND NEW.status NOT IN ('Approved', 'Generated') THEN
            RAISE EXCEPTION 'Invalid status transition from Verified to % (Expected Approved)', NEW.status;
        ELSIF OLD.status = 'Approved' AND NEW.status NOT IN ('Paid') THEN
            RAISE EXCEPTION 'Invalid status transition from Approved to % (Expected Paid)', NEW.status;
        ELSIF OLD.status = 'Paid' THEN
            RAISE EXCEPTION 'Cannot alter an invoice that is already Paid.';
        END IF;

        IF NEW.status = 'Verified' THEN
            NEW.verified_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'Approved' THEN
            NEW.approved_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'Paid' THEN
            NEW.paid_at = CURRENT_TIMESTAMP;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_invoice_status ON "CatererInvoice";
CREATE TRIGGER trg_invoice_status
BEFORE UPDATE ON "CatererInvoice"
FOR EACH ROW EXECUTE FUNCTION fn_invoice_status_order();

-- Stored Procedure: sp_generate_invoice
CREATE OR REPLACE PROCEDURE sp_generate_invoice(
    p_start_date DATE,
    p_end_date DATE,
    p_generated_by VARCHAR,
    INOUT p_invoice_id INT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_inv_number VARCHAR(50);
    v_total_plates INT := 0;
    v_grand_total NUMERIC(12,2) := 0.00;
    rec RECORD;
    v_rate NUMERIC(8,2);
    v_line_total NUMERIC(10,2);
BEGIN
    -- Check overlap with existing invoices
    IF EXISTS (
        SELECT 1 FROM "CatererInvoice"
        WHERE (p_start_date <= billing_period_end AND p_end_date >= billing_period_start)
    ) THEN
        RAISE EXCEPTION 'An invoice already exists overlapping the period % to %', p_start_date, p_end_date;
    END IF;

    -- Generate unique invoice number
    v_inv_number := 'INV-' || TO_CHAR(p_start_date, 'YYYYMMDD') || '-' || TO_CHAR(p_end_date, 'YYYYMMDD');

    -- Insert invoice header
    INSERT INTO "CatererInvoice" (
        invoice_number, billing_period_start, billing_period_end, total_plates, total_amount, status, generated_by
    ) VALUES (
        v_inv_number, p_start_date, p_end_date, 0, 0.00, 'Generated', p_generated_by
    ) RETURNING invoice_id INTO p_invoice_id;

    -- Loop through each meal slot to calculate plates and cost based on temporal rates
    FOR rec IN (
        SELECT 
            ma.slot_id, 
            COUNT(ma.meal_att_id) AS slot_plates
        FROM "MealAttendance" ma
        WHERE ma.meal_date BETWEEN p_start_date AND p_end_date
          AND ma.is_invoiced = FALSE
        GROUP BY ma.slot_id
    ) LOOP
        -- Lookup active rate for slot
        SELECT rate_per_plate INTO v_rate
        FROM "MealRate"
        WHERE slot_id = rec.slot_id
          AND p_end_date >= effective_from
          AND (effective_to IS NULL OR p_start_date <= effective_to)
        ORDER BY effective_from DESC
        LIMIT 1;

        IF v_rate IS NULL THEN
            v_rate := 50.00; -- Fallback default rate
        END IF;

        v_line_total := rec.slot_plates * v_rate;
        v_total_plates := v_total_plates + rec.slot_plates;
        v_grand_total := v_grand_total + v_line_total;

        -- Insert line item
        INSERT INTO "InvoiceLine" (invoice_id, slot_id, plate_count, rate_applied, line_total)
        VALUES (p_invoice_id, rec.slot_id, rec.slot_plates, v_rate, v_line_total);
    END LOOP;

    -- Update header totals
    UPDATE "CatererInvoice"
    SET total_plates = v_total_plates,
        total_amount = v_grand_total
    WHERE invoice_id = p_invoice_id;

    -- Mark records as invoiced
    UPDATE "MealAttendance"
    SET is_invoiced = TRUE,
        invoice_id = p_invoice_id
    WHERE meal_date BETWEEN p_start_date AND p_end_date
      AND is_invoiced = FALSE;
END;
$$;


-- ========================================================
-- MODULE 4: Menu and Canteen Orders
-- ========================================================

-- Trigger 4a: trg_orderitem_price (Copies price into OrderItem from MenuItem)
CREATE OR REPLACE FUNCTION fn_orderitem_price()
RETURNS TRIGGER AS $$
DECLARE
    v_item_price NUMERIC(8,2);
    v_is_avail BOOLEAN;
BEGIN
    SELECT price, is_available INTO v_item_price, v_is_avail
    FROM "MenuItem"
    WHERE item_id = NEW.item_id;

    IF NOT v_is_avail THEN
        RAISE EXCEPTION 'Item ID % is currently unavailable for order.', NEW.item_id;
    END IF;

    NEW.unit_price := v_item_price;
    NEW.subtotal := NEW.unit_price * NEW.quantity;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orderitem_price ON "OrderItem";
CREATE TRIGGER trg_orderitem_price
BEFORE INSERT OR UPDATE ON "OrderItem"
FOR EACH ROW EXECUTE FUNCTION fn_orderitem_price();

-- Trigger 4b: trg_order_total (Calculates and maintains Orders.total_amount)
CREATE OR REPLACE FUNCTION fn_recalc_order_total()
RETURNS TRIGGER AS $$
DECLARE
    v_order_id INT;
    v_total NUMERIC(10,2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_order_id := OLD.order_id;
    ELSE
        v_order_id := NEW.order_id;
    END IF;

    SELECT COALESCE(SUM(subtotal), 0.00) INTO v_total
    FROM "OrderItem"
    WHERE order_id = v_order_id;

    UPDATE "Orders"
    SET total_amount = v_total
    WHERE order_id = v_order_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_total ON "OrderItem";
CREATE TRIGGER trg_order_total
AFTER INSERT OR UPDATE OR DELETE ON "OrderItem"
FOR EACH ROW EXECUTE FUNCTION fn_recalc_order_total();


-- ========================================================
-- MODULE 5: Inventory and Suppliers
-- ========================================================

-- Trigger 5a: trg_stock_on_purchase (Increases stock and recalculates low-stock)
CREATE OR REPLACE FUNCTION fn_stock_on_purchase()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "InventoryItem"
    SET current_stock = current_stock + NEW.quantity,
        is_low_stock = ((current_stock + NEW.quantity) <= reorder_level),
        updated_at = CURRENT_TIMESTAMP
    WHERE inventory_item_id = NEW.inventory_item_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stock_on_purchase ON "PurchaseItem";
CREATE TRIGGER trg_stock_on_purchase
AFTER INSERT ON "PurchaseItem"
FOR EACH ROW EXECUTE FUNCTION fn_stock_on_purchase();

-- Trigger 5b: trg_stock_on_usage (Deducts stock, forbids negative stock, flags reorder)
CREATE OR REPLACE FUNCTION fn_stock_on_usage()
RETURNS TRIGGER AS $$
DECLARE
    v_stock NUMERIC(10,2);
    v_reorder NUMERIC(10,2);
    v_total_deduct NUMERIC(10,2);
BEGIN
    v_total_deduct := NEW.quantity_used + NEW.quantity_wasted;

    SELECT current_stock, reorder_level INTO v_stock, v_reorder
    FROM "InventoryItem"
    WHERE inventory_item_id = NEW.inventory_item_id
    FOR UPDATE;

    IF (v_stock - v_total_deduct) < 0 THEN
        RAISE EXCEPTION 'Insufficient stock for Item ID %. Current: %, Requested: %', 
            NEW.inventory_item_id, v_stock, v_total_deduct;
    END IF;

    UPDATE "InventoryItem"
    SET current_stock = current_stock - v_total_deduct,
        is_low_stock = ((current_stock - v_total_deduct) <= reorder_level),
        updated_at = CURRENT_TIMESTAMP
    WHERE inventory_item_id = NEW.inventory_item_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stock_on_usage ON "StockUsage";
CREATE TRIGGER trg_stock_on_usage
BEFORE INSERT ON "StockUsage"
FOR EACH ROW EXECUTE FUNCTION fn_stock_on_usage();


-- ========================================================
-- MODULE 6: Feedback, Complaints and Audit Log
-- ========================================================

-- Trigger 6: trg_complaint_log (Writes every status change into ComplaintUpdate)
CREATE OR REPLACE FUNCTION fn_complaint_log()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO "ComplaintUpdate" (complaint_id, old_status, new_status, action_note)
        VALUES (NEW.complaint_id, NULL, NEW.status, 'Complaint created');
    ELSIF TG_OP = 'UPDATE' AND OLD.status <> NEW.status THEN
        INSERT INTO "ComplaintUpdate" (complaint_id, old_status, new_status, action_note)
        VALUES (NEW.complaint_id, OLD.status, NEW.status, COALESCE(NEW.resolution_note, 'Status changed to ' || NEW.status));
        
        IF NEW.status = 'Resolved' THEN
            NEW.resolved_at = CURRENT_TIMESTAMP;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_complaint_log ON "Complaint";
CREATE TRIGGER trg_complaint_log
BEFORE INSERT OR UPDATE ON "Complaint"
FOR EACH ROW EXECUTE FUNCTION fn_complaint_log();

-- Stored Procedure: sp_resolve_complaint
CREATE OR REPLACE PROCEDURE sp_resolve_complaint(
    p_complaint_id INT,
    p_staff_id INT,
    p_note TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE "Complaint"
    SET status = 'Resolved',
        assigned_to_staff_id = p_staff_id,
        resolution_note = p_note,
        resolved_at = CURRENT_TIMESTAMP
    WHERE complaint_id = p_complaint_id;
END;
$$;
