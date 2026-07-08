from flask import jsonify, redirect, request, url_for
from flask_login import LoginManager
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
login_manager = LoginManager()
login_manager.login_view = "auth.login"
login_manager.login_message = "Please sign in to access this page."
login_manager.login_message_category = "warning"


@login_manager.unauthorized_handler
def unauthorized():
    """Return JSON 401 for API requests; redirect browsers to login."""
    if request.path.startswith("/api/") or request.accept_mimetypes.best_match(
        ["application/json", "text/html"]
    ) == "application/json":
        return jsonify({"error": "Not authenticated"}), 401
    return redirect(url_for("auth.login", next=request.url))
