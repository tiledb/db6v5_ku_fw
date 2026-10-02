"""One ControlHub session that can read both daughterboard FPGAs.

VIO Monitor opens a single JTAG chain, so every plugin there sees one FPGA.
Over IPBus the same status address is read twice: bit 31 of the address
selects the FPGA (``IPbus.DB_Read_Val``). Config writes use the same
ordering with the targeted FPGA field ``0b10`` (side A) and ``0b11``
(side B), matching ``FEB`` dbside 1 and 2 and ``DB_Deskew_*``.
"""

from __future__ import annotations

import os
import sys
import threading
import time
from collections import deque
from datetime import datetime

_LIB = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "lib"))
if _LIB not in sys.path:
    sys.path.insert(0, _LIB)

# Side index is the bit-31 selector used by IPbus.DB_Read_Val.
# fpga is the configbus field at fpga_side_offset (bit 12): 0b10 / 0b11.
SIDES = (
    {"id": "A", "label": "Side A", "index": 0, "fpga": 0b10},
    {"id": "B", "label": "Side B", "index": 1, "fpga": 0b11},
)
SIDE_BY_ID = {side["id"]: side for side in SIDES}

_MD_CTRL = 0x00010018
_MD_DATA = 0x00010019


def word(value) -> int:
    """Unwrap a uHAL read (int or one-element list) to a 32-bit word."""
    if isinstance(value, (list, tuple)):
        if not value:
            raise RuntimeError("empty IPBus read")
        value = value[0]
    return int(value) & 0xFFFFFFFF


class IpbusSession:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.ipbus = None
        self.ppr = None
        self.controlhub = ""
        self.ppr_ip = ""
        self.md = 0
        self.log: deque = deque(maxlen=500)
        self._saved_global_trigger = None
        self._pipeline_deadtime_armed = False

    @property
    def connected(self) -> bool:
        return self.ipbus is not None

    def _note(self, text: str, *, error: bool = False) -> None:
        self.log.append({
            "t": datetime.now().strftime("%H:%M:%S"),
            "text": text,
            "error": error,
        })

    def connect(self, controlhub: str, ppr_ip: str, md: int) -> None:
        from db_ppr_ipbus import IPbus, PPr

        hub = (controlhub or "localhost").strip()
        ppr = (ppr_ip or "192.168.0.1").strip()
        md_i = int(md)
        if md_i < 0 or md_i > 3:
            raise ValueError("mini-drawer must be 0..3")

        self._note(f"connect controlhub={hub} ppr={ppr} MD {md_i + 1}")
        bus = IPbus(hub, ppr, verbose=False)
        try:
            fw = word(bus.ReadVal(0x1))
        except Exception:
            self._note("firmware read failed; connection dropped", error=True)
            raise
        self.ipbus = bus
        # PPr.read/write call .Read/.Write, which live on the uHAL client,
        # not on the IPbus helper (that helper exposes ReadVal / DB_Read_Val).
        self.ppr = PPr(bus.ipbus)
        self.controlhub = hub
        self.ppr_ip = ppr
        self.md = md_i
        self._saved_global_trigger = None
        self._pipeline_deadtime_armed = False
        self._note(f"PPr firmware 0x{fw:08X}")
        # Deadtime (busy) on RO_GLOBAL_TRIGGER bit 3 freezes pipeline writes so
        # an L1A snapshot stays stable for IPbus. Clear then set, once per connect.
        # The previous register value is restored on disconnect.
        self._arm_pipeline_deadtime()

    def disconnect(self) -> None:
        if self.ipbus is not None:
            try:
                self._restore_pipeline_deadtime()
            except Exception as exc:
                self._note(f"PPr restore on disconnect failed: {exc}", error=True)
            self._note("disconnect")
        self.ipbus = None
        self.ppr = None
        self._saved_global_trigger = None
        self._pipeline_deadtime_armed = False

    def _arm_pipeline_deadtime(self) -> None:
        """Enable global-trigger deadtime once after connect (RO_GLOBAL_TRIGGER bit 3).

        Only flips bit 3 on the value read from the PPr. Never rewrite from a
        failed/empty read — that would wipe L1A delay / rate and leave the
        board looking "misconfigured".
        """
        from db_ppr_ipbus import PPrReg

        ppr = self.ppr
        if ppr is None:
            return
        before = word(ppr.get_global_trigger())
        self._saved_global_trigger = before
        self._note(f"arm PPr pipeline deadtime (RO_GLOBAL_TRIGGER was 0x{before:08X})")
        # Clear then set bit 3, preserving every other bit from the live read.
        cleared = before & ~(1 << 3)
        armed = before | (1 << 3)
        ppr.write(PPrReg.RO_GLOBAL_TRIGGER, cleared)
        ppr.write(PPrReg.RO_GLOBAL_TRIGGER, armed)
        after = word(ppr.get_global_trigger())
        if not (after & (1 << 3)):
            # Roll back immediately so a failed arm does not leave a partial write.
            ppr.write(PPrReg.RO_GLOBAL_TRIGGER, before)
            self._saved_global_trigger = None
            raise RuntimeError(
                f"RO_GLOBAL_TRIGGER deadtime not set after arm "
                f"(wrote 0x{armed:08X}, read 0x{after:08X}); restored 0x{before:08X}"
            )
        self._pipeline_deadtime_armed = True
        if (after & ~(1 << 3)) != (before & ~(1 << 3)):
            self._note(
                f"RO_GLOBAL_TRIGGER other bits changed on arm: "
                f"0x{before:08X} → 0x{after:08X}",
                error=True,
            )

    def _restore_pipeline_deadtime(self) -> None:
        """Put RO_GLOBAL_TRIGGER / RO_SYNC_CMD back so other tools see a clean PPr."""
        from db_ppr_ipbus import PPrReg

        ppr = self.ppr
        if ppr is None:
            return
        # Always drop the sticky sync-enable left by FEB.send_L1A.
        ppr.write(PPrReg.RO_SYNC_CMD, 0)
        saved = self._saved_global_trigger
        if saved is None:
            if self._pipeline_deadtime_armed:
                current = word(ppr.get_global_trigger())
                ppr.write(PPrReg.RO_GLOBAL_TRIGGER, current & ~(1 << 3))
                self._note("cleared RO_GLOBAL_TRIGGER deadtime bit on disconnect")
            return
        ppr.write(PPrReg.RO_GLOBAL_TRIGGER, saved)
        back = word(ppr.get_global_trigger())
        self._note(f"restored RO_GLOBAL_TRIGGER 0x{saved:08X} (readback 0x{back:08X})")
        self._pipeline_deadtime_armed = False
        self._saved_global_trigger = None

    def set_md(self, md: int) -> None:
        md_i = int(md)
        if md_i < 0 or md_i > 3:
            raise ValueError("mini-drawer must be 0..3")
        self.md = md_i
        self._note(f"select MD {md_i + 1}")

    def _require(self):
        if self.ipbus is None:
            raise RuntimeError("IPBus is not connected")
        return self.ipbus

    def ppr_read(self, addr: int, count: int = 1):
        bus = self._require()
        addr_i = int(addr) & 0xFFFFFFFF
        count_i = max(1, int(count))
        self._note(f"read 0x{addr_i:08X} x{count_i}")
        if count_i == 1:
            return word(bus.ReadVal(addr_i))
        return [word(item) for item in bus.RODReadChunck(addr_i, count_i)]

    def ppr_write(self, addr: int, value: int) -> None:
        bus = self._require()
        addr_i = int(addr) & 0xFFFFFFFF
        value_i = int(value) & 0xFFFFFFFF
        self._note(f"write 0x{addr_i:08X} <= 0x{value_i:08X}")
        bus.RODConfigWrite(addr_i, value_i)

    def read_side(self, side_id: str, reg: int) -> int:
        """One side of ``IPbus.DB_Read_Val`` (bit 31 selects the FPGA)."""
        bus = self._require()
        side = SIDE_BY_ID[side_id]
        reg_i = int(reg) & 0x7FFFFFFF
        ctrl = _MD_CTRL + (self.md << 20)
        data = _MD_DATA + (self.md << 20)
        addr = (side["index"] << 31) | reg_i
        self._note(f"DB read MD {self.md + 1} side {side_id} reg 0x{reg_i:03X}")
        bus.RODConfigWrite(ctrl, addr)
        time.sleep(0.05)
        return word(bus.ReadVal(data))

    def read_both(self, reg: int) -> dict[str, int]:
        """Status word from side A and side B."""
        bus = self._require()
        reg_i = int(reg) & 0x7FFFFFFF
        self._note(f"DB_Read_Val MD {self.md + 1} reg 0x{reg_i:03X}")
        values = bus.DB_Read_Val(self.md, reg_i)
        return {side["id"]: word(values[side["index"]]) for side in SIDES}

    def write_side(self, side_id: str, reg: int, value: int, mask: int = 0) -> None:
        """``IPbus.DB_Write_Val`` for one FPGA. ``reg`` is the configbus hw address."""
        bus = self._require()
        side = SIDE_BY_ID[side_id]
        reg_i = int(reg) & 0xFFFF
        value_i = int(value) & 0xFFFFFFFF
        self._note(
            f"DB_Write_Val MD {self.md + 1} side {side_id} fpga={side['fpga']:#x} "
            f"reg 0x{reg_i:03X} <= 0x{value_i:08X}"
        )
        bus.DB_Write_Val(self.md, side["fpga"], reg_i, value_i, int(mask) & 0xFFFFFFFF)

    def trigger_readout(self, bcr: int) -> int:
        """Latch a PPr pipeline snapshot at ``bcr``, then leave it frozen for IPbus.

        Each cycle must:
        1. Read ``LAST_EVT_BCID`` / ``LAST_EVT_L1ID`` (releases busy so the next
           L1A can update the pipelines).
        2. ``FEB.send_L1A(bcid, 3)`` — sync command that latches the event.
        Deadtime must already be armed once at connect (see ``_arm_pipeline_deadtime``).
        """
        from db_ppr_ipbus import FEB, PPrReg

        self._require()
        if self.ppr is None:
            raise RuntimeError("IPBus is not connected")
        bcid = int(bcr) & 0xFFF
        last_bcid = word(self.ppr.read(PPrReg.LAST_EVT_BCID)) & 0xFFF
        last_l1id = word(self.ppr.read(PPrReg.LAST_EVT_L1ID)) & 0xFFF
        self._note(
            f"PPr last event BCID={last_bcid} L1ID={last_l1id}; "
            f"send_L1A BCR={bcid} cmd=3"
        )
        # FEB methods expect an object with lowercase write(); PPr provides that.
        FEB(self.ppr).send_L1A(bcid, 3)
        time.sleep(0.02)
        return bcid

    def pipeline(self, adc: int, samples: int, gain: str) -> list[int]:
        """PPr pipeline samples. ``adc`` is 0..11 within the selected mini-drawer."""
        self._require()
        if self.ppr is None:
            raise RuntimeError("IPBus is not connected")
        count = max(1, min(int(samples), 32))
        channel = int(adc)
        if channel < 0 or channel > 11:
            raise ValueError("ADC channel must be 0..11")
        self._note(f"pipeline MD {self.md + 1} adc={channel} {gain} x{count}")
        if gain == "lg":
            values = self.ppr.get_data_LG(self.md, channel, count)
        else:
            values = self.ppr.get_data_HG(self.md, channel, count)
        return [int(item) & 0xFFF for item in values]


SESSION = IpbusSession()
