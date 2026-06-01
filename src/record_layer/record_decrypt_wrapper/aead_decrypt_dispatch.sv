`timescale 1ns / 1ps

// ============================================================================
// aead_decrypt_dispatch.sv
// Dispatches encrypted records to AEAD decryption (AES-128-GCM)
// Input: encrypted record + authentication tag
// Output: plaintext record | Inner Content Type
// ============================================================================

import record_layer_pkg::*;

module aead_decrypt_dispatch (
    input  logic clk,
    input  logic rst_n,

    // Traffic keys (from key_schedule)
    input  traffic_key_t rx_key,        // Key, IV, sequence number
    input  logic         rx_key_valid,

    // Ciphertext record input
    input  logic [7:0]   ciphertext_byte,
    input  logic         ciphertext_valid,
    output logic         ciphertext_ready,

    // Authentication tag input
    input  logic [127:0] auth_tag_in,
    input  logic         auth_tag_valid,
    output logic         auth_tag_ready,

    // Plaintext output
    output logic [7:0]   plaintext_byte,
    output logic         plaintext_valid,
    input  logic         plaintext_ready,

    // Extracted inner content type (from padding removal)
    output logic [7:0]   inner_content_type,
    output logic         inner_ct_valid,
    input  logic         inner_ct_ready,

    // Error indication
    output logic         err_decrypt_failed,
    output logic         err_tag_verification_failed
);

    // ========================================================================
    // Decryption State Machine
    // ========================================================================
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        BUFFER_CT  = 3'b001,  // Buffer ciphertext
        GET_TAG    = 3'b010,  // Receive authentication tag
        DECRYPT    = 3'b011,  // Decrypt (would call GCM engine)
        VERIFY_TAG = 3'b100,  // Verify authentication tag
        OUTPUT_PT  = 3'b101,  // Output plaintext
        DONE       = 3'b110
    } decrypt_state_t;

    decrypt_state_t state_r, state_w;

    // Buffers for ciphertext and metadata
    logic [2047:0] ciphertext_buffer_r, ciphertext_buffer_w;  // Max 256 bytes
    logic [13:0]   ciphertext_length_r, ciphertext_length_w;
    logic [127:0]  auth_tag_r, auth_tag_w;
    logic [7:0]    inner_ct_r, inner_ct_w;
    logic          key_loaded_r, key_loaded_w;
    traffic_key_t  rx_key_r, rx_key_w;
    logic [7:0]    ciphertext_buffer_lsb;

    assign ciphertext_buffer_lsb = ciphertext_buffer_r[7:0];

    // ========================================================================
    // Sequential Logic
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r            <= IDLE;
            ciphertext_buffer_r<= '0;
            ciphertext_length_r<= '0;
            auth_tag_r         <= '0;
            inner_ct_r         <= '0;
            key_loaded_r       <= 1'b0;
            rx_key_r           <= '0;
        end else begin
            state_r            <= state_w;
            ciphertext_buffer_r<= ciphertext_buffer_w;
            ciphertext_length_r<= ciphertext_length_w;
            auth_tag_r         <= auth_tag_w;
            inner_ct_r         <= inner_ct_w;
            key_loaded_r       <= key_loaded_w;
            rx_key_r           <= rx_key_w;
        end
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always_comb begin
        state_w              = state_r;
        ciphertext_buffer_w  = ciphertext_buffer_r;
        ciphertext_length_w  = ciphertext_length_r;
        auth_tag_w           = auth_tag_r;
        inner_ct_w           = inner_ct_r;
        key_loaded_w         = key_loaded_r;
        rx_key_w             = rx_key_r;

        ciphertext_ready     = 1'b0;
        auth_tag_ready       = 1'b0;
        plaintext_valid      = 1'b0;
        plaintext_byte       = 8'h00;
        inner_ct_valid       = 1'b0;
        inner_content_type   = 8'h00;
        err_decrypt_failed   = 1'b0;
        err_tag_verification_failed = 1'b0;

        case (state_r)
            IDLE: begin
                if (rx_key_valid) begin
                    rx_key_w   = rx_key;
                    key_loaded_w = 1'b1;
                end

                if (key_loaded_r && ciphertext_valid) begin
                    state_w = BUFFER_CT;
                    ciphertext_buffer_w[7:0] = ciphertext_byte;
                    ciphertext_length_w = 14'h0001;
                    ciphertext_ready = 1'b1;
                end
            end

            BUFFER_CT: begin
                if (ciphertext_valid && ciphertext_length_r < MAX_RECORD_PLAINTEXT) begin
                    // Shift in new byte
                    ciphertext_buffer_w = (ciphertext_buffer_r << 8) | ciphertext_byte;
                    ciphertext_length_w = ciphertext_length_r + 14'h0001;
                    ciphertext_ready = 1'b1;
                end else if (auth_tag_valid) begin
                    // Got auth tag, ready to decrypt
                    auth_tag_w = auth_tag_in;
                    auth_tag_ready = 1'b1;
                    state_w = DECRYPT;
                end
            end

            DECRYPT: begin
                // Call to AES-128-GCM decryption engine (TBD)
                // For now: placeholder - in real implementation, this would:
                // 1. Call GCM_DECRYPT(key, nonce=IV XOR seq_num, AAD, ciphertext, tag)
                // 2. Output plaintext
                // 3. Set verify_tag signal
                
                state_w = VERIFY_TAG;
            end

            VERIFY_TAG: begin
                // Verify computed tag against received tag
                // If tags don't match: set err_tag_verification_failed
                // For now: assume tag is valid
                
                if (plaintext_ready) begin
                    state_w = OUTPUT_PT;
                end
            end

            OUTPUT_PT: begin
                // Output plaintext bytes
                if (plaintext_ready && ciphertext_length_r > 0) begin
                    plaintext_valid = 1'b1;
                    plaintext_byte = ciphertext_buffer_lsb;  // First decrypted byte
                    ciphertext_length_w = ciphertext_length_r - 14'h0001;
                end else begin
                    // Extract inner content type from last byte (padding removal)
                    inner_ct_valid = 1'b1;
                    inner_content_type = inner_ct_r;
                    
                    if (inner_ct_ready) begin
                        state_w = DONE;
                    end
                end
            end

            DONE: begin
                state_w = IDLE;
            end

            default: state_w = IDLE;
        endcase
    end

endmodule : aead_decrypt_dispatch
