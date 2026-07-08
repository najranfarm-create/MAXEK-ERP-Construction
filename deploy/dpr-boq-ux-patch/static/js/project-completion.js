(function () {
  "use strict";

  var docTypes = [];

  function syncProject(projectId) {
    var hidden = document.getElementById("pc_project_id");
    var nameSel = document.getElementById("pc_project_name");
    var codeSel = document.getElementById("pc_project_code");
    if (hidden) hidden.value = projectId || "";
    if (nameSel && nameSel.value !== projectId) nameSel.value = projectId || "";
    if (codeSel && codeSel.value !== projectId) codeSel.value = projectId || "";
    if (projectId) loadProjectContext(projectId);
  }

  function loadProjectContext(projectId) {
    fetch("/api/project-completion/project/" + encodeURIComponent(projectId), { credentials: "same-origin" })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data.error) return;
        var comp = document.getElementById("pc_completion_date");
        var war = document.getElementById("pc_warranty_date");
        var maint = document.querySelector("[name=maintenance_conditions]");
        if (comp && !comp.dataset.touched && data.planned_completion_date) comp.value = data.planned_completion_date;
        if (war && !war.dataset.touched && data.warranty_completion_date) war.value = data.warranty_completion_date;
        if (maint && !maint.value && data.last_maintenance_conditions) maint.value = data.last_maintenance_conditions;
      })
      .catch(function () {});
  }

  function reindexDocFiles() {
    var tbody = document.getElementById("pc-docs-body");
    if (!tbody) return;
    tbody.querySelectorAll("[data-pc-doc-row]").forEach(function (row, idx) {
      var fileInput = row.querySelector('input[type="file"]');
      if (fileInput) fileInput.name = "doc_file_" + idx;
    });
  }

  function bindDocRow(row) {
    var removeBtn = row.querySelector(".pc-remove-doc");
    if (removeBtn) {
      removeBtn.addEventListener("click", function () {
        var tbody = document.getElementById("pc-docs-body");
        if (!tbody || tbody.querySelectorAll("[data-pc-doc-row]").length <= 1) return;
        row.remove();
        reindexDocFiles();
      });
    }
  }

  function addDocRow() {
    var tpl = document.getElementById("pc-doc-row-template");
    var tbody = document.getElementById("pc-docs-body");
    if (!tpl || !tbody) return;
    var idx = tbody.querySelectorAll("[data-pc-doc-row]").length;
    var html = tpl.innerHTML.replace(/__IDX__/g, String(idx));
    var wrap = document.createElement("tbody");
    wrap.innerHTML = html.trim();
    var row = wrap.firstElementChild;
    tbody.appendChild(row);
    bindDocRow(row);
  }

  function bindProjectSync() {
    var nameSel = document.getElementById("pc_project_name");
    var codeSel = document.getElementById("pc_project_code");
    if (nameSel) nameSel.addEventListener("change", function () { syncProject(nameSel.value); });
    if (codeSel) codeSel.addEventListener("change", function () { syncProject(codeSel.value); });
    var hidden = document.getElementById("pc_project_id");
    if (hidden && hidden.value) syncProject(hidden.value);
  }

  function bindStitchPanel() {
    var required = document.getElementById("pc_stitch_required");
    var stitched = document.getElementById("pc_stitched");
    var stitchDate = document.getElementById("pc_stitch_date");
    if (!required) return;
    required.addEventListener("change", function () {
      if (required.value === "yes" && stitched && stitched.value === "yes" && stitchDate && !stitchDate.value) {
        stitchDate.value = new Date().toISOString().slice(0, 10);
      }
    });
    if (stitched) {
      stitched.addEventListener("change", function () {
        if (stitched.value === "yes" && stitchDate && !stitchDate.value) {
          stitchDate.value = new Date().toISOString().slice(0, 10);
        }
      });
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    bindProjectSync();
    bindStitchPanel();
    document.querySelectorAll("[data-pc-doc-row]").forEach(bindDocRow);
    var addBtn = document.getElementById("pc-add-doc");
    if (addBtn) addBtn.addEventListener("click", addDocRow);
    var comp = document.getElementById("pc_completion_date");
    var war = document.getElementById("pc_warranty_date");
    if (comp) comp.addEventListener("change", function () { comp.dataset.touched = "1"; });
    if (war) war.addEventListener("change", function () { war.dataset.touched = "1"; });
    reindexDocFiles();
  });
})();
