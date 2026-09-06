/**
 * Tier Filter for GrokDevOps Wiki
 *
 * Adds a toggle bar at the top of pages that have tables with a "Tier" column.
 * Default: DevOps Focus (tiers 1-3). Users can toggle to "All Tiers" to see
 * Life Skills content, or "Core Only" for resume-proven skills.
 *
 * Detects tier values from table cell text: Core, Professional, Specialty,
 * Life Skills (matching TIER_LABELS in gen_content_indexes.py).
 */

(function () {
  "use strict";

  var TIER_MAP = {
    Core: 1,
    Professional: 2,
    Specialty: 3,
    "Life Skills": 4,
  };

  var FILTER_ID = "gd-tier-filter";

  function findTierTables() {
    var tables = document.querySelectorAll("table");
    var tierTables = [];
    for (var i = 0; i < tables.length; i++) {
      var headers = tables[i].querySelectorAll("thead th");
      for (var j = 0; j < headers.length; j++) {
        if (headers[j].textContent.trim() === "Tier") {
          tierTables.push({ table: tables[i], tierCol: j });
          break;
        }
      }
    }
    return tierTables;
  }

  function getTierFromRow(row, tierCol) {
    var cells = row.querySelectorAll("td");
    if (cells.length > tierCol) {
      var text = cells[tierCol].textContent.trim();
      return TIER_MAP[text] || 0;
    }
    return 0;
  }

  function applyFilter(tierTables, maxTier) {
    var hiddenCount = 0;
    var shownCount = 0;
    for (var i = 0; i < tierTables.length; i++) {
      var rows = tierTables[i].table.querySelectorAll("tbody tr");
      for (var j = 0; j < rows.length; j++) {
        var tier = getTierFromRow(rows[j], tierTables[i].tierCol);
        if (maxTier > 0 && tier > maxTier) {
          rows[j].style.display = "none";
          hiddenCount++;
        } else {
          rows[j].style.display = "";
          shownCount++;
        }
      }
    }
    return { shown: shownCount, hidden: hiddenCount };
  }

  function createFilterBar(tierTables) {
    // Remove existing filter bar if present
    var existing = document.getElementById(FILTER_ID);
    if (existing) existing.remove();

    // Count topics per tier
    var tierCounts = { 1: 0, 2: 0, 3: 0, 4: 0 };
    for (var i = 0; i < tierTables.length; i++) {
      var rows = tierTables[i].table.querySelectorAll("tbody tr");
      for (var j = 0; j < rows.length; j++) {
        var tier = getTierFromRow(rows[j], tierTables[i].tierCol);
        if (tier >= 1 && tier <= 4) tierCounts[tier]++;
      }
    }

    var bar = document.createElement("div");
    bar.id = FILTER_ID;
    bar.style.cssText =
      "margin: 1em 0; padding: 0.75em 1em; " +
      "background: var(--md-code-bg-color, #f5f5f5); " +
      "border-radius: 8px; display: flex; flex-wrap: wrap; " +
      "align-items: center; gap: 0.5em; font-size: 0.85em;";

    var label = document.createElement("span");
    label.textContent = "Show: ";
    label.style.fontWeight = "600";
    bar.appendChild(label);

    var buttons = [
      { text: "All Tiers", maxTier: 0, title: "Show everything" },
      {
        text: "DevOps Focus (1\u20133)",
        maxTier: 3,
        title: "Hide Life Skills / personal development topics",
      },
      {
        text: "Core Only (1)",
        maxTier: 1,
        title: "Resume-proven skills only",
      },
    ];

    var activeBtn = null;

    for (var b = 0; b < buttons.length; b++) {
      (function (cfg) {
        var btn = document.createElement("button");
        btn.textContent = cfg.text;
        btn.title = cfg.title;
        btn.className = "md-button md-button--primary";
        btn.style.cssText =
          "padding: 0.3em 0.8em; font-size: 0.85em; cursor: pointer; " +
          "border-radius: 4px; border: 1px solid var(--md-primary-fg-color, #4051b5); " +
          "transition: all 0.15s;";

        if (cfg.maxTier === 3) {
          activeBtn = btn;
          btn.style.background = "var(--md-primary-fg-color, #4051b5)";
          btn.style.color = "var(--md-primary-bg-color, #fff)";
        } else {
          btn.style.background = "transparent";
          btn.style.color = "var(--md-primary-fg-color, #4051b5)";
        }

        btn.addEventListener("click", function () {
          var result = applyFilter(tierTables, cfg.maxTier);
          // Update active state
          var allBtns = bar.querySelectorAll("button");
          for (var k = 0; k < allBtns.length; k++) {
            allBtns[k].style.background = "transparent";
            allBtns[k].style.color = "var(--md-primary-fg-color, #4051b5)";
          }
          btn.style.background = "var(--md-primary-fg-color, #4051b5)";
          btn.style.color = "var(--md-primary-bg-color, #fff)";
          // Update status
          var status = bar.querySelector(".gd-filter-status");
          if (status) {
            if (cfg.maxTier === 0) {
              status.textContent = "";
            } else {
              status.textContent =
                result.shown + " shown, " + result.hidden + " hidden";
            }
          }
        });
        bar.appendChild(btn);
      })(buttons[b]);
    }

    var status = document.createElement("span");
    status.className = "gd-filter-status";
    status.style.cssText = "margin-left: 0.5em; opacity: 0.7; font-style: italic;";
    bar.appendChild(status);

    return bar;
  }

  function init() {
    var tierTables = findTierTables();
    if (tierTables.length === 0) return;

    // Insert the filter bar before the first heading after the page title
    var contentArea = document.querySelector(".md-content__inner");
    if (!contentArea) return;

    // Find a good insertion point — after the first paragraph
    var firstH1 = contentArea.querySelector("h1");
    var insertAfter = null;
    if (firstH1) {
      // Find the next sibling that is a paragraph or the quick nav heading
      var sibling = firstH1.nextElementSibling;
      while (sibling) {
        if (
          sibling.tagName === "P" ||
          sibling.tagName === "H2" ||
          sibling.tagName === "HR"
        ) {
          insertAfter = sibling;
          break;
        }
        sibling = sibling.nextElementSibling;
      }
    }

    var bar = createFilterBar(tierTables);
    if (insertAfter && insertAfter.parentNode) {
      insertAfter.parentNode.insertBefore(bar, insertAfter);
    } else if (contentArea.firstChild) {
      contentArea.insertBefore(bar, contentArea.firstChild);
    }

    // Apply DevOps Focus (tiers 1-3) filter by default
    var result = applyFilter(tierTables, 3);
    var status = bar.querySelector(".gd-filter-status");
    if (status && result.hidden > 0) {
      status.textContent = result.shown + " shown, " + result.hidden + " hidden";
    }
  }

  // Run on load
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  // Re-run after MkDocs Material instant navigation
  if (typeof document$ !== "undefined") {
    document$.subscribe(function () {
      init();
    });
  }
})();
