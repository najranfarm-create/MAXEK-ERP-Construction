# Deploy updated dashboard from GitHub to live server

## Important

GitHub `main` currently has only a **stub** (README + small Flask scaffold), **not** your full 23,125-line ERP.

Your **corrected dashboard** must be **pushed to GitHub** from your dev machine first.

---

## Step 1 — Push full ERP / dashboard from your PC

On the computer where you made the dashboard corrections:

```bash
cd /path/to/your/maxek-erp
git init   # if not already a repo
git remote add origin https://github.com/najranfarm-create/MAXEK-ERP-Construction.git
git add templates/   # dashboard templates only, or full app
git commit -m "feat: platform dashboard layout — recent customers top, dept grid, tickets bottom"
git push origin main
```

Or push to a branch: `git push origin dashboard-update`

---

## Step 2 — On server (safe — templates only)

**Do NOT** `git clone` into `/var/www/maxek-erp`.

```bash
cd /tmp
rm -rf maxek-github-pull
git clone --branch main https://github.com/najranfarm-create/MAXEK-ERP-Construction.git maxek-github-pull

# Check GitHub has real ERP (not stub)
wc -l maxek-github-pull/app.py
# Must be 20000+ for full ERP. If ~30 lines, only copy specific template files you pushed.

# Copy ONLY dashboard template (example names — adjust after grep on server)
sudo cp maxek-github-pull/templates/super_admin_dashboard.html \
        /var/www/maxek-erp/templates/super_admin_dashboard.html

sudo systemctl restart maxek-erp.service
```

---

## Step 3 — Keep working login

Do not overwrite login:

```bash
sudo cp /var/www/maxek-erp/templates/login.html.working-20260707 \
        /var/www/maxek-erp/templates/login.html
sudo systemctl restart maxek-erp.service
```

---

## Which GitHub branch?

Tell us the branch name if not `main`. Then on server:

```bash
GITHUB_BRANCH=your-branch bash /tmp/maxek-github-pull/scripts/pull-dashboard-from-github.sh
```

---

## Verify

https://erp.maxekindia.com/super-admin/dashboard — hard refresh Ctrl+Shift+R

Expected layout per your spec:
1. Recent Customers (top, report style)
2. Department grid (no Planning/BOQ/DPR cards)
3. Tickets + Quick Actions (bottom)
4. No Platform Command Centre stats block
