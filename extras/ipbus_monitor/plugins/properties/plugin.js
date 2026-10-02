(function () {
  const ID = 'properties';

  function esc(s) {
    return HWMonitor.esc(s);
  }

  function fieldText(side) {
    const parts = [];
    for (const field of (side.fields || [])) {
      if (field.msb === field.lsb && field.value === 0) continue;
      parts.push(field.name + '=' + field.hex);
    }
    const extra = side.extra || {};
    for (const key of Object.keys(extra)) {
      parts.push(key + ': ' + extra[key]);
    }
    return parts.join(' · ') || '—';
  }

  const FAULT_ON = /miss|collision|fault|los|abs|fatal|uncorrect|blocked|error/;

  function ledClass(name, on) {
    if (!on) return 'led';
    return 'led on' + (FAULT_ON.test(name) ? ' bad' : ' good');
  }

  function ledBits(side, sideId) {
    const bits = [];
    for (const field of (side.fields || [])) {
      if (field.name === 'side' && field.msb === field.lsb) {
        const reported = field.value ? 'B' : 'A';
        bits.push({
          name: 'side ' + reported,
          on: true,
          bad: reported !== sideId,
        });
      } else if (field.msb === field.lsb) {
        bits.push({ name: field.name, on: field.value === 1 });
      } else if (field.name === 'db_leds') {
        const width = field.msb - field.lsb + 1;
        for (let i = 0; i < width; i += 1) {
          bits.push({ name: 'led' + i, on: ((field.value >> i) & 1) === 1 });
        }
      }
    }
    return bits;
  }

  function ledRow(sideId, bits) {
    if (!bits.length) return '';
    return '<div class="prop-led-side"><span class="prop-led-tag">Side ' + sideId + '</span><div class="led-grid">' +
      bits.map(function (bit) {
        const cls = bit.bad ? 'led on bad' : ledClass(bit.name, bit.on);
        return '<span class="' + cls + '"><i></i>' + esc(bit.name) + '</span>';
      }).join('') + '</div></div>';
  }

  function ledBlock(row) {
    const a = ledBits(row.sides.A, 'A');
    const b = ledBits(row.sides.B, 'B');
    if (!a.length && !b.length) return '';
    return '<div class="prop-led-block"><h3>' + esc(row.name) + '</h3>' +
      ledRow('A', a) + ledRow('B', b) + '</div>';
  }

  function bitLed(value) {
    return '<span class="led ' + (value ? 'on good' : '') + '"><i></i></span>';
  }

  function opticalTable(rows) {
    let html = '<div class="prop-led-block"><h3>Optical links</h3>' +
      '<p class="sfp-legend">Each PPr status word holds link 0 in bits 15:0 and link 1 in bits 31:16. ' +
      'The selected mini-drawer is highlighted.</p>' +
      '<table class="data reg-table prop-links"><tr><th>MD</th><th>Link</th>' +
      '<th>bit0</th><th>bit1</th><th>bit2</th><th>bit3</th><th>bits 9:4</th>' +
      '<th>bit10</th><th>bit11</th><th>bit12</th><th class="num">CRC errors</th>' +
      '<th class="num">CRC total</th><th class="num">Frames</th></tr>';
    (rows || []).forEach(function (row) {
      (row.links || []).forEach(function (link, index) {
        const bits = link.bits || {};
        html += '<tr class="' + (row.selected ? 'prop-md-current' : '') + '">' +
          '<td>' + (index === 0 ? ('MD ' + (Number(row.md) + 1)) : '') + '</td>' +
          '<td class="col-name">' + esc(link.id) + '</td>' +
          '<td>' + bitLed(bits.b0) + '</td><td>' + bitLed(bits.b1) + '</td>' +
          '<td>' + bitLed(bits.b2) + '</td><td>' + bitLed(bits.b3) + '</td>' +
          '<td class="num">' + (bits.bits_9_4 == null ? '—' : bits.bits_9_4) + '</td>' +
          '<td>' + bitLed(bits.b10) + '</td><td>' + bitLed(bits.b11) + '</td>' +
          '<td>' + bitLed(bits.b12) + '</td>' +
          '<td class="num' + (link.crc ? ' prop-crc' : '') + '">' + link.crc + '</td>' +
          '<td class="num">' + link.crc_total + '</td>' +
          '<td class="num">' + (index === 0 ? row.frames : '') + '</td></tr>';
      });
    });
    return html + '</table></div>';
  }

  function resetButtons(resets) {
    return '<div class="prop-resets">' + (resets || []).map(function (item) {
      return '<button type="button" class="danger" data-reset-bit="' + item.bit +
        '" data-reset-name="' + esc(item.name) + '">' + esc(item.name) + '</button>';
    }).join('') + '</div>';
  }

  function render(data) {
    const wrap = document.getElementById('wrap-properties');
    if (!wrap) return;
    if (!data || !data.registers) {
      wrap.innerHTML = '<p class="empty">No data.</p>';
      return;
    }
    let html = '<div class="ppr-strip">' +
      '<span>PPr ' + esc(data.ppr_ip || '') + ' MD ' + (Number(data.md) + 1) + '</span>' +
      '<span>firmware ' + esc(data.firmware) + '</span></div>';
    html += resetButtons(data.resets);
    html += opticalTable(data.optical);
    html += data.registers.map(ledBlock).join('');
    html += '<p class="sfp-legend">Status bus via <code>DB_Read_Val</code>. ' +
      'A lit LED is a set bit. Red is a fault flag. ' +
      'Pulse reset writes that <code>cfb_strobe_reg</code> bit, then clears it.</p>';
    html += '<table class="data"><tr><th>Register</th><th>Addr</th>' +
      '<th>Side A</th><th>Side A fields</th><th>Side B</th><th>Side B fields</th></tr>';
    for (const row of data.registers) {
      const a = row.sides.A;
      const b = row.sides.B;
      html += '<tr><td>' + esc(row.name) + '</td><td class="num">' + esc(row.addr_hex) + '</td>' +
        '<td class="num">' + esc(a.hex) + '</td><td>' + esc(fieldText(a)) + '</td>' +
        '<td class="num">' + esc(b.hex) + '</td><td>' + esc(fieldText(b)) + '</td></tr>';
    }
    html += '</table>';
    wrap.innerHTML = html;
  }

  async function refresh() {
    if (!HWMonitor.state.connected) return;
    const j = await HWMonitor.fetchJson('/api/plugins/properties/data');
    const timeEl = document.getElementById('time-properties');
    if (timeEl) timeEl.textContent = 'Updated ' + new Date().toLocaleTimeString();
    render(j);
  }

  async function pulseReset(bit, name) {
    const side = document.getElementById('propResetSide').value;
    const where = side === 'both' ? 'side A and side B' : ('side ' + side);
    if (!window.confirm('Pulse ' + name + ' on ' + where + '?')) return;
    const j = await HWMonitor.fetchJson('/api/plugins/properties/reset', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ side: side, bit: Number(bit) }),
    });
    HWMonitor.setStatus('Pulsed ' + j.name + ' on ' + where);
    await refresh();
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['properties'],
    refresh: refresh,
    onInit() {
      document.getElementById('wrap-properties').addEventListener('click', function (ev) {
        const btn = ev.target.closest('[data-reset-bit]');
        if (!btn) return;
        HWMonitor.withBusy('Pulsing reset…', function () {
          return pulseReset(btn.getAttribute('data-reset-bit'), btn.getAttribute('data-reset-name'));
        }).catch(function (err) {
          HWMonitor.setStatus(String(err), true);
        });
      });
      renderEmpty();
    },
    onMdChange() {
      renderEmpty();
      const timeEl = document.getElementById('time-properties');
      if (timeEl) timeEl.textContent = '';
    },
    onDisconnect() {
      renderEmpty();
    },
  });

  function renderEmpty() {
    const wrap = document.getElementById('wrap-properties');
    if (!wrap) return;
    const md = Number(HWMonitor.state && HWMonitor.state.md) || 0;
    wrap.innerHTML = '<p class="adcrd-legend">MD ' + (md + 1) +
      ' · status LEDs, resets, and optical-link table appear here after Refresh. ' +
      'Switching mini-drawer clears the previous MD view until you read again.</p>' +
      '<div class="prop-led-block"><h3>Status / LEDs</h3>' +
      '<p class="empty">No readout yet.</p></div>' +
      '<div class="prop-led-block"><h3>Resets</h3>' +
      '<p class="empty">No readout yet.</p></div>' +
      '<div class="prop-led-block"><h3>Optical links</h3>' +
      '<p class="empty">No readout yet.</p></div>';
  }
})();
