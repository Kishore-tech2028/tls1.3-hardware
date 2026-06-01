`timescale 1ns / 1ps

// ============================================================================
// record_header_writer.sv
// Encodes TLS record header: type(1) | version(2) | length(2)
// RFC 8446: Creates 5-byte header for each TLS record
// ============================================================================

import record_layer_pkg::*;

module record_header_writer (
    input  logic clk,
    input  logic rst_n,

    // Control signals
    input  logic [7:0]  record_type_in,
    input  logic [15:0] version_in,
    input  logic [13:0] payload_length_in,
    input  logic        start_write,
    output logic        write_complete,

    // Output header bytes (ready to send to FIFO)
    output logic [7:0]  header_byte,
    output logic        header_byte_valid,
    input  logic        header_byte_ready
);

    // ========================================================================
    // Header Generation State Machine
    // ========================================================================
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        WRITE_TYPE = 3'b001,
        WRITE_VER1 = 3'b010,
        WRITE_VER2 = 3'b011,
        WRITE_LEN1 = 3'b100,
        WRITE_LEN2 = 3'b101,
        DONE       = 3'b110
    } write_state_t;

    write_state_t state_r, state_w;
    logic [7:0]  type_r, type_w;
    logic [15:0] version_r, version_w;
    logic [13:0] length_r, length_w;

    // ========================================================================
    // Sequential Logic
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r   <= IDLE;
            type_r    <= '0;
            version_r <= '0;
            length_r  <= '0;
        end else begin
            state_r   <= state_w;
            type_r    <= type_w;
            version_r <= version_w;
            length_r  <= length_w;
        end
    end

    // ========================================================================
    // Next State Logic and Output Generation
    // ========================================================================
    always_comb begin
        state_w              = state_r;
        type_w               = type_r;
        version_w            = version_r;
        length_w             = length_r;
        header_byte          = 8'h00;
        header_byte_valid    = 1'b0;
        write_complete       = 1'b0;

        case (state_r)
            IDLE: begin
                if (start_write) begin
                    type_w   = record_type_in;
                    version_w = version_in;
                    length_w  = payload_length_in;
                    state_w   = WRITE_TYPE;
                end
            end

            WRITE_TYPE: begin
                header_byte = type_r;
                header_byte_valid = 1'b1;
                if (header_byte_ready) begin
                    state_w = WRITE_VER1;
                end
            end

            WRITE_VER1: begin
                header_byte = version_r[15:8];  // MSB of version
                header_byte_valid = 1'b1;
                if (header_byte_ready) begin
                    state_w = WRITE_VER2;
                end
            end

            WRITE_VER2: begin
                header_byte = version_r[7:0];   // LSB of version
                header_byte_valid = 1'b1;
                if (header_byte_ready) begin
                    state_w = WRITE_LEN1;
                end
            end

            WRITE_LEN1: begin
                header_byte = {2'b00, length_r[13:8]};  // MSB of 14-bit length
                header_byte_valid = 1'b1;
                if (header_byte_ready) begin
                    state_w = WRITE_LEN2;
                end
            end

            WRITE_LEN2: begin
                header_byte = length_r[7:0];    // LSB of length
                header_byte_valid = 1'b1;
                if (header_byte_ready) begin
                    state_w = DONE;
                end
            end

            DONE: begin
                write_complete = 1'b1;
                state_w = IDLE;
            end

            default: state_w = IDLE;
        endcase
    end

endmodule : record_header_writer
