`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Written by: Martin Tran 
// 
// Create Date: 03/24/2025 
// Design Name: 
// Module Name: sdram_controller_tb
// Project Name: 
// Target Devices: CMOD A7-35T
// Tool Versions: 
// 
// Description: 
//   SystemVerilog testbench for the SDRAM controller module.
//   This testbench verifies correct behavior of burst READ and WRITE 
//   transactions with appropriate handling of SDRAM timing constraints 
//   (tRCD, tWR, tRP). It includes:
//     - Clock and reset generation
//     - Bidirectional `sdram_dq` emulation
//     - Tasks for performing burst read/write requests
//     - Simulation of SDRAM responses during read
//     - Live monitoring of signals using $monitor
//
// Test Flow:
//   1. Apply reset to DUT
//   2. Perform a WRITE burst of 4 words to a given address
//   3. Perform a READ burst of 4 words from the same address
//   4. Display output waveforms and signal activity for debugging
//
//////////////////////////////////////////////////////////////////////////////////

module sdram_controller_tb;

    parameter CLK_PERIOD = 10;

    logic clk;
    logic reset_n;

    logic req_valid;
    logic [24:0] req_addr;
    logic req_rw;
    logic [2:0] burst_len;
    logic [15:0] write_data;
    logic [15:0] read_data;
    logic read_valid;
    logic ready;

    logic [3:0] sdram_cmd;
    logic [12:0] sdram_addr;
    logic [1:0] sdram_ba;
    logic a10_ap;
    wire [15:0] sdram_dq;

    // Bi-directional data line emulation
    logic [15:0] sdram_dq_driver;
    logic sdram_dq_drive_en;
    assign sdram_dq = sdram_dq_drive_en ? sdram_dq_driver : 16'bz;

    sdram_controller dut (
        .clk(clk),
        .reset_n(reset_n),
        .req_valid(req_valid),
        .req_addr(req_addr),
        .req_rw(req_rw),
        .burst_len(burst_len),
        .write_data(write_data),
        .read_data(read_data),
        .read_valid(read_valid),
        .ready(ready),
        .sdram_cmd(sdram_cmd),
        .sdram_addr(sdram_addr),
        .sdram_ba(sdram_ba),
        .a10_ap(a10_ap),
        .sdram_dq(sdram_dq)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // reset
    task reset_dut();
        begin
            clk = 0;
            reset_n = 0;
            req_valid = 0;
            req_addr = 25'd0;
            req_rw = 0;
            burst_len = 3'd0;
            write_data = 16'd0;
            sdram_dq_driver = 16'd0;
            sdram_dq_drive_en = 0;
            @(posedge clk);
            @(posedge clk);
            reset_n = 1;
        end
    endtask

    // Write transaction
    task do_write(input [24:0] addr, input [2:0] len);
        begin
            wait (ready);
            req_valid = 1;
            req_rw = 0;
            req_addr = addr;
            burst_len = len;
            repeat (1) @(posedge clk);
            req_valid = 0;

            repeat (len) begin
                write_data = $random;
                @(posedge clk);
            end
        end
    endtask

    // Read transaction
    task do_read(input [24:0] addr, input [2:0] len);
        begin
            wait (ready);
            req_valid = 1;
            req_rw = 1;
            req_addr = addr;
            burst_len = len;
            repeat (1) @(posedge clk);
            req_valid = 0;

            repeat (len + 2) begin // +2 for latency
                sdram_dq_driver = $random;
                sdram_dq_drive_en = 1;
                @(posedge clk);
            end
            sdram_dq_drive_en = 0;
        end
    endtask

    // test
    initial begin
        $display("Starting SDRAM Controller Testbench");
        reset_dut();

        $display("[Test] WRITE Burst");
        do_write(25'h0A1234, 3'd4);
        repeat (5) @(posedge clk);

        $display("[Test] READ Burst");
        do_read(25'h0A1234, 3'd4);
        repeat (5) @(posedge clk);

        $display("Test complete.");
        $stop;
    end

    // Monitoring
    initial begin
        $monitor("T=%0t | CMD=%b ADDR=%h BA=%b A10=%b RW=%b REQ=%b RD_VALID=%b RD_DATA=%h",
                 $time, sdram_cmd, sdram_addr, sdram_ba, a10_ap, req_rw, req_valid, read_valid, read_data);
    end

endmodule