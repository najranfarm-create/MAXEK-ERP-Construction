from functools import wraps
from typing import Callable, TypeVar

from flask import abort
from flask_login import current_user

from app.models.user import User

F = TypeVar("F", bound=Callable)


def get_current_user() -> User:
    if not current_user.is_authenticated:
        raise RuntimeError("Not authenticated")
    return current_user  # type: ignore[return-value]


def get_current_user_or_none() -> User | None:
    if not current_user.is_authenticated:
        return None
    return current_user  # type: ignore[return-value]


def require_admin() -> User:
    user = get_current_user()
    if user.role != "admin":
        raise PermissionError("Admin access required")
    return user


def admin_required(view: F) -> F:
    @wraps(view)
    def wrapped(*args, **kwargs):
        user = get_current_user_or_none()
        if user is None:
            abort(401)
        if user.role != "admin":
            abort(403)
        return view(*args, **kwargs)

    return wrapped  # type: ignore[return-value]


def role_required(*roles: str) -> Callable[[F], F]:
    def decorator(view: F) -> F:
        @wraps(view)
        def wrapped(*args, **kwargs):
            user = get_current_user_or_none()
            if user is None:
                abort(401)
            if user.role not in roles:
                abort(403)
            return view(*args, **kwargs)

        return wrapped  # type: ignore[return-value]

    return decorator


def owner_required(get_owner_id: Callable[..., int | None]) -> Callable[[F], F]:
    """Ensure the current user owns a resource (or is admin)."""

    def decorator(view: F) -> F:
        @wraps(view)
        def wrapped(*args, **kwargs):
            user = get_current_user_or_none()
            if user is None:
                abort(401)
            if user.role == "admin":
                return view(*args, **kwargs)
            owner_id = get_owner_id(*args, **kwargs)
            if owner_id is None or owner_id != user.id:
                abort(403)
            return view(*args, **kwargs)

        return wrapped  # type: ignore[return-value]

    return decorator
