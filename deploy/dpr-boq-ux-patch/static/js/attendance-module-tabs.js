(function () {
  "use strict";

  const PANEL_IDS = {
    entry: ["add-attendance", "sub-bulk-attendance"],
    saved: ["attendance-saved-list", "attendance-records", "attendance-register"],
    monthly: ["monthly-attendance"],
  };

  function currentTab() {
    const params = new URLSearchParams(window.location.search);
    const tab = (params.get("tab") || "").trim().toLowerCase();
    if (tab === "saved" || tab === "monthly" || tab === "entry") {
      return tab;
    }
    if (params.get("mode") === "monthly") {
      return "monthly";
    }
    if (window.location.hash === "#monthly-attendance") {
      return "monthly";
    }
    if (window.location.hash === "#attendance-saved-list") {
      return "saved";
    }
    return "entry";
  }

  function markPanel(node, tabName) {
    if (!node) {
      return;
    }
    node.setAttribute("data-attendance-tab-panel", tabName);
  }

  function ensureSavedPanelId() {
    const known = document.getElementById("attendance-saved-list");
    if (known) {
      return known;
    }
    const candidates = document.querySelectorAll(
      ".erp-table-panel, .erp-form-card, section.erp-module-list-panel"
    );
    for (let i = 0; i < candidates.length; i += 1) {
      const panel = candidates[i];
      if (!panel.querySelector("table")) {
        continue;
      }
      if (panel.id === "add-attendance" || panel.closest("#add-attendance")) {
        continue;
      }
      if (panel.id === "monthly-attendance" || panel.closest("#monthly-attendance")) {
        continue;
      }
      if (!panel.id) {
        panel.id = "attendance-saved-list";
      }
      return panel;
    }
    return null;
  }

  function tagPanels() {
    PANEL_IDS.entry.forEach(function (id) {
      markPanel(document.getElementById(id), "entry");
    });
    PANEL_IDS.monthly.forEach(function (id) {
      markPanel(document.getElementById(id), "monthly");
    });
    PANEL_IDS.saved.forEach(function (id) {
      markPanel(document.getElementById(id), "saved");
    });
    markPanel(ensureSavedPanelId(), "saved");
  }

  function setActiveTabUi(tab) {
    document.querySelectorAll("[data-attendance-tab-link]").forEach(function (link) {
      const name = link.getAttribute("data-attendance-tab-link");
      link.classList.toggle("active", name === tab);
    });
  }

  function showTab(tab) {
    const panels = document.querySelectorAll("[data-attendance-tab-panel]");
    panels.forEach(function (panel) {
      const name = panel.getAttribute("data-attendance-tab-panel");
      panel.hidden = name !== tab;
    });
    setActiveTabUi(tab);
  }

  function initAttendanceTabs() {
    if (!document.querySelector("[data-attendance-tabs]")) {
      return;
    }
    tagPanels();
    showTab(currentTab());
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAttendanceTabs);
  } else {
    initAttendanceTabs();
  }
})();
