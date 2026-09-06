(function () {
  "use strict";

  var GRAPH_CONTAINER_ID = "graph-container";
  var DATA_PATH = "graph-data.json";

  function detectBase() {
    var scripts = document.querySelectorAll('script[src*="graph.js"]');
    if (scripts.length === 0) return "";
    var src = scripts[0].getAttribute("src");
    var idx = src.indexOf("library/portal/js/graph.js");
    return idx > 0 ? src.substring(0, idx) : "";
  }

  function init() {
    var container = document.getElementById(GRAPH_CONTAINER_ID);
    if (!container) return;

    var base = detectBase();
    var url = base + "library/portal/graph-data.json";

    var xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.onload = function () {
      if (xhr.status === 200) {
        var data = JSON.parse(xhr.responseText);
        render(container, data);
      }
    };
    xhr.send();
  }

  var LEVEL_RADIUS = { L0: 3, L1: 4, L2: 5, L3: 7 };

  function render(container, data) {
    var width = container.clientWidth || 960;
    var height = Math.max(600, window.innerHeight - 200);

    container.innerHTML = "";

    var controls = document.createElement("div");
    controls.style.cssText = "margin-bottom:8px;display:flex;flex-wrap:wrap;gap:6px;align-items:center;";

    var areaNames = Object.keys(data.areas).sort();
    var select = document.createElement("select");
    select.id = "graph-area-filter";
    var optAll = document.createElement("option");
    optAll.value = "";
    optAll.textContent = "All areas";
    select.appendChild(optAll);
    areaNames.forEach(function (a) {
      var opt = document.createElement("option");
      opt.value = a;
      opt.textContent = data.areas[a].display;
      select.appendChild(opt);
    });
    controls.appendChild(select);

    var levelSelect = document.createElement("select");
    levelSelect.id = "graph-level-filter";
    var lAll = document.createElement("option");
    lAll.value = "";
    lAll.textContent = "All levels";
    levelSelect.appendChild(lAll);
    ["L0", "L1", "L2", "L3"].forEach(function (l) {
      var opt = document.createElement("option");
      opt.value = l;
      opt.textContent = l;
      levelSelect.appendChild(opt);
    });
    controls.appendChild(levelSelect);

    var resetBtn = document.createElement("button");
    resetBtn.textContent = "Reset";
    resetBtn.style.cssText = "padding:4px 12px;cursor:pointer;";
    controls.appendChild(resetBtn);

    var countSpan = document.createElement("span");
    countSpan.style.cssText = "margin-left:auto;font-size:0.85em;opacity:0.7;";
    countSpan.textContent = data.nodes.length + " assets, " + data.edges.length + " connections";
    controls.appendChild(countSpan);

    container.appendChild(controls);

    var svgEl = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svgEl.setAttribute("width", width);
    svgEl.setAttribute("height", height);
    svgEl.style.cssText = "border:1px solid var(--md-default-fg-color--lightest, #ddd);border-radius:4px;background:var(--md-default-bg-color, #fff);";
    container.appendChild(svgEl);

    var svg = d3.select(svgEl);
    var g = svg.append("g");

    var zoom = d3.zoom()
      .scaleExtent([0.1, 6])
      .on("zoom", function (event) {
        g.attr("transform", event.transform);
      });
    svg.call(zoom);

    var nodeMap = {};
    data.nodes.forEach(function (n) { nodeMap[n.id] = n; });

    var validEdges = data.edges.filter(function (e) {
      return nodeMap[e.source] && nodeMap[e.target];
    });

    var simulation = d3.forceSimulation(data.nodes)
      .force("link", d3.forceLink(validEdges).id(function (d) { return d.id; }).distance(40).strength(function (d) {
        return d.rel === "prerequisite" ? 0.3 : 0.05;
      }))
      .force("charge", d3.forceManyBody().strength(-20).distanceMax(200))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(function (d) {
        return (LEVEL_RADIUS[d.level] || 4) + 1;
      }))
      .force("x", d3.forceX(width / 2).strength(0.03))
      .force("y", d3.forceY(height / 2).strength(0.03))
      .alphaDecay(0.02);

    var link = g.append("g")
      .attr("stroke-opacity", 0.15)
      .selectAll("line")
      .data(validEdges)
      .join("line")
      .attr("stroke", function (d) {
        return d.rel === "prerequisite" ? "var(--md-default-fg-color, #333)" : "#999";
      })
      .attr("stroke-width", function (d) {
        return d.rel === "prerequisite" ? 0.8 : 0.3;
      });

    var node = g.append("g")
      .selectAll("circle")
      .data(data.nodes)
      .join("circle")
      .attr("r", function (d) { return LEVEL_RADIUS[d.level] || 4; })
      .attr("fill", function (d) {
        var areaInfo = data.areas[d.area];
        return areaInfo ? areaInfo.color : "#999";
      })
      .attr("stroke", "var(--md-default-bg-color, #fff)")
      .attr("stroke-width", 0.5)
      .style("cursor", "pointer")
      .call(d3.drag()
        .on("start", function (event, d) {
          if (!event.active) simulation.alphaTarget(0.3).restart();
          d.fx = d.x;
          d.fy = d.y;
        })
        .on("drag", function (event, d) {
          d.fx = event.x;
          d.fy = event.y;
        })
        .on("end", function (event, d) {
          if (!event.active) simulation.alphaTarget(0);
          d.fx = null;
          d.fy = null;
        })
      );

    var tooltip = d3.select(container).append("div")
      .style("position", "absolute")
      .style("pointer-events", "none")
      .style("background", "var(--md-default-bg-color, #fff)")
      .style("border", "1px solid var(--md-default-fg-color--lightest, #ccc)")
      .style("border-radius", "4px")
      .style("padding", "6px 10px")
      .style("font-size", "0.8em")
      .style("box-shadow", "0 2px 8px rgba(0,0,0,0.15)")
      .style("display", "none")
      .style("z-index", "100")
      .style("max-width", "300px");

    node.on("mouseover", function (event, d) {
      var areaInfo = data.areas[d.area];
      var areaName = areaInfo ? areaInfo.display : d.area;
      tooltip.html(
        "<strong>" + d.title + "</strong><br>" +
        d.level + " &middot; " + areaName +
        (d.typeLabel ? " &middot; " + d.typeLabel : "") +
        (d.time ? "<br>~" + d.time : "")
      ).style("display", "block");

      d3.select(this).attr("stroke", "#ff0").attr("stroke-width", 2);

      var connected = {};
      validEdges.forEach(function (e) {
        var sid = typeof e.source === "object" ? e.source.id : e.source;
        var tid = typeof e.target === "object" ? e.target.id : e.target;
        if (sid === d.id) connected[tid] = true;
        if (tid === d.id) connected[sid] = true;
      });

      node.style("opacity", function (n) {
        return n.id === d.id || connected[n.id] ? 1 : 0.1;
      });
      link.style("opacity", function (e) {
        var sid = typeof e.source === "object" ? e.source.id : e.source;
        var tid = typeof e.target === "object" ? e.target.id : e.target;
        return sid === d.id || tid === d.id ? 0.6 : 0.02;
      });
    }).on("mousemove", function (event) {
      var rect = container.getBoundingClientRect();
      tooltip
        .style("left", (event.clientX - rect.left + 12) + "px")
        .style("top", (event.clientY - rect.top - 10) + "px");
    }).on("mouseout", function () {
      tooltip.style("display", "none");
      d3.select(this).attr("stroke", "var(--md-default-bg-color, #fff)").attr("stroke-width", 0.5);
      node.style("opacity", 1);
      link.style("opacity", 1);
    }).on("click", function (event, d) {
      if (d.path) {
        var base = window.location.pathname.split("/library/")[0];
        window.location.href = base + "/" + d.path.replace(/^training\//, "");
      }
    });

    simulation.on("tick", function () {
      link
        .attr("x1", function (d) { return d.source.x; })
        .attr("y1", function (d) { return d.source.y; })
        .attr("x2", function (d) { return d.target.x; })
        .attr("y2", function (d) { return d.target.y; });
      node
        .attr("cx", function (d) { return d.x; })
        .attr("cy", function (d) { return d.y; });
    });

    function applyFilter() {
      var areaVal = select.value;
      var levelVal = levelSelect.value;
      var visible = {};
      var visibleCount = 0;

      data.nodes.forEach(function (n) {
        var show = true;
        if (areaVal && n.area !== areaVal) show = false;
        if (levelVal && n.level !== levelVal) show = false;
        if (show) {
          visible[n.id] = true;
          visibleCount++;
        }
      });

      node.style("display", function (d) { return visible[d.id] ? null : "none"; });
      link.style("display", function (e) {
        var sid = typeof e.source === "object" ? e.source.id : e.source;
        var tid = typeof e.target === "object" ? e.target.id : e.target;
        return visible[sid] && visible[tid] ? null : "none";
      });

      var visibleEdges = validEdges.filter(function (e) {
        var sid = typeof e.source === "object" ? e.source.id : e.source;
        var tid = typeof e.target === "object" ? e.target.id : e.target;
        return visible[sid] && visible[tid];
      });

      countSpan.textContent = visibleCount + " assets, " + visibleEdges.length + " connections";
    }

    select.addEventListener("change", applyFilter);
    levelSelect.addEventListener("change", applyFilter);
    resetBtn.addEventListener("click", function () {
      select.value = "";
      levelSelect.value = "";
      applyFilter();
      svg.transition().duration(500).call(zoom.transform, d3.zoomIdentity);
    });

    var legend = document.createElement("div");
    legend.style.cssText = "margin-top:8px;display:flex;flex-wrap:wrap;gap:4px 12px;font-size:0.75em;";
    areaNames.forEach(function (a) {
      var item = document.createElement("span");
      var dot = document.createElement("span");
      dot.style.cssText = "display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:3px;background:" + data.areas[a].color + ";";
      item.appendChild(dot);
      item.appendChild(document.createTextNode(data.areas[a].display));
      item.style.cursor = "pointer";
      item.addEventListener("click", function () {
        select.value = a;
        applyFilter();
      });
      legend.appendChild(item);
    });
    container.appendChild(legend);
  }

  function safeInit() {
    if (document.getElementById(GRAPH_CONTAINER_ID)) {
      init();
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", safeInit);
  } else {
    safeInit();
  }

  if (typeof document$ !== "undefined") {
    document$.subscribe(safeInit);
  }
})();
