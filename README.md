# Mess and Canteen Management System (DBMS Course Project)

A database-driven web application connecting students, meal attendance, canteen ordering, inventory, and finances into a single verified system for a college hostel mess and canteen.

---

## 📁 Repository Structure

```
├── sql/                                # Modular SQL Scripts (PostgreSQL / Supabase)
│   ├── 00_master_schema.sql           # Complete Master DDL (All 6 modules & indexes)
│   ├── 01_students.sql                # Module 1: Hostel, Student, MessEnrollment, LeaveRequest
│   ├── 02_attendance.sql              # Module 2: MealSlot, HostelAttendance, MealAttendance
│   ├── 03_billing.sql                 # Module 3: MealRate, CatererInvoice, InvoiceLine, Payment
│   ├── 04_menu_orders.sql             # Module 4: Category, MenuItem, MessMenu, Orders, OrderItem
│   ├── 05_inventory.sql               # Module 5: InventoryItem, Supplier, Purchase, StockUsage
│   ├── 06_users_complaints.sql        # Module 6: Staff, AppUser, Feedback, Complaint, Audit Log
│   ├── 07_views.sql                   # All 10 views required by project brief
│   ├── 08_triggers_and_procedures.sql # All PL/pgSQL triggers and stored procedures
│   └── sample_data.sql                # Comprehensive seed data for testing
│
├── backend/                            # Python Flask API
│   ├── app.py                         # Application entrypoint
│   ├── database.py                    # Connection handler (Supabase + Local fallback)
│   ├── routes/
│   │   └── m1_students.py             # Module 1 endpoints & Member 1 analytical queries
│   ├── requirements.txt
│   └── .env                           # Supabase DATABASE_URL configuration
│
└── frontend/                           # React + Vite Web Client
    ├── src/
    │   ├── App.jsx                    # Module 1 UI & integrated project shell
    │   └── index.css                  # Modern design system & styles
    └── vite.config.js                 # Proxy to Flask API on port 5000
```

---

## 🚀 Setting up with Supabase

1. Open your **Supabase Dashboard** and navigate to the **SQL Editor**.
2. Copy the entire contents of [`sql/00_master_schema.sql`](sql/00_master_schema.sql) and click **Run**.
3. Next, copy the contents of [`sql/08_triggers_and_procedures.sql`](sql/08_triggers_and_procedures.sql) and [`sql/07_views.sql`](sql/07_views.sql) and run them.
4. *(Optional)* Run [`sql/sample_data.sql`](sql/sample_data.sql) to populate initial data.
5. In Supabase, go to **Project Settings** → **Database** → **Connection String** → select **URI**.
6. Open [`backend/.env`](backend/.env) and paste your URI into:
   ```env
   DATABASE_URL=postgresql://postgres.xxxx:[YOUR-PASSWORD]@aws-0-xxxx.pooler.supabase.com:6543/postgres
   ```
*(Note: If `DATABASE_URL` is left blank, the backend automatically uses an internal database so you can test the frontend and API immediately).*

---

## 💻 Running Locally

### 1. Start the Flask Backend
```powershell
cd backend
python -m pip install -r requirements.txt
python app.py
```
*Backend runs on `http://localhost:5000`.*

### 2. Start the Vite Frontend
```powershell
cd frontend
npm install
npm run dev
```
*Frontend runs on `http://localhost:3000`.*

---

## 🎓 Module 1 Deliverables (Member 1)
- **Tables**: `Hostel`, `Student`, `MessEnrollment`, `LeaveRequest`
- **Database Trigger**: `trg_leave_overlap` (rejects overlapping leaves for the same student).
- **Stored Procedure**: `sp_approve_leave(leave_id, approver)` (updates status and stamps approver).
- **Database View**: `v_students_on_leave_today` (active leaves for today reducing plates forecast).
- **Cross-cutting Duty**: Relational Normalization documentation (1NF, 2NF, 3NF decomposition).
- **Non-trivial Queries**:
  1. Students on leave by hostel.
  2. Enrollment count vs room capacity per hostel.
  3. Students with the highest leave count.
