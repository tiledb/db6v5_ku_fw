(function () {
  const ID = 'sfp_ddm';
  const HIST_MAX = 120;
  const COLORS = ['#f0b429', '#4f8cff', '#3ecf8e', '#ff6b6b', '#5eead4', '#fdba74', '#c084fc', '#f472b6'];
  const GROUPS = {
    temp: ['temperature', 'laser_temperature'],
    volt: ['vcc'],
    current: ['tx_bias_current', 'tec_current'],
  };
  const charts = { temp: null, volt: null, current: null };
  const hist = { temp: {}, volt: {}, current: {} };

  function esc(s) { return HWMonitor.esc(s); }

  function plotValue(fieldId, cell) {
    if (!cell || cell.value == null || Number.isNaN(cell.value)) return null;
    if (fieldId === 'tx_bias_current') return cell.value * 1e3;
    return cell.value;
  }

  function ensureCharts() {
    if (typeof Chart === 'undefined') return;
    const specs = [['temp', 'sfpTempChart', '°C'], ['volt', 'sfpVoltChart', 'V'], ['current', 'sfpCurrentChart', 'mA']];
    for (const [key, canvasId, unit] of specs) {
      if (charts[key]) continue;
      const ctx = document.getElementById(canvasId);
      if (!ctx) continue;
      charts[key] = new Chart(ctx, {
        type: 'line',
        data: { datasets: [] },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: false,
          scales: {
            x: { type: 'time', time: { tooltipFormat: 'HH:mm:ss' }, ticks: { color: '#8b9bb4', maxTicksLimit: 6 } },
            y: { title: { display: true, text: unit, color: '#8b9bb4' }, ticks: { color: '#8b9bb4' } },
          },
          plugins: { legend: { position: 'bottom', labels: { color: '#8b9bb4', boxWidth: 10, font: { size: 9 } } } },
        },
      });
    }
  }

  function pushHist(sides) {
    const ts = Date.now();
    for (const sideId of ['A', 'B']) {
      for (const row of sides[sideId] || []) {
        for (const key of Object.keys(GROUPS)) {
          if (!GROUPS[key].includes(row.field_id)) continue;
          for (const sfp of ['0', '1']) {
            const y = plotValue(row.field_id, row.sfps[sfp]);
            if (y == null) continue;
            const label = 'Side ' + sideId + ' SFP+' + sfp + ' ' + row.label;
            if (!hist[key][label]) hist[key][label] = [];
            hist[key][label].push({ x: ts, y: y });
            if (hist[key][label].length > HIST_MAX) hist[key][label].shift();
          }
        }
      }
    }
  }

  function drawCharts() {
    ensureCharts();
    for (const key of Object.keys(charts)) {
      const chart = charts[key];
      if (!chart) continue;
      const labels = Object.keys(hist[key]).sort();
      chart.data.datasets = labels.map(function (label, idx) {
        const color = COLORS[idx % COLORS.length];
        return { label: label, data: hist[key][label], borderColor: color, borderWidth: 1.5, pointRadius: 0, tension: 0.15 };
      });
      chart.resize();
      chart.update('none');
    }
  }

  function sideTable(sideId, rows) {
    let html = '<table class="data"><tr><th>Parameter</th><th class="num">SFP+0</th><th class="num">SFP+1</th></tr>';
    for (const row of rows) {
      html += '<tr><td>' + esc(row.label) + '<div class="probe-hint">' + esc(row.spec) + ' @ ' + esc(row.addr_hex) + '</div></td>' +
        '<td class="num">' + esc(row.sfps['0'].value_text) + '<div class="probe-hint">' + esc(row.sfps['0'].raw_hex) + '</div></td>' +
        '<td class="num">' + esc(row.sfps['1'].value_text) + '<div class="probe-hint">' + esc(row.sfps['1'].raw_hex) + '</div></td></tr>';
    }
    html += '</table>';
    return '<div class="side-card side-' + sideId.toLowerCase() + '"><h3>Side ' + sideId + '</h3>' + html + '</div>';
  }

  function render(data) {
    const wrap = document.getElementById('wrap-sfp_ddm');
    if (!wrap) return;
    pushHist(data.sides);
    wrap.innerHTML = '<div class="side-grid">' + sideTable('A', data.sides.A) + sideTable('B', data.sides.B) + '</div>';
    drawCharts();
  }

  async function refresh() {
    if (!HWMonitor.state.connected) return;
    const j = await HWMonitor.fetchJson('/api/plugins/sfp_ddm/data');
    document.getElementById('time-sfp_ddm').textContent = 'Updated ' + new Date().toLocaleTimeString();
    render(j);
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['sfp_ddm'],
    refresh: refresh,
    onInit() {
      ensureCharts();
      const wrap = document.getElementById('wrap-sfp_ddm');
      if (wrap) {
        wrap.innerHTML = '<p class="adcrd-legend">SFP+ DDM for side A and side B. ' +
          'Tables and history fill after Refresh. Plots stay ready with no series until data arrives.</p>' +
          '<p class="empty">No readout yet.</p>';
      }
    },
    onMdChange() {
      for (const key of Object.keys(hist)) hist[key] = {};
      for (const key of Object.keys(charts)) {
        if (!charts[key]) continue;
        charts[key].data.datasets = [];
        charts[key].update('none');
      }
      const wrap = document.getElementById('wrap-sfp_ddm');
      if (wrap) wrap.innerHTML = '<p class="empty">No readout yet for this MD.</p>';
      const timeEl = document.getElementById('time-sfp_ddm');
      if (timeEl) timeEl.textContent = '';
    },
    onDisconnect() {
      const wrap = document.getElementById('wrap-sfp_ddm');
      if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
    },
    onTabActivate() {
      for (const key of Object.keys(charts)) {
        if (charts[key]) charts[key].resize();
      }
    },
  });
})();
