"""Revised Estimate — separate tool for BOQ estimate revisions (original vs revised)."""

from __future__ import annotations

from datetime import datetime
from typing import Any


def _table_exists(db, table: str) -> bool:
    row = db.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None


def _ensure_column(db, table: str, column: str, col_type: str) -> None:
    if not _table_exists(db, table):
        return
    cols = {r[1] for r in db.execute(f"PRAGMA table_info({table})").fetchall()}
    if column not in cols:
        db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}")


def _now_ts() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _float(value: Any, default: float = 0.0) -> float:
    try:
        return round(float(value or default), 4)
    except (TypeError, ValueError):
        return default


def ensure_revised_estimate_tables(db) -> None:
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS revised_estimates(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            boq_id INTEGER,
            revision_no INTEGER DEFAULT 1,
            revision_date TEXT,
            title TEXT,
            remarks TEXT,
            status TEXT DEFAULT 'Draft',
            original_total REAL DEFAULT 0,
            revised_total REAL DEFAULT 0,
            delta_total REAL DEFAULT 0,
            created_by TEXT,
            created_at TEXT,
            modified_at TEXT,
            FOREIGN KEY(project_id) REFERENCES projects(id)
        )
        """
    )
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS revised_estimate_lines(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            estimate_id INTEGER NOT NULL,
            boq_item_id INTEGER,
            is_new_item INTEGER DEFAULT 0,
            item_code TEXT,
            item_description TEXT,
            unit TEXT,
            original_qty REAL DEFAULT 0,
            original_rate REAL DEFAULT 0,
            original_amount REAL DEFAULT 0,
            revised_qty REAL DEFAULT 0,
            revised_rate REAL DEFAULT 0,
            revised_amount REAL DEFAULT 0,
            delta_amount REAL DEFAULT 0,
            remarks TEXT,
            FOREIGN KEY(estimate_id) REFERENCES revised_estimates(id),
            FOREIGN KEY(boq_item_id) REFERENCES boq_items(id)
        )
        """
    )
    _ensure_column(db, "revised_estimates", "boq_id", "INTEGER")
    _ensure_column(db, "revised_estimate_lines", "is_new_item", "INTEGER DEFAULT 0")
    db.execute(
        "CREATE INDEX IF NOT EXISTS idx_revised_estimates_project "
        "ON revised_estimates(project_id, revision_date)"
    )
    db.execute(
        "CREATE INDEX IF NOT EXISTS idx_revised_estimate_lines_estimate "
        "ON revised_estimate_lines(estimate_id)"
    )


def prepare_revised_estimate_db(db) -> None:
    ensure_revised_estimate_tables(db)


def _estimate_select_sql(db) -> str:
    if _table_exists(db, "boq_master"):
        return (
            "SELECT e.*, p.project_code, p.project_name, bm.boq_number "
            "FROM revised_estimates e "
            "LEFT JOIN projects p ON e.project_id = p.id "
            "LEFT JOIN boq_master bm ON e.boq_id = bm.id "
        )
    return (
        "SELECT e.*, p.project_code, p.project_name, NULL AS boq_number "
        "FROM revised_estimates e "
        "LEFT JOIN projects p ON e.project_id = p.id "
    )


def list_revised_estimates(db, project_id: int | None = None) -> list[dict[str, Any]]:
    sql = _estimate_select_sql(db) + "WHERE 1=1"
    params: list[Any] = []
    if project_id:
        sql += " AND e.project_id=?"
        params.append(project_id)
    sql += " ORDER BY e.id DESC"
    rows = db.execute(sql, params).fetchall()
    return [dict(r) for r in rows]


def get_revised_estimate(db, estimate_id: int) -> dict[str, Any] | None:
    row = db.execute(
        _estimate_select_sql(db) + "WHERE e.id=?",
        (estimate_id,),
    ).fetchone()
    if not row:
        return None
    data = dict(row)
    lines = db.execute(
        "SELECT * FROM revised_estimate_lines WHERE estimate_id=? ORDER BY id",
        (estimate_id,),
    ).fetchall()
    data["lines"] = [dict(l) for l in lines]
    return data


def _next_revision_no(db, project_id: int) -> int:
    row = db.execute(
        "SELECT COALESCE(MAX(revision_no), 0) AS mx FROM revised_estimates WHERE project_id=?",
        (project_id,),
    ).fetchone()
    return int(row["mx"] if row else 0) + 1


def load_boq_lines_for_project(db, project_id: int, boq_id: int | None = None) -> list[dict[str, Any]]:
    try:
        from boq_management_service import ensure_boq_management_schema, get_boq_items_for_project

        ensure_boq_management_schema(db)
        items = get_boq_items_for_project(db, project_id, boq_id=boq_id)
        return _items_to_estimate_lines(items)
    except Exception:
        return []


def _items_to_estimate_lines(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    lines = []
    for item in items:
        qty = _float(item.get("quantity"))
        rate = _float(item.get("rate"))
        amount = _float(item.get("amount")) or round(qty * rate, 2)
        lines.append(
            {
                "boq_item_id": item.get("id"),
                "is_new_item": 0,
                "item_code": item.get("item_code") or item.get("item_number") or "",
                "item_description": item.get("item_description") or item.get("description") or "",
                "unit": item.get("unit") or "",
                "original_qty": qty,
                "original_rate": rate,
                "original_amount": amount,
                "revised_qty": qty,
                "revised_rate": rate,
                "revised_amount": amount,
                "delta_amount": 0.0,
                "remarks": "",
            }
        )
    return lines


def parse_lines_from_form(form) -> list[dict[str, Any]]:
    lines = []
    boq_ids = form.getlist("line_boq_item_id")
    is_new_list = form.getlist("line_is_new_item")
    for idx, boq_item_id in enumerate(boq_ids):
        is_new = (is_new_list[idx] if idx < len(is_new_list) else "0").strip() in ("1", "true", "yes")
        original_qty = _float(form.getlist("line_original_qty")[idx] if idx < len(form.getlist("line_original_qty")) else 0)
        original_rate = _float(form.getlist("line_original_rate")[idx] if idx < len(form.getlist("line_original_rate")) else 0)
        revised_qty = _float(form.getlist("line_revised_qty")[idx] if idx < len(form.getlist("line_revised_qty")) else original_qty)
        revised_rate = _float(form.getlist("line_revised_rate")[idx] if idx < len(form.getlist("line_revised_rate")) else original_rate)
        if is_new:
            original_qty = 0.0
            original_rate = 0.0
        original_amount = round(original_qty * original_rate, 2)
        revised_amount = round(revised_qty * revised_rate, 2)
        remarks_list = form.getlist("line_remarks")
        remarks = remarks_list[idx] if idx < len(remarks_list) else ""
        item_code_list = form.getlist("line_item_code")
        item_code = item_code_list[idx] if idx < len(item_code_list) else ""
        desc_list = form.getlist("line_item_description")
        item_description = desc_list[idx] if idx < len(desc_list) else ""
        unit_list = form.getlist("line_unit")
        unit = unit_list[idx] if idx < len(unit_list) else ""
        if not item_description and not revised_qty and not revised_rate:
            continue
        lines.append(
            {
                "boq_item_id": int(boq_item_id) if boq_item_id and not is_new else None,
                "is_new_item": 1 if is_new else 0,
                "item_code": item_code,
                "item_description": item_description,
                "unit": unit,
                "original_qty": original_qty,
                "original_rate": original_rate,
                "original_amount": original_amount,
                "revised_qty": revised_qty,
                "revised_rate": revised_rate,
                "revised_amount": revised_amount,
                "delta_amount": round(revised_amount - original_amount, 2),
                "remarks": remarks,
            }
        )
    return lines


def save_revised_estimate(db, form, username: str) -> int:
    project_id = int(form.get("project_id") or 0)
    if not project_id:
        raise ValueError("Select a project.")

    boq_id_raw = (form.get("boq_id") or "").strip()
    boq_id = int(boq_id_raw) if boq_id_raw.isdigit() else None

    estimate_id_raw = (form.get("estimate_id") or "").strip()
    title = (form.get("title") or "").strip() or f"Revised Estimate — Project {project_id}"
    remarks = (form.get("remarks") or "").strip()
    revision_date = (form.get("revision_date") or "").strip() or datetime.now().strftime("%Y-%m-%d")
    status = (form.get("status") or "Draft").strip() or "Draft"
    lines = parse_lines_from_form(form)
    if not lines:
        raise ValueError("Add at least one line item.")

    original_total = round(sum(l["original_amount"] for l in lines), 2)
    revised_total = round(sum(l["revised_amount"] for l in lines), 2)
    delta_total = round(revised_total - original_total, 2)
    now = _now_ts()

    if estimate_id_raw:
        estimate_id = int(estimate_id_raw)
        db.execute(
            "UPDATE revised_estimates SET project_id=?, boq_id=?, revision_date=?, title=?, remarks=?, "
            "status=?, original_total=?, revised_total=?, delta_total=?, modified_at=? WHERE id=?",
            (
                project_id,
                boq_id,
                revision_date,
                title,
                remarks,
                status,
                original_total,
                revised_total,
                delta_total,
                now,
                estimate_id,
            ),
        )
        db.execute("DELETE FROM revised_estimate_lines WHERE estimate_id=?", (estimate_id,))
    else:
        revision_no = _next_revision_no(db, project_id)
        cur = db.execute(
            "INSERT INTO revised_estimates("
            "project_id, boq_id, revision_no, revision_date, title, remarks, status, "
            "original_total, revised_total, delta_total, created_by, created_at, modified_at"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                project_id,
                boq_id,
                revision_no,
                revision_date,
                title,
                remarks,
                status,
                original_total,
                revised_total,
                delta_total,
                username,
                now,
                now,
            ),
        )
        estimate_id = cur.lastrowid

    for line in lines:
        db.execute(
            "INSERT INTO revised_estimate_lines("
            "estimate_id, boq_item_id, is_new_item, item_code, item_description, unit, "
            "original_qty, original_rate, original_amount, revised_qty, revised_rate, "
            "revised_amount, delta_amount, remarks"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                estimate_id,
                line.get("boq_item_id"),
                line.get("is_new_item") or 0,
                line.get("item_code"),
                line.get("item_description"),
                line.get("unit"),
                line["original_qty"],
                line["original_rate"],
                line["original_amount"],
                line["revised_qty"],
                line["revised_rate"],
                line["revised_amount"],
                line["delta_amount"],
                line.get("remarks"),
            ),
        )
    db.commit()
    return estimate_id
