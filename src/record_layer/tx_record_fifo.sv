`timescale 1ns / 1ps

// ============================================================================
// tx_record_fifo.sv
// Synchronous FIFO for TX record buffering (session_controller → record_layer)
// Ready/Valid handshake on both sides
// ============================================================================

import record_layer_pkg::*;

module tx_record_fifo (
    input  logic clk,
    input  logic rst_n,

    // Write Port (from record_layer or TX path)
    input  logic                write_en,
    input  logic [31:0]         write_data,
    output logic                write_ready,       // FIFO not full
    output logic                write_almost_full, // FIFO >80% full

    // Read Port (to session_controller TX)
    input  logic                read_en,
    output logic [31:0]         read_data,
    output logic                read_valid,        // Data available
    output logic                read_almost_empty, // FIFO <20% full

    // Status (for debugging)
    output logic [FIFO_ADDR_WIDTH:0] fifo_count   // Number of entries in FIFO
);

    // ========================================================================
    // Internal Signals
    // ========================================================================
    logic [FIFO_ADDR_WIDTH-1:0] write_ptr_r, write_ptr_w;
    logic [FIFO_ADDR_WIDTH-1:0] read_ptr_r, read_ptr_w;
    logic [FIFO_ADDR_WIDTH:0]   write_ptr_gray_r, write_ptr_gray_w;
    logic [FIFO_ADDR_WIDTH:0]   read_ptr_gray_r, read_ptr_gray_w;
    
    logic [31:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [FIFO_ADDR_WIDTH:0] fifo_count_r, fifo_count_w;
    logic fifo_full, fifo_empty;

    // ========================================================================
    // FIFO Pointer Management
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_r <= '0;
            read_ptr_r  <= '0;
            fifo_count_r <= '0;
        end else begin
            write_ptr_r <= write_ptr_w;
            read_ptr_r  <= read_ptr_w;
            fifo_count_r <= fifo_count_w;
        end
    end

    // Next state logic for pointers
    always_comb begin
        write_ptr_w = write_ptr_r;
        read_ptr_w  = read_ptr_r;
        fifo_count_w = fifo_count_r;

        if (write_en && write_ready) begin
            write_ptr_w = write_ptr_r + 1'b1;
            fifo_count_w = fifo_count_w + 1'b1;
        end

        if (read_en && read_valid) begin
            read_ptr_w = read_ptr_r + 1'b1;
            fifo_count_w = fifo_count_w - 1'b1;
        end

        // Handle simultaneous read/write (count stays same)
        if ((write_en && write_ready) && (read_en && read_valid)) begin
            fifo_count_w = fifo_count_r;  // No net change
        end
    end

    // ========================================================================
    // FIFO Status Signals
    // ========================================================================
    assign fifo_full  = (fifo_count_r == FIFO_DEPTH);
    assign fifo_empty = (fifo_count_r == 0);
    assign fifo_count = fifo_count_r;

    assign write_ready       = ~fifo_full;
    assign write_almost_full = (fifo_count_r >= (FIFO_DEPTH * 5 / 8));  // >80% threshold

    assign read_valid        = ~fifo_empty;
    assign read_almost_empty = (fifo_count_r < (FIFO_DEPTH / 5));       // <20% threshold

    // ========================================================================
    // FIFO Memory Operations
    // ========================================================================
    always_ff @(posedge clk) begin
        if (write_en && write_ready) begin
            fifo_mem[write_ptr_r] <= write_data;
        end
    end

    assign read_data = fifo_mem[read_ptr_r];

endmodule : tx_record_fifo
