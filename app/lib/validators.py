import re

from wtforms.validators import Email, ValidationError

_EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

try:
    from email_validator import EmailNotValidError, validate_email
except ImportError:  # pragma: no cover
    validate_email = None
    EmailNotValidError = ValueError


class ERPEmail(Email):
    """Email validator that allows internal/reserved domains (e.g. admin@maxek.local)."""

    def __call__(self, form, field) -> None:
        if not field.data:
            return

        value = str(field.data).strip().lower()
        if validate_email is not None:
            try:
                validate_email(value, check_deliverability=False)
                return
            except EmailNotValidError:
                if _EMAIL_PATTERN.match(value):
                    return
                raise ValidationError("Invalid email address.") from None

        super().__call__(form, field)
