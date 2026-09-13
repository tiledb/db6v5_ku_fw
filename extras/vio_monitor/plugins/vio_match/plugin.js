(function () {
  const ID = 'vio_match';
  let lastPayload = null;
  let filter = 'all';
  let query = '';

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function rangeText(row) {
    if (row.left == null || row.right == null) return String(row.width || '');
    if (row.left === row.right) return String(row.left);
    return row.left + ':' + row.right;
  }

  function liveCell(live) {
    if (!live || !live.length) return '—';
    return live.map(function (p) {
      const val = p.value && p.value !== '-' ? ' = ' + p.value : '';
      const w = p.width ? '[' + p.width + ']' : '';
      return esc(p.name) + w + val;
    }).join('<br>');
  }

  function netsCell(row) {
    const nets = row.nets || [];
    if (!nets.length) return esc(row.pin || '');
    return nets.map(esc).join('<br>');
  }

  function rowMatchesQuery(row, q) {
    if (!q) return true;
    const hay = [
      row.pin, row.vio, row.direction,
      (row.nets || []).join(' '),
      (row.aliases || []).join(' '),
      (row.plugins || []).join(' '),
      (row.live || []).map(function (p) { return p.name; }).join(' '),
    ].join(' ').toLowerCase();
    return hay.indexOf(q) !== -1;
  }

  function liveMatchesQuery(row, q) {
    if (!q) return true;
    const hay = [row.name, row.vio, row.direction, row.value].join(' ').toLowerCase();
    return hay.indexOf(q) !== -1;
  }

  function renderSummary(j) {
    const el = document.getElementById('vio-match-summary');
    if (!el) return;
    const s = j.summary || {};
    const bits = [];
    bits.push('LTX <code>' + esc(j.ltx_path || '(none)') + '</code>');
    if (j.ltx_error) bits.push('<span class="bad">' + esc(j.ltx_error) + '</span>');
    bits.push('slices <span class="ok">' + (s.ltx_slices || 0) + '</span>');
    bits.push('matched <span class="ok">' + (s.matched || 0) + '</span>');
    if (s.ltx_only) bits.push('LTX-only <span class="bad">' + s.ltx_only + '</span>');
    if (s.no_jtag) bits.push('no JTAG yet <span class="warn">' + s.no_jtag + '</span>');
    bits.push('JTAG probes <span class="ok">' + (s.jtag_probes || 0) + '</span>');
    if (s.jtag_only) bits.push('JTAG-only <span class="warn">' + s.jtag_only + '</span>');
    if ((j.cores || []).length) bits.push('cores ' + j.cores.map(esc).join(', '));
    if (j.device) bits.push('device ' + esc(j.device));
    if (j.live_error && j.device) bits.push('<span class="warn">' + esc(j.live_error) + '</span>');
    el.innerHTML = bits.join(' · ');
  }

  function render(j) {
    const wrap = document.getElementById('wrap-vio_match');
    if (!wrap) return;
    renderSummary(j);
    const q = query.trim().toLowerCase();
    const rows = (j.rows || []).filter(function (row) {
      if (filter === 'matched' && row.status !== 'matched') return false;
      if (filter === 'unmatched' && row.status !== 'unmatched' && row.status !== 'no_jtag') return false;
      if (filter === 'jtag_only') return false;
      return rowMatchesQuery(row, q);
    });
    const jtagOnly = (j.jtag_only || []).filter(function (row) {
      if (filter === 'matched' || filter === 'unmatched') return false;
      return liveMatchesQuery(row, q);
    });

    let html = '';
    if (!rows.length && !jtagOnly.length) {
      html = '<p class="empty">No probes for this filter.</p>';
    } else {
      html += '<table class="data vio-match"><tr>' +
        '<th>Status</th><th>VIO pin</th><th>Dir</th><th>Bits</th>' +
        '<th>LTX net</th><th>JTAG hw_probe</th><th>Plugins</th></tr>';
      for (const row of rows) {
        html += '<tr class="' + esc(row.status) + '">' +
          '<td class="status">' + esc(row.status) + '</td>' +
          '<td class="mono">' + esc(row.pin) + '</td>' +
          '<td class="dir-' + esc(row.direction) + '">' + esc(row.direction) + '</td>' +
          '<td class="mono">' + esc(String(rangeText(row))) + '</td>' +
          '<td class="mono">' + netsCell(row) + '</td>' +
          '<td class="mono">' + liveCell(row.live) + '</td>' +
          '<td class="plugins">' + esc((row.plugins || []).join(', ') || '—') + '</td>' +
          '</tr>';
      }
      if (filter === 'all' || filter === 'jtag_only') {
        if (jtagOnly.length) {
          html += '<tr class="group"><td colspan="7">JTAG probes with no LTX match (' +
            jtagOnly.length + ')</td></tr>';
          for (const row of jtagOnly) {
            html += '<tr class="jtag-only">' +
              '<td class="status">jtag_only</td>' +
              '<td class="mono">—</td>' +
              '<td class="dir-' + esc(row.direction) + '">' + esc(row.direction) + '</td>' +
              '<td class="mono">' + esc(row.width || '') + '</td>' +
              '<td class="mono">—</td>' +
              '<td class="mono">' + esc(row.name) +
                (row.value && row.value !== '-' ? ' = ' + esc(row.value) : '') + '</td>' +
              '<td class="plugins">—</td></tr>';
          }
        }
      }
      html += '</table>';
    }
    wrap.innerHTML = html;
  }

  function bindFilters() {
    const box = document.getElementById('vio-match-q');
    if (box && !box.dataset.bound) {
      box.dataset.bound = '1';
      box.addEventListener('input', function () {
        query = box.value || '';
        if (lastPayload) render(lastPayload);
      });
    }
    document.querySelectorAll('#vio-match-filters [data-match-filter]').forEach(function (btn) {
      if (btn.dataset.bound) return;
      btn.dataset.bound = '1';
      btn.addEventListener('click', function () {
        filter = btn.dataset.matchFilter || 'all';
        document.querySelectorAll('#vio-match-filters [data-match-filter]').forEach(function (b) {
          b.classList.toggle('active', b === btn);
        });
        if (lastPayload) render(lastPayload);
      });
    });
  }

  async function refresh() {
    bindFilters();
    const params = new URLSearchParams();
    const path = HWMonitor.getLtxPath ? HWMonitor.getLtxPath() : '';
    if (path) params.set('path', path);
    if (HWMonitor.state.device) params.set('device', HWMonitor.state.device);
    const qs = params.toString();
    try {
      const r = await fetch('/api/plugins/vio_match/data' + (qs ? '?' + qs : ''));
      const j = await r.json();
      lastPayload = j;
      render(j);
      const timeEl = document.getElementById('time-vio_match');
      if (timeEl) timeEl.textContent = 'Updated ' + new Date().toLocaleTimeString();
    } catch (e) {
      HWMonitor.setStatus('LTX vs JTAG refresh error: ' + e, true);
    }
  }

  function onDisconnect() {
    lastPayload = null;
    const wrap = document.getElementById('wrap-vio_match');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected — LTX comparison still works after Refresh.</p>';
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['vio_match'],
    onInit() { bindFilters(); },
    refresh,
    onDisconnect,
    onDeviceChange() { refresh(); },
    onTabActivate() { refresh(); },
  });
})();
