/////////////////////////////////////////////////////////////////////////////
//
//
//
/////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /
// \   \   \/    Core:          sem_ultra
//  \   \        Module:        simulation
//  /   /        Filename:      simulation.v
// /___/   /\    Purpose:       Simulation harness
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
// This module is the simulation harness.  Including the controller as part of 
// a larger simulation project is supported. However, SEM controller behaviors 
// can not be observed in simulation. Hardware-based evaluation is required.  
// During simulation, the controller is expected to halt in the initialization 
// state.
//
/////////////////////////////////////////////////////////////////////////////
//
// Port Definition: There are no top level ports.
//
/////////////////////////////////////////////////////////////////////////////
//
// Parameter and Localparam Definition:
//
// Name                          Type   Description
// ============================= ====== ====================================
// THP                           int    Sets the half period for the clock
//                                      generation process.
//
// TSC                           int    Number of simulation cycles to run.
//
/////////////////////////////////////////////////////////////////////////////
//
// Module Dependencies:
//
// simulation
// |
// \- sem_ultra_example_design
//
/////////////////////////////////////////////////////////////////////////////

`timescale 1 ps / 1 ps

/////////////////////////////////////////////////////////////////////////////
// Module
/////////////////////////////////////////////////////////////////////////////

module simulation;

  ///////////////////////////////////////////////////////////////////////////
  // Define local constants.
  ///////////////////////////////////////////////////////////////////////////

  localparam TSC = 100000;
  localparam THP = 4000;

  ///////////////////////////////////////////////////////////////////////////
  // Declare signals.
  ///////////////////////////////////////////////////////////////////////////

  reg  [31:0] simulation_cycles = 32'h00000000;

  reg         clk = 1'b0;

  wire        uart_tx;
  wire        uart_rx;


  ///////////////////////////////////////////////////////////////////////////
  // Instantiate the example design.
  ///////////////////////////////////////////////////////////////////////////

  sem_ultra_example_design simulation_example (
    .uart_tx(uart_tx),
    .uart_rx(uart_rx),
    .clk(clk));

  ///////////////////////////////////////////////////////////////////////////
  // Clock generation process.
  ///////////////////////////////////////////////////////////////////////////

  always
  begin
    #THP;
    clk <= 1'b0;
    #THP;
    clk <= 1'b1;
  end

  ///////////////////////////////////////////////////////////////////////////
  // Simulation cycle count process.
  ///////////////////////////////////////////////////////////////////////////

  always @(posedge clk)
  begin
    if (simulation_cycles == 32'h00000000)
    begin
      $display("NOTE: Simulation starting...");
    end
    if (simulation_cycles == TSC)
    begin
      $display("NOTE: Simulation ending...");
      $display("INFO: Test Completed Successfully");
      $stop;
    end
    simulation_cycles <= simulation_cycles + 32'h00000001;
    $display("INFO: Simulation advancing...");
  end

  ///////////////////////////////////////////////////////////////////////////
  // Input signal assignments.
  ///////////////////////////////////////////////////////////////////////////

  assign uart_rx = 1'b1;

  ///////////////////////////////////////////////////////////////////////////
  // Advisory statement.
  ///////////////////////////////////////////////////////////////////////////

  initial
  begin
    $display ("NOTE: Functional and timing simulation of designs that include");
    $display ("NOTE: this core is supported.  However, it is not possible to");
    $display ("NOTE: observe the core behaviors in simulation.  Evaluation in");
    $display ("NOTE: hardware is required.");
  end

  ///////////////////////////////////////////////////////////////////////////
  //
  ///////////////////////////////////////////////////////////////////////////

endmodule

/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
