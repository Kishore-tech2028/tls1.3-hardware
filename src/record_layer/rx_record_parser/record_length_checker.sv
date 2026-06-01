`timescale 1ns / 1ps

// ============================================================================
// record_length_checker.sv
// Validates record payload length per RFC 8446
// Max encrypted record: 2^14 + 1 = 16,385 bytes (includes 1-byte type + 16-byte tag)
// Max plaintext: 2^14 = 16,384 bytes
// ============================================================================

import record_layer_pkg::*;

module record_length_checker (
    input  logic clk,
    input  logic rst_n,

    // Incoming record metadata
    input  logic [7:0]  record_type_in,
    input  logic [15:0] version_in,
    input  logic [13:0] length_in,
    input  logic        record_valid_in,
    output logic        record_ready_out,

    // Outgoing (validated) record metadata
    output logic [7:0]  record_type_out,
    output logic [15:0] version_out,
    output logic [13:0] length_out,
    output logic        record_valid_out,
    input  logic        record_ready_in,

    // Error indication
    output logic        err_length_exceeded,
    output logic [15:0] err_length_value      // Actual length that was too large
);

    // ========================================================================
    // Validation Logic
    // ========================================================================
    logic length_valid;

    // RFC 8446: Encrypted record max = 2^14 + 1 = 16,385 bytes
    // Plaintex max = 2^14 = 16,384 bytes
    always_comb begin
        err_length_exceeded = 1'b0;
        err_length_value    = '0;
        length_valid        = 1'b1;

        // Check if length exceeds maximum (16,384 bytes)
        if (length_in > MAX_RECORD_PLAINTEXT) begin
            err_length_exceeded = 1'b1;
            err_length_value    = {2'b00, length_in};  // Extend to 16 bits
            length_valid        = 1'b0;
        end

        // Special case: zero-length records are allowed (for keep-alive)
        // but typically used only for empty APPLICATION_DATA
        if (length_in == 14'h0) begin
            length_valid = 1'b1;  // Allow zero-length records
        end
    end

    // ========================================================================
    // Pass-through with validation
    // ========================================================================
    assign record_valid_out  = record_valid_in && length_valid;
    assign record_ready_out  = record_ready_in;

    assign record_type_out   = record_type_in;
    assign version_out       = version_in;
    assign length_out        = length_in;

endmodule : record_length_checker
