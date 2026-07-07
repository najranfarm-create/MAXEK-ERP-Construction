# Restore updated dashboard layout (department tabs / Project sub-tabs)

## Problem

ERP works and login works, but dashboard shows **old flat tabs** instead of the **updated layout**:
- Department-based navigation
- Project, BOQ, Costing grouped under **Project** tab (not separate main tabs)

## What we changed (did NOT touch dashboard)

Only these were modified during the July 7 fix session:
- `templates/login.html`
- `/etc/nginx/...`
- `/etc/systemd/system/maxek-erp.service`

If dashboard layout reverted, likely causes:
1. **Accidental tar restore** of old `templates/` or `static/js/`
2. **Wrong template** being rendered (old `base_maxek.html`)
3. **Browser cache** of old dashboard JS
4. **Database menu config** reset (if menus are DB-driven)

## Step 1 — Audit (run on server)

```bash
bash /tmp/maxek-routing-fix/scripts/audit-dashboard-templates.sh
```

Or manually:

```bash
ls -la /var/www/maxek-erp/templates/base_maxek.html
ls -la /var/www/maxek-erp/templates/*dashboard*
grep -n -i "project\|boq\|department" /var/www/maxek-erp/templates/base_maxek.html | head -20
```

Note file **dates**. Updated dashboard files should be **newer** (e.g. July 2026) than June backups.

## Step 2 — Compare with backup (do NOT full restore)

List dashboard files inside backup:

```bash
tar -tzf /root/maxek-erp-backup-2026-06-29-1535.tar.gz | grep -E 'base_maxek|dashboard|templates/'
```

Extract **one file** for comparison (example):

```bash
mkdir -p /tmp/compare
tar -xzf /root/maxek-erp-backup-2026-06-29-1535.tar.gz -C /tmp/compare var/www/maxek-erp/templates/base_maxek.html 2>/dev/null || \
tar -xzf /root/maxek-erp-backup-2026-06-29-1535.tar.gz -C /tmp/compare --wildcards '*base_maxek.html'

diff -u /tmp/compare/**/base_maxek.html /var/www/maxek-erp/templates/base_maxek.html | head -40
```

- If **live file is OLDER** than your updated work → live was overwritten; restore from a **July backup** or re-apply dashboard edits.
- If **live file is NEWER** than June tar → layout code is still there; problem may be **cache** or **DB menu**.

## Step 3 — Restore single template (safe)

Only if diff shows live file is wrong:

```bash
sudo cp /var/www/maxek-erp/templates/base_maxek.html /var/www/maxek-erp/templates/base_maxek.html.bak.before-restore
# Copy from known-good copy (USB, dev machine, or July snapshot — NOT June tar if that is the old layout)
sudo cp /path/to/good/base_maxek.html /var/www/maxek-erp/templates/base_maxek.html
sudo systemctl restart maxek-erp.service
```

## Step 4 — Browser cache

After server files are correct:
- Hard refresh: Ctrl+Shift+R
- Or incognito login

## Step 5 — If menus are in database

```bash
grep -n -i "menu\|department\|module" /var/www/maxek-erp/app.py | head -30
# Check sqlite if used:
find /var/www/maxek-erp -name '*.db' -ls
```

## Do NOT

- `git clone` over `/var/www/maxek-erp`
- Full `tar -xzf` extract over live folder without backup
- Restore June 25–29 tar **entire app** if that predates your dashboard update

## What to paste for help

```bash
ls -la /var/www/maxek-erp/templates/base_maxek.html
grep -n -i "project\|boq\|tab" /var/www/maxek-erp/templates/base_maxek.html | head -15
stat /var/www/maxek-erp/templates/base_maxek.html
```

And say: did anyone run a **full tar restore** today?
