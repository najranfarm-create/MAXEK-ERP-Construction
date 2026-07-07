import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent


def resolve_database_uri() -> str:
    """Always use an absolute SQLite path so gunicorn/systemd cwd does not break the DB."""
    raw = os.environ.get("DATABASE_URL")
    if not raw:
        return f"sqlite:///{BASE_DIR / 'maxek_erp.db'}"

    if raw.startswith("sqlite:///") and not raw.startswith("sqlite:////"):
        relative_path = raw.removeprefix("sqlite:///")
        if relative_path == ":memory:":
            return raw
        path = Path(relative_path)
        if not path.is_absolute():
            path = BASE_DIR / path
        return f"sqlite:///{path}"

    return raw


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only-change-in-production")
    SQLALCHEMY_DATABASE_URI = resolve_database_uri()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    WTF_CSRF_ENABLED = True
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    REMEMBER_COOKIE_HTTPONLY = True

    ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "admin@maxek.local")
    ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "change-me")
    ADMIN_NAME = os.environ.get("ADMIN_NAME", "System Admin")


class DevelopmentConfig(Config):
    DEBUG = True


class ProductionConfig(Config):
    DEBUG = False


config_by_name = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "default": DevelopmentConfig,
}
