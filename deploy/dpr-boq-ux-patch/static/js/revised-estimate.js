(function () {
  "use strict";

  var boqItems = [];
  var boot = window.REVISED_ESTIMATE_BOOT || {};

  function parseNum(value) {
    var n = parseFloat(value);
    return Number.isFinite(n) ? n : 0;
  }

  function formatMoney(n) {
    return "₹" + parseNum(n).toFixed(2);
  }

  function recalcRow(row) {
    var origQty = parseNum(row.querySelector(".re-orig-qty") && row.querySelector(".re-orig-qty").value);
    var origRate = parseNum(row.querySelector(".re-orig-rate") && row.querySelector(".re-orig-rate").value);
    var revQty = parseNum(row.querySelector(".re-rev-qty") && row.querySelector(".re-rev-qty").value);
    var revRate = parseNum(row.querySelector(".re-rev-rate") && row.querySelector(".re-rev-rate").value);
    var origAmount = Math.round(origQty * origRate * 100) / 100;
    var revAmount = Math.round(revQty * revRate * 100) / 100;
    var origEl = row.querySelector(".re-orig-amount");
    var revEl = row.querySelector(".re-rev-amount");
    if (origEl) origEl.textContent = formatMoney(origAmount);
    if (revEl) revEl.textContent = formatMoney(revAmount);
    recalcTotals();
  }

  function recalcTotals() {
    var tbody = document.getElementById("re-lines-body");
    if (!tbody) return;
    var origTotal = 0;
    var revTotal = 0;
    tbody.querySelectorAll("[data-re-line]").forEach(function (row) {
      var origQty = parseNum(row.querySelector(".re-orig-qty") && row.querySelector(".re-orig-qty").value);
      var origRate = parseNum(row.querySelector(".re-orig-rate") && row.querySelector(".re-orig-rate").value);
      var revQty = parseNum(row.querySelector(".re-rev-qty") && row.querySelector(".re-rev-qty").value);
      var revRate = parseNum(row.querySelector(".re-rev-rate") && row.querySelector(".re-rev-rate").value);
      origTotal += Math.round(origQty * origRate * 100) / 100;
      revTotal += Math.round(revQty * revRate * 100) / 100;
    });
    var origTotalEl = document.getElementById("re-total-orig");
    var revTotalEl = document.getElementById("re-total-rev");
    if (origTotalEl) origTotalEl.textContent = formatMoney(origTotal);
    if (revTotalEl) revTotalEl.textContent = formatMoney(revTotal);
  }

  function clearEmptyRow() {
    var tbody = document.getElementById("re-lines-body");
    if (!tbody) return;
    var empty = tbody.querySelector(".re-empty-row");
    if (empty) empty.remove();
  }

  function bindRow(row) {
    ["input", "change"].forEach(function (evt) {
      row.addEventListener(evt, function (e) {
        if (e.target.classList.contains("re-rev-qty") || e.target.classList.contains("re-rev-rate")) {
          recalcRow(row);
        }
      });
    });
    var pick = row.querySelector("[data-re-item-pick]");
    if (pick) {
      pick.addEventListener("change", function () {
        applyBoqItemToRow(row, pick.value);
      });
    }
    var removeBtn = row.querySelector(".re-remove-line");
    if (removeBtn) {
      removeBtn.addEventListener("click", function () {
        row.remove();
        recalcTotals();
      });
    }
    recalcRow(row);
  }

  function findBoqItem(itemId) {
    var id = String(itemId);
    for (var i = 0; i < boqItems.length; i += 1) {
      if (String(boqItems[i].id) === id) return boqItems[i];
    }
    return null;
  }

  function applyBoqItemToRow(row, itemId) {
    var item = findBoqItem(itemId);
    if (!item) return;
    var descHidden = row.querySelector('input[name="line_item_description"]');
    var descDisplay = row.querySelector(".re-desc-display");
    var unitHidden = row.querySelector('input[name="line_unit"]');
    var unitDisplay = row.querySelector(".re-unit-display");
    var codeHidden = row.querySelector('input[name="line_item_code"]');
    var boqIdHidden = row.querySelector('input[name="line_boq_item_id"]');
    var qty = parseNum(item.quantity);
    var rate = parseNum(item.rate);
    var desc = item.item_description || item.description || "";
    var unit = item.unit || "";
    var code = item.item_code || item.item_number || "";
    if (descHidden) descHidden.value = desc;
    if (descDisplay) descDisplay.textContent = desc || "—";
    if (unitHidden) unitHidden.value = unit;
    if (unitDisplay) unitDisplay.textContent = unit || "—";
    if (codeHidden) codeHidden.value = code;
    if (boqIdHidden) boqIdHidden.value = item.id;
    var origQty = row.querySelector(".re-orig-qty");
    var origRate = row.querySelector(".re-orig-rate");
    var revQty = row.querySelector(".re-rev-qty");
    var revRate = row.querySelector(".re-rev-rate");
    if (origQty) origQty.value = String(qty);
    if (origRate) origRate.value = String(rate);
    if (revQty && !revQty.dataset.touched) revQty.value = String(qty);
    if (revRate && !revRate.dataset.touched) revRate.value = String(rate);
    recalcRow(row);
  }

  function buildItemPickOptions(selectedId) {
    var html = '<option value="">— Select item —</option>';
    boqItems.forEach(function (item) {
      var label = (item.item_code || item.item_number || "Item") + " — " + (item.item_description || item.description || "").slice(0, 40);
      var sel = String(item.id) === String(selectedId) ? " selected" : "";
      html += '<option value="' + item.id + '"' + sel + ">" + label + "</option>";
    });
    return html;
  }

  function addBoqLineRow(item) {
    clearEmptyRow();
    var tbody = document.getElementById("re-lines-body");
    if (!tbody) return;
    var tr = document.createElement("tr");
    tr.className = "re-line-row";
    tr.setAttribute("data-re-line", "");
    tr.innerHTML =
      "<td>" +
      '<select name="line_item_pick" class="re-item-pick erp-input--sm" data-re-item-pick>' +
      buildItemPickOptions(item ? item.id : "") +
      "</select>" +
      '<input type="hidden" name="line_boq_item_id" value="' + (item ? item.id : "") + '">' +
      '<input type="hidden" name="line_is_new_item" value="0">' +
      '<input type="hidden" name="line_item_code" value="' + (item ? (item.item_code || item.item_number || "") : "") + '">' +
      "</td>" +
      "<td>" +
      '<input type="hidden" name="line_item_description" value="' + (item ? (item.item_description || item.description || "") : "") + '">' +
      '<span class="re-desc-display">' + (item ? (item.item_description || item.description || "—") : "—") + "</span>" +
      "</td>" +
      "<td>" +
      '<input type="hidden" name="line_unit" value="' + (item ? (item.unit || "") : "") + '">' +
      '<span class="re-unit-display">' + (item ? (item.unit || "—") : "—") + "</span>" +
      "</td>" +
      '<td class="re-orig-col"><input type="number" step="0.0001" name="line_original_qty" class="erp-input--qty re-orig-qty" readonly value="' + (item ? item.quantity : "") + '"></td>' +
      '<td class="re-orig-col"><input type="number" step="0.01" name="line_original_rate" class="erp-input--amount re-orig-rate" readonly value="' + (item ? item.rate : "") + '"></td>' +
      '<td class="re-orig-col"><span class="re-orig-amount">₹0.00</span></td>' +
      '<td><input type="number" step="0.0001" min="0" name="line_revised_qty" class="erp-input--qty re-rev-qty" value="' + (item ? item.quantity : "") + '"></td>' +
      '<td><input type="number" step="0.01" min="0" name="line_revised_rate" class="erp-input--amount re-rev-rate" value="' + (item ? item.rate : "") + '"></td>' +
      '<td><span class="re-rev-amount">₹0.00</span></td>' +
      '<td><input type="text" name="line_remarks" placeholder="Remarks"></td>' +
      '<td><button type="button" class="erp-btn erp-btn-ghost erp-btn-sm re-remove-line">&times;</button></td>';
    tbody.appendChild(tr);
    bindRow(tr);
    if (item) applyBoqItemToRow(tr, item.id);
  }

  function addNewItemRow() {
    clearEmptyRow();
    var tbody = document.getElementById("re-lines-body");
    if (!tbody) return;
    var units = boot.units || ["Nos"];
    var unitOptions = units.map(function (u) {
      return '<option value="' + u + '">' + u + "</option>";
    }).join("");
    var tr = document.createElement("tr");
    tr.className = "re-line-row re-line-new";
    tr.setAttribute("data-re-line", "");
    tr.innerHTML =
      "<td>" +
      '<input type="hidden" name="line_boq_item_id" value="">' +
      '<input type="hidden" name="line_is_new_item" value="1">' +
      '<span class="re-new-badge">New</span>' +
      "</td>" +
      "<td>" +
      '<input type="text" name="line_item_description" class="re-desc-input" placeholder="New item description">' +
      "</td>" +
      "<td>" +
      '<select name="line_unit" class="re-unit-input">' + unitOptions + "</select>" +
      "</td>" +
      '<td class="re-orig-col"><input type="number" step="0.0001" name="line_original_qty" class="erp-input--qty re-orig-qty" readonly value=""></td>' +
      '<td class="re-orig-col"><input type="number" step="0.01" name="line_original_rate" class="erp-input--amount re-orig-rate" readonly value=""></td>' +
      '<td class="re-orig-col"><span class="re-orig-amount">—</span></td>' +
      '<td><input type="number" step="0.0001" min="0" name="line_revised_qty" class="erp-input--qty re-rev-qty" value=""></td>' +
      '<td><input type="number" step="0.01" min="0" name="line_revised_rate" class="erp-input--amount re-rev-rate" value=""></td>' +
      '<td><span class="re-rev-amount">₹0.00</span></td>' +
      '<td><input type="text" name="line_remarks" placeholder="Remarks"></td>' +
      '<td><button type="button" class="erp-btn erp-btn-ghost erp-btn-sm re-remove-line">&times;</button></td>';
    tbody.appendChild(tr);
    bindRow(tr);
  }

  function refreshItemPicks() {
    document.querySelectorAll("[data-re-item-pick]").forEach(function (pick) {
      var current = pick.value;
      pick.innerHTML = buildItemPickOptions(current);
      pick.value = current;
    });
  }

  function loadBoqs(projectId) {
    var boqSelect = document.getElementById("re_boq_select");
    if (!boqSelect) return Promise.resolve();
    if (!projectId) {
      boqSelect.innerHTML = '<option value="">— Select BOQ —</option>';
      boqSelect.disabled = true;
      return Promise.resolve();
    }
    return fetch("/api/boq-management/project/" + encodeURIComponent(projectId) + "/boqs", { credentials: "same-origin" })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var boqs = (data && data.boqs) || [];
        var html = '<option value="">— Select BOQ —</option>';
        boqs.forEach(function (b) {
          var sel = boot.boqId && String(b.id) === String(boot.boqId) ? " selected" : "";
          html += '<option value="' + b.id + '"' + sel + ">" + (b.boq_number || b.id) + (b.boq_name ? " — " + b.boq_name : "") + "</option>";
        });
        boqSelect.innerHTML = html;
        boqSelect.disabled = false;
        if (boot.boqId) {
          boqSelect.value = String(boot.boqId);
          return loadBoqItems(projectId, boot.boqId);
        }
      })
      .catch(function () {});
  }

  function loadBoqItems(projectId, boqId) {
    if (!projectId || !boqId) {
      boqItems = [];
      return Promise.resolve();
    }
    var url = "/api/boq-management/project/" + encodeURIComponent(projectId) + "/items?boq_id=" + encodeURIComponent(boqId);
    return fetch(url, { credentials: "same-origin" })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        boqItems = (data && data.items) || [];
        refreshItemPicks();
        var addBoqBtn = document.getElementById("re-add-boq-line");
        if (addBoqBtn) addBoqBtn.disabled = boqItems.length === 0;
      })
      .catch(function () {
        boqItems = [];
      });
  }

  function syncProject(projectId) {
    var hidden = document.getElementById("re_project_id");
    var nameSel = document.getElementById("re_project_name");
    var codeSel = document.getElementById("re_project_code");
    if (hidden) hidden.value = projectId || "";
    if (nameSel && nameSel.value !== projectId) nameSel.value = projectId || "";
    if (codeSel && codeSel.value !== projectId) codeSel.value = projectId || "";
    return loadBoqs(projectId);
  }

  document.addEventListener("DOMContentLoaded", function () {
    var form = document.getElementById("revised-estimate-save-form");
    if (!form) return;

    var nameSel = document.getElementById("re_project_name");
    var codeSel = document.getElementById("re_project_code");
    var boqSelect = document.getElementById("re_boq_select");
    var addBoqBtn = document.getElementById("re-add-boq-line");
    var addNewBtn = document.getElementById("re-add-new-item");

    if (nameSel) {
      nameSel.addEventListener("change", function () {
        syncProject(nameSel.value).then(function () {
          var tbody = document.getElementById("re-lines-body");
          if (tbody && !tbody.querySelector("[data-re-line]")) {
            tbody.innerHTML = '<tr class="re-empty-row"><td colspan="11">Select BOQ to load items, or add a new item.</td></tr>';
          }
        });
      });
    }
    if (codeSel) {
      codeSel.addEventListener("change", function () {
        syncProject(codeSel.value);
      });
    }
    if (boqSelect) {
      boqSelect.addEventListener("change", function () {
        var projectId = document.getElementById("re_project_id") && document.getElementById("re_project_id").value;
        loadBoqItems(projectId, boqSelect.value);
      });
    }
    if (addBoqBtn) {
      addBoqBtn.addEventListener("click", function () {
        addBoqLineRow(null);
      });
    }
    if (addNewBtn) {
      addNewBtn.addEventListener("click", function () {
        addNewItemRow();
      });
    }

    document.querySelectorAll("[data-re-line]").forEach(function (row) {
      row.querySelectorAll(".re-rev-qty, .re-rev-rate").forEach(function (el) {
        if (el.value) el.dataset.touched = "1";
      });
      bindRow(row);
    });
    recalcTotals();

    if (boot.projectId) {
      syncProject(boot.projectId).then(function () {
        if (boot.boqId) loadBoqItems(boot.projectId, boot.boqId);
      });
    }
  });
})();
