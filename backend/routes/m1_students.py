from flask import Blueprint, request, jsonify
from database import execute_query, get_db_connection

m1_bp = Blueprint('m1_students', __name__)

# ========================================================
# Hostels API
# ========================================================

@m1_bp.route('/hostels', methods=['GET'])
def get_hostels():
    query = """
    SELECT hostel_id, hostel_name, warden_name, warden_phone, total_rooms, created_at 
    FROM "Hostel" 
    ORDER BY hostel_name ASC
    """
    try:
        hostels = execute_query(query)
        return jsonify({"success": True, "data": hostels})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ========================================================
# Students & Mess Enrollment API
# ========================================================

@m1_bp.route('/students', methods=['GET'])
def get_students():
    query = """
    SELECT 
        s.student_id,
        s.roll_number,
        s.first_name,
        s.last_name,
        s.first_name || ' ' || s.last_name AS full_name,
        s.email,
        s.phone,
        s.room_number,
        s.is_active,
        h.hostel_id,
        h.hostel_name,
        h.warden_name,
        me.enrollment_status,
        me.academic_term
    FROM "Student" s
    JOIN "Hostel" h ON s.hostel_id = h.hostel_id
    LEFT JOIN "MessEnrollment" me ON s.student_id = me.student_id
    ORDER BY s.roll_number ASC
    """
    try:
        students = execute_query(query)
        return jsonify({"success": True, "data": students})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@m1_bp.route('/students', methods=['POST'])
def register_student():
    data = request.json or {}
    roll = data.get('roll_number', '').strip().upper()
    first_name = data.get('first_name', '').strip()
    last_name = data.get('last_name', '').strip()
    email = data.get('email', '').strip().lower()
    phone = data.get('phone', '').strip()
    hostel_id = data.get('hostel_id')
    room_number = data.get('room_number', '').strip()
    academic_term = data.get('academic_term', 'Fall 2026').strip()

    if not all([roll, first_name, last_name, email, phone, hostel_id, room_number]):
        return jsonify({"success": False, "error": "All fields are required."}), 400

    db = get_db_connection()
    conn = db["conn"]
    db_type = db["type"]

    try:
        cursor = conn.cursor()
        if db_type == "sqlite":
            cursor.execute(
                "INSERT INTO Student (roll_number, first_name, last_name, email, phone, hostel_id, room_number) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (roll, first_name, last_name, email, phone, hostel_id, room_number)
            )
            student_id = cursor.lastrowid
            cursor.execute(
                "INSERT INTO MessEnrollment (student_id, academic_term, enrollment_status) VALUES (?, ?, 'Active')",
                (student_id, academic_term)
            )
        else:
            cursor.execute(
                """INSERT INTO "Student" (roll_number, first_name, last_name, email, phone, hostel_id, room_number) 
                   VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING student_id""",
                (roll, first_name, last_name, email, phone, hostel_id, room_number)
            )
            student_id = cursor.fetchone()["student_id"]
            cursor.execute(
                """INSERT INTO "MessEnrollment" (student_id, academic_term, enrollment_status) 
                   VALUES (%s, %s, 'Active')""",
                (student_id, academic_term)
            )

        conn.commit()
        cursor.close()
        conn.close()
        return jsonify({"success": True, "message": "Student registered and enrolled successfully!", "student_id": student_id})
    except Exception as e:
        conn.rollback()
        conn.close()
        return jsonify({"success": False, "error": str(e)}), 400


@m1_bp.route('/students/<int:student_id>', methods=['GET'])
def get_student_profile(student_id):
    student_query = """
    SELECT 
        s.student_id,
        s.roll_number,
        s.first_name,
        s.last_name,
        s.email,
        s.phone,
        s.room_number,
        s.is_active,
        h.hostel_name,
        h.warden_name,
        me.enrollment_status,
        me.academic_term,
        me.enrolled_at
    FROM "Student" s
    JOIN "Hostel" h ON s.hostel_id = h.hostel_id
    LEFT JOIN "MessEnrollment" me ON s.student_id = me.student_id
    WHERE s.student_id = %s
    """
    leaves_query = """
    SELECT leave_id, start_date, end_date, reason, status, approved_by, approved_at, rejection_reason, created_at
    FROM "LeaveRequest"
    WHERE student_id = %s
    ORDER BY created_at DESC
    """
    try:
        student = execute_query(student_query, (student_id,))
        if not student:
            return jsonify({"success": False, "error": "Student not found"}), 404

        leaves = execute_query(leaves_query, (student_id,))
        return jsonify({
            "success": True,
            "data": {
                "profile": student[0],
                "leave_history": leaves
            }
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ========================================================
# Leave Requests API
# ========================================================

@m1_bp.route('/leaves', methods=['GET'])
def get_leaves():
    status = request.args.get('status')
    hostel_id = request.args.get('hostel_id')
    
    query = """
    SELECT 
        lr.leave_id,
        lr.student_id,
        s.roll_number,
        s.first_name || ' ' || s.last_name AS student_name,
        s.room_number,
        h.hostel_name,
        lr.start_date,
        lr.end_date,
        lr.reason,
        lr.status,
        lr.approved_by,
        lr.approved_at,
        lr.rejection_reason,
        lr.created_at
    FROM "LeaveRequest" lr
    JOIN "Student" s ON lr.student_id = s.student_id
    JOIN "Hostel" h ON s.hostel_id = h.hostel_id
    WHERE 1=1
    """
    params = []
    if status and status != 'All':
        query += " AND lr.status = %s"
        params.append(status)
    if hostel_id and hostel_id != 'All':
        query += " AND h.hostel_id = %s"
        params.append(hostel_id)

    query += " ORDER BY lr.created_at DESC"
    try:
        leaves = execute_query(query, tuple(params) if params else None)
        return jsonify({"success": True, "data": leaves})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@m1_bp.route('/leaves', methods=['POST'])
def submit_leave_request():
    data = request.json or {}
    student_id = data.get('student_id')
    start_date = data.get('start_date')
    end_date = data.get('end_date')
    reason = data.get('reason', '').strip()

    if not all([student_id, start_date, end_date, reason]):
        return jsonify({"success": False, "error": "Student, start date, end date, and reason are required."}), 400

    if end_date < start_date:
        return jsonify({"success": False, "error": "End date cannot be prior to start date."}), 400

    # Overlap validation check (matches trigger trg_leave_overlap logic)
    overlap_query = """
    SELECT leave_id, start_date, end_date FROM "LeaveRequest"
    WHERE student_id = %s
      AND status IN ('Pending', 'Approved')
      AND (%s <= end_date AND %s >= start_date)
    """
    overlaps = execute_query(overlap_query, (student_id, start_date, end_date))
    if overlaps:
        return jsonify({
            "success": False, 
            "error": f"Trigger Violation [trg_leave_overlap]: Student already has an active/pending leave from {overlaps[0]['start_date']} to {overlaps[0]['end_date']}."
        }), 400

    insert_query = """
    INSERT INTO "LeaveRequest" (student_id, start_date, end_date, reason, status)
    VALUES (%s, %s, %s, %s, 'Pending')
    """
    try:
        execute_query(insert_query, (student_id, start_date, end_date, reason), fetch=False, commit=True)
        return jsonify({"success": True, "message": "Leave request submitted successfully."})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400


@m1_bp.route('/leaves/<int:leave_id>/approve', methods=['POST'])
def approve_leave(leave_id):
    data = request.json or {}
    approver = data.get('approver', 'Warden').strip()
    
    query = """
    UPDATE "LeaveRequest"
    SET status = 'Approved',
        approved_by = %s,
        approved_at = CURRENT_TIMESTAMP
    WHERE leave_id = %s
    """
    try:
        execute_query(query, (approver, leave_id), fetch=False, commit=True)
        return jsonify({"success": True, "message": f"Leave request #{leave_id} approved by {approver}."})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400


@m1_bp.route('/leaves/<int:leave_id>/reject', methods=['POST'])
def reject_leave(leave_id):
    data = request.json or {}
    rejection_reason = data.get('rejection_reason', 'Not approved').strip()

    query = """
    UPDATE "LeaveRequest"
    SET status = 'Rejected',
        rejection_reason = %s
    WHERE leave_id = %s
    """
    try:
        execute_query(query, (rejection_reason, leave_id), fetch=False, commit=True)
        return jsonify({"success": True, "message": f"Leave request #{leave_id} rejected."})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400


# ========================================================
# View & Analytical Queries (Member 1 Deliverables)
# ========================================================

@m1_bp.route('/leaves/on-leave-today', methods=['GET'])
def get_students_on_leave_today():
    """Implements View: v_students_on_leave_today"""
    query = """
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
      AND CURRENT_DATE BETWEEN lr.start_date AND lr.end_date
    """
    try:
        on_leave = execute_query(query)
        return jsonify({"success": True, "data": on_leave, "count": len(on_leave)})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@m1_bp.route('/analytics/m1', methods=['GET'])
def get_m1_analytics():
    """
    Runs the 4 non-trivial queries required for Member 1:
    1. Students on leave grouped by hostel
    2. Active enrollment count per hostel
    3. Students with the most leave days taken
    4. Enrolled students with no meals marked
    """
    q1 = """
    SELECT h.hostel_name, COUNT(lr.leave_id) AS total_on_leave
    FROM "Hostel" h
    LEFT JOIN "Student" s ON h.hostel_id = s.hostel_id
    LEFT JOIN "LeaveRequest" lr ON s.student_id = lr.student_id 
        AND lr.status = 'Approved' 
        AND CURRENT_DATE BETWEEN lr.start_date AND lr.end_date
    GROUP BY h.hostel_name
    ORDER BY total_on_leave DESC
    """

    q2 = """
    SELECT h.hostel_name, COUNT(me.enrollment_id) AS enrolled_students, h.total_rooms
    FROM "Hostel" h
    LEFT JOIN "Student" s ON h.hostel_id = s.hostel_id AND s.is_active = TRUE
    LEFT JOIN "MessEnrollment" me ON s.student_id = me.student_id AND me.enrollment_status = 'Active'
    GROUP BY h.hostel_name, h.total_rooms
    ORDER BY enrolled_students DESC
    """

    q3 = """
    SELECT 
        s.roll_number,
        s.first_name || ' ' || s.last_name AS student_name,
        h.hostel_name,
        COUNT(lr.leave_id) AS total_leave_requests,
        SUM(CASE WHEN lr.status = 'Approved' THEN 1 ELSE 0 END) AS approved_leaves
    FROM "Student" s
    JOIN "Hostel" h ON s.hostel_id = h.hostel_id
    LEFT JOIN "LeaveRequest" lr ON s.student_id = lr.student_id
    GROUP BY s.student_id, s.roll_number, s.first_name, s.last_name, h.hostel_name
    ORDER BY approved_leaves DESC
    LIMIT 5
    """

    try:
        res1 = execute_query(q1)
        res2 = execute_query(q2)
        res3 = execute_query(q3)
        return jsonify({
            "success": True,
            "data": {
                "leave_by_hostel": res1,
                "enrollment_per_hostel": res2,
                "top_leave_students": res3
            }
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
