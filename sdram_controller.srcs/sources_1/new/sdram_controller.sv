`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Written by: Martin Tran
// 
// Create Date: 03/24/2025
// Design Name: 
// Module Name: sdram_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// This module implements a synchronous SDRAM controller that interfaces with
// Micron's 16M x 16 SDRAM (MT48LC16M16A2P-6A:G). It coordinates high-level 
// memory requests and ensures SDRAM timing constraints are met, including:
//   - tRCD: Row to column delay
//   - tWR: Write recovery time
//   - tRP: Row precharge time
//
// The controller integrates the lower-level command and data modules:
//   - `sdram_cmd_sequencer`: Issues ACTIVATE, READ, WRITE, and PRECHARGE
//   - `sdram_data_io`: Handles burst-mode data transfer on the bidirectional bus
//
// Features:
// - FSM-based command sequencing with built-in timing delay handling
// - Handles burst-mode READ and WRITE operations
// - Supports configurable burst length
// - Issues ACTIVATE → READ/WRITE → PRECHARGE command sequences
// - Waits appropriate cycles between commands to satisfy SDRAM timing
//
// Ports:
// Inputs:
//   clk           : System clock
//   reset_n       : Active-low reset
//   req_valid     : High-level request trigger (read/write)
//   req_addr      : SDRAM address to access (row, column, bank)
//   req_rw        : Read (1) or write (0) mode
//   burst_len     : Number of 16-bit transfers
//   write_data    : Input data to be written to SDRAM
//
// Outputs:
//   read_data     : Output data read from SDRAM
//   read_valid    : Indicates when read_data is valid
//   ready         : High when controller is ready for new request
//
// SDRAM Interface:
//   sdram_cmd     : Command encoding (mapped to CS#, RAS#, CAS#, WE#)
//   sdram_addr    : Address lines shared between row/column/mode
//   sdram_ba      : Bank address lines
//   a10_ap        : A10 auto-precharge signal
//   sdram_dq      : Bidirectional 16-bit data bus
//
// Notes:
// - CAS latency (`tCAS`) is not yet implemented in this version.
// - Mode Register Set (MRS) configuration is also not yet included.
// - Timings (tRCD, tWR, tRP) are implemented using simple cycle counters.
//
// Revision History:
//   [v1.0] - Initial FSM-based SDRAM controller with timing counters
// 
//////////////////////////////////////////////////////////////////////////////////


module sdram_controller(
    input  logic clk,
    input  logic reset_n,

    // External interface
    input  logic req_valid, // Request to read or write
    input  logic [24:0] req_addr, // SDRAM address (row/col/bank)
    input  logic req_rw, // 1 = read, 0 = write
    input  logic [2:0] burst_len, // Number of 16-bit words
    input  logic [15:0] write_data,  // Data to write
    output logic [15:0] read_data, // Output from read
    output logic  read_valid, // Valid read data
    output logic  ready,  // Controller ready for new request

    // SDRAM interface
    output logic [3:0] sdram_cmd,
    output logic [12:0] sdram_addr,
    output logic [1:0] sdram_ba,
    output logic a10_ap,
    inout  logic [15:0] sdram_dq,
    
    // Test signals
    output logic test_burst_start
);

    // Internal signals
    logic burst_start, write_enable, read_enable, burst_done, cmd_req;
    logic [3:0]  op_mode;
    logic [2:0] trcd_counter, twr_counter, trp_counter;
    
    // Test signals for simulation
    always_comb begin
        test_burst_start = burst_start;
    end

    // FSM states
    typedef enum logic [3:0] {
        IDLE,
        ACTIVATE,
        WAIT_TRCD,
        READ_BURST,
        READ_PROCESS,
        WRITE_BURST,
        WRITE_PROCESS,
        WAIT_TWR,
        PRECHARGE,
        WAIT_TRP
    } state_t;

    state_t state, next_state;

    // FSM state transition
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
        end
        else
            state <= next_state;
    end

    // SDRAM command encoding (Table 14: Truth Table)
    localparam CMD_NOP = 4'b0111; // No operation (CS#=0, RAS#=1, CAS#=1, WE#=1)
    localparam CMD_ACTIVE = 4'b0011; // Activate row (CS#=0, RAS#=0, CAS#=1, WE#=1)
    localparam CMD_READ = 4'b0101; // Read column (CS#=0, RAS#=1, CAS#=0, WE#=1)
    localparam CMD_WRITE = 4'b0100; // Write column (CS#=0, RAS#=1, CAS#=0, WE#=0)
    localparam CMD_PRECHARGE = 4'b0010; // Precharge row (CS#=0, RAS#=0, CAS#=1, WE#=0)
    localparam CMD_REFRESH = 4'b0001; // Auto-Refresh (CS#=0, RAS#=0, CAS#=0, WE#=1)
    localparam CMD_LOAD_MODE = 4'b0000; // Load mode register (CS#=0, RAS#=0, CAS#=0, WE#=0)
    
    // op_mode logic
    always_comb begin
        case (state)
            ACTIVATE: op_mode = CMD_ACTIVE;
            READ_BURST: op_mode = CMD_READ;
            WRITE_BURST: op_mode = CMD_WRITE;
            PRECHARGE: op_mode = CMD_PRECHARGE;
            default: op_mode = CMD_NOP;           
            
        endcase
    end
    
    
    // FSM logic
    always_comb begin
        // Send a request to update cmd, will default to NOP 
        assign cmd_req = ((state == ACTIVATE) ||
                  (state == READ_BURST) ||
                  (state == WRITE_BURST) ||
                  (state == PRECHARGE));
                  
        next_state = state;
        case (state)
            IDLE: begin 
                if (req_valid) next_state = ACTIVATE;              
            end
            ACTIVATE: begin
                next_state = WAIT_TRCD;
            end
            WAIT_TRCD: begin
                if (trcd_counter == 0) next_state = req_rw ? READ_BURST : WRITE_BURST;
            end
            READ_BURST: begin 
                next_state = PRECHARGE;
            end
            READ_PROCESS: begin
                if (burst_done) next_state = PRECHARGE;
            end
            WRITE_BURST: begin
                next_state = WRITE_PROCESS;
            end
            WRITE_PROCESS: begin
                if (burst_done) next_state = WAIT_TWR;
            end
            WAIT_TWR: begin
                if (twr_counter == 0) next_state = PRECHARGE;
            end
            PRECHARGE: begin
                next_state = WAIT_TRP;
            end
            WAIT_TRP: begin
                if (trp_counter == 0)  next_state = IDLE;
            end
        endcase
    end
    
    // Control logic and counters
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            burst_start <= 0;
            write_enable <= 0;
            read_enable <= 0;
            trcd_counter <= 0;
            twr_counter <= 0;
            trp_counter <= 0;
        end else begin
            burst_start <= 0;
            write_enable <= 0;
            read_enable <= 0;

            // Note: Timing parameters found on Table 12 from datasheet
            case (state)
                ACTIVATE: begin
                    burst_start  <= 0;
                    trcd_counter <= 3'd2; // tRCD = 18 ns -> 2 clock cycles at 100MHz
                end
                WAIT_TRCD: begin // Row to column delay
                    if (trcd_counter > 0)
                        trcd_counter <= trcd_counter - 1;
                    end
                READ_BURST: begin
                    burst_start  <= 1; // start only once
                    read_enable  <= 1;
                end
                READ_PROCESS: begin
                    burst_start <= 0;
                    read_enable  <= 1;
                    // TODO: implement CAS latency
                end
                WRITE_BURST: begin
                    burst_start  <= 1; // start only once
                    write_enable <= 1;

                end
                WRITE_PROCESS: begin
                    burst_start <= 0;
                    write_enable <= 1;
                    if (burst_done)  
                        twr_counter <= 3'd2; // tWR = 1 CLK + 6ns -> 2 clk cycles                    
                end
                WAIT_TWR: begin // Write recovery time, allow SDRAM to finish writing
                    if (twr_counter > 0)
                        twr_counter <= twr_counter - 1;
                end
                PRECHARGE: begin
                    trp_counter <= 3'd2; // tRP = 18ns -> 2 clk cycles
                end
                WAIT_TRP: begin // Row precharge time, time needed to close before opening a new one
                    if (trp_counter > 0)
                        trp_counter <= trp_counter - 1;
                end
            endcase
        end
    end

    // Outputs
    assign ready = (state == IDLE);
    assign read_valid = read_enable && !req_rw ? 0 : 1;
    assign read_data = sdram_dq; // could be buffered externally, maybe implement FIFO later??

    // Instantiate submodules
    sdram_cmd_sequencer cmd_seq (
        .clk(clk),
        .reset_n(reset_n),
        .cmd_req(cmd_req),
        .addr(req_addr),
        .rw_mode(req_rw),
        .burst_len(burst_len),
        .op_mode(op_mode),
        .sdram_cmd(sdram_cmd),
        .sdram_addr(sdram_addr),
        .sdram_ba(sdram_ba),
        .a10_ap(a10_ap),
        .sdram_dq(sdram_dq)
    );

    sdram_data_io data_io (
        .clk(clk),
        .reset_n(reset_n),
        .burst_start(burst_start),
        .rw_mode(req_rw),
        .burst_len(burst_len),
        .write_enable(write_enable),
        .write_data(write_data),
        .read_enable(read_enable),
        .read_data(read_data),
        .read_valid(read_valid),
        .burst_done(burst_done),
        .sdram_dq(sdram_dq)
    );

endmodule
