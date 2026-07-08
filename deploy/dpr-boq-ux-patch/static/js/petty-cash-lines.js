(function () {
  "use strict";

  function parseAmount(value) {
    const num = parseFloat(String(value || "").replace(/,/g, ""));
    return Number.isFinite(num) ? num : 0;
  }

  function formatAmount(num) {
    return Number(num || 0).toFixed(2);
  }

  function renumberRows(body) {
    const rows = body.querySelectorAll("[data-petty-cash-line-row]");
    rows.forEach(function (row, index) {
      const sl = row.querySelector("[data-petty-cash-line-sl]");
      if (sl) {
        sl.textContent = String(index + 1);
      }
    });
  }

  function updateTotal(root) {
    const totalInput = root.querySelector(".petty-cash-line-total");
    if (!totalInput) {
      return;
    }
    let total = 0;
    root.querySelectorAll(".petty-cash-line-amount").forEach(function (input) {
      total += parseAmount(input.value);
    });
    totalInput.value = formatAmount(total);
  }

  function bindRow(row, root) {
    const amountInput = row.querySelector(".petty-cash-line-amount");
    if (amountInput) {
      amountInput.addEventListener("input", function () {
        updateTotal(root);
      });
    }
    const removeBtn = row.querySelector("[data-petty-cash-remove-row]");
    if (removeBtn) {
      removeBtn.addEventListener("click", function () {
        const body = root.querySelector("[data-petty-cash-lines-body]");
        const rows = body.querySelectorAll("[data-petty-cash-line-row]");
        if (rows.length <= 1) {
          row.querySelector(".petty-cash-line-purpose").value = "";
          row.querySelector(".petty-cash-line-amount").value = "";
          updateTotal(root);
          return;
        }
        row.remove();
        renumberRows(body);
        updateTotal(root);
      });
    }
  }

  function createRow(body) {
    const row = document.createElement("div");
    row.className = "petty-cash-line-items__row";
    row.setAttribute("data-petty-cash-line-row", "");
    row.innerHTML =
      '<div class="petty-cash-line-col petty-cash-line-col--sl">' +
      '<span class="petty-cash-line-sl" data-petty-cash-line-sl></span>' +
      "</div>" +
      '<div class="petty-cash-line-col petty-cash-line-col--purpose">' +
      '<input type="text" name="purpose_line[]" class="erp-input petty-cash-line-purpose" placeholder="Enter purpose">' +
      "</div>" +
      '<div class="petty-cash-line-col petty-cash-line-col--amount">' +
      '<input type="number" name="amount_line[]" class="erp-input petty-cash-line-amount" min="0" step="0.01" placeholder="0.00">' +
      "</div>" +
      '<div class="petty-cash-line-col petty-cash-line-col--action">' +
      '<button type="button" class="erp-btn erp-btn-ghost erp-btn-sm petty-cash-line-remove" data-petty-cash-remove-row title="Remove row" aria-label="Remove row">' +
      '<i class="fa-solid fa-minus" aria-hidden="true"></i>' +
      "</button>" +
      "</div>";
    body.appendChild(row);
    return row;
  }

  function hideLegacyFields() {
    document.querySelectorAll(
      'textarea[name="description"], input[name="description"], ' +
        '.petty-cash-legacy-description, [data-petty-cash-legacy-description]'
    ).forEach(function (node) {
      const field = node.closest(".erp-field") || node.closest(".form-group") || node;
      field.classList.add("petty-cash-legacy-hidden");
      field.setAttribute("hidden", "hidden");
    });
    document.querySelectorAll(
      'input[name="purpose"]:not(.petty-cash-line-purpose), ' +
        'input[name="required_amount"]:not(.petty-cash-line-total)'
    ).forEach(function (node) {
      const field = node.closest(".erp-field") || node.closest(".form-group") || node;
      field.classList.add("petty-cash-legacy-hidden");
      field.setAttribute("hidden", "hidden");
    });
  }

  function initPettyCashLines() {
    const root = document.querySelector("[data-petty-cash-lines]");
    if (!root) {
      return;
    }
    hideLegacyFields();
    const body = root.querySelector("[data-petty-cash-lines-body]");
    body.querySelectorAll("[data-petty-cash-line-row]").forEach(function (row) {
      bindRow(row, root);
    });
    const addBtn = root.querySelector("[data-petty-cash-add-row]");
    if (addBtn) {
      addBtn.addEventListener("click", function () {
        const row = createRow(body);
        bindRow(row, root);
        renumberRows(body);
        const purposeInput = row.querySelector(".petty-cash-line-purpose");
        if (purposeInput) {
          purposeInput.focus();
        }
      });
    }
    updateTotal(root);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPettyCashLines);
  } else {
    initPettyCashLines();
  }
})();
