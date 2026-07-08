(function () {
  "use strict";

  const MAX_DEFAULT = 10;

  function postApproval(actionUrl, payload) {
    const body = new FormData();
    Object.keys(payload).forEach(function (key) {
      body.append(key, payload[key]);
    });
    return fetch(actionUrl, {
      method: "POST",
      body: body,
      credentials: "same-origin",
      redirect: "manual",
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
    if (!toolbar || !actionUrl) {
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

    root.addEventListener("change", function (event) {
      const target = event.target;
      if (!(target instanceof HTMLInputElement)) {
        return;
      }

      if (target.matches("[data-approvals-select-all]")) {
        const checks = rowChecks();
        checks.forEach((check, index) => {
          check.checked = target.checked && index < maxSelected;
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
        const verb = role === "checker" ? "verify" : "approve";
        if (!window.confirm("Apply " + verb + " to " + ids.length + " selected item(s)?")) {
          return;
        }
        submitBtn.disabled = true;
        submitBtn.textContent = "Processing…";

        (async function runBulk() {
          for (let i = 0; i < ids.length; i += 1) {
            await postApproval(actionUrl, {
              approval_id: ids[i],
              action: bulkAction,
              role: role,
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
