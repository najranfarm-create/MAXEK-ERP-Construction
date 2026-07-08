(function () {
  "use strict";

  function parseNum(value) {
    var n = parseFloat(String(value || "").replace(/,/g, ""));
    return Number.isFinite(n) ? n : 0;
  }

  function formatMoney(n) {
    return parseNum(n).toFixed(2);
  }

  function qs(sel, root) {
    return (root || document).querySelector(sel);
  }

  function qsa(sel, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(sel));
  }

  function initModule() {
    var module = qs("[data-petty-cash-module]");
    if (!module) return;

    var form = qs("[data-petty-form]", module);
    var panel = qs("#petty-request-form", module);
    var linesBody = qs("[data-petty-purpose-body]", module);
    if (!form || !linesBody) return;

    var isReadonly = form.getAttribute("data-readonly") === "1";

    function setFormAction(action) {
      var input = qs("[data-petty-form-action]", form);
      if (input) input.value = action;
    }

    function syncStaffHidden() {
      var staffSelect = qs("[data-petty-staff]", form);
      var opt = staffSelect && staffSelect.selectedOptions[0];
      var nameHidden = qs("[data-petty-staff-name-hidden]", form);
      var idHidden = qs("[data-petty-staff-id-hidden]", form);
      if (nameHidden) nameHidden.value = opt ? opt.getAttribute("data-name") || "" : "";
      if (idHidden) idHidden.value = staffSelect ? staffSelect.value : "";
    }

    function fillStaffFields() {
      var staffSelect = qs("[data-petty-staff]", form);
      var opt = staffSelect && staffSelect.selectedOptions[0];
      var emp = qs("[data-petty-employee-id]", form);
      var dept = qs("[data-petty-department]", form);
      if (emp) emp.value = opt ? opt.getAttribute("data-code") || "" : "";
      if (dept) dept.value = opt ? opt.getAttribute("data-dept") || "" : "";
      syncStaffHidden();
    }

    function fillProjectFields() {
      var projectSelect = qs("[data-petty-project]", form);
      var opt = projectSelect && projectSelect.selectedOptions[0];
      var projectId = qs("[data-petty-project-id]", form);
      if (projectId) {
        projectId.value = opt
          ? opt.getAttribute("data-code") || opt.value || ""
          : "";
      }
    }

    function renumberLines() {
      qsa("[data-petty-line]", linesBody).forEach(function (row, idx) {
        var sl = qs("[data-line-sl]", row);
        if (sl) sl.textContent = String(idx + 1);
      });
    }

    function recalcTotal() {
      var total = 0;
      qsa("[data-petty-line]", linesBody).forEach(function (row) {
        total += parseNum(qs("[data-line-amount]", row)?.value);
      });
      var totalEl = qs("[data-petty-total]", module);
      var amountHidden = qs("[data-petty-amount-hidden]", form);
      if (totalEl) totalEl.value = formatMoney(total);
      if (amountHidden) amountHidden.value = formatMoney(total);
      return total;
    }

    function syncPurposeHidden() {
      var purposes = [];
      qsa("[data-petty-line]", linesBody).forEach(function (row) {
        var p = (qs("[data-line-purpose]", row)?.value || "").trim();
        var a = parseNum(qs("[data-line-amount]", row)?.value);
        if (p || a > 0) purposes.push(p);
      });
      var hidden = qs("[data-petty-purpose-hidden]", form);
      if (hidden) hidden.value = purposes.join("; ");
    }

    function bindLineRow(row) {
      qsa("input", row).forEach(function (input) {
        input.addEventListener("input", function () {
          recalcTotal();
          syncPurposeHidden();
        });
      });
      var removeBtn = qs("[data-petty-remove-line]", row);
      if (removeBtn) {
        removeBtn.addEventListener("click", function () {
          var rows = qsa("[data-petty-line]", linesBody);
          if (rows.length <= 1) return;
          row.remove();
          renumberLines();
          recalcTotal();
          syncPurposeHidden();
        });
      }
    }

    function addLine(purpose, amount) {
      var tr = document.createElement("tr");
      tr.setAttribute("data-petty-line", "");
      var purposeVal = purpose || "";
      var amountVal = amount !== undefined && amount !== null ? formatMoney(amount) : "";
      var readonlyAttr = isReadonly ? " readonly" : "";
      var disabledAttr = isReadonly ? " disabled" : "";
      tr.innerHTML =
        '<td class="col-sl" data-line-sl></td>' +
        '<td><input type="text" name="purpose_line[]" class="petty-line-purpose" value="' +
        purposeVal.replace(/"/g, "&quot;") +
        '" placeholder="Purpose" data-line-purpose required' +
        readonlyAttr +
        "></td>" +
        '<td><input type="number" step="0.01" min="0" name="amount_line[]" class="petty-line-amount" value=\"" +
        amountVal +
        '" placeholder="0.00" data-line-amount required' +
        readonlyAttr +
        "></td>" +
        '<td class="col-action">' +
        (isReadonly
          ? ""
          : '<button type="button" class="erp-btn erp-btn-ghost erp-btn-sm" data-petty-remove-line aria-label="Remove row"><i class="fa-solid fa-trash"></i></button>') +
        "</td>";
      linesBody.appendChild(tr);
      bindLineRow(tr);
      renumberLines();
      recalcTotal();
      syncPurposeHidden();
    }

    function seedLines() {
      var seedEl = document.getElementById("petty-purpose-seed");
      if (seedEl) {
        try {
          var seed = JSON.parse(seedEl.textContent || "{}");
          var purpose = seed.purpose || "";
          var amount = seed.amount || 0;
          var parts = purpose.split(/;\s*/).filter(Boolean);
          if (parts.length > 1) {
            var perLine = amount / parts.length;
            parts.forEach(function (p) {
              addLine(p, perLine);
            });
          } else if (purpose) {
            addLine(purpose, amount);
          } else {
            addLine("", amount || "");
          }
          return;
        } catch (e) {
          /* fall through */
        }
      }
      addLine("", "");
    }

    function validateForm(submit) {
      var date = qs("[data-petty-request-date]", form);
      var project = qs("[data-petty-project]", form);
      var staff = qs("[data-petty-staff]", form);
      if (!date?.value) {
        alert("Request date is required.");
        date?.focus();
        return false;
      }
      if (!project?.value) {
        alert("Project is required.");
        project?.focus();
        return false;
      }
      if (!staff?.value) {
        alert("Staff is required.");
        staff?.focus();
        return false;
      }
      var hasLine = false;
      qsa("[data-petty-line]", linesBody).forEach(function (row) {
        var p = (qs("[data-line-purpose]", row)?.value || "").trim();
        var a = parseNum(qs("[data-line-amount]", row)?.value);
        if (p && a > 0) hasLine = true;
      });
      if (!hasLine) {
        alert("Add at least one purpose line with amount greater than zero.");
        return false;
      }
      var total = recalcTotal();
      if (total <= 0) {
        alert("Total amount must be greater than zero.");
        return false;
      }
      syncPurposeHidden();
      if (submit && !window.confirm("Submit this petty cash request for approval?")) {
        return false;
      }
      return true;
    }

    function submitWithAction(action) {
      if (!validateForm(action === "submit_request")) return;
      setFormAction(action === "submit_request" ? "submit_request" : "save_draft");
      form.submit();
    }

    seedLines();
    fillStaffFields();
    fillProjectFields();

    var staffSelect = qs("[data-petty-staff]", form);
    if (staffSelect) {
      staffSelect.addEventListener("change", fillStaffFields);
    }

    var projectSelect = qs("[data-petty-project]", form);
    if (projectSelect) {
      projectSelect.addEventListener("change", fillProjectFields);
    }

    var addBtn = qs("[data-petty-add-line]", module);
    if (addBtn) {
      addBtn.addEventListener("click", function () {
        addLine("", "");
      });
    }

    qsa("[data-petty-save]", module).forEach(function (btn) {
      btn.addEventListener("click", function () {
        submitWithAction(btn.getAttribute("data-petty-save") === "submit" ? "submit_request" : "save_draft");
      });
    });

    qsa("[data-petty-toolbar-save]", module).forEach(function (btn) {
      btn.addEventListener("click", function () {
        submitWithAction(btn.getAttribute("data-petty-toolbar-save") === "submit" ? "submit_request" : "save_draft");
      });
    });

    var dateInput = qs("[data-petty-request-date]", form);
    if (dateInput && !dateInput.value) {
      var today = new Date();
      var m = String(today.getMonth() + 1).padStart(2, "0");
      var d = String(today.getDate()).padStart(2, "0");
      dateInput.value = today.getFullYear() + "-" + m + "-" + d;
    }

    var dropzone = qs("[data-petty-dropzone]", module);
    var fileInput = qs("[data-petty-file]", module);
    if (dropzone && fileInput && !dropzone.getAttribute("data-readonly")) {
      dropzone.addEventListener("click", function (e) {
        if (e.target === fileInput) return;
        fileInput.click();
      });
      dropzone.addEventListener("dragover", function (e) {
        e.preventDefault();
        dropzone.classList.add("is-dragover");
      });
      dropzone.addEventListener("dragleave", function () {
        dropzone.classList.remove("is-dragover");
      });
      dropzone.addEventListener("drop", function (e) {
        e.preventDefault();
        dropzone.classList.remove("is-dragover");
        if (e.dataTransfer?.files?.length) {
          fileInput.files = e.dataTransfer.files;
        }
      });
    }

    if (panel && !panel.hidden && module.classList.contains("module-layout--entry-form-open")) {
      qsa("[data-hide-on-entry-open]", module).forEach(function (el) {
        el.setAttribute("hidden", "");
        el.setAttribute("aria-hidden", "true");
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initModule);
  } else {
    initModule();
  }
})();
