import os

from flask import Flask

from app.auth import auth_bp
from app.config import config_by_name
from app.extensions import db, login_manager
from app.main import main_bp
from app.models.user import User


def create_app(config_name: str | None = None) -> Flask:
    app = Flask(__name__)
    config_key = config_name or os.environ.get("FLASK_ENV", "default")
    app.config.from_object(config_by_name.get(config_key, config_by_name["default"]))

    db.init_app(app)
    login_manager.init_app(app)

    @login_manager.user_loader
    def load_user(user_id: str) -> User | None:
        return db.session.get(User, int(user_id))

    app.register_blueprint(auth_bp)
    app.register_blueprint(main_bp)

    return app
