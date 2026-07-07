# MAXEK ERP Construction (Flask)

Construction ERP backend with session-based authentication.

## Server setup (Linux / VPS)

**Do not run `pip install` system-wide** on Debian/Ubuntu — use the virtual environment below.

### One-command deploy (fresh server)

```bash
apt update && apt install -y git python3 python3-venv python3-pip
bash -c "$(curl -fsSL https://raw.githubusercontent.com/najranfarm-create/MAXEK-ERP-Construction/cursor/auth-setup-flask-0620/scripts/deploy-from-git.sh)"
```

Or step by step:

```bash
# 1. System packages (once per server)
apt update && apt install -y git python3 python3-venv python3-pip

# 2. Clone application code
git clone --branch cursor/auth-setup-flask-0620 \
  https://github.com/najranfarm-create/MAXEK-ERP-Construction.git \
  /var/www/maxek-erp-flask

# 3. Run automated setup (creates .venv, installs deps, init-db)
cd /var/www/maxek-erp-flask
bash scripts/setup.sh

# 4. Edit secrets
nano .env   # set SECRET_KEY and ADMIN_PASSWORD, then re-run: .venv/bin/flask --app run init-db

# 5. Start app (always use .venv/bin/ — never bare flask/pip)
.venv/bin/flask --app run run --host 0.0.0.0 --port 5000
```

Open `http://YOUR_SERVER_IP:5000/auth/login` and sign in with `ADMIN_EMAIL` / `ADMIN_PASSWORD` from `.env`.

### If you already have an empty /var/www/maxek-erp-flask folder

```bash
rm -rf /var/www/maxek-erp-flask/*
git clone --branch cursor/auth-setup-flask-0620 \
  https://github.com/najranfarm-create/MAXEK-ERP-Construction.git \
  /var/www/maxek-erp-flask
cd /var/www/maxek-erp-flask && bash scripts/setup.sh
```

## Local development

```bash
cd /var/www/maxek-erp-flask
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
flask --app run init-db
flask --app run run --debug
```

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

Add this **inside a Python file** (e.g. `app/main/routes.py`), not in the terminal:

```python
from flask_login import login_required
from app.lib.auth import admin_required, role_required

@main_bp.route("/admin")
@login_required
@admin_required
def admin_panel():
    return render_template("main/dashboard.html", user=get_current_user())

@main_bp.route("/sites")
@login_required
@role_required("admin", "site_supervisor", "manager")
def sites():
    return render_template("main/dashboard.html", user=get_current_user())
```

## Production

Use gunicorn behind nginx:

```bash
gunicorn -w 4 -b 0.0.0.0:8000 "run:app"
```

Set `FLASK_ENV=production` and a strong `SECRET_KEY` in production.

## Troubleshooting Internal Server Error (500)

On the server, run:

```bash
cd /var/www/maxek-erp-flask
git pull origin cursor/auth-setup-flask-0620
bash scripts/diagnose.sh
.venv/bin/flask --app run init-db
.venv/bin/flask --app run run --host 127.0.0.1 --port 5000 --debug
```

Then open the site again — the terminal will show the real traceback.

**Common fix:** relative SQLite path in `.env`. Use an absolute path:

```bash
nano /var/www/maxek-erp-flask/.env
# Set:
# DATABASE_URL=sqlite:////var/www/maxek-erp-flask/maxek_erp.db
.venv/bin/flask --app run init-db
```

Check health: `curl http://127.0.0.1:5000/health`
