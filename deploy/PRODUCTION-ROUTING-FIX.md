# Production routing fix (erp.maxekindia.com)

**Scope:** Nginx static routing + systemd service only.  
**Does NOT** modify `/var/www/maxek-erp` application code.  
**Does NOT** use `/var/www/maxek-erp-flask`.

## Problem

| URL | Symptom | Cause |
|-----|---------|-------|
| `https://erp.maxekindia.com/login` | HTTP 500 | Service may point at wrong app directory |
| `https://erp.maxekindia.com/static/css/maxek-login.css` | HTTP 404 | Nginx not serving `/static/` from disk |
| `http://127.0.0.1:8000/static/css/maxek-login.css` | HTTP 200 | Flask/Gunicorn static works locally |

## Fix (on VPS as root)

### Option A — automated (recommended)

Copy only the `deploy/` and `scripts/` folders to the server, then:

```bash
cd /tmp
git clone --depth 1 --branch cursor/fix-production-routing-0620 \
  https://github.com/najranfarm-create/MAXEK-ERP-Construction.git maxek-routing-fix
cd maxek-routing-fix
sudo bash scripts/fix-production-routing.sh
```

This script does **not** write to `/var/www/maxek-erp` except reading static files for validation.

### Option B — manual

#### 1. Systemd — `/etc/systemd/system/maxek-erp.service`

```ini
[Service]
WorkingDirectory=/var/www/maxek-erp
ExecStart=/var/www/maxek-erp/.venv/bin/gunicorn --workers 2 --bind 127.0.0.1:8000 --timeout 120 wsgi:app
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart maxek-erp.service
```

#### 2. Nginx — add **before** `location /` in the `erp.maxekindia.com` server block

```nginx
location /static/ {
    alias /var/www/maxek-erp/static/;
    expires 30d;
    access_log off;
}
```

Full reference: `deploy/nginx/erp.maxekindia.com.conf`

```bash
sudo nginx -t
sudo systemctl reload nginx
```

#### 3. Verify

```bash
curl -I http://127.0.0.1:8000/login
curl -I http://127.0.0.1:8000/static/css/maxek-login.css
curl -I https://erp.maxekindia.com/login
curl -I https://erp.maxekindia.com/static/css/maxek-login.css
```

Expected: login `200` or `302`; static `200` on both local and public.

## Status after routing fix (2026-07-07)

| Check | Result |
|-------|--------|
| `https://erp.maxekindia.com/static/css/maxek-login.css` | **200** — Nginx static routing fixed |
| `http://127.0.0.1:8000/static/css/maxek-login.css` | **200** — Gunicorn static OK |
| `http://127.0.0.1:8000/login` | **500** — application error (not Nginx) |
| `https://erp.maxekindia.com/login` | **500** — same app error |

**Do not paste Nginx or systemd config into the terminal.** The fix script already applied those. Config blocks belong in `/etc/nginx/sites-available/` and `/etc/systemd/system/`, not bash.

## If login still returns 500

Routing is fixed. The remaining issue is inside the Flask app at `/var/www/maxek-erp`.

```bash
cd /tmp/maxek-routing-fix   # or re-clone the branch
sudo bash scripts/diagnose-login-500.sh
```

Or manually:

```bash
sudo journalctl -u maxek-erp.service -n 100 --no-pager
curl http://127.0.0.1:8000/login
```

Watch journalctl while curling — the Python traceback shows the real cause (database, template, import, `.env`, etc.).

Temporary debug server (does not affect production on :8000):

```bash
cd /var/www/maxek-erp
.venv/bin/flask --app wsgi:app run --host 127.0.0.1 --port 5001 --debug
# other terminal: curl http://127.0.0.1:5001/login
```
