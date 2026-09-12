(function () {
  const ID = 'tilecal_flash_driver';

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function parseHex(text, fallback) {
    if (!text || !String(text).trim()) return fallback;
    const t = String(text).trim().toLowerCase();
    try {
      return parseInt(t.startsWith('0x') ? t : ('0x' + t), 16);
    } catch (e) {
      return fallback;
    }
  }

  function flag(label, val, warn) {
    const cls = val ? (warn ? 'flag-warn' : 'flag-true') : 'flag-false';
    return '<span class="' + cls + '">' + esc(label) + ': ' + (val ? 'yes' : 'no') + '</span>';
  }

  function renderHexDump(dump) {
    if (!dump || !dump.rows || !dump.rows.length) return '';
    let html = '<div class="flash-dump-head">' +
      esc(dump.base_hex) + ' · ' + dump.length + ' bytes · ' +
      (dump.byte_count != null ? dump.byte_count + ' captured' : '') +
      '</div>';
    html += '<table class="flash-hex"><tr>' +
      '<th>Address</th><th>Hex</th><th>ASCII</th></tr>';
    for (const row of dump.rows) {
      html += '<tr><td class="addr">' + esc(row.address_hex) + '</td>' +
        '<td class="hex">' + esc(row.hex) + '</td>' +
        '<td class="ascii">' + esc(row.ascii) + '</td></tr>';
    }
    html += '</table>';
    return html;
  }

  function renderResult(data) {
    const wrap = document.getElementById('wrap-tilecal_flash_driver');
    if (!wrap) return;
    if (!data) {
      wrap.innerHTML = '<p class="empty">No data.</p>';
      return;
    }

    let html = '';
    if (data.errors && data.errors.length) {
      html += '<div class="flash-errors">' + data.errors.map(esc).join('<br>') + '</div>';
    }

    html += '<p class="flash-legend">' +
      'IS25LP256 via <code>s_clknet_debug_control[flash_manual_*]</code>. ' +
      'Bulk read issues up to 4096 bytes (4-byte chunks). ' +
      'Writes/erase require address above firmware floor or floor override.</p>';

    const st = data.status || {};
    const rd = data.rdata || {};
    html += '<div class="flash-result">';
    html += '<div class="flash-box"><h3>flash_status</h3><div class="flash-kv">' +
      '<div>' + esc(st.raw_hex || '—') + '</div>' +
      '<div>' + flag('done', st.done) + ' · ' + flag('busy', st.busy) + '</div>' +
      '<div>' + flag('write_blocked', st.write_blocked, true) + '</div>' +
      '<div>SR: 0x' + esc((st.status_reg != null ? st.status_reg : 0).toString(16).toUpperCase().padStart(2, '0')) +
      ' · op: ' + esc(st.op_name || '—') + '</div></div></div>';

    html += '<div class="flash-box"><h3>flash_rdata (last)</h3><div class="flash-kv">' +
      '<div>' + esc(rd.raw_hex || '—') + '</div>' +
      '<div>' + esc(rd.bytes_hex || '') + '</div></div></div>';
    html += '</div>';

    html += renderHexDump(data.hex_dump);

    if (data.probes && Object.keys(data.probes).length) {
      html += '<div class="flash-probes">' +
        Object.entries(data.probes).map(function (e) {
          return esc(e[0] + ': ' + e[1]);
        }).join('<br>') + '</div>';
    }

    wrap.innerHTML = html;

    const hint = document.getElementById('status-tilecal_flash_driver');
    if (hint) {
      hint.textContent = data.operation ? ('Last: ' + data.operation) : 'Status read';
      hint.classList.toggle('warn', !!(data.errors && data.errors.length) || st.write_blocked);
    }
  }

  function floorPayload() {
    const en = document.getElementById('flashFloorEn');
    if (!en || !en.checked) return {};
    return {
      floor_enable: true,
      floor: parseHex(document.getElementById('flashFloor') && document.getElementById('flashFloor').value, 0),
    };
  }

  function pluginReady() {
    return HWMonitor.ltxPluginStatus[ID] === 'ok';
  }

  function showIdleMessage(message) {
    const wrap = document.getElementById('wrap-tilecal_flash_driver');
    if (wrap) wrap.innerHTML = '<p class="empty">' + esc(message) + '</p>';
    const hint = document.getElementById('status-tilecal_flash_driver');
    if (hint) {
      hint.textContent = message;
      hint.classList.remove('warn');
    }
  }

  async function runOp(operation) {
    if (!HWMonitor.state.targetOpen || !HWMonitor.state.device) {
      HWMonitor.setStatus('Select a device before flash operations', true);
      return;
    }
    if (!pluginReady()) {
      const info = (HWMonitor.ltxPluginInfo || {})[ID] || {};
      showIdleMessage(info.message || 'Load LTX to the device before using the flash driver.');
      return;
    }
    if (operation.indexOf('erase') >= 0 || operation === 'write_byte') {
      const addr = document.getElementById('flashAddr') && document.getElementById('flashAddr').value;
      if (!window.confirm('Run ' + operation + ' at ' + addr + '? This modifies flash.')) return;
    }

    const byteCountEl = document.getElementById('flashByteCount');
    const byteCount = parseInt((byteCountEl && byteCountEl.value) || '4096', 10);

    const body = {
      device: HWMonitor.state.device,
      operation: operation,
      address: parseHex(document.getElementById('flashAddr') && document.getElementById('flashAddr').value, 0),
      wdata: parseHex(document.getElementById('flashWdata') && document.getElementById('flashWdata').value, 0) & 0xFF,
      byte_count: byteCount,
      ...floorPayload(),
    };

    const isStatus = operation === 'status';
    const url = isStatus
      ? '/api/plugins/tilecal_flash_driver/status' + HWMonitor.deviceQuery()
      : '/api/plugins/tilecal_flash_driver/execute';

    const readOps = operation === 'read' || operation === 'fast_read';
    const busyLabel = isStatus ? 'Reading flash status…' :
      (readOps ? ('Reading ' + byteCount + ' bytes from flash…') : ('Flash ' + operation + '…'));
    try {
      await HWMonitor.withBusy(busyLabel, async function () {
        const r = isStatus
          ? await fetch(url)
          : await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
        const j = await r.json();
        if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
        j.operation = j.operation || operation;
        const timeEl = document.getElementById('time-tilecal_flash_driver');
        if (timeEl) timeEl.textContent = new Date().toLocaleTimeString();
        renderResult(j);
        if (j.errors && j.errors.length) {
          HWMonitor.setStatus('Flash: ' + j.errors.join('; '), true);
        } else {
          HWMonitor.setStatus('Flash ' + operation + ' complete');
        }
      });
    } catch (e) {
      HWMonitor.setStatus('Flash error: ' + e, true);
    }
  }

  function onDisconnect() {
    const wrap = document.getElementById('wrap-tilecal_flash_driver');
    if (wrap) wrap.innerHTML = '<p class="empty">Disconnected.</p>';
    const hint = document.getElementById('status-tilecal_flash_driver');
    if (hint) hint.textContent = '';
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['tilecal_flash_driver'],
    onInit() {
      document.querySelectorAll('[data-flash-op]').forEach(function (btn) {
        btn.addEventListener('click', function () {
          runOp(btn.getAttribute('data-flash-op'));
        });
      });
    },
    refresh() {
      if (!pluginReady()) {
        const info = (HWMonitor.ltxPluginInfo || {})[ID] || {};
        showIdleMessage(info.message || 'Load LTX to the device before using the flash driver.');
        return Promise.resolve();
      }
      return runOp('status');
    },
    onDisconnect,
    onDeviceChange() {
      if (!pluginReady()) {
        const info = (HWMonitor.ltxPluginInfo || {})[ID] || {};
        showIdleMessage(info.message || 'Load LTX to the device before using the flash driver.');
        return;
      }
      return runOp('status');
    },
    onTabActivate() {},
  });
})();
