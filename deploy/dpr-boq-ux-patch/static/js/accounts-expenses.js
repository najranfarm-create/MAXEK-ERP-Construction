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
    var module = qs("[data-expense-module]");
    if (!module) return;

    var form = qs("[data-expense-form]", module);
    var panel = qs("#expense-form", module);
    var linesBody = qs("[data-expense-lines-body]", module);
    var gstRates = [];
    try {
      gstRates = JSON.parse(panel.getAttribute("data-gst-rates") || "[]");
    } catch (e) {
      gstRates = [0, 5, 12, 18, 28];
    }

    if (!form || !linesBody) return;

    var recordId = panel.getAttribute("data-record-id") || "";

    function setFormAction(action) {
      var input = qs("[data-expense-form-action]", form);
      if (input) input.value = action;
    }

    function calcLineAmount(row) {
      var qty = parseNum(qs("[data-line-qty]", row)?.value);
      var rate = parseNum(qs("[data-line-rate]", row)?.value);
      var disc = parseNum(qs("[data-line-discount]", row)?.value);
      var gst = parseNum(qs("[data-line-gst]", row)?.value);
      var base = qty * rate;
      var discAmt = base * (disc / 100);
      var taxable = base - discAmt;
      var gstAmt = taxable * (gst / 100);
      var total = taxable + gstAmt;
      var amountInput = qs("[data-line-amount]", row);
      if (amountInput) amountInput.value = formatMoney(total);
      return { base: base, disc: discAmt, gst: gstAmt, total: total };
    }

    function recalcTotals() {
      var sub = 0;
      var disc = 0;
      var gst = 0;
      var grand = 0;
      qsa("[data-expense-line]", linesBody).forEach(function (row) {
        var parts = calcLineAmount(row);
        sub += parts.base;
        disc += parts.disc;
        gst += parts.gst;
        grand += parts.total;
      });

      var tdsCheck = qs("[data-expense-tds-check]", form);
      var tdsRate = parseNum(qs("[data-expense-tds-rate]", form)?.value);
      var tdsApplicable = tdsCheck && tdsCheck.checked;
      var tdsAmt = tdsApplicable ? grand * (tdsRate / 100) : 0;
      var netPayable = grand - tdsAmt;
      var paid = parseNum(qs("[data-expense-amount-paid]", form)?.value);
      var balance = netPayable - paid;

      var set = function (sel, val) {
        var el = qs(sel, module);
        if (el) el.textContent = formatMoney(val);
      };
      set("[data-expense-sum-subtotal]", sub);
      set("[data-expense-sum-discount]", disc);
      set("[data-expense-sum-gst]", gst);
      set("[data-expense-sum-tds]", tdsAmt);
      set("[data-expense-sum-paid]", paid);
      set("[data-expense-sum-balance]", balance);
      set("[data-expense-sum-grand]", grand);
      set("[data-expense-lines-total]", grand);

      var tdsDed = qs("#expense-tds-deduction", form);
      var netEl = qs("#expense-net-payable", form);
      var balInput = qs("[data-expense-balance]", form);
      if (tdsDed) tdsDed.value = formatMoney(tdsAmt);
      if (netEl) netEl.value = formatMoney(netPayable);
      if (balInput) balInput.value = formatMoney(balance);
    }

    function renumberLines() {
      qsa("[data-expense-line]", linesBody).forEach(function (row, idx) {
        var sl = qs("[data-line-sl]", row);
        if (sl) sl.textContent = String(idx + 1);
      });
    }

    function buildGstOptions(selected) {
      var html = "";
      gstRates.forEach(function (rate) {
        var sel = parseNum(rate) === parseNum(selected) ? " selected" : "";
        html += '<option value="' + rate + '"' + sel + ">" + rate + "%</option>";
      });
      return html;
    }

    function addLine(lineData) {
      lineData = lineData || {};
      var tr = document.createElement("tr");
      tr.setAttribute("data-expense-line", "");
      tr.innerHTML =
        '<td class="col-sl" data-line-sl></td>' +
        '<td><input type="text" name="line_item[]" value="' + (lineData.item || "") + '"></td>' +
        '<td><input type="text" name="line_description[]" value="' + (lineData.description || "") + '" required></td>' +
        '<td><input type="number" step="0.0001" min="0" name="line_quantity[]" class="erp-input--qty" value="' +
        (lineData.quantity || "") + '" required data-line-qty></td>' +
        '<td><input type="text" name="line_unit[]" value="' + (lineData.unit || "") + '"></td>' +
        '<td><input type="number" step="0.01" min="0" name="line_unit_price[]" class="erp-input--amount" value="' +
        (lineData.unit_price || "") + '" required data-line-rate></td>' +
        '<td><input type="number" step="0.01" min="0" name="line_discount[]" value="' +
        (lineData.discount || 0) + '" data-line-discount></td>' +
        '<td><select name="line_tax_percent[]" data-line-gst>' +
        buildGstOptions(lineData.tax_percent || 18) +
        "</select></td>" +
        '<td><input type="text" name="line_amount[]" readonly value="0.00" data-line-amount></td>' +
        '<td><button type="button" class="erp-btn erp-btn-ghost erp-btn-sm" data-expense-remove-line><i class="fa-solid fa-trash"></i></button></td>';
      linesBody.appendChild(tr);
      bindLineRow(tr);
      renumberLines();
      recalcTotals();
    }

    function bindLineRow(row) {
      qsa("input, select", row).forEach(function (input) {
        input.addEventListener("input", recalcTotals);
        input.addEventListener("change", recalcTotals);
      });
      var removeBtn = qs("[data-expense-remove-line]", row);
      if (removeBtn) {
        removeBtn.addEventListener("click", function () {
          var rows = qsa("[data-expense-line]", linesBody);
          if (rows.length <= 1) {
            qsa("input", row).forEach(function (inp) {
              if (inp.type !== "hidden") inp.value = inp.name.indexOf("discount") >= 0 ? "0" : "";
            });
          } else {
            row.remove();
          }
          renumberLines();
          recalcTotals();
        });
      }
    }

    qsa("[data-expense-line]", linesBody).forEach(bindLineRow);
    if (!qsa("[data-expense-line]", linesBody).length && !form.getAttribute("data-readonly")) {
      addLine();
    }

    var addBtn = qs("[data-expense-add-line]", module);
    if (addBtn) addBtn.addEventListener("click", function () { addLine(); });

    // Project auto-fill
    var projectSelect = qs("[data-expense-project]", form);
    function fillProjectMeta() {
      if (!projectSelect || !projectSelect.value) return;
      var opt = projectSelect.options[projectSelect.selectedIndex];
      var codeEl = qs("#expense-project-code", form);
      var mgrEl = qs("#expense-project-manager", form);
      var ccEl = qs("#expense-cost-center", form);
      if (codeEl) codeEl.value = opt.getAttribute("data-code") || "";
      if (mgrEl) mgrEl.value = opt.getAttribute("data-manager") || "";
      if (ccEl) ccEl.value = opt.getAttribute("data-cost-center") || "";
    }
    if (projectSelect) {
      projectSelect.addEventListener("change", fillProjectMeta);
      fillProjectMeta();
    }

    // Vendor select → vendor_name + meta
    var vendorSelect = qs("[data-expense-vendor-select]", form);
    var vendorNameInput = qs("#expense-vendor-name", form);
    var vendorMeta = qs("[data-expense-vendor-meta]", form);

    function fillVendorMeta() {
      if (!vendorSelect) return;
      var opt = vendorSelect.options[vendorSelect.selectedIndex];
      if (!opt || !opt.value) {
        if (vendorMeta) vendorMeta.hidden = true;
        return;
      }
      if (vendorNameInput) vendorNameInput.value = opt.getAttribute("data-name") || opt.textContent.trim();
      if (vendorMeta) {
        vendorMeta.hidden = false;
        qs("#expense-vendor-gst", form).value = opt.getAttribute("data-gst") || "";
        qs("#expense-vendor-pan", form).value = opt.getAttribute("data-pan") || "";
        qs("#expense-vendor-address", form).value = opt.getAttribute("data-address") || "";
        qs("#expense-vendor-phone", form).value = opt.getAttribute("data-phone") || "";
        qs("#expense-vendor-terms", form).value = opt.getAttribute("data-terms") || "";
      }
      checkDuplicateInvoice();
    }
    if (vendorSelect) {
      vendorSelect.addEventListener("change", fillVendorMeta);
      fillVendorMeta();
    }

    // Payment source panels
    var paymentSource = qs("[data-expense-payment-source]", form);
    var pettyBlock = qs("[data-expense-petty-details]", form);
    var bankDetails = qs("[data-expense-bank-details]", form);
    var pettyCashSelect = qs("[data-expense-petty-select]", form);

    function togglePaymentPanels() {
      var src = paymentSource ? paymentSource.value : "";
      var isPetty = /petty/i.test(src);
      var isBank = /bank/i.test(src);
      if (pettyBlock) pettyBlock.hidden = !isPetty;
      if (bankDetails) bankDetails.hidden = !isBank;
      var pettyField = qs("[data-expense-petty-block]", form);
      if (pettyField) pettyField.style.display = isPetty ? "" : "none";
      if (isPetty) refreshPettyCashBalance();
    }

    function refreshPettyCashBalance() {
      if (!pettyCashSelect || !pettyCashSelect.value) return;
      var opt = pettyCashSelect.options[pettyCashSelect.selectedIndex];
      var transferred = parseNum(opt.getAttribute("data-transferred"));
      var required = parseNum(opt.getAttribute("data-required"));
      qs("#expense-pc-available", form).value = formatMoney(transferred);
      qs("#expense-pc-requested", form).value = formatMoney(required);
      qs("#expense-pc-approved", form).value = formatMoney(transferred);
      fetch("/api/accounts/petty-cash-balance/" + pettyCashSelect.value)
        .then(function (r) { return r.json(); })
        .then(function (data) {
          qs("#expense-pc-current", form).value = formatMoney(data.balance || 0);
        })
        .catch(function () {});
    }

    if (paymentSource) {
      paymentSource.addEventListener("change", togglePaymentPanels);
      togglePaymentPanels();
    }
    if (pettyCashSelect) pettyCashSelect.addEventListener("change", refreshPettyCashBalance);

    // TDS toggle
    var tdsCheck = qs("[data-expense-tds-check]", form);
    var tdsFields = qs("[data-expense-tds-fields]", form);
    function toggleTds() {
      if (!tdsFields) return;
      tdsFields.hidden = !(tdsCheck && tdsCheck.checked);
      recalcTotals();
    }
    if (tdsCheck) {
      tdsCheck.addEventListener("change", toggleTds);
      toggleTds();
    }
    var tdsRateInput = qs("[data-expense-tds-rate]", form);
    if (tdsRateInput) tdsRateInput.addEventListener("input", recalcTotals);
    var paidInput = qs("[data-expense-amount-paid]", form);
    if (paidInput) paidInput.addEventListener("input", recalcTotals);

    // Duplicate invoice check
    var invoiceInput = qs("[data-expense-invoice]", form);
    var invoiceHint = qs("[data-expense-invoice-hint]", form);

    function checkDuplicateInvoice() {
      if (!invoiceInput || !invoiceInput.value.trim()) {
        if (invoiceHint) invoiceHint.hidden = true;
        return;
      }
      var vendor = vendorNameInput ? vendorNameInput.value : "";
      var url = "/api/accounts/expense-check-invoice?vendor=" +
        encodeURIComponent(vendor) + "&invoice=" + encodeURIComponent(invoiceInput.value.trim());
      if (recordId) url += "&exclude_id=" + recordId;
      fetch(url)
        .then(function (r) { return r.json(); })
        .then(function (data) {
          if (!invoiceHint) return;
          if (data.duplicate) {
            invoiceHint.textContent = "Duplicate invoice for this vendor.";
            invoiceHint.hidden = false;
            invoiceHint.classList.add("is-error");
          } else {
            invoiceHint.hidden = true;
            invoiceHint.classList.remove("is-error");
          }
        })
        .catch(function () {});
    }
    if (invoiceInput) {
      invoiceInput.addEventListener("blur", checkDuplicateInvoice);
      invoiceInput.addEventListener("input", function () {
        if (invoiceHint) invoiceHint.hidden = true;
      });
    }

    // Save buttons
    qsa("[data-expense-save]", form).forEach(function (btn) {
      btn.addEventListener("click", function (e) {
        e.preventDefault();
        setFormAction(btn.getAttribute("data-expense-save") === "submit" ? "save_submit" : "save_draft");
        if (!validateForm()) return;
        form.requestSubmit();
      });
    });

    qsa("[data-expense-toolbar-save]", module).forEach(function (btn) {
      btn.addEventListener("click", function () {
        if (btn.disabled) return;
        setFormAction(btn.getAttribute("data-expense-toolbar-save") === "submit" ? "save_submit" : "save_draft");
        if (!validateForm()) return;
        form.requestSubmit();
      });
    });

    function validateForm() {
      if (!vendorNameInput || !vendorNameInput.value.trim()) {
        window.alert("Vendor is required.");
        return false;
      }
      if (!projectSelect || !projectSelect.value) {
        window.alert("Project is required.");
        return false;
      }
      if (invoiceInput && invoiceInput.value.trim() && invoiceHint && !invoiceHint.hidden) {
        window.alert("Duplicate invoice number for this vendor.");
        return false;
      }
      var lines = qsa("[data-expense-line]", linesBody);
      if (!lines.length) {
        window.alert("Add at least one line item.");
        return false;
      }
      var hasValidLine = false;
      lines.forEach(function (row) {
        var desc = qs('input[name="line_description[]"]', row);
        var qty = qs("[data-line-qty]", row);
        var rate = qs("[data-line-rate]", row);
        if (desc && desc.value.trim() && parseNum(qty && qty.value) > 0 && parseNum(rate && rate.value) > 0) {
          hasValidLine = true;
        }
      });
      if (!hasValidLine) {
        window.alert("Enter valid line items (description, qty, rate).");
        return false;
      }
      return true;
    }

    // Quick picks
    qsa("[data-expense-pick-vendor]", module).forEach(function (chip) {
      chip.addEventListener("click", function () {
        var name = chip.getAttribute("data-expense-pick-vendor");
        if (vendorSelect) {
          var found = false;
          Array.prototype.forEach.call(vendorSelect.options, function (opt) {
            if (opt.getAttribute("data-name") === name) {
              vendorSelect.value = opt.value;
              found = true;
            }
          });
          if (!found && vendorNameInput) vendorNameInput.value = name;
          fillVendorMeta();
        }
      });
    });
    qsa("[data-expense-pick-project]", module).forEach(function (chip) {
      chip.addEventListener("click", function () {
        if (projectSelect) {
          projectSelect.value = chip.getAttribute("data-expense-pick-project");
          fillProjectMeta();
        }
      });
    });
    qsa("[data-expense-pick-head]", module).forEach(function (chip) {
      chip.addEventListener("click", function () {
        var headSelect = qs("[data-expense-chart-select]", form);
        if (headSelect) headSelect.value = chip.getAttribute("data-expense-pick-head");
      });
    });

    // Modals
    qsa("[data-expense-open-modal]", module).forEach(function (btn) {
      btn.addEventListener("click", function () {
        var id = btn.getAttribute("data-expense-open-modal");
        var dlg = qs('[data-expense-modal="' + id + '"]', module);
        if (dlg && dlg.showModal) dlg.showModal();
      });
    });
    qsa("[data-expense-close-modal]", module).forEach(function (btn) {
      btn.addEventListener("click", function () {
        var dlg = btn.closest("dialog");
        if (dlg) dlg.close();
      });
    });

    // Drag & drop attachment
    var dropzone = qs("[data-expense-dropzone]", form);
    var fileInput = qs("[data-expense-file]", form);
    if (dropzone && fileInput && !dropzone.getAttribute("data-readonly")) {
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
        if (e.dataTransfer.files.length) {
          fileInput.files = e.dataTransfer.files;
          showFilePreview(e.dataTransfer.files[0].name);
        }
      });
      fileInput.addEventListener("change", function () {
        if (fileInput.files[0]) showFilePreview(fileInput.files[0].name);
      });
    }

    function showFilePreview(name) {
      var preview = qs("[data-expense-preview]", dropzone);
      if (!preview) {
        preview = document.createElement("div");
        preview.className = "expense-attachment-preview";
        preview.setAttribute("data-expense-preview", "");
        dropzone.appendChild(preview);
      }
      preview.textContent = name;
    }

    // Auto-save draft (localStorage)
    var draftKey = "maxek-expense-draft";
    if (!form.getAttribute("data-readonly") && !recordId) {
      form.addEventListener("input", debounce(function () {
        try {
          var data = new FormData(form);
          var obj = {};
          data.forEach(function (val, key) {
            if (key.indexOf("line_") === 0) return;
            obj[key] = val;
          });
          localStorage.setItem(draftKey, JSON.stringify(obj));
        } catch (e) { /* ignore */ }
      }, 1200));

      try {
        var saved = localStorage.getItem(draftKey);
        if (saved && !window.location.search.match(/edit=|view=/)) {
          var parsed = JSON.parse(saved);
          Object.keys(parsed).forEach(function (key) {
            var field = form.elements[key];
            if (field && field.type !== "file") field.value = parsed[key];
          });
          fillProjectMeta();
          fillVendorMeta();
          recalcTotals();
        }
      } catch (e) { /* ignore */ }
    }

    form.addEventListener("submit", function () {
      qsa("[data-expense-line]", linesBody).forEach(function (row) {
        var item = qs('input[name="line_item[]"]', row);
        var desc = qs('input[name="line_description[]"]', row);
        if (item && desc && item.value.trim()) {
          var combined = item.value.trim();
          if (desc.value.trim()) combined += " — " + desc.value.trim();
          desc.value = combined;
        }
      });
      try { localStorage.removeItem(draftKey); } catch (e) { /* ignore */ }
    });

    // Excel export for register
    var exportBtn = qs('[data-erp-export="excel"]', module);
    if (exportBtn) {
      exportBtn.addEventListener("click", function () {
        var table = qs("#expense-register-table", module);
        if (!table || !window.URL) return;
        var rows = [];
        qsa("tr", table).forEach(function (tr) {
          var cells = qsa("th, td", tr).map(function (c) {
            return '"' + String(c.textContent).replace(/"/g, '""').trim() + '"';
          });
          if (cells.length) rows.push(cells.join(","));
        });
        var blob = new Blob([rows.join("\n")], { type: "text/csv;charset=utf-8;" });
        var a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "expense-register.csv";
        a.click();
      });
    }

    recalcTotals();
  }

  function debounce(fn, ms) {
    var t;
    return function () {
      var args = arguments;
      clearTimeout(t);
      t = setTimeout(function () { fn.apply(null, args); }, ms);
    };
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initModule);
  } else {
    initModule();
  }
})();
