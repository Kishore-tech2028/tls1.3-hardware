`timescale 1ns / 1ps

// ============================================================================
// inner_content_type_appender.sv
// Appends inner content type byte to plaintext before AEAD encryption
// RFC 8446 §5.2: Ensures recipient knows true content type after decryption
// ============================================================================

import record_layer_pkg::*;

module inner_content_type_appender (
    input  logic clk,
    input  logic rst_n,

    // Plaintext input
    input  logic [7:0]  plaintext_byte,
    input  logic        plaintext_valid,
    output logic        plaintext_ready,

    // Inner content type to append
    input  logic [7:0]  inner_content_type,
    input  logic        append_en,

    // Plaintext + ICT output
    output logic [7:0]  plaintext_ict_byte,
    output logic        plaintext_ict_valid,
    input  logic        plaintext_ict_ready
);

    // ========================================================================
    // Append State Machine
    // ========================================================================
    typedef enum logic {
        PASS_THROUGH = 1'b0,
        APPEND_ICT   = 1'b1
    } append_state_t;

    append_state_t state_r, state_w;
    logic [7:0] ict_r, ict_w;

    // ========================================================================
    // Sequential Logic
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r <= PASS_THROUGH;
            ict_r   <= '0;
        end else begin
            state_r <= state_w;
            ict_r   <= ict_w;
        end
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always_comb begin
        state_w              = state_r;
        ict_w                = ict_r;
        plaintext_ready      = 1'b0;
        plaintext_ict_byte   = plaintext_byte;
        plaintext_ict_valid  = plaintext_valid;

        if (append_en) begin
            ict_w = inner_content_type;
            state_w = APPEND_ICT;
        end

        case (state_r)
            PASS_THROUGH: begin
                if (plaintext_valid && plaintext_ict_ready) begin
                    plaintext_ready = 1'b1;
                end
            end

            APPEND_ICT: begin
                // Pass through plaintext bytes, then append ICT
                if (plaintext_valid && plaintext_ict_ready) begin
                    plaintext_ict_byte = plaintext_byte;
                    plaintext_ict_valid = 1'b1;
                    plaintext_ready = 1'b1;
                end else if (!plaintext_valid) begin
                    // All plaintext consumed, now append ICT
                    plaintext_ict_byte = ict_r;
                    plaintext_ict_valid = 1'b1;
                    if (plaintext_ict_ready) begin
                        state_w = PASS_THROUGH;
                    end
                end
            end
        endcase
    end

endmodule : inner_content_type_appender
