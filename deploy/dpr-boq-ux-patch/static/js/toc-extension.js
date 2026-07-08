(function () {
  'use strict';

  function daysBetween(start, end) {
    if (!start || !end) return '';
    var d0 = new Date(start + 'T00:00:00');
    var d1 = new Date(end + 'T00:00:00');
    if (isNaN(d0.getTime()) || isNaN(d1.getTime())) return '';
    var diff = Math.round((d1 - d0) / (1000 * 60 * 60 * 24));
    return diff >= 0 ? String(diff) : '';
  }

  function recalcExtensionDays(form) {
    var prev = form.querySelector('[data-toc-prev-completion]');
    var next = form.querySelector('[data-toc-next-date]');
    var days = form.querySelector('[data-toc-ext-days]');
    if (!prev || !next || !days) return;
    var val = daysBetween(prev.value, next.value);
    if (val !== '') days.value = val;
  }

  function clearBgRows(container) {
    container.querySelectorAll('[data-toc-bg-row]').forEach(function (row) {
      row.remove();
    });
  }

  function appendBgRow(container, template, data) {
    if (!template || !container) return;
    var node = template.content.firstElementChild.cloneNode(true);
    if (data) {
      var map = {
        bg_original_number: data.bg_number || data.original_bg_number || '',
        bg_original_expiry_date: data.bg_expiry_date || data.original_bg_expiry_date || '',
        bg_original_amount: data.bg_amount != null ? data.bg_amount : (data.original_bg_amount || ''),
        bg_extended_number: data.extended_bg_number || '',
        bg_extended_date: data.extended_bg_date || '',
        bg_extended_amount: data.extended_bg_amount != null ? data.extended_bg_amount : '',
        bg_extended_expiry_date: data.extended_bg_expiry_date || '',
        bg_remarks: data.remarks || '',
      };
      Object.keys(map).forEach(function (name) {
        var input = node.querySelector('[name="' + name + '"]');
        if (input && map[name] !== '') input.value = map[name];
      });
    }
    container.appendChild(node);
  }

  function loadProjectContext(projectId, form) {
    if (!projectId || !form) return;
    fetch('/api/toc-extension/project/' + encodeURIComponent(projectId))
      .then(function (res) { return res.ok ? res.json() : null; })
      .then(function (data) {
        if (!data || data.error) return;
        var agreement = form.querySelector('[data-toc-agreement-no]');
        var base = form.querySelector('[data-toc-base-completion]');
        var prev = form.querySelector('[data-toc-prev-completion]');
        if (agreement && data.agreement_number) agreement.value = data.agreement_number;
        if (base && data.agreement_base_completion_date) base.value = data.agreement_base_completion_date;
        if (prev && data.previous_completion_date) prev.value = data.previous_completion_date;
        var bgContainer = form.querySelector('[data-toc-bg-rows]');
        var template = document.getElementById('toc-bg-row-template');
        if (!bgContainer || !template || !data.bank_guarantees || !data.bank_guarantees.length) {
          recalcExtensionDays(form);
          return;
        }
        var hasExtended = bgContainer.querySelector('[name="bg_extended_number"]');
        var hasValues = hasExtended && hasExtended.value;
        if (hasValues) {
          recalcExtensionDays(form);
          return;
        }
        clearBgRows(bgContainer);
        data.bank_guarantees.forEach(function (bg) {
          appendBgRow(bgContainer, template, bg);
        });
        recalcExtensionDays(form);
      })
      .catch(function () { /* ignore */ });
  }

  function initTocForm() {
    var form = document.querySelector('[data-toc-form]');
    if (!form) return;

    var projectSelect = form.querySelector('[data-toc-project-select]');
    var bgContainer = form.querySelector('[data-toc-bg-rows]');
    var template = document.getElementById('toc-bg-row-template');
    var addBtn = document.querySelector('[data-toc-add-bg]');

    form.querySelectorAll('[data-toc-prev-completion], [data-toc-next-date]').forEach(function (el) {
      el.addEventListener('change', function () { recalcExtensionDays(form); });
    });

    if (projectSelect && !projectSelect.disabled) {
      projectSelect.addEventListener('change', function () {
        loadProjectContext(projectSelect.value, form);
      });
      if (projectSelect.value) {
        loadProjectContext(projectSelect.value, form);
      }
    } else {
      recalcExtensionDays(form);
    }

    if (addBtn && bgContainer && template) {
      addBtn.addEventListener('click', function () {
        appendBgRow(bgContainer, template, null);
      });
    }

    document.addEventListener('click', function (event) {
      var removeBtn = event.target.closest('[data-toc-remove-bg]');
      if (!removeBtn || !form.contains(removeBtn)) return;
      var row = removeBtn.closest('[data-toc-bg-row]');
      var rows = form.querySelectorAll('[data-toc-bg-row]');
      if (row && rows.length > 1) row.remove();
    });

    var tocDate = form.querySelector('[data-toc-date]');
    var docNo = form.querySelector('[data-toc-doc-no]');
    if (tocDate && docNo && !docNo.value) {
      tocDate.addEventListener('change', function () {
        fetch('/api/toc-extension/preview-doc-no?toc_date=' + encodeURIComponent(tocDate.value || ''))
          .then(function (res) { return res.ok ? res.json() : null; })
          .then(function (data) {
            if (data && data.document_number && !form.querySelector('[name="toc_id"]')) {
              docNo.value = data.document_number;
            }
          })
          .catch(function () { /* ignore */ });
      });
    }
  }

  document.addEventListener('DOMContentLoaded', initTocForm);
})();
