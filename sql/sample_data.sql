-- ========================================================
-- Mess and Canteen Management System (PostgreSQL / Supabase)
-- Seed Sample Data for Testing and Verification
-- ========================================================

-- 1. Hostels
INSERT INTO "Hostel" (hostel_name, warden_name, warden_phone, total_rooms) VALUES
('Cauvery Hostel', 'Dr. Ramesh Kumar', '9876543210', 120),
('Ganga Hostel', 'Prof. Sunita Sharma', '9876543211', 150),
('Yamuna Hostel', 'Dr. Arvind Verma', '9876543212', 100),
('Krishna Hostel', 'Prof. Priya Nair', '9876543213', 130)
ON CONFLICT (hostel_name) DO NOTHING;

-- 2. Meal Slots
INSERT INTO "MealSlot" (meal_type, start_time, end_time, cutoff_time) VALUES
('Breakfast', '07:30:00', '09:30:00', '10:00:00'),
('Lunch',     '12:30:00', '14:30:00', '15:00:00'),
('Snacks',    '17:00:00', '18:30:00', '19:00:00'),
('Dinner',    '19:45:00', '21:45:00', '22:15:00')
ON CONFLICT (meal_type) DO NOTHING;

-- 3. Temporal Meal Rates
INSERT INTO "MealRate" (slot_id, rate_per_plate, effective_from, effective_to) VALUES
(1, 35.00, '2026-01-01', NULL),
(2, 65.00, '2026-01-01', NULL),
(3, 25.00, '2026-01-01', NULL),
(4, 70.00, '2026-01-01', NULL);

-- 4. Students
INSERT INTO "Student" (roll_number, first_name, last_name, email, phone, hostel_id, room_number) VALUES
('CS24B001', 'Aarav', 'Patel', 'aarav.patel@college.edu', '9123456780', 1, 'C-101'),
('CS24B002', 'Diya', 'Iyer', 'diya.iyer@college.edu', '9123456781', 2, 'G-204'),
('EE24B015', 'Rohan', 'Deshmukh', 'rohan.d@college.edu', '9123456782', 1, 'C-215'),
('ME24B030', 'Ananya', 'Sen', 'ananya.sen@college.edu', '9123456783', 3, 'Y-108'),
('EC24B045', 'Kabir', 'Reddy', 'kabir.reddy@college.edu', '9123456784', 4, 'K-302'),
('CS24B055', 'Isha', 'Mehta', 'isha.mehta@college.edu', '9123456785', 2, 'G-312')
ON CONFLICT (roll_number) DO NOTHING;

-- 5. Mess Enrollments
INSERT INTO "MessEnrollment" (student_id, academic_term, enrollment_status) VALUES
(1, 'Fall 2026', 'Active'),
(2, 'Fall 2026', 'Active'),
(3, 'Fall 2026', 'Active'),
(4, 'Fall 2026', 'Active'),
(5, 'Fall 2026', 'Active'),
(6, 'Fall 2026', 'Active')
ON CONFLICT DO NOTHING;

-- 6. Leave Requests
INSERT INTO "LeaveRequest" (student_id, start_date, end_date, reason, status, approved_by, approved_at) VALUES
(2, CURRENT_DATE, CURRENT_DATE + INTERVAL '2 days', 'Attending cousin wedding in Mumbai', 'Approved', 'Dr. Sunita Sharma', CURRENT_TIMESTAMP),
(3, CURRENT_DATE + INTERVAL '5 days', CURRENT_DATE + INTERVAL '7 days', 'Family emergency', 'Pending', NULL, NULL);

-- 7. Canteen Categories & Menu Items
INSERT INTO "Category" (category_name, description) VALUES
('Beverages', 'Hot and cold beverages, juices and shakes'),
('Snacks', 'Quick bites, samosas, rolls, and sandwiches'),
('Meals', 'Special fried rice, thalis and parathas'),
('Desserts', 'Ice creams and sweets')
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO "MenuItem" (category_id, item_name, description, price, is_available) VALUES
(1, 'Filter Coffee', 'Hot brewed South Indian filter coffee', 20.00, TRUE),
(1, 'Masala Chai', 'Ginger cardamom hot spiced tea', 15.00, TRUE),
(1, 'Cold Coffee with Ice Cream', 'Thick blended cold coffee topped with vanilla', 50.00, TRUE),
(2, 'Samosa (Pair)', 'Crispy potato stuffed samosas with mint chutney', 25.00, TRUE),
(2, 'Paneer Kathi Roll', 'Whole wheat wrap stuffed with spiced cottage cheese', 60.00, TRUE),
(2, 'Veg Cheese Grilled Sandwich', 'Toasted bread with cheddar and veggies', 55.00, TRUE),
(3, 'Paneer Butter Masala Combo', 'Served with 2 butter naan and salad', 110.00, TRUE),
(3, 'Schezwan Fried Rice', 'Spicy wok tossed Indo-Chinese rice', 80.00, TRUE),
(4, 'Gulab Jamun (2 pcs)', 'Warm milk dumplings in sugar syrup', 35.00, TRUE);

-- 8. Suppliers
INSERT INTO "Supplier" (supplier_name, contact_person, phone, email, address, outstanding_dues) VALUES
('Annapurna Agro Foods', 'Suresh Gupta', '9822012345', 'suresh@annapurnaagro.com', 'APMC Market Yard, Pune', 12500.00),
('Kisan Dairy Co-op', 'Mahesh Patil', '9822054321', 'sales@kisandairy.com', 'MIDC Phase II, Baramati', 4500.00),
('Everfresh Veggies & Fruits', 'Rajendra Jagtap', '9822098765', 'orders@everfresh.in', 'Gultekdi Wholesale Yard', 0.00)
ON CONFLICT (supplier_name) DO NOTHING;

-- 9. Inventory Items
INSERT INTO "InventoryItem" (item_name, unit, current_stock, reorder_level, unit_cost, is_low_stock) VALUES
('Basmati Rice (Sharbati)', 'kg', 240.00, 100.00, 65.00, FALSE),
('Toor Dal Superfine', 'kg', 45.00, 50.00, 140.00, TRUE),
('Refined Sunflower Oil', 'liter', 85.00, 60.00, 125.00, FALSE),
('Fresh Whole Milk', 'liter', 25.00, 40.00, 55.00, TRUE),
('Wheat Flour (Chakki Atta)', 'kg', 310.00, 150.00, 42.00, FALSE),
('Sugar', 'kg', 60.00, 40.00, 44.00, FALSE),
('Fresh Paneer', 'kg', 12.00, 15.00, 320.00, TRUE);

-- 10. Staff Members
INSERT INTO "Staff" (first_name, last_name, role, phone, email) VALUES
('Raghavan', 'Pillai', 'Caterer', '9711223344', 'caterer@campusmess.com'),
('Manoj', 'Yadav', 'Mess Staff', '9711223345', 'manoj.y@campusmess.com'),
('Pooja', 'Chauhan', 'Canteen Staff', '9711223346', 'pooja.c@campusmess.com'),
('Dr. Ramesh', 'Kumar', 'Warden', '9876543210', 'warden.cauvery@college.edu'),
('Super', 'Admin', 'Admin', '9999900000', 'admin@college.edu')
ON CONFLICT DO NOTHING;

-- 11. Initial Complaints & Feedback
INSERT INTO "Feedback" (student_id, slot_id, meal_date, rating, taste_rating, hygiene_rating, comments) VALUES
(1, 2, CURRENT_DATE, 4, 4, 5, 'Lunch was tasty today, sambar was properly seasoned.'),
(4, 2, CURRENT_DATE, 2, 2, 3, 'Chapatis were cold and dry.')
ON CONFLICT DO NOTHING;

INSERT INTO "Complaint" (student_id, category, subject, description, status) VALUES
(1, 'Food Quality', 'Cold breakfast on Monday', 'Idlis were cold when served at 8:15 AM.', 'Under Review');
