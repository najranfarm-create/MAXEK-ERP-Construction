(function () {
  "use strict";

  const MAX_DEFAULT = 10;

  function initApprovalsBulk() {
    const root = document.querySelector("[data-approvals-module]");
    if (!root) {
      return;
    }

    const maxSelected = parseInt(root.getAttribute("data-bulk-max") || String(MAX_DEFAULT), 10) || MAX_DEFAULT;
    const bulkAction = (root.getAttribute("data-bulk-action") || "").trim();
    const actionUrl = root.getAttribute("data-action-url") || "";
    const role = root.getAttribute("data-approval-role") || "checker";
    const toolbar = root.querySelector("[data-approvals-bulk-toolbar]");
    if (!toolbar || !bulkAction || !actionUrl) {
      return;
    }

    const selectAll = toolbar.querySelector("[data-approvals-select-all]");
    const countEl = toolbar.querySelector("[data-approvals-bulk-count]");
    const submitBtn = toolbar.querySelector("[data-approvals-bulk-submit]");
    const rowChecks = () => Array.from(root.querySelectorAll(".approvals-row-check"));

    function selectedChecks() {
      return rowChecks().filter((el) => el.checked);
    }

    function updateUi() {
      const selected = selectedChecks();
      const count = selected.length;
      if (countEl) {
        countEl.textContent = count + " selected (max " + maxSelected + ")";
      }
      if (submitBtn) {
        submitBtn.disabled = count === 0;
      }
      if (selectAll) {
        const checks = rowChecks();
        selectAll.indeterminate = count > 0 && count < checks.length;
        selectAll.checked = checks.length > 0 && count === checks.length;
      }
    }

    function setChecked(check, checked) {
      check.checked = checked;
    }

    root.addEventListener("change", function (event) {
      const target = event.target;
      if (!(target instanceof HTMLInputElement)) {
        return;
      }

      if (target.matches("[data-approvals-select-all]")) {
        const checks = rowChecks();
        checks.forEach((check, index) => {
          setChecked(check, target.checked && index < maxSelected);
        });
        updateUi();
        return;
      }

      if (target.matches(".approvals-row-check")) {
        const selected = selectedChecks();
        if (target.checked && selected.length > maxSelected) {
          target.checked = false;
          window.alert("You can select at most " + maxSelected + " items at once.");
        }
        updateUi();
      }
    });

    if (submitBtn) {
      submitBtn.addEventListener("click", function () {
        const ids = selectedChecks().map((el) => el.value).filter(Boolean);
        if (!ids.length) {
          return;
        }
        const label = bulkAction === "verify" ? "verify" : "approve";
        if (!window.confirm("Apply " + label + " to " + ids.length + " selected item(s)?")) {
          return;
        }
        submitBtn.disabled = true;
        submitBtn.textContent = "Processing…";

        (async function runBulk() {
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

          for (let i = 0; i < ids.length; i += 1) {
            const body = new FormData();
            body.append("approval_id", ids[i]);
            body.append("action", bulkAction);
            body.append("role", role);
            await fetch(actionUrl, {
              method: "POST",
              body: body,
              credentials: "same-origin",
              redirect: "manual",
            });
          }
          window.location.reload();
        })().catch(function () {
          window.location.reload();
        });
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
