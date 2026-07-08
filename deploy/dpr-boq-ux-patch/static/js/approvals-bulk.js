(function () {
  "use strict";

  const MAX_DEFAULT = 10;
  const MAX_WARNING = "Maximum 10 items can be selected at a time.";

  function postApproval(actionUrl, payload) {
    const body = new FormData();
    Object.keys(payload).forEach(function (key) {
      const value = payload[key];
      if (Array.isArray(value)) {
        value.forEach(function (entry) {
          body.append(key, entry);
        });
        return;
      }
      body.append(key, value);
    });
    return fetch(actionUrl, {
      method: "POST",
      body: body,
      credentials: "same-origin",
      redirect: "manual",
    });
  }

  function submitBulkForm(actionUrl, ids, bulkAction, role) {
    const form = document.createElement("form");
    form.method = "post";
    form.action = actionUrl;
    form.style.display = "none";

    ids.forEach(function (id) {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = "approval_ids";
      input.value = id;
      form.appendChild(input);
    });

    ["action", "role"].forEach(function (name) {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      input.value = name === "action" ? bulkAction : role;
      form.appendChild(input);
    });

    document.body.appendChild(form);
    if (typeof form.requestSubmit === "function") {
      form.requestSubmit();
      return;
    }
    form.submit();
  }

  function syncSelectAllControls(root, selectAllEls, checks, selectedCount, maxSelected) {
    selectAllEls.forEach(function (selectAll) {
      if (!selectAll) {
        return;
      }
      selectAll.indeterminate = selectedCount > 0 && selectedCount < checks.length;
      selectAll.checked = checks.length > 0 && selectedCount === checks.length;
    });
  }

  function initApprovalsBulk() {
    const root = document.querySelector("[data-approvals-module]");
    if (!root) {
      return;
    }

    const maxSelected = parseInt(root.getAttribute("data-bulk-max") || String(MAX_DEFAULT), 10) || MAX_DEFAULT;
    const bulkAction = (root.getAttribute("data-bulk-action") || "approve").trim() || "approve";
    const actionUrl = root.getAttribute("data-action-url") || "";
    const role = root.getAttribute("data-approval-role") || "checker";
    const toolbar = root.querySelector("[data-approvals-bulk-toolbar]");
    const countEl = root.querySelector("[data-approvals-bulk-count]");
    const submitBtn = root.querySelector("[data-approvals-bulk-submit]");
    const rowChecks = () => Array.from(root.querySelectorAll(".approvals-row-check"));
    const selectAllEls = () =>
      Array.from(root.querySelectorAll("[data-approvals-select-all], [data-approvals-select-all-header]"));

    function selectedChecks() {
      return rowChecks().filter((el) => el.checked);
    }

    function updateUi() {
      const selected = selectedChecks();
      const count = selected.length;
      const checks = rowChecks();
      if (countEl) {
        countEl.textContent = count + " selected (max " + maxSelected + ")";
      }
      if (submitBtn) {
        submitBtn.disabled = count === 0;
      }
      syncSelectAllControls(root, selectAllEls(), checks, count, maxSelected);
    }

    root.addEventListener("change", function (event) {
      const target = event.target;
      if (!(target instanceof HTMLInputElement)) {
        return;
      }

      if (target.matches("[data-approvals-select-all], [data-approvals-select-all-header]")) {
        const checks = rowChecks();
        const shouldSelect = target.checked;
        checks.forEach((check, index) => {
          check.checked = shouldSelect && index < maxSelected;
        });
        if (shouldSelect && checks.length > maxSelected) {
          window.alert(MAX_WARNING);
        }
        updateUi();
        return;
      }

      if (target.matches(".approvals-row-check")) {
        const selected = selectedChecks();
        if (target.checked && selected.length > maxSelected) {
          target.checked = false;
          window.alert(MAX_WARNING);
        }
        updateUi();
      }
    });

    root.addEventListener("click", function (event) {
      const rejectBtn = event.target.closest("[data-approval-reject]");
      if (rejectBtn) {
        event.preventDefault();
        const approvalId = rejectBtn.getAttribute("data-approval-id");
        if (!approvalId) {
          return;
        }
        const rejectRole = rejectBtn.getAttribute("data-approval-role") || role;
        const comments = window.prompt("Rejection reason (required):", "");
        if (comments === null) {
          return;
        }
        if (!comments.trim()) {
          window.alert("Rejection reason is required.");
          return;
        }
        rejectBtn.disabled = true;
        postApproval(actionUrl, {
          approval_id: approvalId,
          action: "reject",
          role: rejectRole,
          comments: comments.trim(),
        })
          .then(function () {
            window.location.reload();
          })
          .catch(function () {
            window.location.reload();
          });
        return;
      }

      const verifyForm = event.target.closest("[data-approval-verify-form]");
      if (verifyForm && event.target.closest("[data-approval-verify]")) {
        event.preventDefault();
        if (!window.confirm("Verify this item?")) {
          return;
        }
        verifyForm.submit();
      }
    });

    if (submitBtn && toolbar && actionUrl) {
      submitBtn.addEventListener("click", function () {
        const ids = selectedChecks().map((el) => el.value).filter(Boolean);
        if (!ids.length) {
          return;
        }
        const verb = role === "checker" ? "verify" : "approve";
        if (!window.confirm("Apply " + verb + " to " + ids.length + " selected item(s)?")) {
          return;
        }
        submitBtn.disabled = true;
        submitBtn.textContent = "Processing…";
        submitBulkForm(actionUrl, ids, bulkAction, role);
      });
    }

    const perPageSelect = root.querySelector("[data-approvals-per-page]");
    if (perPageSelect) {
      perPageSelect.addEventListener("change", function () {
        const url = new URL(window.location.href);
        url.searchParams.set("per_page", perPageSelect.value);
        url.searchParams.set("page", "1");
        window.location.href = url.toString();
      });
    }

    updateUi();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initApprovalsBulk);
  } else {
    initApprovalsBulk();
  }
})();
