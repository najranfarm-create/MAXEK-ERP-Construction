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

## If login still returns 500

Routing is fixed separately from app errors. Check Gunicorn logs:

```bash
sudo journalctl -u maxek-erp.service -n 50 --no-pager
```

Common non-routing causes: database connection, missing `.env`, Python import errors in the original ERP app.
