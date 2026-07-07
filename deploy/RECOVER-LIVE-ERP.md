# Recover live ERP after accidental revert / missing dashboard

## What we changed (only these)

| Item | Path | Notes |
|------|------|-------|
| login template | `/var/www/maxek-erp/templates/login.html` | Patched for Jinja/CSS — backups exist |
| nginx | `/etc/nginx/sites-available/erp.maxekindia.com` | Static routing only |
| systemd | `/etc/systemd/system/maxek-erp.service` | Points to `/var/www/maxek-erp` |

**We did NOT intentionally change:** `app.py`, dashboard templates, database, or other modules.

## If dashboard / tools are missing

### 1. Check nothing was cloned over live ERP

```bash
sudo bash /tmp/maxek-routing-fix/scripts/check-erp-version.sh
# or after cloning repo:
ls -la /var/www/maxek-erp/app.py
wc -l /var/www/maxek-erp/app.py
```

Original ERP `app.py` was **8000+ lines** (login at line ~8380 in logs).  
If `app.py` is tiny (~30 lines), the live app was **overwritten** by the GitHub scaffold.

### 2. Restore login.html from BEFORE our edits (keeps routing fixes)

```bash
ls -lt /var/www/maxek-erp/templates/login.html.bak*
# Pick oldest backup from BEFORE Jul 7 21:50 (before first patch):
sudo cp /var/www/maxek-erp/templates/login.html.bak.20260707215039 \
        /var/www/maxek-erp/templates/login.html
```

Then re-apply **only** the minimal Jinja fixes (or use fixed version from backup.recovery).

### 3. If entire app was overwritten — restore from server backup

Check Hostinger / VPS snapshots, or:

```bash
# Any tar backups?
find /var/www /root /home -name '*maxek*backup*' -o -name '*maxek*.tar*' 2>/dev/null | head -10
```

### 4. Confirm service uses ORIGINAL path

```bash
systemctl cat maxek-erp.service | grep -E 'WorkingDirectory|ExecStart'
# Must be /var/www/maxek-erp NOT maxek-erp-flask
```

### 5. Do NOT run

```bash
git clone ... /var/www/maxek-erp   # overwrites live ERP
rm -rf /var/www/maxek-erp/*        # while shell is inside that dir
```

## Nginx + static fixes are safe to keep

Even after restoring app files, keep:
- `location /static/ { alias /var/www/maxek-erp/static/; }`
- systemd `WorkingDirectory=/var/www/maxek-erp`

## Get help

Paste output of:

```bash
wc -l /var/www/maxek-erp/app.py
ls -la /var/www/maxek-erp/templates/ | head -20
ls -lt /var/www/maxek-erp/templates/login.html.bak* | head -5
```
