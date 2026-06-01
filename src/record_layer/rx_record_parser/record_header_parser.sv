`timescale 1ns / 1ps

// ============================================================================
// record_header_parser.sv
// Extracts type, version, and length from 5-byte TLS record header
// RFC 8446: Header is [type(1) | version(2) | length(2)]
// ============================================================================

import record_layer_pkg::*;

module record_header_parser (
    input  logic clk,
    input  logic rst_n,

    // Input stream (byte-by-byte from RX FIFO)
    input  logic [7:0]  byte_in,
    input  logic        byte_valid,
    output logic        byte_ready,

    // Output: Complete record header (valid after 5 bytes)
    output logic [7:0]  record_type_out,
    output logic [15:0] version_out,
    output logic [13:0] length_out,
    output logic        header_valid,
    input  logic        header_ready
);

    // ========================================================================
    // State Machine for Header Parsing
    // ========================================================================
    typedef enum logic [2:0] {
        PARSE_TYPE    = 3'b000,
        PARSE_VER_MSB = 3'b001,
        PARSE_VER_LSB = 3'b010,
        PARSE_LEN_MSB = 3'b011,
        PARSE_LEN_LSB = 3'b100,
        HEADER_DONE   = 3'b101
    } parse_state_t;

    parse_state_t state_r, state_w;
    logic [7:0]  type_r, type_w;
    logic [15:0] version_r, version_w;
    logic [13:0] length_r, length_w;
    logic        header_valid_r, header_valid_w;

    // ========================================================================
    // Sequential Logic: State and Data Registers
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r       <= PARSE_TYPE;
            type_r        <= '0;
            version_r     <= '0;
            length_r      <= '0;
            header_valid_r<= 1'b0;
        end else begin
            state_r       <= state_w;
            type_r        <= type_w;
            version_r     <= version_w;
            length_r      <= length_w;
            header_valid_r<= header_valid_w;
        end
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always_comb begin
        state_w        = state_r;
        type_w         = type_r;
        version_w      = version_r;
        length_w       = length_r;
        header_valid_w = 1'b0;
        byte_ready     = 1'b0;

        case (state_r)
            PARSE_TYPE: begin
                if (byte_valid) begin
                    type_w   = byte_in;
                    state_w  = PARSE_VER_MSB;
                    byte_ready = 1'b1;
                end
            end

            PARSE_VER_MSB: begin
                if (byte_valid) begin
                    version_w[15:8] = byte_in;
                    state_w = PARSE_VER_LSB;
                    byte_ready = 1'b1;
                end
            end

            PARSE_VER_LSB: begin
                if (byte_valid) begin
                    version_w[7:0] = byte_in;
                    state_w = PARSE_LEN_MSB;
                    byte_ready = 1'b1;
                end
            end

            PARSE_LEN_MSB: begin
                if (byte_valid) begin
                    length_w[13:8] = byte_in[5:0];  // Only 14 bits: byte[5:0] + next byte[7:0]
                    state_w = PARSE_LEN_LSB;
                    byte_ready = 1'b1;
                end
            end

            PARSE_LEN_LSB: begin
                if (byte_valid) begin
                    length_w[7:0] = byte_in;
                    state_w = HEADER_DONE;
                    byte_ready = 1'b1;
                end
            end

            HEADER_DONE: begin
                // Wait for downstream to accept header
                if (header_ready) begin
                    header_valid_w = 1'b1;
                    state_w = PARSE_TYPE;  // Reset for next record
                end else begin
                    header_valid_w = 1'b1;  // Hold valid until accepted
                end
            end

            default: state_w = PARSE_TYPE;
        endcase
    end

    // ========================================================================
    // Output Assignment
    // ========================================================================
    assign record_type_out = type_r;
    assign version_out     = version_r;
    assign length_out      = length_r;
    assign header_valid    = header_valid_r;

endmodule : record_header_parser
