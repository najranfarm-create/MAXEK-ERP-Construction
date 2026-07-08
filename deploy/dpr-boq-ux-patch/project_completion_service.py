"""Project completion details — completion date, warranty, maintenance, documents & certificate stitching."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

COMPLETION_DOC_TYPES = (
    "Completion Certificate",
    "Provisional Completion Certificate",
    "Final Completion Certificate",
    "Handover Document",
    "Defects Liability Certificate",
    "Warranty Certificate",
    "O&M Manual",
    "As-Built Drawings",
    "Final Account / Bill",
    "Maintenance Handover",
    "Other",
)

COMPLETION_STATUSES = ("Draft", "Submitted", "Approved", "Handed Over")


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


def ensure_project_completion_tables(db) -> None:
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS project_completion_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_number TEXT NOT NULL,
            project_id INTEGER NOT NULL,
            project_completion_date TEXT,
            warranty_completion_date TEXT,
            maintenance_conditions TEXT,
            maintenance_end_date TEXT,
            certificate_stitching_required INTEGER DEFAULT 0,
            certificate_stitched INTEGER DEFAULT 0,
            certificate_stitch_date TEXT,
            certificate_stitch_remarks TEXT,
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
        CREATE TABLE IF NOT EXISTS project_completion_documents(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            completion_id INTEGER NOT NULL,
            sort_order INTEGER DEFAULT 0,
            document_type TEXT,
            document_name TEXT,
            document_date TEXT,
            sent_date TEXT,
            received_date TEXT,
            include_in_stitch INTEGER DEFAULT 0,
            stitched INTEGER DEFAULT 0,
            remarks TEXT,
            stored_filename TEXT,
            original_filename TEXT,
            FOREIGN KEY(completion_id) REFERENCES project_completion_records(id)
        )
        """
    )
    db.execute(
        "CREATE INDEX IF NOT EXISTS idx_project_completion_project "
        "ON project_completion_records(project_id, project_completion_date)"
    )
    db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_project_completion_docno "
        "ON project_completion_records(document_number)"
    )
    db.execute(
        "CREATE INDEX IF NOT EXISTS idx_project_completion_docs "
        "ON project_completion_documents(completion_id, sort_order)"
    )


def prepare_project_completion_db(db) -> None:
    ensure_project_completion_tables(db)


def next_completion_document_number(db, ref_date: str | None = None) -> str:
    day = (ref_date or _today())[:10].replace("-", "")
    prefix = f"PC/{day}/"
    row = db.execute(
        "SELECT document_number FROM project_completion_records "
        "WHERE document_number LIKE ? ORDER BY id DESC LIMIT 1",
        (prefix + "%",),
    ).fetchone()
    seq = 1
    if row and row["document_number"]:
        try:
            seq = int(str(row["document_number"]).split("/")[-1]) + 1
        except ValueError:
            seq = 1
    return f"{prefix}{seq:03d}"


def _project_column_names(db) -> set[str]:
    rows = db.execute("PRAGMA table_info(projects)").fetchall()
    return {str(r["name"]) for r in rows}


def get_project_completion_context(db, project_id: int) -> dict[str, Any] | None:
    columns = [
        "id",
        "project_code",
        "project_name",
        "start_date",
        "end_date",
        "planned_completion_date",
        "actual_completion_date",
        "dlp_end_date",
    ]
    available = _project_column_names(db)
    if "completion_time" in available:
        columns.append("completion_time")
    if "warranty_completion_period" in available:
        columns.append("warranty_completion_period")
    row = db.execute(
        f"SELECT {', '.join(columns)} FROM projects WHERE id=?",
        (project_id,),
    ).fetchone()
    if not row:
        return None
    data = dict(row)
    latest = db.execute(
        "SELECT project_completion_date, warranty_completion_date, maintenance_conditions "
        "FROM project_completion_records WHERE project_id=? "
        "ORDER BY id DESC LIMIT 1",
        (project_id,),
    ).fetchone()
    if latest:
        data["last_completion_date"] = latest["project_completion_date"]
        data["last_warranty_date"] = latest["warranty_completion_date"]
        data["last_maintenance_conditions"] = latest["maintenance_conditions"]
    data["planned_completion_date"] = data.get("planned_completion_date") or data.get("end_date")
    data["warranty_completion_date"] = data.get("dlp_end_date") or data.get("last_warranty_date")
    return data


def list_project_completions(db, project_id: int | None = None) -> list[dict[str, Any]]:
    sql = (
        "SELECT c.*, p.project_code, p.project_name FROM project_completion_records c "
        "LEFT JOIN projects p ON c.project_id = p.id WHERE 1=1"
    )
    params: list[Any] = []
    if project_id:
        sql += " AND c.project_id=?"
        params.append(project_id)
    sql += " ORDER BY c.id DESC"
    rows = db.execute(sql, params).fetchall()
    return [dict(r) for r in rows]


def get_project_completion(db, completion_id: int) -> dict[str, Any] | None:
    row = db.execute(
        "SELECT c.*, p.project_code, p.project_name FROM project_completion_records c "
        "LEFT JOIN projects p ON c.project_id = p.id WHERE c.id=?",
        (completion_id,),
    ).fetchone()
    if not row:
        return None
    data = dict(row)
    docs = db.execute(
        "SELECT * FROM project_completion_documents WHERE completion_id=? ORDER BY sort_order, id",
        (completion_id,),
    ).fetchall()
    data["documents"] = [dict(d) for d in docs]
    return data


def _bool_form(value: str | None) -> int:
    return 1 if (value or "").strip().lower() in ("1", "yes", "true", "on") else 0


def parse_documents_from_form(form) -> list[dict[str, Any]]:
    types = form.getlist("doc_type")
    lines: list[dict[str, Any]] = []
    for idx, doc_type in enumerate(types):
        name_list = form.getlist("doc_name")
        date_list = form.getlist("doc_date")
        sent_list = form.getlist("doc_sent_date")
        recv_list = form.getlist("doc_received_date")
        stitch_list = form.getlist("doc_include_stitch")
        stitched_list = form.getlist("doc_stitched")
        remarks_list = form.getlist("doc_remarks")
        id_list = form.getlist("doc_id")
        doc_name = name_list[idx] if idx < len(name_list) else ""
        doc_date = date_list[idx] if idx < len(date_list) else ""
        if not (doc_type or doc_name or doc_date):
            continue
        doc_id_raw = id_list[idx] if idx < len(id_list) else ""
        doc_id = int(doc_id_raw) if str(doc_id_raw).isdigit() else None
        lines.append(
            {
                "id": doc_id,
                "sort_order": idx,
                "document_type": (doc_type or "").strip(),
                "document_name": (doc_name or "").strip(),
                "document_date": (doc_date or "").strip()[:10],
                "sent_date": (sent_list[idx] if idx < len(sent_list) else "").strip()[:10],
                "received_date": (recv_list[idx] if idx < len(recv_list) else "").strip()[:10],
                "include_in_stitch": _bool_form(stitch_list[idx] if idx < len(stitch_list) else ""),
                "stitched": _bool_form(stitched_list[idx] if idx < len(stitched_list) else ""),
                "remarks": (remarks_list[idx] if idx < len(remarks_list) else "").strip(),
            }
        )
    return lines


def save_project_completion(
    db,
    form,
    username: str,
    uploaded_files: dict[int, tuple[str, str]] | None = None,
) -> int:
    project_id = int(form.get("project_id") or 0)
    if not project_id:
        raise ValueError("Select a project.")

    completion_id_raw = (form.get("completion_id") or "").strip()
    ref_date = (form.get("project_completion_date") or "").strip()[:10] or _today()
    project_completion_date = ref_date
    warranty_completion_date = (form.get("warranty_completion_date") or "").strip()[:10]
    maintenance_conditions = (form.get("maintenance_conditions") or "").strip()
    maintenance_end_date = (form.get("maintenance_end_date") or "").strip()[:10]
    certificate_stitching_required = _bool_form(form.get("certificate_stitching_required"))
    certificate_stitched = _bool_form(form.get("certificate_stitched"))
    certificate_stitch_date = (form.get("certificate_stitch_date") or "").strip()[:10]
    certificate_stitch_remarks = (form.get("certificate_stitch_remarks") or "").strip()
    remarks = (form.get("remarks") or "").strip()
    status = (form.get("status") or "Draft").strip() or "Draft"
    documents = parse_documents_from_form(form)
    now = _now_ts()

    if completion_id_raw:
        completion_id = int(completion_id_raw)
        db.execute(
            "UPDATE project_completion_records SET project_id=?, project_completion_date=?, "
            "warranty_completion_date=?, maintenance_conditions=?, maintenance_end_date=?, "
            "certificate_stitching_required=?, certificate_stitched=?, certificate_stitch_date=?, "
            "certificate_stitch_remarks=?, remarks=?, status=?, modified_at=? WHERE id=?",
            (
                project_id,
                project_completion_date,
                warranty_completion_date,
                maintenance_conditions,
                maintenance_end_date,
                certificate_stitching_required,
                certificate_stitched,
                certificate_stitch_date,
                certificate_stitch_remarks,
                remarks,
                status,
                now,
                completion_id,
            ),
        )
        existing_docs = {
            r["id"]: dict(r)
            for r in db.execute(
                "SELECT id, stored_filename, original_filename FROM project_completion_documents "
                "WHERE completion_id=?",
                (completion_id,),
            ).fetchall()
        }
        kept_ids: set[int] = set()
        for line in documents:
            line_id = line.get("id")
            stored = original = None
            if line_id and line_id in existing_docs:
                stored = existing_docs[line_id].get("stored_filename")
                original = existing_docs[line_id].get("original_filename")
            upload_meta = (uploaded_files or {}).get(line["sort_order"])
            if upload_meta:
                stored, original = upload_meta
            if line_id and line_id in existing_docs:
                kept_ids.add(line_id)
                db.execute(
                    "UPDATE project_completion_documents SET sort_order=?, document_type=?, "
                    "document_name=?, document_date=?, sent_date=?, received_date=?, "
                    "include_in_stitch=?, stitched=?, remarks=?, "
                    "stored_filename=COALESCE(?, stored_filename), "
                    "original_filename=COALESCE(?, original_filename) WHERE id=?",
                    (
                        line["sort_order"],
                        line["document_type"],
                        line["document_name"],
                        line["document_date"],
                        line["sent_date"],
                        line["received_date"],
                        line["include_in_stitch"],
                        line["stitched"],
                        line["remarks"],
                        stored,
                        original,
                        line_id,
                    ),
                )
            else:
                cur = db.execute(
                    "INSERT INTO project_completion_documents("
                    "completion_id, sort_order, document_type, document_name, document_date, "
                    "sent_date, received_date, include_in_stitch, stitched, remarks, "
                    "stored_filename, original_filename"
                    ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                    (
                        completion_id,
                        line["sort_order"],
                        line["document_type"],
                        line["document_name"],
                        line["document_date"],
                        line["sent_date"],
                        line["received_date"],
                        line["include_in_stitch"],
                        line["stitched"],
                        line["remarks"],
                        stored,
                        original,
                    ),
                )
                kept_ids.add(cur.lastrowid)
        for doc_id, doc_row in existing_docs.items():
            if doc_id not in kept_ids:
                db.execute("DELETE FROM project_completion_documents WHERE id=?", (doc_id,))
    else:
        document_number = next_completion_document_number(db, ref_date)
        cur = db.execute(
            "INSERT INTO project_completion_records("
            "document_number, project_id, project_completion_date, warranty_completion_date, "
            "maintenance_conditions, maintenance_end_date, certificate_stitching_required, "
            "certificate_stitched, certificate_stitch_date, certificate_stitch_remarks, "
            "remarks, status, created_by, created_at, modified_at"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                document_number,
                project_id,
                project_completion_date,
                warranty_completion_date,
                maintenance_conditions,
                maintenance_end_date,
                certificate_stitching_required,
                certificate_stitched,
                certificate_stitch_date,
                certificate_stitch_remarks,
                remarks,
                status,
                username,
                now,
                now,
            ),
        )
        completion_id = cur.lastrowid
        for line in documents:
            stored = original = None
            upload_meta = (uploaded_files or {}).get(line["sort_order"])
            if upload_meta:
                stored, original = upload_meta
            db.execute(
                "INSERT INTO project_completion_documents("
                "completion_id, sort_order, document_type, document_name, document_date, "
                "sent_date, received_date, include_in_stitch, stitched, remarks, "
                "stored_filename, original_filename"
                ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    completion_id,
                    line["sort_order"],
                    line["document_type"],
                    line["document_name"],
                    line["document_date"],
                    line["sent_date"],
                    line["received_date"],
                    line["include_in_stitch"],
                    line["stitched"],
                    line["remarks"],
                    stored,
                    original,
                ),
            )

    if project_completion_date:
        db.execute(
            "UPDATE projects SET actual_completion_date=COALESCE(actual_completion_date, ?) WHERE id=?",
            (project_completion_date, project_id),
        )
    if warranty_completion_date:
        db.execute(
            "UPDATE projects SET dlp_end_date=COALESCE(dlp_end_date, ?) WHERE id=?",
            (warranty_completion_date, project_id),
        )

    db.commit()
    return completion_id
