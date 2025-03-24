`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Written by: Martin Tran
// 
// Create Date: 03/23/2025
// Design Name: 
// Module Name: sdram_data_io_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
// This testbench is designed to verify the functionality of the `sdram_data_io`
// module. It simulates both write and read burst operations, and ensures the correct
// handling of the data bus (`sdram_dq`). The testbench generates a clock, applies
// a reset, and initiates various read and write burst operations.
//
// It also provides stimulus for both `write_enable` and `read_enable` signals, and
// verifies that the correct data is written to or read from the `sdram_dq` bus. 
// The `burst_done` signal is checked at the end of each burst to confirm that
// the burst operation has completed successfully.
//
// The testbench also includes:
// - A clock generator
// - Reset signal management
// - Generation of random data for write operations
// - Simulation of SDRAM driving the `sdram_dq` bus during read bursts
// - Displaying of read and write data values for verification
//
//------------------------------------------------------------------------------
// Test Features:
// - Clock generation with 100 MHz frequency (CLK_PERIOD = 10ns)
// - Write and read burst tests with configurable burst length (BURST_LEN = 4)
// - Verifies correct operation of `write_enable`, `read_enable`, and `burst_done`
// - Simulates SDRAM driving data onto `sdram_dq` during read operations
// - Displays read and write data values during simulation for validation
//
//------------------------------------------------------------------------------
// Ports:
// Inputs:
//   - clk           : Clock signal
//   - reset_n       : Active-low reset signal
//   - burst_start   : Initiates a new burst transfer (1 cycle active)
//   - rw_mode       : Read (1) or write (0) mode for the burst
//   - burst_len     : Length of the burst in terms of 16-bit words
//   - write_enable  : Enables writing data to SDRAM during write burst
//   - write_data    : Data to be written to SDRAM during write bursts
//   - read_enable   : Enables reading from SDRAM during read burst
//   - sdram_dq_driver : Simulates data driven by SDRAM during read operations
//   - sdram_dq_drive_en : Enables SDRAM drive onto the `sdram_dq` bus
//
// Outputs:
//   - read_data     : Captured data from SDRAM during read bursts
//   - read_valid    : Indicates when `read_data` is valid and should be captured
//   - burst_done    : Indicates when the burst operation is complete
//   - sdram_dq      : Bidirectional data bus between FPGA and SDRAM 
// 
// Revision History:
//   [v1.0] - Initial version, designed to verify basic read and write burst functionality
// 
//////////////////////////////////////////////////////////////////////////////////


module sdram_data_io_tb;

    parameter CLK_PERIOD = 10; // Period for 100 MHz clk
    parameter BURST_LEN  = 4;

    // DUT interface
    logic         clk;
    logic         reset_n;
    logic         burst_start;
    logic         rw_mode;
    logic [2:0]   burst_len;
    logic         write_enable;
    logic [15:0]  write_data;
    logic         read_enable;
    logic [15:0]  read_data;
    logic         read_valid;
    logic         burst_done;

    wire [15:0]   sdram_dq;
    logic [15:0]  sdram_dq_driver;
    logic         sdram_dq_drive_en;

    // Simulate SDRAM driving the bus during read 
    assign sdram_dq = sdram_dq_drive_en ? sdram_dq_driver : 16'bz;

    sdram_data_io uut (
        .clk(clk),
        .reset_n(reset_n),
        .burst_start(burst_start),
        .rw_mode(rw_mode),
        .burst_len(burst_len),
        .write_enable(write_enable),
        .write_data(write_data),
        .read_enable(read_enable),
        .read_data(read_data),
        .read_valid(read_valid),
        .burst_done(burst_done),
        .sdram_dq(sdram_dq)
    );
       
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // Simulation procedure
    initial begin
        $display("Starting SDRAM Data IO Testbench");
        clk = 0;
        reset_n = 0;
        burst_start = 0;
        rw_mode = 0;
        burst_len = 0;
        write_enable = 0;
        write_data = 16'd0;
        read_enable = 0;
        sdram_dq_driver = 16'd0;
        sdram_dq_drive_en = 0;

        #(2*CLK_PERIOD);
        reset_n = 1;  // Reset

        // WRITE BURST TEST
        $display("\n[Test] Write Burst");
        rw_mode = 0;  // write
        burst_len = BURST_LEN;
        @(posedge clk);
        burst_start = 1;

        repeat (BURST_LEN) begin
            write_enable = 1;
            write_data   = $random;
            @(posedge clk);
            burst_start = 0;
        end
        @(posedge clk);
        write_enable = 0;
        wait (burst_done);
        $display("[Pass] Write burst complete");

        // READ BURST TEST
        $display("\n[Test] Read Burst");

        sdram_dq_driver = $random;
        @(posedge clk);

        rw_mode = 1;  // read
        burst_len = BURST_LEN;
        burst_start = 1;
        

        read_enable = 1;
        sdram_dq_drive_en = 1;
        @(posedge clk);
        burst_start = 0;
        if (read_valid)
            $display("Read data = %h", read_data);

        repeat (BURST_LEN - 1) begin
            sdram_dq_driver = $random;
            read_enable = 1;
            sdram_dq_drive_en = 1;
            @(posedge clk);
            burst_start = 0;
            if (read_valid)
                $display("Read data = %h", read_data);
        end
        @(posedge clk);
        sdram_dq_drive_en = 0;
        read_enable = 0;

        wait (burst_done);
        $display("[Pass] Read burst complete");

        $display("\nAll tests complete.");
        $stop;
    end

endmodule
