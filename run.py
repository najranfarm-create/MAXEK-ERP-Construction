import os

from app import create_app
from app.extensions import db
from app.models.user import User

app = create_app()


@app.cli.command("init-db")
def init_db() -> None:
    """Create database tables and seed the first admin user if none exist."""
    db.create_all()

    if User.query.count() == 0:
        admin = User(
            email=app.config["ADMIN_EMAIL"].lower().strip(),
            name=app.config["ADMIN_NAME"],
            role="admin",
        )
        admin.set_password(app.config["ADMIN_PASSWORD"])
        db.session.add(admin)
        db.session.commit()
        print(f"Created admin user: {admin.email}")
    else:
        print("Database already initialized.")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
