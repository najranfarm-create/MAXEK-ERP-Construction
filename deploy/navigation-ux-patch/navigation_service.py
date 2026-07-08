"""Page navigation helpers — breadcrumbs and back URLs (main → department → module → detail)."""

from __future__ import annotations

from typing import Any
from urllib.parse import urlencode

from flask import Request, url_for

from ui_shell_config import (
    DEPARTMENT_PORTAL_MENUS,
    resolve_department_portal_for_request,
    resolve_department_portal_slug,
)


_SKIP_ENDPOINTS = frozenset(
    {
        "login",
        "logout",
        "index",
        "static",
        "dashboard",
        "dashboard_choice_b",
        "super_admin_platform_dashboard",
    }
)


def _endpoint_menu_labels() -> dict[str, dict[str, str]]:
    """Map Flask endpoint → {label, dept_slug, dept_label}."""
    index: dict[str, dict[str, str]] = {}
    for dept_slug, menu in DEPARTMENT_PORTAL_MENUS.items():
        canonical = resolve_department_portal_slug(dept_slug)
        dept_label = dept_slug.replace("-", " ").title()
        for item in menu:
            endpoints = list(item.get("active_endpoints") or [])
            ep = item.get("endpoint")
            if ep and ep not in endpoints:
                endpoints.append(ep)
            label = item.get("label") or ep or ""
            for endpoint in endpoints:
                if not endpoint:
                    continue
                existing = index.get(endpoint)
                if existing and existing.get("dept_slug") == canonical:
                    continue
                index[endpoint] = {
                    "label": label,
                    "dept_slug": canonical,
                    "dept_label": dept_label,
                }
    return index


_ENDPOINT_LABELS: dict[str, dict[str, str]] | None = None


def _labels_for_endpoint(endpoint: str) -> dict[str, str]:
    global _ENDPOINT_LABELS
    if _ENDPOINT_LABELS is None:
        _ENDPOINT_LABELS = _endpoint_menu_labels()
    return _ENDPOINT_LABELS.get(endpoint, {})


def _strip_crud_params(request: Request) -> str:
    """Module list URL — same route without view/edit/new/hash params."""
    if not request.endpoint or request.endpoint in _SKIP_ENDPOINTS:
        return ""
    params = {
        k: v
        for k, v in request.args.items()
        if k not in ("view", "edit", "new", "view_document", "edit_document")
        and not k.startswith("_")
    }
    base = url_for(request.endpoint, **(request.view_args or {}))
    if params:
        return f"{base}?{urlencode(params)}"
    return base


def _crud_mode(request: Request) -> str:
    if request.args.get("view") or request.args.get("view_document"):
        return "view"
    if request.args.get("edit") or request.args.get("edit_document"):
        return "edit"
    if request.args.get("new") in ("1", "true", "yes"):
        return "create"
    return "list"


def build_page_navigation(
    request: Request,
    *,
    dept_slug: str | None = None,
    session_dept_slug: str | None = None,
    nav_toolbar_slug: str | None = None,
    primary_dashboard_endpoint: str = "dashboard",
) -> dict[str, Any]:
    """Back URLs and optional breadcrumb_items for the current request."""
    endpoint = request.endpoint or ""
    if endpoint in _SKIP_ENDPOINTS:
        return {
            "page_crud_mode": "list",
            "page_list_url": "",
            "page_parent_url": url_for(primary_dashboard_endpoint),
            "pro_shell_back_url": url_for(primary_dashboard_endpoint),
            "pro_shell_home_url": url_for(primary_dashboard_endpoint),
            "page_nav_show": False,
        }

    view_slug = (request.view_args or {}).get("slug")
    resolved_dept = dept_slug or resolve_department_portal_for_request(
        endpoint,
        view_slug=view_slug,
        dept_hint=(request.args.get("dept") or "").strip() or None,
        session_slug=session_dept_slug,
        nav_toolbar_slug=nav_toolbar_slug,
    )

    meta = _labels_for_endpoint(endpoint)
    module_label = meta.get("label") or (endpoint.replace("_", " ").title() if endpoint else "Module")
    dept_label = meta.get("dept_label") or "Department"
    dept_slug_final = resolved_dept or meta.get("dept_slug")

    list_url = _strip_crud_params(request)
    crud_mode = _crud_mode(request)

    if endpoint == "department_portal" and view_slug:
        parent_url = url_for(primary_dashboard_endpoint)
        back_url = parent_url
        crumbs = [
            {"label": "Dashboard", "url": url_for(primary_dashboard_endpoint)},
            {"label": resolve_department_portal_slug(view_slug).replace("-", " ").title()},
        ]
    elif crud_mode in ("view", "edit", "create"):
        parent_url = (
            url_for("department_portal", slug=dept_slug_final)
            if dept_slug_final
            else url_for(primary_dashboard_endpoint)
        )
        back_url = list_url or parent_url
        crumbs = [
            {"label": "Dashboard", "url": url_for(primary_dashboard_endpoint)},
        ]
        if dept_slug_final:
            crumbs.append(
                {
                    "label": dept_label,
                    "url": url_for("department_portal", slug=dept_slug_final),
                }
            )
        crumbs.append({"label": module_label, "url": list_url})
        mode_label = {"view": "View", "edit": "Edit", "create": "New"}.get(crud_mode, "")
        if mode_label:
            crumbs.append({"label": mode_label})
    else:
        parent_url = (
            url_for("department_portal", slug=dept_slug_final)
            if dept_slug_final
            else url_for(primary_dashboard_endpoint)
        )
        back_url = parent_url
        crumbs = [
            {"label": "Dashboard", "url": url_for(primary_dashboard_endpoint)},
        ]
        if dept_slug_final:
            crumbs.append(
                {
                    "label": dept_label,
                    "url": url_for("department_portal", slug=dept_slug_final),
                }
            )
        crumbs.append({"label": module_label})

    back_label = "Back"
    if crud_mode in ("view", "edit", "create"):
        back_label = f"Back to {module_label}"
    elif dept_slug_final:
        back_label = f"Back to {dept_label}"

    return {
        "page_crud_mode": crud_mode,
        "page_list_url": list_url,
        "page_parent_url": parent_url,
        "pro_shell_back_url": back_url,
        "pro_shell_home_url": url_for(primary_dashboard_endpoint),
        "page_nav_back_url": back_url,
        "page_nav_back_label": back_label,
        "page_nav_parent_url": parent_url,
        "page_nav_parent_label": f"Back to {dept_label}" if dept_slug_final else "Dashboard",
        "page_nav_show": True,
        "auto_breadcrumb_items": crumbs,
    }
