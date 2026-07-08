from flask import current_app, flash, redirect, render_template, request, url_for
from flask_login import login_required, login_user, logout_user

from app.auth.forms import LoginForm, ProfileForm, RegisterForm
from app.auth import auth_bp
from app.extensions import db
from app.lib.auth import get_current_user, get_current_user_or_none
from app.models.user import User


@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if get_current_user_or_none():
        return redirect(url_for("main.dashboard"))

    form = LoginForm()
    if form.validate_on_submit():
        email = form.email.data.lower().strip()
        user = User.query.filter_by(email=email).first()

        if user is None or not user.check_password(form.password.data):
            flash("Invalid email or password.", "danger")
            return render_template("auth/login.html", form=form)

        if not user.is_active_user:
            flash("Your account has been deactivated. Contact an administrator.", "danger")
            return render_template("auth/login.html", form=form)

        user.touch()
        db.session.commit()
        login_user(user, remember=form.remember_me.data)
        next_page = request.args.get("next")
        if next_page and next_page.startswith("/"):
            return redirect(next_page)
        return redirect(url_for("main.dashboard"))

    return render_template("auth/login.html", form=form)


@auth_bp.route("/logout")
@login_required
def logout():
    logout_user()
    flash("You have been signed out.", "info")
    return redirect(url_for("auth.login"))


@auth_bp.route("/register", methods=["GET", "POST"])
def register():
    if not current_app.config.get("ALLOW_REGISTRATION", True):
        flash("Registration is disabled. Contact an administrator.", "warning")
        return redirect(url_for("auth.login"))

    if get_current_user_or_none():
        return redirect(url_for("main.dashboard"))

    form = RegisterForm()
    if form.validate_on_submit():
        user = User(
            email=form.email.data.lower().strip(),
            name=form.name.data.strip(),
            role="user",
        )
        user.set_password(form.password.data)
        db.session.add(user)
        db.session.commit()

        login_user(user)
        flash("Welcome to MAXEK ERP. Your account has been created.", "success")
        return redirect(url_for("main.dashboard"))

    return render_template("auth/register.html", form=form)


@auth_bp.route("/profile", methods=["GET", "POST"])
@login_required
def profile():
    user = get_current_user()
    form = ProfileForm(obj=user)

    if form.validate_on_submit():
        user.name = form.name.data.strip()

        if form.new_password.data:
            if not user.check_password(form.current_password.data):
                flash("Current password is incorrect.", "danger")
                return render_template("auth/profile.html", form=form, user=user)
            user.set_password(form.new_password.data)

        user.touch()
        db.session.commit()
        flash("Profile updated.", "success")
        return redirect(url_for("auth.profile"))

    return render_template("auth/profile.html", form=form, user=user)
