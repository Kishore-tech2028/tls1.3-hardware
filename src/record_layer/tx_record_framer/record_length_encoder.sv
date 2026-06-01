`timescale 1ns / 1ps

// ============================================================================
// record_length_encoder.sv
// Encodes 14-bit record length into 2-byte big-endian format
// Used by TX path to frame outgoing records
// ============================================================================

import record_layer_pkg::*;

module record_length_encoder (
    input  logic clk,
    input  logic rst_n,

    // Length input (14 bits)
    input  logic [13:0] length_in,
    input  logic        encode_en,
    output logic        encode_ready,

    // Encoded output (2 bytes, MSB first)
    output logic [7:0]  byte_out,
    output logic        byte_valid,
    input  logic        byte_ready
);

    // ========================================================================
    // Encoder State Machine
    // ========================================================================
    typedef enum logic {
        IDLE    = 1'b0,
        SENDING = 1'b1
    } encode_state_t;

    encode_state_t state_r, state_w;
    logic [13:0] length_r, length_w;
    logic [1:0]  byte_count_r, byte_count_w;  // 0=MSB, 1=LSB, 2=done

    // ========================================================================
    // Sequential Logic
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r      <= IDLE;
            length_r     <= '0;
            byte_count_r <= 2'b00;
        end else begin
            state_r      <= state_w;
            length_r     <= length_w;
            byte_count_r <= byte_count_w;
        end
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always_comb begin
        state_w       = state_r;
        length_w      = length_r;
        byte_count_w  = byte_count_r;
        byte_out      = 8'h00;
        byte_valid    = 1'b0;
        encode_ready  = 1'b0;

        case (state_r)
            IDLE: begin
                encode_ready = 1'b1;
                if (encode_en) begin
                    length_w   = length_in;
                    byte_count_w = 2'b00;
                    state_w    = SENDING;
                end
            end

            SENDING: begin
                case (byte_count_r)
                    2'b00: begin
                        // Send MSB of 14-bit length (padded to 8 bits)
                        byte_out = {2'b00, length_r[13:8]};
                        byte_valid = 1'b1;
                        if (byte_ready) begin
                            byte_count_w = 2'b01;
                        end
                    end

                    2'b01: begin
                        // Send LSB of length
                        byte_out = length_r[7:0];
                        byte_valid = 1'b1;
                        if (byte_ready) begin
                            byte_count_w = 2'b10;
                        end
                    end

                    2'b10: begin
                        // Encoding complete
                        state_w = IDLE;
                    end

                    default: begin
                        byte_count_w = 2'b00;
                        state_w = IDLE;
                    end
                endcase
            end

            default: state_w = IDLE;
        endcase
    end

endmodule : record_length_encoder
