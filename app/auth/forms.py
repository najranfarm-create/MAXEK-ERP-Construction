from flask_wtf import FlaskForm
from wtforms import BooleanField, PasswordField, StringField, SubmitField
from wtforms.validators import DataRequired, EqualTo, Length, Optional, ValidationError

from app.lib.validators import ERPEmail
from app.models.user import User


class LoginForm(FlaskForm):
    email = StringField("Email", validators=[DataRequired(), ERPEmail()])
    password = PasswordField("Password", validators=[DataRequired()])
    remember_me = BooleanField("Remember me")
    submit = SubmitField("Sign in")


class RegisterForm(FlaskForm):
    name = StringField("Full name", validators=[DataRequired(), Length(min=2, max=100)])
    email = StringField("Email", validators=[DataRequired(), ERPEmail()])
    password = PasswordField(
        "Password",
        validators=[DataRequired(), Length(min=8, max=128)],
    )
    confirm_password = PasswordField(
        "Confirm password",
        validators=[DataRequired(), EqualTo("password", message="Passwords must match.")],
    )
    submit = SubmitField("Create account")

    def validate_email(self, field: StringField) -> None:
        if User.query.filter_by(email=field.data.lower().strip()).first():
            raise ValidationError("Email is already registered.")


class ProfileForm(FlaskForm):
    name = StringField("Full name", validators=[DataRequired(), Length(min=2, max=100)])
    current_password = PasswordField("Current password")
    new_password = PasswordField(
        "New password",
        validators=[Optional(), Length(min=8, max=128)],
    )
    confirm_password = PasswordField(
        "Confirm new password",
        validators=[Optional(), EqualTo("new_password", message="Passwords must match.")],
    )
    submit = SubmitField("Save profile")

    def validate(self, extra_validators=None) -> bool:
        if not super().validate(extra_validators=extra_validators):
            return False
        if self.new_password.data and not self.current_password.data:
            self.current_password.errors.append("Enter your current password to set a new one.")
            return False
        return True
