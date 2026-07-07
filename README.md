# MAXEK ERP Construction (Flask)

Construction ERP backend with session-based authentication.

## Quick start

```bash
cd /var/www/maxek-erp-flask
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env — set SECRET_KEY and ADMIN_PASSWORD

flask --app run init-db
flask --app run run --debug
```

Open http://localhost:5000 and sign in with the admin credentials from `.env`.

## Authentication

| Component | Location |
|-----------|----------|
| User model | `app/models/user.py` |
| Auth helpers | `app/lib/auth.py` |
| Login / register / profile | `app/auth/routes.py` |
| Protected routes | `@login_required` or `role_required()` |

### Roles

- `user` — default registered user
- `manager` — project management access
- `site_supervisor` — site-level operations
- `admin` — full system access

### Protecting routes

```python
from flask_login import login_required
from app.lib.auth import admin_required, role_required

@main_bp.route("/admin")
@login_required
@admin_required
def admin_panel():
    ...

@main_bp.route("/sites")
@login_required
@role_required("admin", "site_supervisor", "manager")
def sites():
    ...
```

## Production

Use gunicorn behind nginx:

```bash
gunicorn -w 4 -b 0.0.0.0:8000 "run:app"
```

Set `FLASK_ENV=production` and a strong `SECRET_KEY` in production.
