-- (c) Copyright 1995-2023 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.
-- IP VLNV: xilinx.com:ip:sem_ultra:3.1
-- IP Revision: 24

-- The following code must appear in the VHDL architecture header.

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
COMPONENT sem_ultra
  PORT (
    status_heartbeat : OUT STD_LOGIC;
    status_initialization : OUT STD_LOGIC;
    status_observation : OUT STD_LOGIC;
    status_correction : OUT STD_LOGIC;
    status_classification : OUT STD_LOGIC;
    status_injection : OUT STD_LOGIC;
    status_essential : OUT STD_LOGIC;
    status_uncorrectable : OUT STD_LOGIC;
    status_diagnostic_scan : OUT STD_LOGIC;
    status_detect_only : OUT STD_LOGIC;
    monitor_txdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    monitor_txwrite : OUT STD_LOGIC;
    monitor_txfull : IN STD_LOGIC;
    monitor_rxdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    monitor_rxread : OUT STD_LOGIC;
    monitor_rxempty : IN STD_LOGIC;
    command_strobe : IN STD_LOGIC;
    command_busy : OUT STD_LOGIC;
    command_code : IN STD_LOGIC_VECTOR(39 DOWNTO 0);
    icap_clk : IN STD_LOGIC;
    cap_rel : IN STD_LOGIC;
    cap_gnt : IN STD_LOGIC;
    cap_req : OUT STD_LOGIC;
    aux_error_cr_ne : IN STD_LOGIC;
    aux_error_cr_es : IN STD_LOGIC;
    aux_error_uc : IN STD_LOGIC 
  );
END COMPONENT;
-- COMP_TAG_END ------ End COMPONENT Declaration ------------

-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.

------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
your_instance_name : sem_ultra
  PORT MAP (
    status_heartbeat => status_heartbeat,
    status_initialization => status_initialization,
    status_observation => status_observation,
    status_correction => status_correction,
    status_classification => status_classification,
    status_injection => status_injection,
    status_essential => status_essential,
    status_uncorrectable => status_uncorrectable,
    status_diagnostic_scan => status_diagnostic_scan,
    status_detect_only => status_detect_only,
    monitor_txdata => monitor_txdata,
    monitor_txwrite => monitor_txwrite,
    monitor_txfull => monitor_txfull,
    monitor_rxdata => monitor_rxdata,
    monitor_rxread => monitor_rxread,
    monitor_rxempty => monitor_rxempty,
    command_strobe => command_strobe,
    command_busy => command_busy,
    command_code => command_code,
    icap_clk => icap_clk,
    cap_rel => cap_rel,
    cap_gnt => cap_gnt,
    cap_req => cap_req,
    aux_error_cr_ne => aux_error_cr_ne,
    aux_error_cr_es => aux_error_cr_es,
    aux_error_uc => aux_error_uc
  );
-- INST_TAG_END ------ End INSTANTIATION Template ---------

-- You must compile the wrapper file sem_ultra.vhd when simulating
-- the core, sem_ultra. When compiling the wrapper file, be sure to
-- reference the VHDL simulation library.



