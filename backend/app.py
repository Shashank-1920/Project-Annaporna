import os
from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

from database import get_db_connection
from routes.m1_students import m1_bp

app = Flask(__name__)
CORS(app)

# Register Blueprints
app.register_blueprint(m1_bp, url_prefix='/api')

@app.route('/api/health', methods=['GET'])
def health_check():
    db_info = get_db_connection()
    conn = db_info["conn"]
    db_type = db_info["type"]
    conn.close()
    return jsonify({
        "status": "online",
        "service": "Mess and Canteen Management System API",
        "database": db_type,
        "database_target": "Supabase / PostgreSQL" if db_type == "postgres" else "Local SQLite Fallback (Ready for Supabase URI)"
    })

if __name__ == '__main__':
    port = int(os.getenv("PORT", 5000))
    print(f"[*] Starting Mess & Canteen Management Backend on port {port}...")
    app.run(host='0.0.0.0', port=port, debug=True)
