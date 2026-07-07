from flask import jsonify, render_template
from flask_login import login_required
from sqlalchemy import text

from app.extensions import db
from app.lib.auth import get_current_user
from app.main import main_bp


@main_bp.route("/health")
def health():
    try:
        db.session.execute(text("SELECT 1"))
        return jsonify({"status": "ok", "database": str(db.engine.url)}), 200
    except Exception as exc:
        return jsonify({"status": "error", "detail": str(exc)}), 500


@main_bp.route("/")
def index():
    return render_template("main/index.html")


@main_bp.route("/dashboard")
@login_required
def dashboard():
    user = get_current_user()
    return render_template("main/dashboard.html", user=user)
