`timescale 1ns / 1ps

// ============================================================================
// aead_encrypt_dispatch.sv
// Dispatches plaintext records to AEAD encryption (AES-128-GCM)
// Input: plaintext record | Inner Content Type
// Output: encrypted record with authentication tag
// ============================================================================

import record_layer_pkg::*;

module aead_encrypt_dispatch (
    input  logic clk,
    input  logic rst_n,

    // Traffic keys (from key_schedule)
    input  traffic_key_t tx_key,        // Key, IV, sequence number
    input  logic         tx_key_valid,

    // Plaintext record input
    input  logic [7:0]   plaintext_byte,
    input  logic         plaintext_valid,
    output logic         plaintext_ready,

    // Inner content type (for padding)
    input  logic [7:0]   inner_content_type,
    input  logic         inner_ct_valid,
    output logic         inner_ct_ready,

    // Encrypted output with tag
    output logic [7:0]   ciphertext_byte,
    output logic         ciphertext_valid,
    input  logic         ciphertext_ready,

    output logic [127:0] auth_tag_out,
    output logic         auth_tag_valid,
    input  logic         auth_tag_ready,

    // Error indication
    output logic         err_encrypt_failed
);

    // ========================================================================
    // Encryption State Machine
    // ========================================================================
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        BUFFER_PT  = 3'b001,  // Buffer plaintext
        ENCRYPT    = 3'b010,  // Encrypt (would call GCM engine)
        TAG_GEN    = 3'b011,  // Generate authentication tag
        OUTPUT_CT  = 3'b100,  // Output ciphertext
        DONE       = 3'b101
    } encrypt_state_t;

    encrypt_state_t state_r, state_w;

    // Buffers for plaintext and metadata
    logic [2047:0] plaintext_buffer_r, plaintext_buffer_w;  // Max 256 bytes
    logic [13:0]   plaintext_length_r, plaintext_length_w;
    logic [7:0]    inner_ct_r, inner_ct_w;
    logic          key_loaded_r, key_loaded_w;
    traffic_key_t  tx_key_r, tx_key_w;
    logic [7:0]    plaintext_buffer_lsb;

    assign plaintext_buffer_lsb = plaintext_buffer_r[7:0];

    // ========================================================================
    // Sequential Logic
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r            <= IDLE;
            plaintext_buffer_r <= '0;
            plaintext_length_r <= '0;
            inner_ct_r         <= '0;
            key_loaded_r       <= 1'b0;
            tx_key_r           <= '0;
        end else begin
            state_r            <= state_w;
            plaintext_buffer_r <= plaintext_buffer_w;
            plaintext_length_r <= plaintext_length_w;
            inner_ct_r         <= inner_ct_w;
            key_loaded_r       <= key_loaded_w;
            tx_key_r           <= tx_key_w;
        end
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always_comb begin
        state_w              = state_r;
        plaintext_buffer_w   = plaintext_buffer_r;
        plaintext_length_w   = plaintext_length_r;
        inner_ct_w           = inner_ct_r;
        key_loaded_w         = key_loaded_r;
        tx_key_w             = tx_key_r;

        plaintext_ready      = 1'b0;
        inner_ct_ready       = 1'b0;
        ciphertext_valid     = 1'b0;
        ciphertext_byte      = 8'h00;
        auth_tag_valid       = 1'b0;
        auth_tag_out         = 128'h00000000000000000000000000000000;
        err_encrypt_failed   = 1'b0;

        case (state_r)
            IDLE: begin
                if (tx_key_valid) begin
                    tx_key_w   = tx_key;
                    key_loaded_w = 1'b1;
                end

                if (key_loaded_r && plaintext_valid) begin
                    state_w = BUFFER_PT;
                    plaintext_buffer_w[7:0] = plaintext_byte;
                    plaintext_length_w = 14'h0001;
                    plaintext_ready = 1'b1;
                end
            end

            BUFFER_PT: begin
                if (plaintext_valid && plaintext_length_r < MAX_RECORD_PLAINTEXT) begin
                    // Shift in new byte
                    plaintext_buffer_w = (plaintext_buffer_r << 8) | plaintext_byte;
                    plaintext_length_w = plaintext_length_r + 14'h0001;
                    plaintext_ready = 1'b1;
                end else if (inner_ct_valid) begin
                    // Got inner content type, ready to encrypt
                    inner_ct_w = inner_content_type;
                    inner_ct_ready = 1'b1;
                    state_w = ENCRYPT;
                end
            end

            ENCRYPT: begin
                // Call to AES-128-GCM encryption engine (TBD)
                // For now: placeholder - in real implementation, this would:
                // 1. Add inner content type byte to plaintext
                // 2. Call GCM_ENCRYPT(key, nonce=IV XOR seq_num, AAD, plaintext+ICT)
                // 3. Output ciphertext + tag
                
                // Placeholder: just forward plaintext as ciphertext
                if (ciphertext_ready) begin
                    state_w = TAG_GEN;
                end
            end

            TAG_GEN: begin
                // GCM tag generation happens here
                // This is done by the GCM engine
                auth_tag_out = 128'h00000000000000000000000000000000;  // Placeholder
                auth_tag_valid = 1'b1;
                
                if (auth_tag_ready) begin
                    state_w = DONE;
                end
            end

            OUTPUT_CT: begin
                // Output ciphertext bytes
                if (ciphertext_ready && plaintext_length_r > 0) begin
                    ciphertext_valid = 1'b1;
                    ciphertext_byte = plaintext_buffer_lsb;  // First encrypted byte
                    plaintext_length_w = plaintext_length_r - 14'h0001;
                end else begin
                    state_w = DONE;
                end
            end

            DONE: begin
                state_w = IDLE;
            end

            default: state_w = IDLE;
        endcase
    end

endmodule : aead_encrypt_dispatch
