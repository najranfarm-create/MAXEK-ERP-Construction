(function () {
  "use strict";

  var descHistory = [];

  function parseNum(value) {
    var n = parseFloat(value);
    return Number.isFinite(n) ? n : 0;
  }

  function hasExecutedColumns() {
    return !!document.querySelector('[name="executed_quantity[]"]');
  }

  function recalcRow(row) {
    var qty = parseNum(row.querySelector(".boq-qty") && row.querySelector(".boq-qty").value);
    var rate = parseNum(row.querySelector(".boq-rate") && row.querySelector(".boq-rate").value);
    var executed = parseNum(row.querySelector('[name="executed_quantity[]"]') && row.querySelector('[name="executed_quantity[]"]').value);
    var amountInput = row.querySelector(".boq-amount");
    var balanceCell = row.querySelector(".boq-balance");
    var amount = Math.round(qty * rate * 100) / 100;
    if (amountInput) amountInput.value = amount.toFixed(2);
    if (balanceCell) balanceCell.textContent = Math.max(qty - executed, 0).toFixed(4);
  }

  function renumberRows(tbody) {
    Array.prototype.forEach.call(tbody.querySelectorAll(".boq-item-row"), function (row, idx) {
      var firstCell = row.querySelector("td");
      if (firstCell) firstCell.textContent = String(idx + 1);
      var itemNo = row.querySelector(".boq-item-no");
      if (itemNo && !itemNo.dataset.locked) itemNo.value = "BOQ" + (idx + 1);
    });
  }

  function findHistoryEntry(description) {
    var key = (description || "").trim().toLowerCase();
    if (!key) return null;
    for (var i = 0; i < descHistory.length; i += 1) {
      if ((descHistory[i].description || "").trim().toLowerCase() === key) return descHistory[i];
    }
    return null;
  }

  function setUnitOnRow(row, unit) {
    var select = row.querySelector(".boq-unit-select");
    var manual = row.querySelector(".boq-unit-manual");
    var value = (unit || "").trim() || "Nos";
    if (select) {
      var found = false;
      Array.prototype.forEach.call(select.options, function (opt) {
        if (opt.value === value) found = true;
      });
      if (!found) {
        var opt = document.createElement("option");
        opt.value = value;
        opt.textContent = value;
        select.appendChild(opt);
      }
      select.value = value;
    }
    if (manual) manual.value = "";
  }

  function applyHistoryToRow(row, entry) {
    if (!entry) return;
    var descInput = row.querySelector(".boq-desc-input");
    var specInput = row.querySelector('[name="specification[]"]');
    var rateInput = row.querySelector(".boq-rate");
    var itemNo = row.querySelector(".boq-item-no");
    if (descInput) descInput.value = entry.description || "";
    if (specInput && entry.source === "library") specInput.value = entry.specification || "";
    if (entry.unit) setUnitOnRow(row, entry.unit);
    if (rateInput && entry.rate) rateInput.value = String(entry.rate);
    if (itemNo && entry.item_code && !itemNo.dataset.locked) itemNo.value = entry.item_code;
    recalcRow(row);
  }

  function populateDescPick(select) {
    if (!select) return;
    var current = select.value;
    select.innerHTML = '<option value="">— History —</option>';
    descHistory.forEach(function (item, idx) {
      var opt = document.createElement("option");
      opt.value = String(idx);
      opt.textContent = (item.description || "").slice(0, 80);
      select.appendChild(opt);
    });
    if (current) select.value = current;
  }

  function populateDescDatalist() {
    var datalist = document.getElementById("boq-desc-history");
    if (!datalist) return;
    datalist.innerHTML = "";
    descHistory.forEach(function (item) {
      var opt = document.createElement("option");
      opt.value = item.description || "";
      datalist.appendChild(opt);
    });
  }

  function refreshAllDescPicks() {
    populateDescDatalist();
    document.querySelectorAll("[data-boq-desc-pick]").forEach(populateDescPick);
  }

  function bindDescPick(row) {
    var pick = row.querySelector("[data-boq-desc-pick]");
    var descInput = row.querySelector(".boq-desc-input");
    if (pick) {
      pick.addEventListener("change", function () {
        var idx = parseInt(pick.value, 10);
        if (!Number.isFinite(idx) || idx < 0 || idx >= descHistory.length) return;
        applyHistoryToRow(row, descHistory[idx]);
      });
    }
    if (descInput) {
      descInput.addEventListener("change", function () {
        var entry = findHistoryEntry(descInput.value);
        if (entry) applyHistoryToRow(row, entry);
      });
      descInput.addEventListener("blur", function () {
        var entry = findHistoryEntry(descInput.value);
        if (entry) {
          if (entry.unit) setUnitOnRow(row, entry.unit);
          if (entry.rate) {
            var rateInput = row.querySelector(".boq-rate");
            if (rateInput && !rateInput.value) rateInput.value = String(entry.rate);
          }
          recalcRow(row);
        }
      });
    }
  }

  function bindRow(row) {
    ["input", "change"].forEach(function (evt) {
      row.addEventListener(evt, function (e) {
        if (
          e.target.classList.contains("boq-qty") ||
          e.target.classList.contains("boq-rate") ||
          e.target.classList.contains("boq-unit-manual")
        ) {
          if (e.target.classList.contains("boq-unit-manual") && e.target.value.trim()) {
            setUnitOnRow(row, e.target.value.trim());
          }
          recalcRow(row);
        }
      });
    });
    var removeBtn = row.querySelector(".boq-remove-line");
    if (removeBtn) {
      removeBtn.addEventListener("click", function () {
        var tbody = row.parentElement;
        if (tbody.querySelectorAll(".boq-item-row").length <= 1) return;
        row.remove();
        renumberRows(tbody);
      });
    }
    bindDescPick(row);
  }

  function buildRowHtml(index, boot, withExecuted) {
    var unitOptions = (boot.units || ["Nos"]).map(function (u) {
      return '<option value="' + u + '">' + u + "</option>";
    }).join("");
    var executedCols = withExecuted
      ? '<td><input name="executed_quantity[]" type="number" step="0.0001" min="0" value="0" readonly></td><td class="boq-balance">0</td>'
      : "";
    return (
      "<td>" + index + "</td>" +
      '<td><input name="item_number[]" value="BOQ' + index + '" class="boq-item-no" readonly></td>' +
      '<td class="boq-desc-cell">' +
      '<select class="boq-desc-pick erp-input--sm" data-boq-desc-pick aria-label="Pick from history">' +
      '<option value="">— History —</option></select>' +
      '<input name="item_description[]" class="boq-desc-input" list="boq-desc-history" placeholder="Select history or type new item">' +
      "</td>" +
      '<td><input name="specification[]" placeholder="New item spec (optional)"></td>' +
      '<td>' +
      '<select name="unit[]" class="boq-unit-select">' + unitOptions + "</select>" +
      '<input type="text" name="unit_manual[]" class="boq-unit-manual" placeholder="Or type unit" style="margin-top:4px;">' +
      "</td>" +
      '<td><input name="quantity[]" type="number" step="0.0001" min="0" class="boq-qty"></td>' +
      '<td><input name="rate[]" type="number" step="0.01" min="0" class="boq-rate"></td>' +
      '<td><input name="amount[]" type="number" step="0.01" min="0" class="boq-amount" readonly></td>' +
      executedCols +
      '<td><button type="button" class="erp-btn erp-btn-ghost erp-btn-sm boq-remove-line">&times;</button></td>'
    );
  }

  function addLine(tbody, boot) {
    var count = tbody.querySelectorAll(".boq-item-row").length;
    if (count >= (boot.maxLines || 500)) return;
    var tr = document.createElement("tr");
    tr.className = "boq-item-row";
    tr.innerHTML = buildRowHtml(count + 1, boot, hasExecutedColumns());
    tbody.appendChild(tr);
    populateDescPick(tr.querySelector("[data-boq-desc-pick]"));
    bindRow(tr);
  }

  function syncProjectSelects(projectId) {
    var nameSel = document.getElementById("boq_project_name");
    var codeSel = document.getElementById("boq_project_code");
    var hidden = document.getElementById("boq_project_id");
    if (hidden) hidden.value = projectId || "";
    if (nameSel && nameSel.value !== projectId) nameSel.value = projectId || "";
    if (codeSel && codeSel.value !== projectId) codeSel.value = projectId || "";
  }

  function updateBoqNumber(projectId) {
    var input = document.getElementById("boq_number_input");
    if (!input || !input.hasAttribute("data-boq-auto-number") || !projectId) return;
    fetch("/api/projects/" + encodeURIComponent(projectId) + "/next-boq-number", { credentials: "same-origin" })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data && data.next_boq_number) input.value = data.next_boq_number;
      })
      .catch(function () {});
  }

  function loadDescriptionHistory(projectId) {
    var url = "/api/boq-management/description-history";
    if (projectId) url += "?project_id=" + encodeURIComponent(projectId);
    return fetch(url, { credentials: "same-origin" })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        descHistory = (data && data.items) || [];
        refreshAllDescPicks();
      })
      .catch(function () {
        descHistory = [];
        refreshAllDescPicks();
      });
  }

  function bindProjectSync() {
    var nameSel = document.getElementById("boq_project_name");
    var codeSel = document.getElementById("boq_project_code");
    if (!nameSel || !codeSel) return;

    function onProjectChange(projectId) {
      syncProjectSelects(projectId);
      updateBoqNumber(projectId);
      loadDescriptionHistory(projectId);
    }

    nameSel.addEventListener("change", function () {
      onProjectChange(nameSel.value);
    });
    codeSel.addEventListener("change", function () {
      onProjectChange(codeSel.value);
    });

    var initial = document.getElementById("boq_project_id");
    if (initial && initial.value) {
      syncProjectSelects(initial.value);
      loadDescriptionHistory(initial.value);
    } else {
      loadDescriptionHistory(null);
    }
  }

  function resolveUnitsBeforeSubmit(form) {
    var tbody = document.getElementById("boq-items-body");
    if (!tbody) return;
    tbody.querySelectorAll(".boq-item-row").forEach(function (row) {
      var manual = row.querySelector(".boq-unit-manual");
      var select = row.querySelector(".boq-unit-select");
      if (manual && select && manual.value.trim()) {
        var val = manual.value.trim();
        var found = false;
        Array.prototype.forEach.call(select.options, function (opt) {
          if (opt.value === val) found = true;
        });
        if (!found) {
          var opt = document.createElement("option");
          opt.value = val;
          opt.textContent = val;
          select.appendChild(opt);
        }
        select.value = val;
      }
    });
  }

  function showImportModal(modal, show) {
    if (!modal) return;
    modal.hidden = !show;
    modal.style.display = show ? "flex" : "none";
  }

  document.addEventListener("DOMContentLoaded", function () {
    var boot = window.BOQ_MANAGEMENT_BOOT || {};
    var tbody = document.getElementById("boq-items-body");
    if (tbody) {
      Array.prototype.forEach.call(tbody.querySelectorAll(".boq-item-row"), function (row) {
        var itemNo = row.querySelector(".boq-item-no");
        if (itemNo && itemNo.value) itemNo.dataset.locked = "1";
        bindRow(row);
        recalcRow(row);
        populateDescPick(row.querySelector("[data-boq-desc-pick]"));
      });
    }
    var addBtn = document.getElementById("boq-add-line");
    if (addBtn && tbody) {
      addBtn.addEventListener("click", function () {
        addLine(tbody, boot);
      });
    }

    bindProjectSync();

    var form = document.querySelector("#boq-form form");
    if (form) {
      form.addEventListener("submit", function () {
        resolveUnitsBeforeSubmit(form);
      });
    }

    var importBtn = document.getElementById("boq-import-btn");
    var importModal = document.getElementById("boq-import-modal");
    var importClose = document.getElementById("boq-import-close");
    var importRun = document.getElementById("boq-import-run");
    var importFile = document.getElementById("boq-import-file");
    var importStatus = document.getElementById("boq-import-status");
    var importProject = document.getElementById("boq-import-project");
    var importName = document.getElementById("boq-import-name");

    if (importBtn) importBtn.addEventListener("click", function () { showImportModal(importModal, true); });
    if (importClose) importClose.addEventListener("click", function () { showImportModal(importModal, false); });
    if (importRun && importFile) {
      importRun.addEventListener("click", function () {
        if (!importFile.files || !importFile.files[0]) {
          if (importStatus) importStatus.textContent = "Choose a file first.";
          return;
        }
        if (importStatus) importStatus.textContent = "Importing…";
        var fd = new FormData();
        fd.append("file", importFile.files[0]);
        if (importProject) fd.append("project_id", importProject.value);
        if (importName) fd.append("boq_name", importName.value);
        fetch("/api/boq-management/import/save", { method: "POST", body: fd, credentials: "same-origin" })
          .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, body: j }; }); })
          .then(function (res) {
            if (res.ok && res.body.ok) {
              if (importStatus) importStatus.textContent = "Imported BOQ " + (res.body.boq_number || "") + ".";
              setTimeout(function () {
                window.location.href = "/boq-management?boq_id=" + (res.body.boq_id || "");
              }, 600);
            } else if (importStatus) {
              importStatus.textContent = res.body.error || "Import failed.";
            }
          })
          .catch(function () {
            if (importStatus) importStatus.textContent = "Import request failed.";
          });
      });
    }

    var aiBtn = document.getElementById("boq-ai-validate-btn");
    var aiStatus = document.getElementById("boq-ai-status");
    if (aiBtn) {
      aiBtn.addEventListener("click", function () {
        if (aiStatus) aiStatus.textContent = "Validating…";
        fetch("/api/boq-management/ai/validate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          credentials: "same-origin",
          body: JSON.stringify({ boq_id: boot.boqId }),
        })
          .then(function (r) { return r.json(); })
          .then(function (data) {
            if (!aiStatus) return;
            if (data.ok) {
              var warn = (data.warnings || []).length;
              aiStatus.textContent = warn ? "OK with " + warn + " warning(s)." : "Validation passed.";
            } else {
              var issues = (data.issues || []).map(function (i) { return i.message; });
              aiStatus.textContent = issues.join(" ") || "Issues found.";
            }
          })
          .catch(function () {
            if (aiStatus) aiStatus.textContent = "Validation request failed.";
          });
      });
    }
  });
})();
