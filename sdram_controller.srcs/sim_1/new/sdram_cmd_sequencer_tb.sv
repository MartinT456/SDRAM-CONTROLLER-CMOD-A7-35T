`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Written by: Martin Tran
// 
// Create Date: 03/22/2025 
// Design Name: 
// Module Name: sdram_cmd_sequencer_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// This testbench verifies the functionality of the `sdram_cmd_sequencer`
// module, which is responsible for generating valid SDRAM command sequences
// (ACTIVE → READ/WRITE → PRECHARGE) based on memory request inputs.
//
// The testbench simulates a variety of read and write transactions to ensure:
//   - Correct SDRAM command outputs (sdram_cmd)
//   - Proper decoding of row, column, and bank addresses
//   - Correct handling of the auto-precharge bit (A10)
//   - Sequential state transitions within the sequencer FSM
//
// Test Features:
// - Generates a 100 MHz clock
// - Asserts and deasserts `cmd_req` to simulate command requests
// - Issues four types of memory transactions:
//     1. Basic WRITE to arbitrary address
//     2. Basic READ from arbitrary address
//     3. WRITE with auto-precharge enabled (A10 = 1)
//     4. READ with auto-precharge enabled (A10 = 1)
// - Uses a reusable task `transaction()` to encapsulate command triggering
// - Continuously monitors output signals for debugging and verification
//
//------------------------------------------------------------------------------
// Notes:
// - This testbench is functional/behavioral only and does not include timing checks.
// - No mock SDRAM model or data path is instantiated-this testbench verifies
//   only the command generation logic.
//
//------------------------------------------------------------------------------
// Revision History:
//   [v1.0] - Initial version
// 
//////////////////////////////////////////////////////////////////////////////////


module sdram_cmd_sequencer_tb;

    // Inputs
    logic        clk;
    logic        reset_n;
    logic        cmd_req;
    logic        rw_mode;
    logic [24:0] addr;
    logic [2:0]  burst_len;
    
    // Outputs
    logic [3:0]  sdram_cmd;
    logic [12:0] sdram_addr;
    logic [1:0]  sdram_ba;
    logic        a10_ap;
    wire [15:0]  sdram_dq;
    
    sdram_cmd_sequencer uut (
        .clk(clk),
        .reset_n(reset_n),
        .cmd_req(cmd_req),
        .addr(addr),
        .rw_mode(rw_mode),
        .burst_len(burst_len),
        .sdram_cmd(sdram_cmd),
        .sdram_addr(sdram_addr),
        .sdram_ba(sdram_ba),
        .a10_ap(a10_ap),
        .sdram_dq(sdram_dq)
    );

    // Clock generator: 100 MHz
    always #5 clk = ~clk;
    
    task automatic transaction(input logic [24:0] address, input logic rw);
        begin
            @(negedge clk); // wait for negedge
            addr = address; // assert signals to start transaction
            rw_mode = rw;
            cmd_req = 1;
            @(negedge clk);
            cmd_req = 0;
        end
    endtask
        
              // Simulation process
      initial begin
        $display("Starting SDRAM CMD Sequencer testbench...");
        clk = 0;
        reset_n = 0;
        cmd_req = 0;
        rw_mode = 0;
        addr = 25'd0;
        burst_len = 3'b000;
    
        // Apply reset
        repeat (2) @(negedge clk);
        reset_n = 1;
        @(negedge clk);
    
        // WRITE operation
        $display("Test 1: WRITE transaction");
        transaction(25'h123456, 0); // write
        repeat (5) @(negedge clk);
    
        // READ operation
        $display("Test 2: READ transaction");
        transaction(25'h0A5A2B, 1); // read
        repeat (5) @(negedge clk);
    
        // WRITE with Auto-Precharge
        $display("Test 3: WRITE with A10 = 1");
        transaction(25'h18F34D | 25'h0000001, 0); // set bit 0 = A10 = 1
        repeat (5) @(negedge clk);
    
        // READ with Auto-Precharge
        $display("Test 4: READ with A10 = 1");
        transaction(25'h1F9B20 | 25'h0000001, 1);
        repeat (5) @(negedge clk);
    
        $display("All tests completed.");
        $stop;
      end
    
      // Monitoring outputs
      initial begin
        $monitor("T=%0t | CMD=%b | ADDR=%h | BA=%b | A10=%b | RW=%0d | REQ=%0d", 
                 $time, sdram_cmd, sdram_addr, sdram_ba, a10_ap, rw_mode, cmd_req);
      end
endmodule
