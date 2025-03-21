`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Written by: Martin Tran
// 
// Create Date: 03/19/2025
// Design Name: 
// Module Name: sdram_cmd_sequencer
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


module sdram_cmd_sequencer(
    input logic clk,
    input logic reset_n,
    input logic cmd_req, // External request for cmd execution
    input logic [24:0] addr,  // Address: [24:12] row, [11:3] col, [2:1] bank
    input logic rw_mode, // read = 1, write = 0
    input logic [2:0] burst_len, // Burst length
    
    output logic [3:0] sdram_cmd,
    output logic [12:0] sdram_addr, // row/col address
    output logic [1:0] sdram_ba, // bank address
    output logic a10_ap, // Auto-precharge bit
    inout logic [15:0] sdram_dq // Bi-directional data bus 
    
    );
    
    // Extract addresses from SDRAM address (Table 2 from datasheet)
    logic [12:0] row_addr;
    logic [8:0] col_addr;
    logic [1:0] bank_addr;
    
    assign row_addr = addr[24:12]; // 13-bit row address
    assign col_addr = addr[11:3];  // 9-bit column address
    assign bank_addr= addr[2:1];   // 2-bit bank address
    assign a10_ap = addr[0];       // auto-precharge bit
    
    // SDRAM command encoding (Table 14: Truth Table)
    localparam CMD_NOP = 4'b0111; // No operation (CS#=0, RAS#=1, CAS#=1, WE#=1)
    localparam CMD_ACTIVE = 4'b0011; // Activate row (CS#=0, RAS#=0, CAS#=1, WE#=1)
    localparam CMD_READ = 4'b0101; // Read column (CS#=0, RAS#=1, CAS#=0, WE#=1)
    localparam CMD_WRITE = 4'b0100; // Write column (CS#=0, RAS#=1, CAS#=0, WE#=0)
    localparam CMD_PRECHARGE = 4'b0010; // Precharge row (CS#=0, RAS#=0, CAS#=1, WE#=0)
    localparam CMD_REFRESH = 4'b0001; // Auto-Refresh (CS#=0, RAS#=0, CAS#=0, WE#=1)
    localparam CMD_LOAD_MODE = 4'b0000; // Load mode register (CS#=0, RAS#=0, CAS#=0, WE#=0)
    
    typedef enum logic [1:0] {
        IDLE,
        ACTIVE,
        READ_WRITE,
        PRECHARGE
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
        // Next State Logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (cmd_req)
                    next_state = ACTIVE;
            end
            ACTIVE: begin
                next_state = READ_WRITE;
            end
            READ_WRITE: begin
                next_state = PRECHARGE;
            end
            PRECHARGE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output Logic: Generating SDRAM Commands
    always_comb begin
        sdram_cmd  = CMD_NOP;   // Default NOP
        sdram_addr = 13'b0;
        sdram_ba   = 2'b00;

        case (state)
            ACTIVE: begin
                sdram_cmd  = CMD_ACTIVE;
                sdram_addr = row_addr; // Send Row Address
                sdram_ba   = bank_addr; // Select Bank
            end
            READ_WRITE: begin
                sdram_cmd  = rw_mode ? CMD_READ : CMD_WRITE;
                sdram_addr = {4'b0000, col_addr}; // Column Address (Fixed!)
                sdram_ba   = bank_addr;
                a10_ap     = addr[0]; // Auto-precharge control
            end
            PRECHARGE: begin
                sdram_cmd  = CMD_PRECHARGE;
                sdram_addr = 13'b0010000000000; // Precharge all banks
            end
        endcase
    end
    
endmodule
