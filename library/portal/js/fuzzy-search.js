(function () {
  "use strict";

  var CONTAINER_ID = "fuzzy-search-container";
  var INDEX_PATH = "library/portal/search-index.json";

  var ms = null;
  var allDocs = null;
  var loadState = "idle"; // idle | loading | ready | error

  var CAT_LABELS = {
    asset: "Asset",
    topic: "Topic",
    flashcard: "Flashcard",
    quiz: "Quiz",
  };

  var CAT_COLORS = {
    asset: "var(--md-primary-fg-color, #3f51b5)",
    topic: "#00838F",
    flashcard: "#6A1B9A",
    quiz: "#E65100",
  };

  function detectBase() {
    var scripts = document.querySelectorAll('script[src*="fuzzy-search.js"]');
    if (!scripts.length) return "";
    var src = scripts[0].getAttribute("src");
    var idx = src.indexOf("library/portal/js/fuzzy-search.js");
    return idx > 0 ? src.substring(0, idx) : "";
  }

  function siteBase() {
    var path = window.location.pathname;
    var idx = path.indexOf("/library/");
    if (idx > 0) return path.substring(0, idx) + "/";
    idx = path.indexOf("/reports/");
    if (idx > 0) return path.substring(0, idx) + "/";
    return "/";
  }

  function init() {
    var container = document.getElementById(CONTAINER_ID);
    if (!container) return;
    if (typeof MiniSearch === "undefined") {
      container.innerHTML = '<p style="color:var(--md-default-fg-color)">MiniSearch not loaded. Check console.</p>';
      return;
    }
    buildUI(container);
  }

  function buildUI(container) {
    container.innerHTML = "";

    var wrap = document.createElement("div");
    wrap.style.cssText = "max-width:800px;";

    var inputRow = document.createElement("div");
    inputRow.style.cssText = "display:flex;gap:8px;margin-bottom:12px;";

    var input = document.createElement("input");
    input.type = "search";
    input.placeholder = "Search with typo tolerance — try 'kuberntes', 'anisble', 'promethus'...";
    input.id = "fuzzy-search-input";
    input.style.cssText = "flex:1;padding:8px 12px;font-size:1em;border:1px solid var(--md-default-fg-color--lighter,#ccc);border-radius:4px;background:var(--md-default-bg-color,#fff);color:var(--md-default-fg-color,#333);";

    var filterWrap = document.createElement("div");
    filterWrap.style.cssText = "display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px;";

    var catAll = makeChip("All", "", true);
    var catAsset = makeChip("Assets", "asset", false);
    var catTopic = makeChip("Topics", "topic", false);
    var catFlash = makeChip("Flashcards", "flashcard", false);
    var catQuiz = makeChip("Quiz", "quiz", false);
    var activeFilter = "";

    [catAll, catAsset, catTopic, catFlash, catQuiz].forEach(function (chip) {
      chip.addEventListener("click", function () {
        activeFilter = chip.dataset.cat;
        [catAll, catAsset, catTopic, catFlash, catQuiz].forEach(function (c) {
          c.style.opacity = c.dataset.cat === activeFilter ? "1" : "0.45";
          c.style.fontWeight = c.dataset.cat === activeFilter ? "bold" : "normal";
        });
        doSearch(input.value.trim());
      });
      filterWrap.appendChild(chip);
    });

    var status = document.createElement("div");
    status.style.cssText = "font-size:0.8em;opacity:0.65;margin-bottom:8px;min-height:1.4em;";
    status.textContent = "Loading index...";

    var results = document.createElement("div");
    results.id = "fuzzy-results";

    inputRow.appendChild(input);
    wrap.appendChild(inputRow);
    wrap.appendChild(filterWrap);
    wrap.appendChild(status);
    wrap.appendChild(results);
    container.appendChild(wrap);

    var base = detectBase();
    var url = base + INDEX_PATH;

    loadState = "loading";
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.onload = function () {
      if (xhr.status !== 200) {
        status.textContent = "Failed to load search index (HTTP " + xhr.status + ").";
        loadState = "error";
        return;
      }
      allDocs = JSON.parse(xhr.responseText);
      ms = new MiniSearch({
        fields: ["title", "topics", "aliases", "snippet"],
        storeFields: ["title", "type", "level", "area", "color", "snippet", "path", "cat"],
        searchOptions: {
          boost: { title: 3, topics: 2, aliases: 2, snippet: 1 },
          fuzzy: 0.2,
          prefix: true,
        },
      });
      ms.addAll(allDocs);
      loadState = "ready";
      status.textContent = allDocs.length.toLocaleString() + " documents indexed — try searching now.";
      input.focus();

      if (input.value.trim()) doSearch(input.value.trim());
    };
    xhr.onerror = function () {
      status.textContent = "Network error loading search index.";
      loadState = "error";
    };
    xhr.send();

    var debounceTimer = null;
    input.addEventListener("input", function () {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function () {
        doSearch(input.value.trim());
      }, 150);
    });

    function doSearch(query) {
      if (loadState !== "ready") return;
      results.innerHTML = "";
      if (!query) {
        status.textContent = allDocs.length.toLocaleString() + " documents indexed — try searching now.";
        return;
      }

      var hits = ms.search(query, { fuzzy: 0.25, prefix: true });

      if (activeFilter) {
        hits = hits.filter(function (h) { return h.cat === activeFilter; });
      }

      status.textContent = hits.length
        ? hits.length + " result" + (hits.length === 1 ? "" : "s") + " for "" + query + """
        : "No results for "" + query + "" — try a different spelling";

      var shown = hits.slice(0, 40);
      shown.forEach(function (hit) {
        var item = document.createElement("div");
        item.style.cssText = "padding:10px 0;border-bottom:1px solid var(--md-default-fg-color--lightest,#eee);";

        var titleRow = document.createElement("div");
        titleRow.style.cssText = "display:flex;align-items:baseline;gap:8px;flex-wrap:wrap;";

        var base2 = siteBase();
        var href = hit.path ? base2 + hit.path : null;

        var titleEl;
        if (href) {
          titleEl = document.createElement("a");
          titleEl.href = href;
          titleEl.style.cssText = "font-weight:600;font-size:0.95em;color:var(--md-primary-fg-color,#3f51b5);text-decoration:none;";
          titleEl.textContent = hit.title;
        } else {
          titleEl = document.createElement("span");
          titleEl.style.cssText = "font-weight:600;font-size:0.95em;";
          titleEl.textContent = hit.title;
        }

        var badge = document.createElement("span");
        badge.style.cssText = "font-size:0.7em;padding:1px 6px;border-radius:10px;color:#fff;background:" +
          (CAT_COLORS[hit.cat] || "#999") + ";white-space:nowrap;";
        badge.textContent = hit.type || CAT_LABELS[hit.cat] || hit.cat;

        titleRow.appendChild(titleEl);
        titleRow.appendChild(badge);

        if (hit.level || hit.area) {
          var meta = document.createElement("span");
          meta.style.cssText = "font-size:0.75em;opacity:0.6;";
          var parts = [];
          if (hit.level) parts.push(hit.level);
          if (hit.area) parts.push(hit.area);
          meta.textContent = parts.join(" · ");
          titleRow.appendChild(meta);
        }

        item.appendChild(titleRow);

        if (hit.snippet) {
          var snip = document.createElement("div");
          snip.style.cssText = "font-size:0.82em;opacity:0.75;margin-top:3px;line-height:1.4;";
          snip.textContent = hit.snippet.length > 160 ? hit.snippet.slice(0, 160) + "…" : hit.snippet;
          item.appendChild(snip);
        }

        results.appendChild(item);
      });

      if (hits.length > 40) {
        var more = document.createElement("p");
        more.style.cssText = "font-size:0.8em;opacity:0.6;padding-top:8px;";
        more.textContent = "Showing top 40 of " + hits.length + " results. Refine your query to narrow down.";
        results.appendChild(more);
      }
    }
  }

  function makeChip(label, cat, active) {
    var el = document.createElement("button");
    el.textContent = label;
    el.dataset.cat = cat;
    el.style.cssText = "padding:3px 10px;border-radius:12px;border:1px solid var(--md-default-fg-color--lighter,#ccc);background:none;cursor:pointer;font-size:0.8em;color:var(--md-default-fg-color,#333);opacity:" + (active ? "1" : "0.45") + ";font-weight:" + (active ? "bold" : "normal") + ";";
    return el;
  }

  function safeInit() {
    if (document.getElementById(CONTAINER_ID)) {
      init();
    }
  }

  // Run immediately (handles direct page loads)
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", safeInit);
  } else {
    safeInit();
  }

  // Also subscribe to document$ for instant navigation re-renders
  if (typeof document$ !== "undefined") {
    document$.subscribe(safeInit);
  }
})();
