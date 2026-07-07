# Platform Super Admin Dashboard — Approved Layout (your corrections)

URL: `https://erp.maxekindia.com/super-admin/dashboard`

This documents the **updated** dashboard you already built. The live site is showing the **old** layout — restore or re-apply this spec.

---

## REMOVE completely

| Section | What to remove |
|---------|----------------|
| Platform Command Centre | Top header block |
| Platform stats sidebar | Total Companies, Active Users, System Health, Storage, etc. list |
| Level 2 header | "LEVEL 2 - COMPANY ERP / COMPANY ERP COMMAND CENTRE / Viewing MAXEK ERP..." |

## REMOVE from department grid (3 cards)

1. **Planning & WBS**
2. **BOQ**
3. **DPR** (marked IPR on sketch — confirm which)

These move under **Project** tab elsewhere (not main dashboard cards).

---

## NEW page order (top → bottom)

### 1. TOP — Recent Customers (position 1)

- Move **Recent Customers** table to **top of page**
- Restyle: report / graph / box cards — **main dashboard look** (not plain table only)

### 2. MIDDLE — Company ERP departments (position 2)

- Department workspace grid (remaining cards after removing Planning, BOQ, DPR)
- **No** Level 2 header above it

### 3. BOTTOM — Tickets & Quick Actions (position 3)

- Ticket Type & Approval (Support, Checker, Approver, Change Requests)
- Platform Quick Actions (Register Customer, Issue License, etc.)
- Move this block **down** to bottom

---

## Find template on server

```bash
grep -rn "Platform Command Centre\|RECENT CUSTOMERS\|LEVEL 2.*COMPANY ERP" \
  /var/www/maxek-erp/templates/ | head -20

grep -n "super-admin/dashboard\|super_admin_dashboard" /var/www/maxek-erp/app.py | head -10
```

Likely files: `super_admin_dashboard.html`, `platform_dashboard.html`, or section inside `base_maxek.html`.

---

## Restore corrected version

```bash
# Find backups of dashboard template
find /var/www/maxek-erp/templates -name '*dashboard*' -o -name '*super*' | xargs ls -la

# Compare with tar (June = OLD layout — do not full restore)
tar -tzf /root/maxek-erp-backup-2026-06-29-1535.tar.gz | grep -i dashboard

# If you have corrected file on dev PC:
# scp corrected_template.html server:/var/www/maxek-erp/templates/...
sudo systemctl restart maxek-erp.service
```

---

## Re-apply if file lost

Paste output of:

```bash
grep -rn "Platform Command Centre" /var/www/maxek-erp/templates/
ls -la /var/www/maxek-erp/templates/*super* /var/www/maxek-erp/templates/*platform* 2>/dev/null
```

Then we can edit that single template to match this spec (no full app overwrite).
