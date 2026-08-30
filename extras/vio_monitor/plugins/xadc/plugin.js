(function () {
  const ID = 'xadc';
  const HIST_MAX = 120;
  const PLOT_COLORS = [
    '#f0b429', '#4f8cff', '#3ecf8e', '#ff6b6b', '#5eead4', '#fdba74',
    '#c084fc', '#f472b6', '#a3e635', '#38bdf8', '#fb923c', '#e879f9',
  ];

  let lastValues = {};
  let charts = { temp: null, volt: null };
  let hist = { temp: {}, volt: {} };
  let legendFilter = { temp: null, volt: null };

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function isHighlight(prop) {
    if (prop === 'TEMPERATURE' || prop.endsWith('_TEMPERATURE') || /^(LOWER_OT|UPPER_OT)/.test(prop)) return 'temp';
    if (/^(VCC|VUSER|VAUX|MAX_|MIN_|LOWER_|UPPER_)/.test(prop)) return 'volt';
    return '';
  }

  function formatValue(prop, value) {
    if (prop.endsWith('_SCALE')) return value;
    const v = parseFloat(value);
    if (isNaN(v)) return value;
    if (prop.includes('TEMPERATURE') || /^(LOWER_OT|UPPER_OT)/.test(prop)) return v.toFixed(1) + ' °C';
    if (/^VCC|^VUSER|^VAUX|^MAX_V|^MIN_V|^LOWER_V|^UPPER_V/.test(prop)) return v.toFixed(3) + ' V';
    return value;
  }

  function isTempVar(prop) {
    if (prop.endsWith('_SCALE') || prop.endsWith('_OFFSET')) return false;
    if (prop === 'MAX_TEMPERATURE' || prop === 'MIN_TEMPERATURE') return true;
    if (/^(LOWER_|UPPER_)/.test(prop)) return false;
    if (/^(MAX_|MIN_)/.test(prop)) return false;
    return prop === 'TEMPERATURE' || prop.includes('TEMPERATURE');
  }

  function isVoltVar(prop) {
    if (prop.endsWith('_SCALE') || prop.endsWith('_OFFSET')) return false;
    if (/^(MAX_|MIN_|LOWER_|UPPER_)/.test(prop)) return false;
    return /^(VCC|VUSER|VAUX)/.test(prop);
  }

  function isMeasurementsTable(prop) {
    if (prop.includes('TEMPERATURE') || prop === 'TEMPERATURE') return true;
    if (/^(LOWER_OT|UPPER_OT)/.test(prop)) return true;
    if (/^(VCC|VUSER|VAUX|MAX_V|MIN_V|LOWER_V|UPPER_V)/.test(prop)) return true;
    return false;
  }

  function parseNumeric(prop, value) {
    if (prop.endsWith('_SCALE')) return NaN;
    const v = parseFloat(value);
    return isNaN(v) ? NaN : v;
  }

  function chartOptions(yLabel) {
    const muted = '#8b9bb4';
    const grid = '#2a3654';
    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      interaction: { mode: 'nearest', intersect: false },
      scales: {
        x: {
          type: 'time',
          time: {
            displayFormats: { second: 'HH:mm:ss', minute: 'HH:mm:ss', hour: 'HH:mm' },
            tooltipFormat: 'HH:mm:ss',
          },
          title: { display: true, text: 'Time', color: muted, font: { size: 10 } },
          ticks: { color: muted, maxTicksLimit: 8, font: { size: 9 }, autoSkip: true },
          grid: { color: grid },
        },
        y: {
          title: { display: true, text: yLabel, color: muted, font: { size: 10 } },
          ticks: { color: muted, font: { size: 9 } },
          grid: { color: grid },
        },
      },
      plugins: {
        legend: {
          display: true,
          position: 'bottom',
          labels: { color: muted, boxWidth: 10, font: { size: 9 }, padding: 6 },
        },
        tooltip: {
          callbacks: {
            title(items) {
              if (!items.length) return '';
              return new Date(items[0].parsed.x).toLocaleTimeString();
            },
            label(ctx) {
              const unit = yLabel === '°C' ? ' °C' : ' V';
              return ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(3) + unit;
            },
          },
        },
      },
    };
  }

  function destroyCharts() {
    for (const key of ['temp', 'volt']) {
      if (charts[key]) {
        charts[key].destroy();
        charts[key] = null;
      }
    }
  }

  function resetPlots() {
    hist = { temp: {}, volt: {} };
    legendFilter = { temp: null, volt: null };
    destroyCharts();
  }

  function applyLegendFilter(chart, key) {
    if (!chart) return;
    const filter = legendFilter[key];
    chart.data.datasets.forEach(ds => {
      ds.hidden = filter !== null && ds.label !== filter;
    });
  }

  function bindLegendIsolate(chart, key) {
    if (!chart || chart._legendIsolateBound) return;
    chart._legendIsolateBound = true;
    chart.canvas.addEventListener('dblclick', (evt) => {
      const legend = chart.legend;
      if (!legend || !legend.legendHitBoxes) return;
      const rect = chart.canvas.getBoundingClientRect();
      const x = evt.clientX - rect.left;
      const y = evt.clientY - rect.top;
      let hitLabel = null;
      legend.legendHitBoxes.forEach((box, i) => {
        if (x >= box.left && x <= box.left + box.width && y >= box.top && y <= box.top + box.height) {
          const item = legend.legendItems[i];
          if (item) hitLabel = item.text;
        }
      });
      if (!hitLabel) return;
      legendFilter[key] = legendFilter[key] === hitLabel ? null : hitLabel;
      applyLegendFilter(chart, key);
      chart.update('none');
    });
  }

  function ensureCharts() {
    if (typeof Chart === 'undefined') return;
    if (!charts.temp) {
      const ctx = document.getElementById('xadcTempChart');
      if (!ctx) return;
      charts.temp = new Chart(ctx, {
        type: 'line',
        data: { datasets: [] },
        options: chartOptions('°C'),
      });
      bindLegendIsolate(charts.temp, 'temp');
    }
    if (!charts.volt) {
      const ctx = document.getElementById('xadcVoltChart');
      if (!ctx) return;
      charts.volt = new Chart(ctx, {
        type: 'line',
        data: { datasets: [] },
        options: chartOptions('V'),
      });
      bindLegendIsolate(charts.volt, 'volt');
    }
  }

  function syncChartDatasets(chart, bucket, key) {
    if (!chart) return;
    const props = Object.keys(bucket).sort();
    chart.data.datasets = props.map((prop, idx) => {
      const color = PLOT_COLORS[idx % PLOT_COLORS.length];
      const points = bucket[prop] || [];
      return {
        label: prop,
        data: points,
        borderColor: color,
        backgroundColor: color + '33',
        borderWidth: 1.5,
        pointRadius: 0,
        pointHitRadius: 6,
        tension: 0.15,
        fill: false,
      };
    });
    applyLegendFilter(chart, key);
    chart.update('none');
  }

  function appendHistory(readings) {
    const ts = Date.now();
    for (const r of readings) {
      const v = parseNumeric(r.property, r.value);
      if (isNaN(v)) continue;
      let bucket = null;
      if (isTempVar(r.property)) bucket = hist.temp;
      else if (isVoltVar(r.property)) bucket = hist.volt;
      else continue;
      if (!bucket[r.property]) bucket[r.property] = [];
      bucket[r.property].push({ x: ts, y: v });
      if (bucket[r.property].length > HIST_MAX) bucket[r.property].shift();
    }
  }

  function updateCharts() {
    ensureCharts();
    syncChartDatasets(charts.temp, hist.temp, 'temp');
    syncChartDatasets(charts.volt, hist.volt, 'volt');
  }

  function buildTableRows(readings) {
    let rows = '';
    for (const r of readings) {
      const key = r.property + '|' + r.device;
      const changed = lastValues[key] !== undefined && lastValues[key] !== r.value;
      lastValues[key] = r.value;
      const hl = isHighlight(r.property);
      rows += '<tr class="' + (hl ? 'xadc-highlight ' + hl : '') + (changed ? ' val-changed' : '') + '">' +
        '<td>' + esc(r.property) + '</td>' +
        '<td class="value">' + esc(formatValue(r.property, r.value)) + '</td></tr>';
    }
    return rows;
  }

  function renderXadc(readings) {
    const wrap = document.getElementById('wrap-xadc');
    if (!wrap) return;
    if (!readings || !readings.length) {
      wrap.innerHTML = '<p class="empty">No System Monitor data. Select a device with an open target.</p>';
      resetPlots();
      return;
    }
    appendHistory(readings);
    const sorted = readings.slice().sort((a, b) => a.property.localeCompare(b.property));
    const primary = sorted.filter(r => isMeasurementsTable(r.property));
    const other = sorted.filter(r => !isMeasurementsTable(r.property));
    const tableHead = '<table class="data"><tr><th>Property</th><th>Value</th></tr>';
    let html = '<h4 class="xadc-section-title">Temperature &amp; Voltages (' + primary.length + ')</h4>';
    html += tableHead + buildTableRows(primary) + '</table>';
    html += '<h4 class="xadc-section-title">Registers (' + other.length + ')</h4>';
    html += tableHead + buildTableRows(other) + '</table>';
    wrap.innerHTML = html;
    updateCharts();
  }

  async function refresh() {
    if (!HWMonitor.state.targetOpen) return;
    try {
      const r = await fetch('/api/plugins/xadc/data' + HWMonitor.deviceQuery());
      const j = await r.json();
      const timeEl = document.getElementById('time-xadc');
      if (timeEl) {
        timeEl.textContent = 'Updated ' + new Date().toLocaleTimeString() +
          ' (' + (j.readings || []).length + ' props)';
      }
      renderXadc(j.readings);
    } catch (e) {
      HWMonitor.setStatus('XADC refresh error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastValues = {};
    resetPlots();
    const wrap = document.getElementById('wrap-xadc');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
  }

  function onDeviceChange() {
    lastValues = {};
    resetPlots();
  }

  function onTabActivate() {
    requestAnimationFrame(() => {
      if (charts.temp) charts.temp.resize();
      if (charts.volt) charts.volt.resize();
    });
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['sysmon'],
    onInit() {
      const btn = document.querySelector('[data-refresh="' + ID + '"]');
      if (btn) btn.addEventListener('click', refresh);
    },
    refresh,
    onDisconnect,
    onDeviceChange,
    onTabActivate,
  });
})();
