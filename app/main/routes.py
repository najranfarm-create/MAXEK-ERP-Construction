from flask import jsonify, redirect, render_template, url_for
from flask_login import current_user, login_required
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
    if current_user.is_authenticated:
        return redirect(url_for("main.dashboard"))
    return render_template("main/index.html")


@main_bp.route("/api/me")
@login_required
def api_me():
    user = get_current_user()
    return jsonify(user.to_dict())


@main_bp.route("/dashboard")
@login_required
def dashboard():
    user = get_current_user()
    return render_template("main/dashboard.html", user=user)
