from flask import render_template
from flask_login import login_required

from app.lib.auth import get_current_user
from app.main import main_bp


@main_bp.route("/")
def index():
    return render_template("main/index.html")


@main_bp.route("/dashboard")
@login_required
def dashboard():
    user = get_current_user()
    return render_template("main/dashboard.html", user=user)
