(function () {
  const ID = 'tilecal_xadc';
  const HIST_MAX = 120;
  const TEMP_IDX = 0;
  const I_095_IDX = 3;
  const PLOT_COLORS = [
    '#f0b429', '#4f8cff', '#3ecf8e', '#ff6b6b', '#5eead4', '#fdba74',
    '#c084fc', '#f472b6', '#a3e635', '#38bdf8', '#fb923c', '#e879f9',
  ];

  let lastAnalog = {};
  let charts = { current: null, corr: null };
  let hist = { current: {}, corr: { temp: [], i095: [] } };
  let legendFilter = { current: null };

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function fmtNum(v, digits) {
    if (v === null || v === undefined || Number.isNaN(v)) return '—';
    return Number(v).toFixed(digits);
  }

  function formatAnalog(ch) {
    if (ch.analog === null || ch.analog === undefined) return '—';
    const unit = ch.analog_unit || '';
    if (unit === '°C') return fmtNum(ch.analog, 1) + ' °C';
    if (unit === 'mV') return fmtNum(ch.analog, 1) + ' mV';
    return fmtNum(ch.analog, 3) + (unit ? ' ' + unit : '');
  }

  function formatCurrent(ch) {
    if (!ch.has_current) return '—';
    if (ch.current === null || ch.current === undefined) return '—';
    const unit = ch.current_unit || 'mA';
    return fmtNum(ch.current, 3) + ' ' + unit;
  }

  function axisStyle() {
    const muted = '#8b9bb4';
    const grid = '#2a3654';
    return { muted, grid };
  }

  function timeScale() {
    const { muted, grid } = axisStyle();
    return {
      type: 'time',
      time: {
        displayFormats: { second: 'HH:mm:ss', minute: 'HH:mm:ss', hour: 'HH:mm' },
        tooltipFormat: 'HH:mm:ss',
      },
      title: { display: true, text: 'Time', color: muted, font: { size: 10 } },
      ticks: { color: muted, maxTicksLimit: 8, font: { size: 9 }, autoSkip: true },
      grid: { color: grid },
    };
  }

  function currentChartOptions() {
    const { muted, grid } = axisStyle();
    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      interaction: { mode: 'nearest', intersect: false },
      scales: {
        x: timeScale(),
        y: {
          title: { display: true, text: 'mA', color: muted, font: { size: 10 } },
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
              return ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(3) + ' mA';
            },
          },
        },
      },
    };
  }

  function corrChartOptions() {
    const { muted, grid } = axisStyle();
    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      interaction: { mode: 'nearest', intersect: false },
      scales: {
        x: timeScale(),
        y: {
          type: 'linear',
          position: 'left',
          title: { display: true, text: 'Temperature (°C)', color: '#f0b429', font: { size: 10 } },
          ticks: { color: '#f0b429', font: { size: 9 } },
          grid: { color: grid },
        },
        y1: {
          type: 'linear',
          position: 'right',
          title: { display: true, text: '0.95V current (mA)', color: '#4f8cff', font: { size: 10 } },
          ticks: { color: '#4f8cff', font: { size: 9 } },
          grid: { drawOnChartArea: false },
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
              const unit = ctx.dataset.yAxisID === 'y1' ? ' mA' : ' °C';
              return ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(3) + unit;
            },
          },
        },
      },
    };
  }

  function destroyCharts() {
    for (const key of ['current', 'corr']) {
      if (charts[key]) {
        charts[key].destroy();
        charts[key] = null;
      }
    }
  }

  function resetPlots() {
    hist = { current: {}, corr: { temp: [], i095: [] } };
    legendFilter = { current: null };
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
    if (!charts.corr) {
      const ctx = document.getElementById('tilecalCorrChart');
      if (!ctx) return;
      charts.corr = new Chart(ctx, {
        type: 'line',
        data: { datasets: [] },
        options: corrChartOptions(),
      });
    }
    if (!charts.current) {
      const ctx = document.getElementById('tilecalCurrentChart');
      if (!ctx) return;
      charts.current = new Chart(ctx, {
        type: 'line',
        data: { datasets: [] },
        options: currentChartOptions(),
      });
      bindLegendIsolate(charts.current, 'current');
    }
  }

  function appendHistory(channels) {
    const ts = Date.now();
    for (const ch of channels) {
      if (ch.index === TEMP_IDX && ch.analog != null && !Number.isNaN(ch.analog)) {
        hist.corr.temp.push({ x: ts, y: ch.analog });
        if (hist.corr.temp.length > HIST_MAX) hist.corr.temp.shift();
      }
      if (ch.index === I_095_IDX && ch.current != null && !Number.isNaN(ch.current)) {
        hist.corr.i095.push({ x: ts, y: ch.current });
        if (hist.corr.i095.length > HIST_MAX) hist.corr.i095.shift();
      }
      if (!ch.has_current || ch.current == null || Number.isNaN(ch.current)) continue;
      if (!hist.current[ch.label]) hist.current[ch.label] = [];
      hist.current[ch.label].push({ x: ts, y: ch.current });
      if (hist.current[ch.label].length > HIST_MAX) hist.current[ch.label].shift();
    }
  }

  function syncCurrentChart() {
    const chart = charts.current;
    if (!chart) return;
    const labels = Object.keys(hist.current).sort();
    chart.data.datasets = labels.map((label, idx) => {
      const color = PLOT_COLORS[idx % PLOT_COLORS.length];
      return {
        label,
        data: hist.current[label] || [],
        borderColor: color,
        backgroundColor: color + '33',
        borderWidth: 1.5,
        pointRadius: 0,
        pointHitRadius: 6,
        tension: 0.15,
        fill: false,
      };
    });
    applyLegendFilter(chart, 'current');
    chart.update('none');
  }

  function syncCorrChart() {
    const chart = charts.corr;
    if (!chart) return;
    chart.data.datasets = [
      {
        label: 'db_temperature',
        data: hist.corr.temp,
        yAxisID: 'y',
        borderColor: '#f0b429',
        backgroundColor: '#f0b42933',
        borderWidth: 1.5,
        pointRadius: 0,
        pointHitRadius: 6,
        tension: 0.15,
        fill: false,
      },
      {
        label: 'db_mon_0.95v',
        data: hist.corr.i095,
        yAxisID: 'y1',
        borderColor: '#4f8cff',
        backgroundColor: '#4f8cff33',
        borderWidth: 1.5,
        pointRadius: 0,
        pointHitRadius: 6,
        tension: 0.15,
        fill: false,
      },
    ];
    chart.update('none');
  }

  function updateCharts() {
    ensureCharts();
    syncCorrChart();
    syncCurrentChart();
  }

  function renderLiveScan(live) {
    const el = document.getElementById('live-tilecal_xadc');
    if (!el) return;
    if (!live || live.address_hex == null) {
      el.textContent = '';
      return;
    }
    el.textContent = 'Live VIO scan: ' + live.address_hex +
      ' raw=' + (live.raw != null ? '0x' + live.raw.toString(16).toUpperCase() : '—');
  }

  function renderChannels(channels) {
    const wrap = document.getElementById('tilecal-table-wrap');
    if (!wrap) return;
    if (!channels || !channels.length) {
      wrap.innerHTML = '<p class="empty">No TileCal xADC channels returned.</p>';
      resetPlots();
      return;
    }

    appendHistory(channels);

    let html = '<p class="tilecal-legend">' +
      'Analog = raw × fa + fb · Current = analog × fg (monitor channels). ' +
      'Values from hw_sysmon (VAUXP<i>_VAUXN<i>); live VIO xadc_channel / xadc_channel_voltage overrides the scanned address.</p>';
    html += '<table class="data"><tr>' +
      '<th>Channel</th><th>Addr</th><th>Raw</th><th>Analog</th><th>Current</th><th>Source</th></tr>';

    let lastGroup = '';
    for (const ch of channels) {
      const group = ch.index < 19 ? 'On-chip &amp; VAUX monitors' :
        (ch.index < 23 ? 'Reference rails' : 'Min / max registers');
      if (group !== lastGroup) {
        html += '<tr class="section"><td colspan="6">' + group + '</td></tr>';
        lastGroup = group;
      }

      const key = ch.index;
      const changed = lastAnalog[key] !== undefined && lastAnalog[key] !== ch.analog;
      lastAnalog[key] = ch.analog;

      const isLive = ch.source && ch.source.startsWith('vio:');
      const missing = ch.raw === null || ch.raw === undefined;
      const rawHex = missing ? '—' : ('0x' + ch.raw.toString(16).toUpperCase().padStart(4, '0'));

      html += '<tr class="' +
        (missing ? 'missing ' : '') +
        (isLive ? 'current-row ' : '') +
        (changed ? 'val-changed' : '') + '">' +
        '<td class="label-col">' + esc(ch.label) + '</td>' +
        '<td class="num">' + esc(ch.address_hex) + '</td>' +
        '<td class="num">' + rawHex + '</td>' +
        '<td class="num">' + esc(formatAnalog(ch)) + '</td>' +
        '<td class="num">' + esc(formatCurrent(ch)) + '</td>' +
        '<td>' + esc(ch.source || '—') + '</td></tr>';
    }
    html += '</table>';
    wrap.innerHTML = html;
    updateCharts();
  }

  async function refresh() {
    if (!HWMonitor.state.targetOpen) return;
    try {
      const r = await fetch('/api/plugins/tilecal_xadc/data' + HWMonitor.deviceQuery());
      const ctype = r.headers.get('content-type') || '';
      if (!r.ok || !ctype.includes('json')) {
        throw new Error(
          'API returned HTTP ' + r.status +
          ' — restart python3 app.py after adding or updating plugins'
        );
      }
      const j = await r.json();
      const timeEl = document.getElementById('time-tilecal_xadc');
      if (timeEl) {
        timeEl.textContent = 'Updated ' + new Date().toLocaleTimeString();
      }
      renderLiveScan(j.live_scan);
      renderChannels(j.channels);
    } catch (e) {
      HWMonitor.setStatus('TileCal xADC refresh error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastAnalog = {};
    resetPlots();
    renderLiveScan(null);
    const wrap = document.getElementById('tilecal-table-wrap');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
    const live = document.getElementById('live-tilecal_xadc');
    if (live) live.textContent = '';
  }

  function onDeviceChange() {
    lastAnalog = {};
    resetPlots();
  }

  function onTabActivate() {
    requestAnimationFrame(() => {
      if (charts.current) charts.current.resize();
      if (charts.corr) charts.corr.resize();
    });
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_xadc'],
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
