`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Written by: Martin Tran
// 
// Create Date: 03/23/2025
// Design Name: 
// Module Name: sdram_data_io
// Project Name: 
// Target Devices: 
// Tool Versions: 
// 
//
// File:        sdram_data_io.sv
// Description: SDRAM Data I/O Module for MT48LC16M16A2P-6A:G
//
// Purpose:
// This module manages the bidirectional 16-bit data bus (`sdram_dq`) between 
// the FPGA and an external SDRAM chip. It supports both read and write 
// operations and includes burst transfer support with clean tri-state control.
//
// This module does not implement CAS latency or buffering internally. Instead, 
// it expects the top-level SDRAM controller to handle CAS latency timing and 
// optionally integrate external FIFO buffers.
//
// Features:
// - Tri-state control of `sdram_dq` during write operations
// - Read data capture during read bursts
// - Burst counter to track the number of words transferred
// - `burst_done` signal to indicate completion of data phase
// - `read_valid` signal to mark valid output data during read
//
// Ports:
// Inputs:
//   clk           : System clock
//   reset_n       : Active-low reset
//   burst_start   : Start signal for a new burst transfer
//   rw_mode       : 1 = Read, 0 = Write
//   burst_len     : Length of burst in words (1-8)
//   write_enable  : Enables data drive during write burst
//   write_data    : 16-bit data to be driven during writes
//   read_enable   : Enables capturing of SDRAM read data
//
// Outputs:
//   read_data     : 16-bit output from SDRAM during read bursts
//   read_valid    : Indicates when `read_data` contains valid data
//   burst_done    : High when current burst completes
//
// Inouts:
//   sdram_dq      : 16-bit bidirectional SDRAM data bus
//
//------------------------------------------------------------------------------
// Notes:
// - This module assumes CAS latency is handled externally.
// - Designed for integration into a larger SDRAM controller.
// - Safe tri-state behavior avoids bus contention with external SDRAM.
//
//------------------------------------------------------------------------------
// Revision History:
//   [v1.0] - Initial version with burst support and tri-state control
//   [v1.1] - Updated burst counter logic to address decrementing counter bug when burst_counter == 1 
//==============================================================================
// 
//////////////////////////////////////////////////////////////////////////////////


module sdram_data_io(
    input  logic clk,
    input  logic reset_n,
    input  logic burst_start,  // Start of a burst
    input  logic rw_mode,      // 1 = read, 0 = write
    input  logic [2:0] burst_len,    // Number of 16-bit words in burst

    // Write interface
    input  logic write_enable, // Drive data onto sdram_dq
    input  logic [15:0] write_data,   // Data to be written to SDRAM

    // Read interface
    input  logic read_enable,   // Allow capturing data from SDRAM
    output logic [15:0] read_data,     // Output read data
    output logic read_valid,   // Indicates when read_data is valid
    output logic burst_done,    // Asserted when burst completes
    inout  logic [15:0] sdram_dq
);

    logic [2:0] burst_counter;
    logic dq_drive;  // 1 when writing

    // tri-state buffer control for writes
    //assign sdram_dq = (dq_drive && !rw_mode && write_enable) ? write_data : 16'bz;
    assign sdram_dq = (!rw_mode && write_enable) ? write_data : 16'bz;

    // Logic for reading SDRAM
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            read_data <= 16'd0;
            read_valid <= 1'b0;
        end else begin
            if (read_enable && rw_mode && burst_counter != 0) begin
                read_data <= sdram_dq;
                read_valid <= 1'b1;
            end else begin
                read_valid <= 1'b0;
            end
        end
    end

    // Burst counter and drive control
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            burst_counter <= 3'd0;
            dq_drive <= 1'b0;
        end else if (burst_start) begin
            burst_counter <= burst_len - 1;
            dq_drive <= !rw_mode; // Enable drive only for write
        end else if (burst_counter > 0) begin
            if ((rw_mode && read_enable) || (!rw_mode && write_enable)) begin
                burst_counter <= burst_counter - 1;
                if (burst_counter == 1) begin
                    dq_drive <= 1'b0; // Turn off drive on final cycle
                end
            end
        end else if (burst_counter == 0 && (read_enable || write_enable)) begin
            burst_done <= 1;    
        end else begin
            burst_done <= 0;
        end
    end

    //assign burst_done = (burst_counter == 0);

endmodule
