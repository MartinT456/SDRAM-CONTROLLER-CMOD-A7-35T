`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Writtem by: Martin Tran
// 
// Create Date: 03/08/2025 
// Design Name: 
// Module Name: sdram_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sdram_controller(
    input logic clk,
    input logic reset,
    input logic write_en,
    input logic read_en,
    input logic [23:0] addr,
    input logic [15:0] data_in,
    input logic [15:0] data_out,
    output logic data_valid,
    output logic busy,
    output logic sdram_clk,
    output logic sdram_clk_en,
    output logic sdram_cs,
    output logic sdram_ras,
    output logic sdram_cas,
    output logic sdram_write_en,
    output logic [12:0] sdram_addr,
    inout logic [15:0] sdram_data_bus   
    );
    
    typedef enum logic [3:0] {
    INIT,        // Initialize SDRAM
    IDLE,       // Waiting for read/write command
    ACTIVATE,  // Open row
    READ,       // Reading column data
    WRITE,      // Writing column data
    PRECHARGE,  // Close row
    REFRESH     // Perform refresh cycle
    } sdram_state_t;

    sdram_state_t state, next_state;
endmodule
