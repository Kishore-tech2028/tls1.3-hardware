`timescale 1ns / 1ps

// ============================================================================
// inner_content_type_extractor.sv
// Extracts inner content type from decrypted plaintext
// RFC 8446 §5.2: Last byte of plaintext is the true content type
// Removes padding and type byte before delivering to downstream handler
// ============================================================================

import record_layer_pkg::*;

module inner_content_type_extractor (
    input  logic clk,
    input  logic rst_n,

    // Decrypted plaintext input
    input  logic [7:0]  plaintext_byte,
    input  logic        plaintext_valid,
    output logic        plaintext_ready,

    // Plaintext without ICT (and padding removed)
    output logic [7:0]  plaintext_clean_byte,
    output logic        plaintext_clean_valid,
    input  logic        plaintext_clean_ready,

    // Extracted inner content type
    output logic [7:0]  inner_content_type,
    output logic        inner_ct_valid,
    input  logic        inner_ct_ready,

    // Error indication
    output logic        err_invalid_content_type
);

    // ========================================================================
    // Extraction State Machine
    // ========================================================================
    typedef enum logic [1:0] {
        BUFFER_PT = 2'b00,   // Buffer plaintext
        EXTRACT_ICT = 2'b01, // Extract ICT from last byte
        OUTPUT_PT = 2'b10    // Output cleaned plaintext
    } extract_state_t;

    extract_state_t state_r, state_w;

    // Buffers
    logic [2047:0] plaintext_buffer_r, plaintext_buffer_w;  // Max 256 bytes
    logic [13:0]   plaintext_length_r, plaintext_length_w;
    logic [7:0]    extracted_ict_r, extracted_ict_w;

    // ========================================================================
    // Sequential Logic
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r            <= BUFFER_PT;
            plaintext_buffer_r <= '0;
            plaintext_length_r <= '0;
            extracted_ict_r    <= '0;
        end else begin
            state_r            <= state_w;
            plaintext_buffer_r <= plaintext_buffer_w;
            plaintext_length_r <= plaintext_length_w;
            extracted_ict_r    <= extracted_ict_w;
        end
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always_comb begin
        state_w              = state_r;
        plaintext_buffer_w   = plaintext_buffer_r;
        plaintext_length_w   = plaintext_length_r;
        extracted_ict_w      = extracted_ict_r;

        plaintext_ready      = 1'b0;
        plaintext_clean_byte = plaintext_byte;
        plaintext_clean_valid= 1'b0;
        inner_content_type   = extracted_ict_r;
        inner_ct_valid       = 1'b0;
        err_invalid_content_type = 1'b0;

        case (state_r)
            BUFFER_PT: begin
                if (plaintext_valid && plaintext_length_r < MAX_RECORD_PLAINTEXT) begin
                    // Buffer incoming plaintext
                    plaintext_buffer_w = {plaintext_buffer_r[2039:0], plaintext_byte};
                    plaintext_length_w = plaintext_length_r + 14'h0001;
                    plaintext_ready = 1'b1;
                end else if (!plaintext_valid && plaintext_length_r > 0) begin
                    // All plaintext received, extract ICT from last byte
                    extracted_ict_w = plaintext_buffer_r[7:0];  // Last byte
                    state_w = EXTRACT_ICT;
                end
            end

            EXTRACT_ICT: begin
                // Validate extracted ICT
                case (extracted_ict_r)
                    8'h15: begin  // ALERT
                        inner_ct_valid = 1'b1;
                    end
                    8'h16: begin  // HANDSHAKE
                        inner_ct_valid = 1'b1;
                    end
                    8'h17: begin  // APPLICATION_DATA
                        inner_ct_valid = 1'b1;
                    end
                    default: begin
                        err_invalid_content_type = 1'b1;
                        inner_ct_valid = 1'b0;
                    end
                endcase

                if (inner_ct_ready) begin
                    state_w = OUTPUT_PT;
                end
            end

            OUTPUT_PT: begin
                // Output plaintext bytes (without last ICT byte)
                if (plaintext_clean_ready && plaintext_length_r > 1) begin
                    plaintext_clean_byte = plaintext_buffer_r[15:8];  // Shift out ICT byte
                    plaintext_clean_valid = 1'b1;
                    plaintext_length_w = plaintext_length_r - 14'h0001;
                end else begin
                    state_w = BUFFER_PT;
                end
            end

            default: state_w = BUFFER_PT;
        endcase
    end

endmodule : inner_content_type_extractor
