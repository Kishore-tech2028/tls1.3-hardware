`timescale 1ns / 1ps

// ============================================================================
// record_encrypt_wrapper.sv
// Encryption wrapper: coordinates plaintext record → inner_ct appending → AEAD encryption
// ============================================================================

import record_layer_pkg::*;

module record_encrypt_wrapper (
    input  logic clk,
    input  logic rst_n,

    // Plaintext record input (from TX framer)
    input  logic [7:0]  plaintext_byte,
    input  logic        plaintext_valid,
    output logic        plaintext_ready,

    // Record metadata
    input  logic [7:0]  record_type,
    input  logic        record_type_valid,

    // Traffic key (from key_schedule)
    input  traffic_key_t tx_key,
    input  logic         tx_key_valid,

    // Encrypted output (with tag)
    output logic [7:0]  ciphertext_byte,
    output logic        ciphertext_valid,
    input  logic        ciphertext_ready,

    output logic [127:0] auth_tag,
    output logic         auth_tag_valid,
    input  logic         auth_tag_ready,

    // Error indication
    output logic         err_encrypt
);

    // ========================================================================
    // Internal Signal Routing
    // ========================================================================
    logic [7:0]  plaintext_ict_byte;
    logic        plaintext_ict_valid;
    logic        plaintext_ict_ready;

    logic [7:0]  ciphertext_dispatch_byte;
    logic        ciphertext_dispatch_valid;
    logic        ciphertext_dispatch_ready;

    logic [127:0] auth_tag_dispatch;
    logic         auth_tag_dispatch_valid;
    logic         auth_tag_dispatch_ready;

    // ========================================================================
    // Step 1: Inner Content Type Appender
    // ========================================================================
    inner_content_type_appender appender_inst (
        .clk                  (clk),
        .rst_n                (rst_n),
        .plaintext_byte       (plaintext_byte),
        .plaintext_valid      (plaintext_valid),
        .plaintext_ready      (plaintext_ready),
        .inner_content_type   (record_type),
        .append_en            (record_type_valid),
        .plaintext_ict_byte   (plaintext_ict_byte),
        .plaintext_ict_valid  (plaintext_ict_valid),
        .plaintext_ict_ready  (plaintext_ict_ready)
    );

    // ========================================================================
    // Step 2: AEAD Encryption Dispatch
    // ========================================================================
    aead_encrypt_dispatch encrypt_inst (
        .clk                (clk),
        .rst_n              (rst_n),
        .tx_key             (tx_key),
        .tx_key_valid       (tx_key_valid),
        .plaintext_byte     (plaintext_ict_byte),
        .plaintext_valid    (plaintext_ict_valid),
        .plaintext_ready    (plaintext_ict_ready),
        .inner_content_type (record_type),
        .inner_ct_valid     (1'b1),
        .inner_ct_ready     (),
        .ciphertext_byte    (ciphertext_dispatch_byte),
        .ciphertext_valid   (ciphertext_dispatch_valid),
        .ciphertext_ready   (ciphertext_dispatch_ready),
        .auth_tag_out       (auth_tag_dispatch),
        .auth_tag_valid     (auth_tag_dispatch_valid),
        .auth_tag_ready     (auth_tag_dispatch_ready),
        .err_encrypt_failed (err_encrypt)
    );

    // ========================================================================
    // Pass-through to Output
    // ========================================================================
    assign ciphertext_byte    = ciphertext_dispatch_byte;
    assign ciphertext_valid   = ciphertext_dispatch_valid;
    assign ciphertext_dispatch_ready = ciphertext_ready;

    assign auth_tag           = auth_tag_dispatch;
    assign auth_tag_valid     = auth_tag_dispatch_valid;
    assign auth_tag_dispatch_ready = auth_tag_ready;

endmodule : record_encrypt_wrapper
