"""Time of Completion (TOC) extension register — agreement baseline, delays, BG extensions."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

DELAY_REASONS = (
    "Site Conditions",
    "Land Availability",
    "Rain / Weather",
    "Client Delay",
    "Statutory / Approval Delay",
    "Material Non-Availability",
    "Labour Shortage",
    "Force Majeure",
    "Other",
)

TOC_STATUSES = ("Draft", "Submitted", "Approved")


def _table_exists(db, table: str) -> bool:
    row = db.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None


def _now_ts() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _today() -> str:
    return date.today().isoformat()


def _parse_date(value: str | None) -> date | None:
    if not value or not str(value).strip():
        return None
    try:
        return datetime.strptime(str(value).strip()[:10], "%Y-%m-%d").date()
    except ValueError:
        return None


def _days_between(start: str | None, end: str | None) -> int | None:
    d0 = _parse_date(start)
    d1 = _parse_date(end)
    if not d0 or not d1:
        return None
    return (d1 - d0).days


def ensure_toc_extension_tables(db) -> None:
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS project_toc_extensions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_number TEXT NOT NULL,
            project_id INTEGER NOT NULL,
            toc_date TEXT NOT NULL,
            agreement_number TEXT,
            agreement_base_completion_date TEXT,
            previous_completion_date TEXT,
            next_extension_date TEXT,
            extension_days INTEGER DEFAULT 0,
            delay_reason TEXT,
            delay_description TEXT,
            remarks TEXT,
            status TEXT DEFAULT 'Draft',
            created_by TEXT,
            created_at TEXT,
            modified_at TEXT,
            FOREIGN KEY(project_id) REFERENCES projects(id)
        )
        """
    )
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS project_toc_bg_extensions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            toc_extension_id INTEGER NOT NULL,
            sort_order INTEGER DEFAULT 0,
            original_bg_number TEXT,
            original_bg_expiry_date TEXT,
            original_bg_amount REAL DEFAULT 0,
            extended_bg_number TEXT,
            extended_bg_date TEXT,
            extended_bg_amount REAL DEFAULT 0,
            extended_bg_expiry_date TEXT,
            remarks TEXT,
            FOREIGN KEY(toc_extension_id) REFERENCES project_toc_extensions(id)
        )
        """
    )
    db.execute(
        "CREATE INDEX IF NOT EXISTS idx_toc_extensions_project "
        "ON project_toc_extensions(project_id, toc_date)"
    )
    db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_toc_extensions_docno "
        "ON project_toc_extensions(document_number)"
    )
    db.execute(
        "CREATE INDEX IF NOT EXISTS idx_toc_bg_extensions_toc "
        "ON project_toc_bg_extensions(toc_extension_id, sort_order)"
    )


def prepare_toc_extension_db(db) -> None:
    ensure_toc_extension_tables(db)


def next_toc_document_number(db, toc_date: str | None = None) -> str:
    """TOC/YYYYMMDD/NNN — sequence resets per calendar day."""
    day = (toc_date or _today())[:10].replace("-", "")
    prefix = f"TOC/{day}/"
    row = db.execute(
        "SELECT document_number FROM project_toc_extensions "
        "WHERE document_number LIKE ? ORDER BY id DESC LIMIT 1",
        (prefix + "%",),
    ).fetchone()
    seq = 1
    if row and row["document_number"]:
        try:
            seq = int(str(row["document_number"]).rsplit("/", 1)[-1]) + 1
        except ValueError:
            seq = 1
    return f"{prefix}{seq:03d}"


def _project_base_completion(project: dict[str, Any]) -> str:
    for key in (
        "end_date",
        "planned_completion_date",
        "gov_completion_date",
    ):
        val = (project.get(key) or "").strip()
        if val:
            return val[:10]
    return ""


def get_project_agreement_context(db, project_id: int) -> dict[str, Any] | None:
    row = db.execute(
        "SELECT id, project_code, project_name, agreement_number, contract_number, "
        "start_date, end_date, planned_completion_date, completion_time, completion_months, "
        "completion_mode, bank_guarantee_number, bank_guarantee_expiry_date, bank_guarantee_amount "
        "FROM projects WHERE id=?",
        (project_id,),
    ).fetchone()
    if not row:
        return None
    project = dict(row)
    base = _project_base_completion(project)
    latest = db.execute(
        "SELECT next_extension_date FROM project_toc_extensions "
        "WHERE project_id=? ORDER BY id DESC LIMIT 1",
        (project_id,),
    ).fetchone()
    previous_completion = (
        (latest["next_extension_date"] or "").strip() if latest else base
    )
    bgs = list_project_bg_rows(db, project_id)
    return {
        "project_id": project_id,
        "project_code": project.get("project_code") or "",
        "project_name": project.get("project_name") or "",
        "agreement_number": project.get("agreement_number") or project.get("contract_number") or "",
        "start_date": (project.get("start_date") or "")[:10],
        "agreement_base_completion_date": base,
        "previous_completion_date": previous_completion,
        "completion_time": project.get("completion_time") or "",
        "completion_months": project.get("completion_months"),
        "bank_guarantees": bgs,
    }


def list_project_bg_rows(db, project_id: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if _table_exists(db, "project_guarantees"):
        for row in db.execute(
            "SELECT * FROM project_guarantees WHERE project_id=? "
            "AND guarantee_type IN ('Bank Guarantee', 'Performance Guarantee') "
            "ORDER BY sort_order, id",
            (project_id,),
        ).fetchall():
            r = dict(row)
            if r.get("bank_guarantee_number") or float(r.get("amount") or 0) > 0:
                rows.append(
                    {
                        "guarantee_type": r.get("guarantee_type") or "Bank Guarantee",
                        "bg_number": r.get("bank_guarantee_number") or "",
                        "bg_issue_date": (r.get("bank_guarantee_issued_date") or "")[:10],
                        "bg_expiry_date": (r.get("bank_guarantee_expiry_date") or "")[:10],
                        "bg_amount": float(r.get("amount") or 0),
                    }
                )
    if not rows:
        project = db.execute(
            "SELECT bank_guarantee_number, bank_guarantee_issued_date, "
            "bank_guarantee_expiry_date, bank_guarantee_amount FROM projects WHERE id=?",
            (project_id,),
        ).fetchone()
        if project and (
            project["bank_guarantee_number"]
            or float(project["bank_guarantee_amount"] or 0) > 0
        ):
            rows.append(
                {
                    "guarantee_type": "Bank Guarantee",
                    "bg_number": project["bank_guarantee_number"] or "",
                    "bg_issue_date": (project["bank_guarantee_issued_date"] or "")[:10],
                    "bg_expiry_date": (project["bank_guarantee_expiry_date"] or "")[:10],
                    "bg_amount": float(project["bank_guarantee_amount"] or 0),
                }
            )
    return rows


def list_toc_extensions(
    db, project_id: int | None = None, limit: int = 200
) -> list[dict[str, Any]]:
    sql = (
        "SELECT t.*, p.project_code, p.project_name, p.agreement_number AS project_agreement "
        "FROM project_toc_extensions t "
        "LEFT JOIN projects p ON t.project_id = p.id WHERE 1=1"
    )
    params: list[Any] = []
    if project_id:
        sql += " AND t.project_id=?"
        params.append(project_id)
    sql += " ORDER BY t.id DESC LIMIT ?"
    params.append(limit)
    rows = db.execute(sql, params).fetchall()
    return [dict(r) for r in rows]


def get_toc_extension(db, toc_id: int) -> dict[str, Any] | None:
    row = db.execute(
        "SELECT t.*, p.project_code, p.project_name "
        "FROM project_toc_extensions t "
        "LEFT JOIN projects p ON t.project_id = p.id WHERE t.id=?",
        (toc_id,),
    ).fetchone()
    if not row:
        return None
    data = dict(row)
    bg_rows = db.execute(
        "SELECT * FROM project_toc_bg_extensions WHERE toc_extension_id=? "
        "ORDER BY sort_order, id",
        (toc_id,),
    ).fetchall()
    data["bg_extensions"] = [dict(b) for b in bg_rows]
    return data


def list_agreement_summaries(db, project_id: int | None = None) -> list[dict[str, Any]]:
    """My Agreement tab — project baseline + cumulative extension stats."""
    sql = (
        "SELECT p.id, p.project_code, p.project_name, p.agreement_number, p.contract_number, "
        "p.start_date, p.end_date, p.planned_completion_date, p.completion_time, p.completion_months "
        "FROM projects p WHERE COALESCE(p.project_status, p.status, '') NOT IN ('Closed', 'Cancelled')"
    )
    params: list[Any] = []
    if project_id:
        sql += " AND p.id=?"
        params.append(project_id)
    sql += " ORDER BY p.project_name"
    projects = db.execute(sql, params).fetchall()
    summaries: list[dict[str, Any]] = []
    for prow in projects:
        p = dict(prow)
        pid = int(p["id"])
        base = _project_base_completion(p)
        toc_rows = list_toc_extensions(db, pid, limit=500)
        total_days = sum(int(r.get("extension_days") or 0) for r in toc_rows)
        latest_ext = toc_rows[0] if toc_rows else None
        current_completion = (
            (latest_ext.get("next_extension_date") or "").strip()
            if latest_ext
            else base
        )
        summaries.append(
            {
                "project_id": pid,
                "project_code": p.get("project_code") or "",
                "project_name": p.get("project_name") or "",
                "agreement_number": p.get("agreement_number") or p.get("contract_number") or "",
                "start_date": (p.get("start_date") or "")[:10],
                "agreement_base_completion_date": base,
                "current_completion_date": current_completion,
                "total_extension_days": total_days,
                "extension_count": len(toc_rows),
                "latest_document_number": latest_ext.get("document_number") if latest_ext else "",
                "latest_delay_reason": latest_ext.get("delay_reason") if latest_ext else "",
            }
        )
    return summaries


def _parse_bg_rows(form) -> list[dict[str, Any]]:
    originals = form.getlist("bg_original_number")
    original_exp = form.getlist("bg_original_expiry_date")
    original_amt = form.getlist("bg_original_amount")
    extended_nums = form.getlist("bg_extended_number")
    extended_dates = form.getlist("bg_extended_date")
    extended_amts = form.getlist("bg_extended_amount")
    extended_exp = form.getlist("bg_extended_expiry_date")
    bg_remarks = form.getlist("bg_remarks")
    row_count = max(
        len(originals),
        len(extended_nums),
        len(extended_dates),
        len(extended_exp),
    )
    rows: list[dict[str, Any]] = []
    for idx in range(row_count):
        ext_num = (extended_nums[idx] if idx < len(extended_nums) else "").strip()
        ext_date = (extended_dates[idx] if idx < len(extended_dates) else "").strip()
        ext_exp = (extended_exp[idx] if idx < len(extended_exp) else "").strip()
        orig = (originals[idx] if idx < len(originals) else "").strip()
        if not ext_num and not ext_date and not ext_exp and not orig:
            continue
        try:
            amt = float((extended_amts[idx] if idx < len(extended_amts) else "") or 0)
        except ValueError:
            amt = 0.0
        try:
            orig_amt = float((original_amt[idx] if idx < len(original_amt) else "") or 0)
        except ValueError:
            orig_amt = 0.0
        rows.append(
            {
                "sort_order": len(rows),
                "original_bg_number": orig,
                "original_bg_expiry_date": (original_exp[idx] if idx < len(original_exp) else "").strip(),
                "original_bg_amount": orig_amt,
                "extended_bg_number": ext_num,
                "extended_bg_date": ext_date,
                "extended_bg_amount": amt,
                "extended_bg_expiry_date": ext_exp,
                "remarks": (bg_remarks[idx] if idx < len(bg_remarks) else "").strip(),
            }
        )
    return rows


def save_toc_extension(db, form, username: str) -> int:
    prepare_toc_extension_db(db)
    try:
        project_id = int(form.get("project_id") or 0)
    except (TypeError, ValueError):
        raise ValueError("Select a project.") from None
    if project_id <= 0:
        raise ValueError("Select a project.")

    toc_id_raw = (form.get("toc_id") or "").strip()
    toc_id = int(toc_id_raw) if toc_id_raw.isdigit() else None
    toc_date = (form.get("toc_date") or _today()).strip()[:10]
    if not _parse_date(toc_date):
        raise ValueError("Enter a valid TOC date.")

    ctx = get_project_agreement_context(db, project_id)
    if not ctx:
        raise ValueError("Project not found.")

    agreement_base = (form.get("agreement_base_completion_date") or ctx["agreement_base_completion_date"] or "").strip()[:10]
    previous = (form.get("previous_completion_date") or ctx["previous_completion_date"] or agreement_base or "").strip()[:10]
    next_ext = (form.get("next_extension_date") or "").strip()[:10]
    if not next_ext:
        raise ValueError("Enter the next extension / revised completion date.")
    if previous and _parse_date(next_ext) and _parse_date(previous):
        if _parse_date(next_ext) <= _parse_date(previous):
            raise ValueError("Next extension date must be after the previous completion date.")

    ext_days = _days_between(previous, next_ext)
    if ext_days is None:
        try:
            ext_days = int(form.get("extension_days") or 0)
        except ValueError:
            ext_days = 0
    if ext_days < 0:
        ext_days = 0

    delay_reason = (form.get("delay_reason") or "").strip()
    if not delay_reason:
        raise ValueError("Select a delay reason.")
    status = (form.get("status") or "Draft").strip()
    if status not in TOC_STATUSES:
        status = "Draft"

    agreement_number = (form.get("agreement_number") or ctx.get("agreement_number") or "").strip()
    delay_description = (form.get("delay_description") or "").strip()
    remarks = (form.get("remarks") or "").strip()
    now = _now_ts()

    if toc_id:
        existing = db.execute(
            "SELECT id FROM project_toc_extensions WHERE id=?", (toc_id,)
        ).fetchone()
        if not existing:
            raise ValueError("TOC record not found.")
        doc_no = (form.get("document_number") or "").strip()
        if not doc_no:
            row = db.execute(
                "SELECT document_number FROM project_toc_extensions WHERE id=?", (toc_id,)
            ).fetchone()
            doc_no = row["document_number"] if row else next_toc_document_number(db, toc_date)
        db.execute(
            "UPDATE project_toc_extensions SET "
            "document_number=?, project_id=?, toc_date=?, agreement_number=?, "
            "agreement_base_completion_date=?, previous_completion_date=?, next_extension_date=?, "
            "extension_days=?, delay_reason=?, delay_description=?, remarks=?, status=?, modified_at=? "
            "WHERE id=?",
            (
                doc_no,
                project_id,
                toc_date,
                agreement_number,
                agreement_base,
                previous,
                next_ext,
                ext_days,
                delay_reason,
                delay_description,
                remarks,
                status,
                now,
                toc_id,
            ),
        )
        db.execute(
            "DELETE FROM project_toc_bg_extensions WHERE toc_extension_id=?", (toc_id,)
        )
        saved_id = toc_id
    else:
        doc_no = next_toc_document_number(db, toc_date)
        cur = db.execute(
            "INSERT INTO project_toc_extensions("
            "document_number, project_id, toc_date, agreement_number, "
            "agreement_base_completion_date, previous_completion_date, next_extension_date, "
            "extension_days, delay_reason, delay_description, remarks, status, "
            "created_by, created_at, modified_at"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                doc_no,
                project_id,
                toc_date,
                agreement_number,
                agreement_base,
                previous,
                next_ext,
                ext_days,
                delay_reason,
                delay_description,
                remarks,
                status,
                username,
                now,
                now,
            ),
        )
        saved_id = int(cur.lastrowid)

    for bg in _parse_bg_rows(form):
        db.execute(
            "INSERT INTO project_toc_bg_extensions("
            "toc_extension_id, sort_order, original_bg_number, original_bg_expiry_date, "
            "original_bg_amount, extended_bg_number, extended_bg_date, extended_bg_amount, "
            "extended_bg_expiry_date, remarks"
            ") VALUES(?,?,?,?,?,?,?,?,?,?)",
            (
                saved_id,
                bg["sort_order"],
                bg["original_bg_number"],
                bg["original_bg_expiry_date"],
                bg["original_bg_amount"],
                bg["extended_bg_number"],
                bg["extended_bg_date"],
                bg["extended_bg_amount"],
                bg["extended_bg_expiry_date"],
                bg["remarks"],
            ),
        )

    db.commit()
    return saved_id
