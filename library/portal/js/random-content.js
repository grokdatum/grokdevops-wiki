/**
 * Random Content Navigator for GrokDevOps Wiki
 *
 * Loads random_manifest.json and powers "Surprise Me" buttons on portal pages.
 * Buttons use data-random-type to specify content type, data-random-domain for
 * domain filtering, and optional data-random-target for inline display.
 *
 * Usage in markdown (MkDocs Material attr_list extension):
 *   <button class="md-button" data-random-type="all">Surprise Me</button>
 *   <button class="md-button" data-random-type="footgun">Random Footgun</button>
 *   <button class="md-button" data-random-type="footgun" data-random-target="results">Show 5</button>
 *   <div id="results"></div>
 */

(function () {
  "use strict";

  var manifest = null;
  var siteBase = null;

  // Detect the site base URL from our own script tag.
  // We know this script is served at <base>/library/portal/js/random-content.js
  function detectSiteBase() {
    var scripts = document.querySelectorAll('script[src*="random-content.js"]');
    for (var i = 0; i < scripts.length; i++) {
      var src = scripts[i].src;
      var idx = src.indexOf("library/portal/js/random-content.js");
      if (idx !== -1) {
        return src.substring(0, idx);
      }
    }
    // Fallback: use the page's base URI and walk up
    var base = document.baseURI || window.location.href;
    // Strip everything after the site name
    var parts = base.split("/");
    // Find the segment that looks like the site root (ends with -wiki or similar)
    for (var j = 3; j < parts.length; j++) {
      if (parts[j].indexOf("wiki") !== -1 || parts[j] === "") {
        return parts.slice(0, j + 1).join("/") + "/";
      }
    }
    return parts.slice(0, 4).join("/") + "/";
  }

  function getSiteBase() {
    if (!siteBase) {
      siteBase = detectSiteBase();
    }
    return siteBase;
  }

  function loadManifest(callback) {
    if (manifest) {
      callback(manifest);
      return;
    }
    var url = getSiteBase() + "library/portal/random_manifest.json";
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.onload = function () {
      if (xhr.status === 200) {
        try {
          manifest = JSON.parse(xhr.responseText);
          callback(manifest);
        } catch (e) {
          console.warn("[random-content] parse error:", e);
        }
      }
    };
    xhr.onerror = function () {
      console.warn("[random-content] network error loading manifest");
    };
    xhr.send();
  }

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function getAllItems(data) {
    var all = [];
    for (var type in data) {
      if (!data.hasOwnProperty(type)) continue;
      var items = data[type];
      for (var i = 0; i < items.length; i++) {
        all.push({
          name: items[i].name,
          domain: items[i].domain,
          url: items[i].url,
          type: type,
        });
      }
    }
    return all;
  }

  var TYPE_LABELS = {
    footgun: "Footgun",
    primer: "Primer",
    street_ops: "Street Ops",
    trivia: "Trivia",
    deep_thinking: "Deep Thinking",
    cheatsheet: "Cheatsheet",
    runbook: "Runbook",
    case_study: "Case Study",
    drill: "Drill",
    deep_dive: "Deep Dive",
  };

  function buildPool(data, type, domain) {
    var pool;
    if (type === "all") {
      pool = getAllItems(data);
    } else if (data[type]) {
      pool = data[type].map(function (item) {
        return { name: item.name, domain: item.domain, url: item.url, type: type };
      });
    } else {
      return [];
    }
    if (domain) {
      pool = pool.filter(function (item) {
        return item.domain === domain;
      });
    }
    return pool;
  }

  function sampleN(pool, n) {
    var picks = [];
    var used = {};
    var limit = Math.min(n, pool.length);
    var attempts = 0;
    while (picks.length < limit && attempts < limit * 3) {
      var pick = pickRandom(pool);
      attempts++;
      if (!used[pick.url]) {
        used[pick.url] = true;
        picks.push(pick);
      }
    }
    return picks;
  }

  // Navigate directly to a random page
  function navigateRandom(type, domain) {
    loadManifest(function (data) {
      var pool = buildPool(data, type, domain);
      if (pool.length === 0) return;
      var pick = pickRandom(pool);
      window.location.href = getSiteBase() + pick.url;
    });
  }

  // Show random picks inline in a target element
  function showRandomInline(type, domain, targetId) {
    loadManifest(function (data) {
      var pool = buildPool(data, type, domain);
      if (pool.length === 0) return;

      var picks = sampleN(pool, 5);
      var target = document.getElementById(targetId);
      if (!target) return;

      var base = getSiteBase();
      var showType = type === "all";
      var html = "<ul>";
      for (var i = 0; i < picks.length; i++) {
        var p = picks[i];
        var label = TYPE_LABELS[p.type] || p.type;
        html += '<li><a href="' + base + p.url + '">' + p.name + "</a>";
        if (showType) {
          html += " <small>(" + label + " &middot; " + p.domain + ")</small>";
        } else {
          html += " <small>(" + p.domain + ")</small>";
        }
        html += "</li>";
      }
      html += "</ul>";
      target.innerHTML = html;
    });
  }

  // Bind click handlers to buttons with data-random-type
  function bindButtons() {
    var buttons = document.querySelectorAll("[data-random-type]");
    for (var i = 0; i < buttons.length; i++) {
      (function (btn) {
        if (btn.dataset.randomBound) return;
        btn.dataset.randomBound = "1";
        btn.addEventListener("click", function (e) {
          e.preventDefault();
          var type = btn.getAttribute("data-random-type");
          var domain = btn.getAttribute("data-random-domain") || "";
          var target = btn.getAttribute("data-random-target");
          if (target) {
            showRandomInline(type, domain, target);
          } else {
            navigateRandom(type, domain);
          }
        });
      })(buttons[i]);
    }
  }

  // Bind on initial load
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bindButtons);
  } else {
    bindButtons();
  }

  // Re-bind after MkDocs Material instant navigation (uses document$ observable)
  if (typeof document$ !== "undefined") {
    document$.subscribe(function () {
      bindButtons();
    });
  }
})();
