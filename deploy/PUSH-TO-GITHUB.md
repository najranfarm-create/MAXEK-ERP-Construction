# Push MAXEK ERP to GitHub (from PC / Codex / NASEER_vps_patch)

Repo: https://github.com/najranfarm-create/MAXEK-ERP-Construction

---

## From Windows (NASEER_vps_patch or full ERP folder)

Open **PowerShell** in your project folder:

```powershell
cd "C:\Users\rajee\Documents\My new project\NASEER_vps_patch"

git init
git remote add origin https://github.com/najranfarm-create/MAXEK-ERP-Construction.git
git fetch origin

# First time: pull then merge, or force if this IS the canonical copy
git pull origin main --allow-unrelated-histories
# OR if your folder is the full truth:
# git checkout -b main

git add app.py templates/ static/ requirements.txt wsgi.py
git status
git commit -m "feat: MAXEK ERP — updated dashboard, billing, VPS patch"
git push -u origin main
```

If push rejected (remote has other commits):

```powershell
git pull origin main --rebase
git push origin main
```

---

## From VPS (after /tmp/maxek-pull has full ERP)

```bash
cd /tmp/maxek-pull
git status
git add -A
git commit -m "feat: sync live ERP updates from VPS"
git push origin main
```

(Needs `git config user.email` and GitHub token or SSH key on server.)

---

## From Cursor / Codex Cloud Agent

Already pushed to branch:
- `cursor/fix-production-routing-0620` — login/nginx fix scripts + docs

Merge to `main` on GitHub:
1. Open https://github.com/najranfarm-create/MAXEK-ERP-Construction/pull/2
2. Merge PR (if full ERP is on another branch, merge that instead)

---

## What should be on GitHub `main`

| File | Expect |
|------|--------|
| `app.py` | ~23,000+ lines |
| `templates/` | All HTML including updated super-admin dashboard |
| `static/` | CSS/JS/images |
| `wsgi.py` | Gunicorn entry |

**Not** the small stub (30-line app).

---

## After push — deploy on VPS

```bash
cd /tmp/maxek-pull && git pull origin main
sudo rsync -av /tmp/maxek-pull/templates/ /var/www/maxek-erp/templates/
sudo cp /var/www/maxek-erp/templates/login.html.working-20260707 \
        /var/www/maxek-erp/templates/login.html
sudo systemctl restart maxek-erp.service
```

---

## GitHub auth

- **HTTPS:** Personal Access Token as password  
- **SSH:** `git@github.com:najranfarm-create/MAXEK-ERP-Construction.git`

Create token: GitHub → Settings → Developer settings → Personal access tokens
