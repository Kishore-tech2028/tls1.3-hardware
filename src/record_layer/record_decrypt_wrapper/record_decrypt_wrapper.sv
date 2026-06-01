`timescale 1ns / 1ps

// ============================================================================
// record_decrypt_wrapper.sv
// Decryption wrapper: coordinates AEAD decryption → inner_ct extraction → plaintext delivery
// ============================================================================

import record_layer_pkg::*;

module record_decrypt_wrapper (
    input  logic clk,
    input  logic rst_n,

    // Encrypted record input (from RX parser)
    input  logic [7:0]  ciphertext_byte,
    input  logic        ciphertext_valid,
    output logic        ciphertext_ready,

    // Authentication tag input
    input  logic [127:0] auth_tag,
    input  logic         auth_tag_valid,
    output logic         auth_tag_ready,

    // Traffic key (from key_schedule)
    input  traffic_key_t rx_key,
    input  logic         rx_key_valid,

    // Plaintext output (with ICT extracted)
    output logic [7:0]  plaintext_byte,
    output logic        plaintext_valid,
    input  logic        plaintext_ready,

    // Extracted inner content type
    output logic [7:0]  inner_content_type,
    output logic        inner_ct_valid,
    input  logic        inner_ct_ready,

    // Error indication
    output logic         err_decrypt,
    output logic         err_tag_verify
);

    // ========================================================================
    // Internal Signal Routing
    // ========================================================================
    logic [7:0]  plaintext_dispatch_byte;
    logic        plaintext_dispatch_valid;
    logic        plaintext_dispatch_ready;

    logic [7:0]  plaintext_extracted_byte;
    logic        plaintext_extracted_valid;
    logic        plaintext_extracted_ready;

    logic [7:0]  extracted_ict;
    logic        extracted_ict_valid;
    logic        extracted_ict_ready;

    // ========================================================================
    // Step 1: AEAD Decryption Dispatch
    // ========================================================================
    aead_decrypt_dispatch decrypt_inst (
        .clk                         (clk),
        .rst_n                       (rst_n),
        .rx_key                      (rx_key),
        .rx_key_valid                (rx_key_valid),
        .ciphertext_byte             (ciphertext_byte),
        .ciphertext_valid            (ciphertext_valid),
        .ciphertext_ready            (ciphertext_ready),
        .auth_tag_in                 (auth_tag),
        .auth_tag_valid              (auth_tag_valid),
        .auth_tag_ready              (auth_tag_ready),
        .plaintext_byte              (plaintext_dispatch_byte),
        .plaintext_valid             (plaintext_dispatch_valid),
        .plaintext_ready             (plaintext_dispatch_ready),
        .inner_content_type          (extracted_ict),
        .inner_ct_valid              (extracted_ict_valid),
        .inner_ct_ready              (extracted_ict_ready),
        .err_decrypt_failed          (err_decrypt),
        .err_tag_verification_failed (err_tag_verify)
    );

    // ========================================================================
    // Step 2: Inner Content Type Extractor
    // ========================================================================
    inner_content_type_extractor extractor_inst (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .plaintext_byte           (plaintext_dispatch_byte),
        .plaintext_valid          (plaintext_dispatch_valid),
        .plaintext_ready          (plaintext_dispatch_ready),
        .plaintext_clean_byte     (plaintext_extracted_byte),
        .plaintext_clean_valid    (plaintext_extracted_valid),
        .plaintext_clean_ready    (plaintext_extracted_ready),
        .inner_content_type       (inner_content_type),
        .inner_ct_valid           (inner_ct_valid),
        .inner_ct_ready           (inner_ct_ready),
        .err_invalid_content_type ()
    );

    // ========================================================================
    // Pass-through to Output
    // ========================================================================
    assign plaintext_byte     = plaintext_extracted_byte;
    assign plaintext_valid    = plaintext_extracted_valid;
    assign plaintext_extracted_ready = plaintext_ready;

endmodule : record_decrypt_wrapper
