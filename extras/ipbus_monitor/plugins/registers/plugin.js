(function () {
  const ID = 'registers';
  let catalog = null;
  let scanned = null;
  const sectionOpen = { tx: true, rx: true, xadc: true };

  function esc(s) { return HWMonitor.esc(s); }

  function fieldText(fields) {
    return (fields || []).map(function (field) {
      const bits = field.msb === field.lsb ? String(field.lsb) : (field.msb + ':' + field.lsb);
      const shown = field.hex != null ? field.hex : bits;
      return field.name + '=' + shown;
    }).join(' · ') || '—';
  }

  function sideCell(side) {
    if (!side) return '<td class="num col-side">—</td><td class="col-fields">—</td>';
    const extra = side.extra || {};
    const bits = [extra.physical, extra.scaled].filter(Boolean).join(' · ');
    const text = fieldText(side.fields);
    const detail = [text !== '—' ? text : '', bits].filter(Boolean).join(' · ') || '—';
    return '<td class="num col-side">' + esc(side.hex) + '</td><td class="col-fields">' + esc(detail) + '</td>';
  }

  function section(id, title, count, body) {
    const open = sectionOpen[id] !== false;
    return '<details class="reg-section" data-reg-section="' + id + '"' + (open ? ' open' : '') + '>' +
      '<summary>' + esc(title) + ' · ' + count + '</summary>' + body + '</details>';
  }

  function txTable(rows) {
    let html = '<table class="data reg-table"><tr>' +
      '<th class="col-addr">Address</th><th class="col-name">Register</th>' +
      '<th class="num col-side">Side A</th><th class="col-fields">Side A fields</th>' +
      '<th class="num col-side">Side B</th><th class="col-fields">Side B fields</th></tr>';
    rows.forEach(function (row) {
      const sides = row.sides || {};
      html += '<tr><td class="num col-addr">' + esc(row.hw_addr_hex || row.addr_hex) + '</td><td class="col-name">' +
        esc(row.name) + (row.note ? '<div class="probe-hint">' + esc(row.note) + '</div>' : '') +
        (row.error ? '<div class="flash-errors">' + esc(row.error) + '</div>' : '') +
        '</td>' + sideCell(sides.A) + sideCell(sides.B) + '</tr>';
    });
    return section('tx', 'Status (tx)', rows.length, html + '</table>');
  }

  function xadcTable(rows) {
    let html = '<table class="data reg-table"><tr>' +
      '<th class="col-addr">Address</th><th class="col-name">Channel</th>' +
      '<th class="num col-side">Side A</th><th class="col-fields">Side A scaled</th>' +
      '<th class="num col-side">Side B</th><th class="col-fields">Side B scaled</th></tr>';
    rows.forEach(function (row) {
      const sides = row.sides || {};
      html += '<tr><td class="num col-addr">' + esc(row.hw_addr_hex || row.addr_hex) + '</td><td class="col-name">' +
        esc(row.name) + (row.note ? '<div class="probe-hint">' + esc(row.note) + '</div>' : '') +
        (row.error ? '<div class="flash-errors">' + esc(row.error) + '</div>' : '') +
        '</td>' + sideCell(sides.A) + sideCell(sides.B) + '</tr>';
    });
    return section('xadc', 'xADC', rows.length, html + '</table>');
  }

  function rxTable(rows) {
    let html = '<p class="sfp-legend">Write side Both sends the same word to side A and side B.</p>' +
      '<table class="data reg-table"><tr><th class="col-addr">Address</th><th class="col-name">Register</th>' +
      '<th class="col-fields">Fields</th><th class="col-side">Value</th><th></th></tr>';
    rows.forEach(function (row) {
      html += '<tr><td class="num col-addr">' + esc(row.hw_addr_hex) + '</td><td class="col-name">' + esc(row.name) +
        (row.note ? '<div class="probe-hint">' + esc(row.note) + '</div>' : '') +
        '</td><td class="col-fields">' + esc(fieldText(row.fields)) + '</td><td class="col-side"><input data-reg-value="' +
        esc(row.name) + '" type="text" value="0x0" spellcheck="false" /></td><td>' +
        '<button type="button" data-reg-write="' + esc(row.name) + '">Write</button></td></tr>';
    });
    return section('rx', 'Config (rx, write)', rows.length, html + '</table>');
  }

  function render() {
    const wrap = document.getElementById('wrap-registers');
    if (!wrap || !catalog) return;
    const tx = (scanned && scanned.tx) || catalog.tx || [];
    const xadc = (scanned && scanned.xadc) || catalog.xadc || [];
    const rx = (scanned && scanned.rx) || catalog.rx || [];
    wrap.innerHTML = txTable(tx) + rxTable(rx) + xadcTable(xadc);
    wrap.querySelectorAll('details[data-reg-section]').forEach(function (el) {
      el.addEventListener('toggle', function () {
        sectionOpen[el.dataset.regSection] = el.open;
      });
    });
    wrap.querySelectorAll('[data-reg-write]').forEach(function (btn) {
      btn.addEventListener('click', function () { writeReg(btn.getAttribute('data-reg-write')); });
    });
  }

  async function readAll() {
    if (!HWMonitor.state.connected) return;
    scanned = await HWMonitor.fetchJson('/api/plugins/registers/scan');
    document.getElementById('time-registers').textContent =
      'Updated ' + new Date().toLocaleTimeString() + ' · MD ' + (Number(scanned.md) + 1);
    render();
  }

  async function writeReg(name) {
    const side = document.getElementById('regSide').value;
    const input = document.querySelector('[data-reg-value="' + name + '"]');
    const value = input ? input.value : '0x0';
    const where = side === 'both' ? 'side A and side B' : ('side ' + side);
    if (!window.confirm('Write ' + value + ' to ' + name + ' on ' + where + '?')) return;
    const j = await HWMonitor.fetchJson('/api/plugins/registers/write', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ side: side, name: name, value: value }),
    });
    HWMonitor.setStatus('Wrote ' + j.name + ' on ' + where + ' = ' + j.value);
  }

  HWMonitor.registerPlugin({
    id: ID,
    treeNodeTypes: ['registers'],
    async onInit() {
      catalog = await HWMonitor.fetchJson('/api/plugins/registers/map');
      document.getElementById('regRead').addEventListener('click', function () {
        HWMonitor.withBusy('Reading tx and xADC on both sides…', readAll);
      });
      scanned = null;
      render();
    },
    refresh: readAll,
    onMdChange() {
      scanned = null;
      render();
      const timeEl = document.getElementById('time-registers');
      if (timeEl) timeEl.textContent = '';
    },
    onDisconnect() {
      scanned = null;
      render();
    },
  });
})();
