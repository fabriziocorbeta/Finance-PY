import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

const parseLocalDate = d3.timeParse("%Y-%m-%d");

export default class extends Controller {
  static values = {
    data: Object,
  };

  _resizeObserver = null;
  _tooltip = null;

  connect() {
    this._draw();
    document.addEventListener("turbo:load", this._redraw);
    this._setupResizeObserver();
  }

  disconnect() {
    this._teardown();
    document.removeEventListener("turbo:load", this._redraw);
    this._resizeObserver?.disconnect();
  }

  _redraw = () => {
    this._teardown();
    this._draw();
  };

  _teardown() {
    this._tooltip = null;
    d3.select(this.element).selectAll("*").remove();
  }

  _setupResizeObserver() {
    this._resizeObserver = new ResizeObserver(() => {
      this._redraw();
    });
    this._resizeObserver.observe(this.element);
  }

  _draw() {
    const container = this.element;
    const width = container.clientWidth;
    const height = container.clientHeight || 300;

    if (width < 100 || height < 100) return;

    const rawHistorical = this.dataValue.historical_series || [];
    const rawProjected = this.dataValue.projected_series || [];
    const allPoints = [...rawHistorical, ...rawProjected].map((d) => ({
      ...d,
      parsedDate: parseLocalDate(d.date),
    }));

    if (allPoints.length === 0) return;

    const currencySymbol = this.dataValue.currency_symbol || "$";
    const labels = this.dataValue.labels || {
      income: "Income",
      expenses: "Expenses",
      net: "Net",
      actual: "Actual",
      projected: "Projected",
    };

    const margin = { top: 24, right: 20, bottom: 36, left: 64 };
    const innerWidth = width - margin.left - margin.right;
    const innerHeight = height - margin.top - margin.bottom;

    const svg = d3
      .select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("viewBox", [0, 0, width, height]);

    const defs = svg.append("defs");

    // Diagonal hatch pattern for projected bars
    const pattern = defs
      .append("pattern")
      .attr("id", `${this.element.id}-projected-hatch`)
      .attr("patternUnits", "userSpaceOnUse")
      .attr("width", 6)
      .attr("height", 6)
      .attr("patternTransform", "rotate(45)");

    pattern
      .append("line")
      .attr("x1", 0)
      .attr("y1", 0)
      .attr("x2", 0)
      .attr("y2", 6)
      .attr("stroke", "rgba(255,255,255,0.35)")
      .attr("stroke-width", 2);

    const g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    const months = allPoints.map((d) => d.month);

    const x0 = d3
      .scaleBand()
      .domain(months)
      .rangeRound([0, innerWidth])
      .paddingInner(0.28)
      .paddingOuter(0.12);

    const x1 = d3
      .scaleBand()
      .domain(["income", "expenses"])
      .rangeRound([0, x0.bandwidth()])
      .padding(0.12);

    const maxBarVal =
      d3.max(allPoints, (d) =>
        Math.max(
          d.income || 0,
          d.expenses || 0,
          d.optimistic?.income || 0,
          d.conservative?.expenses || 0,
        ),
      ) || 100;

    const minNetVal =
      d3.min(allPoints, (d) =>
        Math.min(0, d.net || 0, d.conservative?.net || 0),
      ) || 0;

    const yMin = minNetVal < 0 ? minNetVal * 1.15 : 0;
    const yMax = maxBarVal > 0 ? maxBarVal * 1.15 : 100;

    const y = d3
      .scaleLinear()
      .domain([yMin, yMax])
      .nice()
      .rangeRound([innerHeight, 0]);

    const zeroY = y(0);

    // Horizontal grid lines
    g.append("g")
      .attr("class", "grid-lines")
      .call(
        d3
          .axisLeft(y)
          .ticks(5)
          .tickSize(-innerWidth)
          .tickFormat(""),
      )
      .call((grid) => grid.select(".domain").remove())
      .call((grid) =>
        grid
          .selectAll(".tick line")
          .attr("stroke", "var(--border-secondary, rgba(150,150,150,0.18))")
          .attr("stroke-dasharray", "3,3"),
      );

    // Zero baseline
    g.append("line")
      .attr("x1", 0)
      .attr("x2", innerWidth)
      .attr("y1", zeroY)
      .attr("y2", zeroY)
      .attr("stroke", "var(--border-primary, rgba(150,150,150,0.4))")
      .attr("stroke-width", 1);

    // Y Axis labels
    g.append("g")
      .call(
        d3
          .axisLeft(y)
          .ticks(5)
          .tickSize(0)
          .tickFormat((val) => this._formatCompactCurrency(val, currencySymbol)),
      )
      .call((axis) => axis.select(".domain").remove())
      .call((axis) =>
        axis
          .selectAll(".tick text")
          .attr("class", "text-secondary")
          .style("font-size", "11px")
          .attr("dx", "-6px"),
      );

    // X Axis labels (thin out if too many months on narrow screens)
    const tickInterval =
      innerWidth < 500 && months.length > 10
        ? 3
        : months.length > 14
          ? 2
          : 1;
    const visibleTicks = months.filter((_, i) => i % tickInterval === 0);

    const monthLabelMap = new Map(allPoints.map((d) => [d.month, d.month_label]));

    g.append("g")
      .attr("transform", `translate(0,${innerHeight})`)
      .call(
        d3
          .axisBottom(x0)
          .tickValues(visibleTicks)
          .tickSize(0)
          .tickFormat((m) => monthLabelMap.get(m) || m),
      )
      .call((axis) => axis.select(".domain").remove())
      .call((axis) =>
        axis
          .selectAll(".tick text")
          .attr("class", "text-secondary")
          .style("font-size", "11px")
          .attr("dy", "14px"),
      );

    // Divider line & subtle background for Projected zone
    if (rawHistorical.length > 0 && rawProjected.length > 0) {
      const firstProjMonth = rawProjected[0].month;
      const lastHistMonth = rawHistorical[rawHistorical.length - 1].month;
      const splitX =
        (x0(lastHistMonth) + x0.bandwidth() + x0(firstProjMonth)) / 2;

      g.append("rect")
        .attr("x", splitX)
        .attr("y", 0)
        .attr("width", Math.max(0, innerWidth - splitX))
        .attr("height", innerHeight)
        .attr("fill", "var(--bg-surface-inset, rgba(120,120,140,0.05))")
        .attr("pointer-events", "none");

      g.append("line")
        .attr("x1", splitX)
        .attr("x2", splitX)
        .attr("y1", 0)
        .attr("y2", innerHeight)
        .attr("stroke", "var(--color-primary, #6366f1)")
        .attr("stroke-width", 1.5)
        .attr("stroke-dasharray", "4,4")
        .attr("opacity", 0.6);

      g.append("text")
        .attr("x", splitX + 6)
        .attr("y", 12)
        .attr("class", "text-secondary")
        .style("font-size", "10px")
        .style("font-weight", "600")
        .style("fill", "currentColor")
        .text(`${labels.projected} →`);
    }

    // Bars per month
    const monthGroups = g
      .selectAll(".month-group")
      .data(allPoints)
      .join("g")
      .attr("class", "month-group")
      .attr("transform", (d) => `translate(${x0(d.month)},0)`);

    // Income bar
    monthGroups
      .append("rect")
      .attr("x", x1("income"))
      .attr("y", (d) => y(Math.max(0, d.income)))
      .attr("width", x1.bandwidth())
      .attr("height", (d) => Math.max(0, Math.abs(zeroY - y(Math.max(0, d.income)))))
      .attr("rx", 3)
      .attr("fill", "var(--color-success, #10b981)")
      .attr("fill-opacity", (d) => (d.kind === "projected" ? 0.45 : 0.85))
      .attr("stroke", (d) =>
        d.kind === "projected" ? "var(--color-success, #10b981)" : "none",
      )
      .attr("stroke-width", (d) => (d.kind === "projected" ? 1.2 : 0))
      .attr("stroke-dasharray", (d) => (d.kind === "projected" ? "3,2" : "none"));

    // Expenses bar
    monthGroups
      .append("rect")
      .attr("x", x1("expenses"))
      .attr("y", (d) => y(Math.max(0, d.expenses)))
      .attr("width", x1.bandwidth())
      .attr("height", (d) =>
        Math.max(0, Math.abs(zeroY - y(Math.max(0, d.expenses)))),
      )
      .attr("rx", 3)
      .attr("fill", "var(--color-destructive, #ef4444)")
      .attr("fill-opacity", (d) => (d.kind === "projected" ? 0.45 : 0.85))
      .attr("stroke", (d) =>
        d.kind === "projected" ? "var(--color-destructive, #ef4444)" : "none",
      )
      .attr("stroke-width", (d) => (d.kind === "projected" ? 1.2 : 0))
      .attr("stroke-dasharray", (d) => (d.kind === "projected" ? "3,2" : "none"));

    // Confidence band for projected net savings (optimistic to conservative)
    if (rawProjected.length > 0) {
      const bandPoints =
        rawHistorical.length > 0
          ? [
              {
                ...rawHistorical[rawHistorical.length - 1],
                optimistic: { net: rawHistorical[rawHistorical.length - 1].net },
                conservative: {
                  net: rawHistorical[rawHistorical.length - 1].net,
                },
              },
              ...rawProjected,
            ]
          : rawProjected;

      const areaBand = d3
        .area()
        .x((d) => x0(d.month) + x0.bandwidth() / 2)
        .y0((d) => y(d.conservative?.net ?? d.net))
        .y1((d) => y(d.optimistic?.net ?? d.net))
        .curve(d3.curveMonotoneX);

      g.append("path")
        .datum(bandPoints)
        .attr("fill", "#6366f1")
        .attr("fill-opacity", 0.12)
        .attr("d", areaBand)
        .attr("pointer-events", "none");
    }

    // Net savings line: solid for actual, dashed for projected
    const lineGenerator = d3
      .line()
      .x((d) => x0(d.month) + x0.bandwidth() / 2)
      .y((d) => y(d.net))
      .curve(d3.curveMonotoneX);

    if (rawHistorical.length > 1) {
      g.append("path")
        .datum(rawHistorical)
        .attr("fill", "none")
        .attr("stroke", "#6366f1")
        .attr("stroke-width", 2.2)
        .attr("d", lineGenerator)
        .attr("pointer-events", "none");
    }

    if (rawProjected.length > 0) {
      const projLinePoints =
        rawHistorical.length > 0
          ? [rawHistorical[rawHistorical.length - 1], ...rawProjected]
          : rawProjected;

      g.append("path")
        .datum(projLinePoints)
        .attr("fill", "none")
        .attr("stroke", "#6366f1")
        .attr("stroke-width", 2.2)
        .attr("stroke-dasharray", "5,4")
        .attr("d", lineGenerator)
        .attr("pointer-events", "none");
    }

    // Net savings dots
    g.selectAll(".net-dot")
      .data(allPoints)
      .join("circle")
      .attr("class", "net-dot")
      .attr("cx", (d) => x0(d.month) + x0.bandwidth() / 2)
      .attr("cy", (d) => y(d.net))
      .attr("r", 3.5)
      .attr("fill", (d) =>
        d.kind === "projected" ? "var(--bg-container, #fff)" : "#6366f1",
      )
      .attr("stroke", "#6366f1")
      .attr("stroke-width", 2)
      .attr("pointer-events", "none");

    // Tooltip
    this._tooltip = d3
      .select(container)
      .append("div")
      .attr(
        "class",
        "bg-container text-xs font-sans absolute p-3 border border-secondary rounded-lg shadow-lg pointer-events-none opacity-0 transition-opacity z-50",
      )
      .style("min-width", "210px");

    // Hover overlay per month column
    g.selectAll(".hover-col")
      .data(allPoints)
      .join("rect")
      .attr("class", "hover-col")
      .attr("x", (d) => x0(d.month))
      .attr("y", 0)
      .attr("width", x0.bandwidth())
      .attr("height", innerHeight)
      .attr("fill", "transparent")
      .style("cursor", "crosshair")
      .on("mousemove", (event, d) => {
        const [mouseX, mouseY] = d3.pointer(event, container);
        const tooltipWidth = 230;
        const leftPos =
          mouseX + tooltipWidth + 24 > width
            ? Math.max(8, mouseX - tooltipWidth - 12)
            : mouseX + 14;
        const topPos = Math.max(8, Math.min(height - 140, mouseY - 20));

        this._tooltip
          .html(this._renderTooltip(d, currencySymbol, labels))
          .style("opacity", 1)
          .style("left", `${leftPos}px`)
          .style("top", `${topPos}px`);
      })
      .on("mouseleave", () => {
        this._tooltip.style("opacity", 0);
      });
  }

  _renderTooltip(d, symbol, labels) {
    const badgeColor =
      d.kind === "projected"
        ? "background: rgba(99,102,241,0.15); color: #6366f1;"
        : "background: rgba(150,150,150,0.15); color: var(--text-secondary);";
    const badgeText = d.kind === "projected" ? labels.projected : labels.actual;

    const netColor =
      d.net >= 0
        ? "var(--color-success, #10b981)"
        : "var(--color-destructive, #ef4444)";

    let scenarioHtml = "";
    if (d.kind === "projected" && d.optimistic && d.conservative) {
      scenarioHtml = `
        <div style="margin-top: 6px; padding-top: 6px; border-top: 1px dashed rgba(150,150,150,0.25); font-size: 11px;" class="text-secondary space-y-0.5">
          <div class="flex justify-between gap-3">
            <span>${labels.range || "Range"}:</span>
            <span class="font-medium text-primary">${this._formatFullCurrency(d.conservative.net, symbol)} … ${this._formatFullCurrency(d.optimistic.net, symbol)}</span>
          </div>
        </div>
      `;
    }

    return `
      <div class="flex items-center justify-between gap-2 mb-2">
        <span class="font-semibold text-primary">${d.month_label}</span>
        <span style="${badgeColor} padding: 1px 6px; border-radius: 9999px; font-size: 10px; font-weight: 600;">
          ${badgeText}
        </span>
      </div>
      <div class="space-y-1">
        <div class="flex justify-between gap-4">
          <span class="text-secondary flex items-center gap-1.5">
            <span style="width: 8px; height: 8px; border-radius: 2px; background: var(--color-success, #10b981); display: inline-block;"></span>
            ${labels.income}:
          </span>
          <span class="font-medium text-primary">${this._formatFullCurrency(d.income, symbol)}</span>
        </div>
        <div class="flex justify-between gap-4">
          <span class="text-secondary flex items-center gap-1.5">
            <span style="width: 8px; height: 8px; border-radius: 2px; background: var(--color-destructive, #ef4444); display: inline-block;"></span>
            ${labels.expenses}:
          </span>
          <span class="font-medium text-primary">${this._formatFullCurrency(d.expenses, symbol)}</span>
        </div>
        <div class="flex justify-between gap-4 pt-1 border-t border-secondary">
          <span class="text-secondary flex items-center gap-1.5">
            <span style="width: 8px; height: 8px; border-radius: 9999px; background: #6366f1; display: inline-block;"></span>
            ${labels.net}:
          </span>
          <span class="font-semibold" style="color: ${netColor};">${this._formatFullCurrency(d.net, symbol)} (${d.savings_rate}%)</span>
        </div>
      </div>
      ${scenarioHtml}
    `;
  }

  _formatCompactCurrency(val, symbol) {
    const abs = Math.abs(val);
    const sign = val < 0 ? "-" : "";
    if (abs >= 1_000_000_000) {
      return `${sign}${symbol}${(abs / 1_000_000_000).toFixed(1)}B`;
    }
    if (abs >= 1_000_000) {
      return `${sign}${symbol}${(abs / 1_000_000).toFixed(1)}M`;
    }
    if (abs >= 1_000) {
      return `${sign}${symbol}${(abs / 1_000).toFixed(0)}k`;
    }
    return `${sign}${symbol}${abs.toFixed(0)}`;
  }

  _formatFullCurrency(val, symbol) {
    const num = Number(val || 0);
    const sign = num < 0 ? "-" : "";
    const abs = Math.abs(num);
    const decimals = abs >= 1000 && Number.isInteger(Math.round(abs)) ? 0 : 2;
    return `${sign}${symbol}${abs.toLocaleString(undefined, {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals,
    })}`;
  }
}
