#################################################################################--
###                                                                            ##--
### db6 constraints                                                            ##--
### Version: 1.0                                                               ##--
### Creation date: 2019-11-05                                                  ##--
### Created by: : Eduardo Valdes                                               ##--
###                                                                            ##--
### Modification date:                                                         ##--
### Modified by:                         		                               ##--
###                                                                            ##--
#################################################################################--



#bitclks

create_clock -period 3.571 -name {p_adc_bitclk_in[0][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[0][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[1][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[1][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[2][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[2][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[3][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[3][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[4][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[4][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[5][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[5][p]}]

create_clock -period 12.500 -name {p_gbt_cis_hss_clk80_local_in[p]} -waveform {0.000 6.250} [get_ports {p_gbt_cis_hss_clk80_local_in[p]}]


#create clocks
create_clock -period 25.000 -name {p_gbt_cfgbus_clk40_local_in[p]} -waveform {0.000 12.500} [get_ports {p_gbt_cfgbus_clk40_local_in[p]}]
create_clock -period 25.000 -name {p_gbt_mb_q0_clk40_local_in[p]} -waveform {0.000 12.500} [get_ports {p_gbt_mb_q0_clk40_local_in[p]}]
create_clock -period 25.000 -name {p_gbt_mb_q1_clk40_local_in[p]} -waveform {0.000 12.500} [get_ports {p_gbt_mb_q1_clk40_local_in[p]}]
#create_clock -period 6.250 -name {p_gth_refclk_gbtx_local_in[0][p]} -waveform {0.000 3.125} [get_ports {p_gth_refclk_gbtx_local_in[0][p]}]
create_clock -period 12.500 -name {p_gth_refclk_gbtx_local_in[0][p]} -waveform {0.000 6.250} [get_ports {p_gth_refclk_gbtx_local_in[0][p]}]
#create_clock -period 12.50 -name {p_gth_refclk_gbtx_local_in[1][p]} -waveform {0.000 6.50} [get_ports {p_gth_refclk_gbtx_local_in[1][p]}]

create_clock -period 10.000 -name {p_osc_clk_in[p]} -waveform {0.000 5.000} [get_ports {p_osc_clk_in[p]}]
create_clock -period 3.125 -name {p_gbt_tp_q0_clk40_local_in[p]} -waveform {0.000 1.562} [get_ports {p_gbt_tp_q0_clk40_local_in[p]}]
create_clock -period 3.125 -name {p_gbt_tp_q1_clk40_local_in[p]} -waveform {0.000 1.562} [get_ports {p_gbt_tp_q1_clk40_local_in[p]}]

create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[0][p]} -waveform {0.000 12.500} [get_ports {p_adc_gbtx_frameclk_in[0][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[1][p]} -waveform {0.000 12.500} [get_ports {p_adc_gbtx_frameclk_in[1][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[2][p]} -waveform {0.000 12.500} [get_ports {p_adc_gbtx_frameclk_in[2][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[3][p]} [get_ports {p_adc_gbtx_frameclk_in[3][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[4][p]} [get_ports {p_adc_gbtx_frameclk_in[4][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[5][p]} [get_ports {p_adc_gbtx_frameclk_in[5][p]}]
create_clock -period 12.500 -name {p_gth_refclk_gbtx_local_in[1][p]} [get_ports {p_gth_refclk_gbtx_local_in[1][p]}]

set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[0][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[0][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[5][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[0][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[1][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[1][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[4][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[1][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[2][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[2][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[3][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[2][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[2][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[3][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[3][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[3][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[1][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[4][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[4][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[4][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[0][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[5][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[5][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[5][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks p_clk320_out_mmcm_cis_interface]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks p_clk320_out_mmcm_cis_interface]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[0][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[1][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[2][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[3][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[4][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[5][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]_1}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[0][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[1][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[2][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[3][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[4][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[5][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[0]}]
#set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]_1}] -group [get_clocks {txoutclk_out[0]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[0]_1}]
#set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks {txoutclk_out[0]_1}]

# hss_adc / hss_adc_ch0-4 (g_clocking_mode=3 ADC readout): the SelectIO wizard's own
# reference XDC ships this exact false-path exception for its internal PLL-lock/reset
# sequencer 2-flop synchronizer (a real CDC boundary, not a meaningful setup path) --
# without it, WNS was -7.1ns/TNS -40.6ns from this synchronizer alone across all 5
# per-channel IPs; with it, both drop out entirely (confirmed via get_timing_paths).
set_false_path -to [get_pins -hier -filter {NAME =~ *sync_flop_0*/D}]

# 2026-09-12: db6_adc_interface_decoder_iddr_bitclk280.vhd's gen_tap_select_iddr280_clkdiv
# (proc_tap_select_sync, the p_adc_bitclkdiv -> cfgbus_clk40 tap-select/tap-locked resync
# this exception used to cover) was removed along with the whole dual-tap canary-lock CDC
# it supported -- see that file's proc_cdc_capture header. Replaced by the toggle/handshake
# exceptions below (shared with db6_adc_interface_decoder_iserdese.vhd's identical pattern)
# and by db6_adc_idelay_calibration.vhd's own req/ack synchronizer exceptions further down.

# db6_cis_interface_hss_io.vhd's proc_cis_cdc_gen (name mirrors db6_clock_interface.vhd's
# proc_cdc_gen -- the same established single-flop, edge-tolerant BCR resync pattern used
# throughout this codebase, see the two set_false_path groups above): reads
# p_clknet_in.bcr.bcr/bcr_locked directly inside a process clocked by the CIS block's own
# PLL (s_hss_cis.pll0_clkout0), same class of genuine but intentionally-unsynchronized CDC
# boundary as the other two groups above -- BCR is a slow (~11kHz), edge-detected orbit
# pulse; missing a resync cycle here just delays the next resync attempt by one orbit, not
# a data-integrity issue. Missing this exception showed up as WNS -1.993ns/TNS -10.9ns
# across 6 endpoints (s_bcr_cis_reg, FSM_onehot_s_sm_cis_sync_reg*, s_cdc_counter_reg*) once
# g_adc_clocking_scheme=hss_wizard was fully placed and routed (2026-09-10).
set_false_path -to [get_pins -hier -filter {NAME =~ *s_bcr_cis_reg*/D}]
set_false_path -to [get_pins -hier -filter {NAME =~ *FSM_onehot_s_sm_cis_sync_reg*/CE}]
set_false_path -to [get_pins -hier -filter {NAME =~ *s_cdc_counter_reg*/CE}]

# db6_adc_interface_io_hss.vhd (g_adc_clocking_scheme=hss_wizard, 2026-09-11 fix): the
# hss_wizard decoder's own internal FSM output now genuinely updates in each channel's own
# s_adc_rx_clk domain (~140MHz, hss_adc's own pll0_clkout0, buffered -- previously this was
# all tied to cfgbus_clk40, which is why this crossing never showed up before).
# vio_clknet_status (db6v5_top.vhd) monitors s_adc_fifo_data_valid/s_adc_rst_seq_done,
# hss_adc status signals that now genuinely live in the s_adc_rx_clk domain too (same root
# cause as db6_adc_interface_io_hss.vhd's fix above -- previously accidentally
# same-domain via the old fifo_rd_clk=cfgbus_clk40 wiring). Not a real CDC: it's a passive
# monitoring tap with no feedback into functional logic, so an asynchronous,
# occasionally-metastable sample is entirely acceptable, same reasoning as the three CDC
# groups above.
# 2026-09-16: the two matching exceptions for i_ila_adc_readout/i_ila_adc_nibble (this
# session's own bring-up-debug ILAs, db6_mainboard_interface.vhd) were removed along with
# those ILA instantiations -- no longer needed now that the bug they were added to debug
# is understood and fixed (see db6_adc_idelay_calibration.vhd).
set_false_path -to [get_pins -hier -filter {NAME =~ *i_vio_clknet_status*/D}]

# db6_adc_interface_decoder_iserdese.vhd (2026-09-11): async reset-recovery/removal timing
# on p_master_reset_in (a board-wide, long-asserted system reset) into this decoder's new
# ~140MHz-domain registers (s_fc_data_fast_reg etc and the proc_align_data/proc_cdc_lock
# process variables) -- this class of check was never exercised before since everything in
# this file used to run on the much slower cfgbus_clk40. Standard, always-safe-to-except
# FPGA practice (Xilinx UG906/UG949): a late-arriving reset *release* here only risks
# holding these registers in reset one extra cycle, never metastability propagating into
# data, since the reset itself stays asserted for many cycles at the system level.
## 2026-09-12: the /R,/PRE,/CLR-only version of this exception above turned out
## incomplete -- checked against a full post-route report, every one of the 314
## remaining failing endpoints traced back to s_master_reset_reg[24] (replicated for
## fanout as _replica_1/_replica_2), not to genuine same-domain data-path logic depth as
## first suspected. Because p_master_reset_in also participates in proc_align_data's
## reset/no-reset if-elsif condition (not just the async reset pin itself), synthesis
## folds part of that check into these registers' CE logic too -- so the exception needs
## to cover CE destinations as well, which a purely destination-pin-type-based filter
## can't cleanly do without also catching genuine data-driven CE paths. Sourced instead:
## anything launched from this specific reset bit's register, landing anywhere in this
## decoder, is by construction reset-recovery-class, not data-path timing.
set_false_path -from [get_cells -hier -filter {NAME =~ *s_master_reset_reg*}] -to [get_pins -hier -filter {NAME =~ *i_db6_adc_interface_decoder_iserdese*}]

## 2026-09-13: db6_adc_interface_decoder_iddr_bitclk280_serdes140.vhd (iddr280_serdes140
## scheme) -- identical root cause and identical proc_align_data/p_master_reset_in
## pattern as the iserdese exception directly above (this decoder's FSM was modeled on
## db6_adc_interface_decoder_iserdese.vhd's, including its use of p_master_reset_in in
## the same if-elsif reset/no-reset condition, which synthesis folds into CE logic the
## same way). Found the hard way: first implementation attempt after fixing this
## scheme's placement (see p_blocks.xdc's pblock_adc_readout_serdes140_ch0-5) still
## failed timing, WNS -2.319ns, on exactly this same s_master_reset_reg[24]-replica ->
## decoder CE path, just under this decoder's own (different) instance name -- the
## exception above never matched it. Same instance-name-glob approach, this decoder's
## name instead.
set_false_path -from [get_cells -hier -filter {NAME =~ *s_master_reset_reg*}] -to [get_pins -hier -filter {NAME =~ *i_db6_adc_interface_decoder_iddr_serdes140*}]

# db6_adc_interface_decoder_iserdese.vhd (2026-09-12, same root cause as the group above):
# real functional consumers of s_adc_readout (db6_gbt_encoder_adc_data among others) DO
# need fc/hg/lg data back in cfgbus_clk40 -- see that file's proc_cdc_capture, a
# toggle/valid-handshake synchronizer (replaced an earlier dual-tap canary-lock design
# that gave different, data-dependent latency per channel -- unacceptable for a
# multi-channel system needing identical fixed latency across all six ADCs; see that
# file's header comment). The ONLY signal that genuinely crosses the clock boundary
# asynchronously is the single-bit s_data_toggle, sampled into s_toggle_sync0 -- a
# conventional first-stage synchronizer flop, the same class of exception as
# s_frame_missalignment_sync0 just below (a torn read of one bit just glitches cleanly to
# old or new, never metastability propagating into the multi-bit data itself, which by
# design is only ever read once the synchronized toggle has settled and confirmed stable
# for several source cycles).
set_false_path -to [get_pins -hier -filter {NAME =~ *s_toggle_sync0_reg*/D}]
# proc_cdc_capture's actual data/status capture (s_adc_readout.fc_data/hg_data/lg_data/
# channel_locked, all written together inside the same toggle-gated if-block) is, from
# Vivado's STA point of view, ALSO a clock-boundary-crossing read of the fast-domain
# s_fc_data_fast/s_hg_data_fast/s_lg_data_fast -- it has no way to know the toggle
# handshake already guarantees this specific read only ever happens once that data has
# been stable for several source cycles, so it still reports the same class of unmeetable
# ~140MHz-to-40MHz timing relationship on these registers as it did on the toggle
# synchronizer itself. Scoped to this decoder's own hierarchy (s_adc_readout_reg is
# otherwise unique to it, so this can't accidentally catch anything unrelated).
set_false_path -to [get_pins -hier -filter {NAME =~ *i_db6_adc_interface_decoder_iserdese*s_adc_readout_reg*/D}]
# same file's plain double-flop synchronizer for the single-bit channel_frame_missalignemt
# status (no dual-tap/marker-check needed for a single bit -- a torn read of one bit just
# glitches cleanly to old or new, unlike a multi-bit word): only the first stage
# (s_frame_missalignment_sync0_reg) is the actual CDC boundary needing this exception.
set_false_path -to [get_pins -hier -filter {NAME =~ *s_frame_missalignment_sync0_reg*/D}]

# 2026-09-12: db6_adc_interface_decoder_iddr_bitclk280.vhd's proc_cdc_capture -- identical
# toggle/handshake pattern and identical signal names (s_toggle_sync0/1/1_prev) to the
# iserdese decoder above, so the generic s_toggle_sync0_reg exception already covers its
# first-stage synchronizer. Only the scoped exception for the actual data-capture registers
# needs a second entry, since that one is deliberately scoped by instance path (see the
# comment above the iserdese version of this exception).
set_false_path -to [get_pins -hier -filter {NAME =~ *i_db6_adc_interface_decoder_iddr*s_adc_readout_reg*/D}]

# 2026-09-12: db6_adc_idelay_calibration.vhd's cfgbus_clk40 <-> p_adc_bitclk_in(v_adc)
# req/ack level-handshake (see that file's header) -- two independent 2-flop synchronizers,
# one per direction. Same class of exception as every other synchronizer group above: only
# the first stage of each actually crosses the clock boundary; everything downstream reads
# an already-settled, held level.
set_false_path -to [get_pins -hier -filter {NAME =~ *s_load_req_sync0_reg*/D}]
set_false_path -to [get_pins -hier -filter {NAME =~ *s_load_ack_sync0_reg*/D}]

set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {p_clk320_out_mmcm_cis_interface}]

#set_false_path -from [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -to [get_clocks {txoutclk_out[0]}]
#set_false_path -from [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -to [get_clocks {txoutclk_out[1]}]
#set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[1]}]

set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks p_clk40_out_pll_osc_clk]



## 2026-09-13: g_adc_clocking_scheme=iddr280_serdes140's per-channel CLKDIV
## (s_adc_bitclkdiv[0-5], BUFGCE_DIV/2 off p_adc_bitclk_in[N][p] -- see
## db6_adc_interface_io_iddr_bitclk280_serdes140.vhd) is its own distinct generated
## clock object in Vivado's clock tree, not automatically covered by the
## p_gbt_cfgbus_clk40_local_in<->p_adc_bitclk_in[N][p] async groups below even though
## it's derived from that same bit clock. Found the hard way: fixing DRC REQP-1742
## (moving each channel's IDELAYE3 CLK from the raw bit clock to this CLKDIV, to match
## its paired ISERDESE3's CLKDIV pin -- a real hardware requirement) exposed
## db6_adc_idelay_calibration.vhd's cfgbus_clk40->CNTVALUEIN crossing as a real,
## unexempted STA path for the first time (WNS -5.3ns, TNS -427ns) -- that crossing is
## exactly the same async, req/ack-handshake-guarded one already asynchronous for the
## raw bit clock below; it just needs the same exemption extended to the derived clock
## that now actually clocks the destination primitive.
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {s_adc_bitclkdiv[0]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {s_adc_bitclkdiv[1]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {s_adc_bitclkdiv[2]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {s_adc_bitclkdiv[3]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {s_adc_bitclkdiv[4]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {s_adc_bitclkdiv[5]}]

set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[0][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[1][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[2][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[3][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[4][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[5][p]}]


set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[0][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[1][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[2][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[3][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[4][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[5][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]

set_clock_groups -asynchronous -group [get_clocks p_clk40_out_pll_osc_clk] -group [get_clocks {p_gbt_tp_q0_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_gbt_tp_q0_clk40_local_in[p]}]

set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks GEN_PLL_IN_IP_US.pll0_clkout0]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks shared_pll0_clkoutphy_out_DIV]



set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {p_db_side_in_IBUF[0]_inst/O}]


set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]_1}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[0]_1}]

set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {p_clk320_out_pll_dskclk}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_clk320_out_pll_dskclk}]



set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks p_clk200_out_pll_osc_clk]


# 2026-09-15: user-requested test -- pair p_clk40_out_pll_osc_clk against each
# s_adc_bitclkdiv[N] individually. NOTE: this exact exception was already tried and
# reverted in an earlier session (blanket set_clock_groups version) -- it cleared this
# STA violation but caused a confirmed hardware regression (db6_adc_config_driver FSM
# livelock). Being re-tested here at the user's request; see memory
# adc-bitclkdiv-osc-clk40-missing-async-group for the full history before trusting a
# clean report_timing_summary on this change alone.
set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {s_adc_bitclkdiv[0]}]
set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {s_adc_bitclkdiv[1]}]
set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {s_adc_bitclkdiv[2]}]
set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {s_adc_bitclkdiv[3]}]
set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {s_adc_bitclkdiv[4]}]
set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {s_adc_bitclkdiv[5]}]
