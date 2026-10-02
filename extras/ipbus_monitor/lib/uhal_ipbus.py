"""uHAL adapter expected by ``db_ppr_ipbus.IPbus``.

``IPbus`` builds a ControlHub URI ``tcp://<hub>:10203?target=<ppr>:50001``
and calls ``Read`` / ``Write`` / ``ReadFIFO`` with raw addresses. This module
translates that onto the cern-ipbus ``uhal`` client (``chtcp-2.0``).
"""

from __future__ import annotations

import os
import re
import tempfile

# IPbus() always appends ":10203" and ":50001". A ControlHub or PPr value
# that already contains its port becomes "host:10203:10203?target=...".
# uHAL then stops at the first port and drops the target argument.
_DOUBLED_HUB_PORT = re.compile(
    r"^chtcp-2\.0://(?P<host>[^/?#:]+):(?P<port>\d+):10203(?P<query>\?.*)?$"
)
_DOUBLED_TARGET_PORT = re.compile(r"(\?target=[^:&?#]+:\d+):50001$")


def _uhal_uri(uri: str) -> str:
    text = (uri or "").strip()
    if text.startswith("tcp://"):
        text = "chtcp-2.0://" + text[len("tcp://"):]
    match = _DOUBLED_HUB_PORT.match(text)
    if match:
        text = f"chtcp-2.0://{match.group('host')}:{match.group('port')}{match.group('query') or ''}"
    return _DOUBLED_TARGET_PORT.sub(r"\1", text)


def _address_table() -> str:
    path = os.path.join(tempfile.gettempdir(), "ipbus_monitor_raw.xml")
    if not os.path.isfile(path):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(
                '<?xml version="1.0" encoding="ISO-8859-1"?>\n'
                "<node>\n"
                '  <node id="top" address="0x00000000" />\n'
                "</node>\n"
            )
    return "file://" + path


class Uhal:
    """Raw-address ControlHub client."""

    def __init__(self, uri: str):
        try:
            import uhal
        except ImportError as exc:
            raise ImportError(
                "Python package 'uhal' is not installed. "
                "Source the IPBus software environment, then restart the monitor."
            ) from exc

        self.verbose = False
        self._uhal = uhal
        uhal.setLogLevelTo(uhal.LogLevel.ERROR)
        self.hw = uhal.getDevice("ipbus_monitor", _uhal_uri(uri), _address_table())
        # Milliseconds. Configbus reads wait on the GBT round trip in software;
        # this only bounds a stuck ControlHub transaction.
        self.hw.setTimeoutPeriod(5000)

    def SetVerbose(self, verbose: bool) -> None:
        self.verbose = bool(verbose)
        level = self._uhal.LogLevel.DEBUG if self.verbose else self._uhal.LogLevel.ERROR
        self._uhal.setLogLevelTo(level)

    def Read(self, addr, size=1):
        count = int(size or 1)
        client = self.hw.getClient()
        if count == 1:
            txn = client.read(int(addr))
            self.hw.dispatch()
            return [int(txn.value()) & 0xFFFFFFFF]
        txn = client.readBlock(int(addr), count)
        self.hw.dispatch()
        return [int(item) & 0xFFFFFFFF for item in txn.value()]

    def ReadFIFO(self, addr, size, fifo=True):
        count = int(size or 1)
        if not fifo:
            return self.Read(addr, count)
        client = self.hw.getClient()
        txns = [client.read(int(addr)) for _ in range(count)]
        self.hw.dispatch()
        return [int(txn.value()) & 0xFFFFFFFF for txn in txns]

    def Write(self, addr, value) -> None:
        """Write one word, or N words to ``addr .. addr+N-1``.

        Multi-word lists are used for adjacent ADDRESS/COMMAND pairs
        (e.g. ``SYNC_PPR`` at 0x10004 / 0x10005). Prefer discrete writes over
        ``writeBlock`` so a raw address-table client cannot auto-increment
        into an unexpected node encoding.
        """
        client = self.hw.getClient()
        if isinstance(value, (list, tuple)):
            words = [int(item) & 0xFFFFFFFF for item in value]
            base = int(addr)
            for offset, word in enumerate(words):
                client.write(base + offset, word)
        else:
            client.write(int(addr), int(value) & 0xFFFFFFFF)
        self.hw.dispatch()
