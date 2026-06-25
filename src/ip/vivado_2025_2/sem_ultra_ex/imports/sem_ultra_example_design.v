/////////////////////////////////////////////////////////////////////////////
//
//
//
/////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /
// \   \   \/    Core:          sem_ultra
//  \   \        Module:        sem_ultra_example_design
//  /   /        Filename:      sem_ultra_example_design.v
// /___/   /\    Purpose:       Example top level.
// \   \  /  \
//  \___\/\___\
//
/////////////////////////////////////////////////////////////////////////////
//
// (c) Copyright 2014-2020 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES. 
//
/////////////////////////////////////////////////////////////////////////////
//
// Module Description:
//
// This module instantiates the system level design example, which includes
// VIO cores as a convenience to demonstrate IP functionality. The VIO may
// be used to drive the IP inputs and monitor the IP outputs. An input clock
// buffer completes the example design.
//
/////////////////////////////////////////////////////////////////////////////
//
// Port Definition:
//
// Name                          Type   Description
// ============================= ====== ====================================
// uart_tx                       output UART status output.  Synchronous
//                                      to icap_clk_out, but received externally
//                                      by another device as an asynchronous
//                                      signal, perceived as lower bitrate.
//                                      Uses 8N1 protocol.
//
// uart_rx                        input UART command input.  Asynchronous
//                                      signal provided by another device at
//                                      a lower bitrate, synchronized to the
//                                      icap_clk and oversampled.  Uses 8N1
//                                      protocol.
//
// clk                           input  System clock; the entire system is
//                                      synchronized to this signal, which
//                                      is distributed on a global clock
//                                      buffer and referred to as icap_clk.
//
/////////////////////////////////////////////////////////////////////////////
//
// Parameter and Localparam Definition:
//
// Name                          Type   Description
// ============================= ====== ====================================
// TCQ                           int    Sets the clock-to-out for behavioral
//                                      descriptions of sequential logic.
//
/////////////////////////////////////////////////////////////////////////////
//
// Module Dependencies:
//
// sem_ultra_example_design
// |
// +- sem_ultra_support_wrapper  (SEM controller and helper blocks)
// |
// +- sem_ultra_vio_si14     (VIO displaying SEM controller status
// |                                and status error signals)
// |
// +- sem_ultra_vio_si1_so5  (VIO for the ICAP arbitration interface
// |                                and auxiliary error inputs)
// |
// +- sem_ultra_vio_si1_so41 (VIO for the command interface)
// |
// \- IBUF (unisim)
//
/////////////////////////////////////////////////////////////////////////////

`timescale 1 ps / 1 ps

/////////////////////////////////////////////////////////////////////////////
// Module
/////////////////////////////////////////////////////////////////////////////

module sem_ultra_example_design (
  input  wire        clk,

// Status interface
  output wire        p_status_heartbeat,
  output wire        p_status_initialization,
  output wire        p_status_observation,
  output wire        p_status_correction,
  output wire        p_status_classification,
  output wire        p_status_injection,
  output wire        p_status_diagnostic_scan,
  output wire        p_status_detect_only,  
  output wire        p_status_essential,
  output wire        p_status_uncorrectable,
  
  input wire [39:0] p_command_code,
  input wire p_command_strobe,
  output wire p_command_busy,
  
  output wire p_status_halt,
  output wire p_status_irregular_sticky,
  output wire p_heartbeat_timeout_sticky,
  output wire p_heartbeat_timeout,
  
  
  
  output wire        uart_tx,
  input  wire        uart_rx,
  
  output  wire  [7:0] p_monitor_txdata,
  output wire        p_monitor_txfull,
  output wire  [7:0] p_monitor_rxdata,
  output wire        p_monitor_rxempty,
  
  output wire p_icap_clk,
// ICAP arbitration interface
  input  wire        p_cap_rel,
  input  wire        p_cap_gnt,
  output wire        p_cap_req
  
  );

  ///////////////////////////////////////////////////////////////////////////
  // Define local constants.
  ///////////////////////////////////////////////////////////////////////////

  localparam TCQ = 1;
  localparam COUNT_1SEC   = 25000000;
  localparam HB_COUNTER_WIDTH = LOGBASE2(COUNT_1SEC); 

  ///////////////////////////////////////////////////////////////////////////
  // Define local function.
  ///////////////////////////////////////////////////////////////////////////

  function integer LOGBASE2;
    input [31:0] val;
    integer width;
  begin
    width = val;
    for (LOGBASE2 = 0; width > 0; LOGBASE2 = LOGBASE2 + 1)
      width = width >> 1;
  end
  endfunction

  ///////////////////////////////////////////////////////////////////////////
  // Internal signals.
  ///////////////////////////////////////////////////////////////////////////

  wire        clk_ibufg;
  wire        icap_clk;

  (* mark_debug = "true" *) wire        cap_gnt;
  (* mark_debug = "true" *) wire        cap_req;
  (* mark_debug = "true" *) wire        cap_rel;


  (* mark_debug = "true" *) wire        status_heartbeat;
  (* mark_debug = "true" *) wire        status_initialization;
  (* mark_debug = "true" *) wire        status_observation;
  (* mark_debug = "true" *) wire        status_correction;
  (* mark_debug = "true" *) wire        status_classification;
  (* mark_debug = "true" *) wire        status_injection;
  (* mark_debug = "true" *) wire        status_diagnostic_scan;
  (* mark_debug = "true" *) wire        status_detect_only;
  (* mark_debug = "true" *) wire        status_essential;
  (* mark_debug = "true" *) wire        status_uncorrectable;

  (* mark_debug = "true" *) wire        command_busy;
  (* mark_debug = "true" *) wire [39:0] command_code;
  (* mark_debug = "true" *) wire        command_strobe;
  reg         command_strobe_delay = 1'b0;
  wire        command_strobe_pulse;

  (* mark_debug = "true" *) wire        aux_error_cr_ne;
  (* mark_debug = "true" *) wire        aux_error_cr_es;
  (* mark_debug = "true" *) wire        aux_error_uc;
  reg         aux_error_cr_ne_delay = 1'b0;
  reg         aux_error_cr_es_delay = 1'b0;
  reg         aux_error_uc_delay = 1'b0;
  wire        aux_error_cr_ne_pulse;
  wire        aux_error_cr_es_pulse;
  wire        aux_error_uc_pulse;

  //Status error signals
  wire heartbeat_valid;
  reg  [HB_COUNTER_WIDTH-1:0] heartbeat_cnt; 
  (* mark_debug = "true" *) reg heartbeat_timeout;
  (* mark_debug = "true" *) reg heartbeat_timeout_sticky;

  wire [3:0] status_sig; 
  (* mark_debug = "true" *)  reg status_irregular_sticky;
  (* mark_debug = "true" *)  reg status_halt;

  ///////////////////////////////////////////////////////////////////////////
  // Instantiate the input buffer for the clock
  ///////////////////////////////////////////////////////////////////////////
  IBUF example_ibuf (
    .I(clk),
    .O(clk_ibufg));

  ///////////////////////////////////////////////////////////////////////////
  // Instantiate the support wrapper layer, which includes the SEM 
  // controller, configuration primitives, and the IP helper blocks
  ///////////////////////////////////////////////////////////////////////////

  sem_ultra_support_wrapper example_support_wrapper (
    .clk (clk_ibufg),
    .status_heartbeat(status_heartbeat),
    .status_initialization(status_initialization),
    .status_observation(status_observation),
    .status_correction(status_correction),
    .status_classification(status_classification),
    .status_injection(status_injection),
    .status_diagnostic_scan(status_diagnostic_scan),
    .status_detect_only(status_detect_only), 
    .status_essential(status_essential),
    .status_uncorrectable(status_uncorrectable),
    .uart_tx(uart_tx),
    .uart_rx(uart_rx),
    //.p_monitor_txdata(p_monitor_txdata),
    //.p_monitor_txfull(p_monitor_txfull),
    //.p_monitor_rxdata(monitor_rxdata),
    //.p_monitor_rxempty(p_monitor_rxempty),
    .command_strobe(command_strobe_pulse),
    .command_busy(command_busy),
    .command_code(command_code),
    .icap_clk_out(icap_clk),
    .cap_rel(cap_rel),
    .cap_gnt(cap_gnt),
    .cap_req(cap_req),
    .aux_error_cr_ne(aux_error_cr_ne_pulse),
    .aux_error_cr_es(aux_error_cr_es_pulse),
    .aux_error_uc(aux_error_uc_pulse));

  ///////////////////////////////////////////////////////////////////////////
  // Heartbeat watchdog logic
  // Expects heartbeat toggles once every 1 second in the following states:
  // observation, detect only and diagnostic scan
  //////////////////////////////////////////////////////////////////////////
  assign heartbeat_valid  = (status_observation || status_diagnostic_scan || status_detect_only);

  always@(posedge icap_clk)
  begin
    if (heartbeat_valid == 1'b0)
      heartbeat_cnt <= 'd0;
    else
    begin
      if (status_heartbeat == 1'b1)
        heartbeat_cnt <= 'd0;
      else        
        heartbeat_cnt <= heartbeat_cnt + 1;
    end

    if (heartbeat_cnt > COUNT_1SEC)
    begin
      heartbeat_timeout <= 1'b1;
      heartbeat_timeout_sticky <= 1'b1 | heartbeat_timeout_sticky;
    end
    else
      heartbeat_timeout <= 1'b0;
      
  end 

  ///////////////////////////////////////////////////////////////////////////
  // Verify other behaviors of the status signals that indicate the
  // current controller state.
  // status_irregular_sticky - sticky signal that asserts if more than
  //                           one status signal is asserted in the  
  //                           same clock cycle
  // status_halt             - asserts when IP is halted (all status
  //                           signals are asserted)
  //////////////////////////////////////////////////////////////////////////
  assign status_sig = status_observation + status_diagnostic_scan + status_detect_only + status_initialization + status_correction + status_classification + status_injection;

  always@(posedge icap_clk)
  begin

    // Make status_irregular sticky
    if (status_sig > 1)
      status_irregular_sticky <= 1'b1 | status_irregular_sticky;

    status_halt <= (status_observation && status_diagnostic_scan && status_detect_only && status_initialization && status_correction && status_classification && status_injection);

  end  


  ///////////////////////////////////////////////////////////////////////////
  // Instantiate VIO to display status interface from the SEM controller
  ///////////////////////////////////////////////////////////////////////////

//  sem_ultra_vio_si14 example_vio_si14 (
//    .probe_in0({
//               status_heartbeat,
//               status_initialization,
//               status_observation,
//               status_correction,
//               status_classification,
//               status_injection,
//               status_diagnostic_scan,
//               status_detect_only,
//               status_essential,
//               status_uncorrectable,
//               status_halt,
//               status_irregular_sticky,
//               heartbeat_timeout_sticky,
//               heartbeat_timeout
//	       }),
//    .clk(icap_clk));


  ///////////////////////////////////////////////////////////////////////////
  // Instantiate VIO for the ICAP arbitration interface and auxiliary
  // error inputs
  ///////////////////////////////////////////////////////////////////////////

//  sem_ultra_vio_si1_so5 example_vio_si1_so5 (
//    .probe_in0(cap_req),    
//    .probe_out0({aux_error_uc,aux_error_cr_es,aux_error_cr_ne,cap_gnt,cap_rel}),
//    .clk(icap_clk));
  assign cap_gnt = p_cap_gnt; 
  assign cap_rel = p_cap_rel;
  assign p_cap_req = cap_req;  
    
  ///////////////////////////////////////////////////////////////////////////
  // Create a single-cycle pulse for each of the VIO aux error outputs. Limiting
  // the duration of the externally-sourced auxiliary error signals ensures 
  // that the IP reports the error a single time.
  ///////////////////////////////////////////////////////////////////////////
  
  always @(posedge icap_clk)
  begin
    aux_error_cr_ne_delay <= #TCQ aux_error_cr_ne;
    aux_error_cr_es_delay <= #TCQ aux_error_cr_es;
    aux_error_uc_delay <= #TCQ aux_error_uc;
  end

  assign aux_error_cr_ne_pulse = !aux_error_cr_ne && aux_error_cr_ne_delay;
  assign aux_error_cr_es_pulse = !aux_error_cr_es && aux_error_cr_es_delay;
  assign aux_error_uc_pulse = !aux_error_uc && aux_error_uc_delay;

  ///////////////////////////////////////////////////////////////////////////
  // Instantiate VIO for the command interface
  ///////////////////////////////////////////////////////////////////////////

//  sem_ultra_vio_si1_so41 example_vio_si1_so41 (
//    .probe_in0(command_busy),
//    .probe_out0({command_strobe,command_code}),
//    .clk(icap_clk));

  ///////////////////////////////////////////////////////////////////////////
  // Create a single-cycle pulse from the VIO command_strobe output to ensure a
  // single command is issued to the SEM controller.
  ///////////////////////////////////////////////////////////////////////////

  always @(posedge icap_clk)
  begin
    command_strobe_delay <= #TCQ command_strobe;
  end

  assign command_strobe_pulse = !command_strobe && command_strobe_delay;

  assign p_status_heartbeat = status_heartbeat; 
  assign p_status_initialization = status_initialization;
  assign p_status_observation = status_observation;
  assign p_status_correction = status_correction;
  assign p_status_classification = status_classification;
  assign p_status_injection = status_injection;
  assign p_status_diagnostic_scan = status_diagnostic_scan;
  assign p_status_detect_only = status_detect_only;  
  assign p_status_essential = status_essential;
  assign p_status_uncorrectable = status_uncorrectable;

  assign p_status_halt = status_halt;
  assign p_status_irregular_sticky = status_irregular_sticky;
  assign p_heartbeat_timeout_sticky = heartbeat_timeout_sticky;
  assign p_heartbeat_timeout = heartbeat_timeout;


  assign command_code = p_command_code;
  assign command_strobe = p_command_strobe;
  assign p_command_busy = command_busy;

  assign p_icap_clk = icap_clk;
  
endmodule

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
