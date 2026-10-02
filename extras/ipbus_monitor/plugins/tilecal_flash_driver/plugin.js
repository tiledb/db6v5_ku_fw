(function () {
  const ID = 'tilecal_flash_driver';

  function esc(s) { return HWMonitor.esc(s); }

  function flag(label, val, warn) {
    const cls = val ? (warn ? 'flag-warn' : 'flag-true') : 'flag-false';
    return '<span class="' + cls + '">' + esc(label) + ': ' + (val ? 'yes' : 'no') + '</span>';
  }

  function dump(dump) {
    if (!dump || !dump.rows || !dump.rows.length) return '';
    let html = '<div class="flash-dump-head">' + esc(dump.base_hex) + ' · ' + dump.length + ' bytes</div>';
    html += '<table class="flash-hex"><tr><th>Address</th><th>Hex</th><th>ASCII</th></tr>';
    for (const row of dump.rows) {
      html += '<tr><td class="addr">' + esc(row.address_hex) + '</td><td class="hex">' + esc(row.hex) +
        '</td><td class="ascii">' + esc(row.ascii) + '</td></tr>';
    }
    return html + '</table>';
  }

  function oneSide(row) {
    const st = row.status || {};
    const rd = row.rdata || {};
    let html = '<div class="side-card side-' + row.side.toLowerCase() + '"><h3>Side ' + esc(row.side) + '</h3>';
    if (row.errors && row.errors.length) {
      html += '<div class="flash-errors">' + row.errors.map(esc).join('<br>') + '</div>';
    }
    html += '<div class="flash-kv"><div>' + esc(st.raw_hex || '—') + '</div><div>' +
      flag('done', st.done) + ' · ' + flag('busy', st.busy) + '</div><div>' +
      flag('write_blocked', st.write_blocked, true) + '</div><div>SR 0x' +
      (st.status_reg == null ? '00' : st.status_reg.toString(16).toUpperCase().padStart(2, '0')) +
      ' · ' + esc(st.op_name || '—') + '</div><div>' + esc(rd.bytes_hex || rd.raw_hex || '') +
      '</div></div>' + dump(row.hex_dump) + '</div>';
    return html;
  }

  function render(data) {
    const wrap = document.getElementById('wrap-tilecal_flash_driver');
    wrap.innerHTML = '<p class="sfp-legend">IS25LP256 via <code>cfb_flash_*</code> / <code>stb_flash_*</code>. ' +
      'Each 4-byte chunk is a configbus round trip, so reads stay at 1 KB here.</p>' +
      '<div class="side-grid">' + (data.sides || []).map(oneSide).join('') + '</div>';
    const hint = document.getElementById('status-tilecal_flash_driver');
    hint.textContent = data.operation ? ('Last: ' + data.operation) : '';
    hint.classList.toggle('warn', !!(data.errors && data.errors.length));
  }

  function parseHex(text, fallback) {
    if (!text || !String(text).trim()) return fallback;
    const t = String(text).trim().toLowerCase();
    const n = parseInt(t.startsWith('0x') ? t : ('0x' + t), 16);
    return Number.isFinite(n) ? n : fallback;
  }

  async function runOp(operation) {
    if (!HWMonitor.state.connected) {
      HWMonitor.setStatus('Connect before flash operations', true);
      return;
    }
    const side = document.getElementById('flashSide').value;
    if ((operation === 'write_byte' || operation.indexOf('erase') === 0) && side === 'both') {
      HWMonitor.setStatus('Choose side A or side B before writing or erasing', true);
      return;
    }
    if (operation.indexOf('erase') === 0 || operation === 'write_byte') {
      const addr = document.getElementById('flashAddr').value;
      if (!window.confirm('Run ' + operation + ' at ' + addr + ' on side ' + side + '?')) return;
    }
    const body = {
      operation: operation,
      side: side,
      address: parseHex(document.getElementById('flashAddr').value, 0),
      wdata: parseHex(document.getElementById('flashWdata').value, 0) & 0xFF,
      byte_count: parseInt(document.getElementById('flashByteCount').value, 10),
    };
    if (document.getElementById('flashFloorEn').checked) {
      body.floor_enable = true;
      body.floor = parseHex(document.getElementById('flashFloor').value, 0);
    }
    const isStatus = operation === 'status';
    const j = await HWMonitor.fetchJson(
      isStatus ? '/api/plugins/tilecal_flash_driver/status' : '/api/plugins/tilecal_flash_driver/execute',
      isStatus ? {} : { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
    );
    j.operation = j.operation || operation;
    document.getElementById('time-tilecal_flash_driver').textContent = new Date().toLocaleTimeString();
    render(j);
    if (j.errors && j.errors.length) HWMonitor.setStatus('Flash: ' + j.errors.join('; '), true);
    else HWMonitor.setStatus('Flash ' + operation + ' complete');
  }

  function renderEmpty() {
    const wrap = document.getElementById('wrap-tilecal_flash_driver');
    if (!wrap) return;
    const md = Number(HWMonitor.state && HWMonitor.state.md) || 0;
    wrap.innerHTML = '<p class="sfp-legend">MD ' + (md + 1) +
      ' · IS25LP256 via <code>cfb_flash_*</code> / <code>stb_flash_*</code>. ' +
      'Side cards fill after Status / Read.</p>' +
      '<div class="side-card side-a"><h3>Side A</h3><p class="empty">No readout yet.</p></div>' +
      '<div class="side-card side-b"><h3>Side B</h3><p class="empty">No readout yet.</p></div>';
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_flash_driver'],
    onInit() {
      document.querySelectorAll('[data-flash-op]').forEach(function (btn) {
        btn.addEventListener('click', function () {
          const op = btn.getAttribute('data-flash-op');
          HWMonitor.withBusy('Flash ' + op + '…', function () { return runOp(op); });
        });
      });
      renderEmpty();
    },
    refresh() { return runOp('status'); },
    onMdChange() { renderEmpty(); },
    onDisconnect() { renderEmpty(); },
  });
})();
