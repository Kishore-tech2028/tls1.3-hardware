`timescale 1ns / 1ps

// ============================================================================
// write_key_deriver.sv
// Derives AES-128 write key from traffic secret
// Computes: write_key = HKDF-Expand-Label(secret, "key", "", 128)
// ============================================================================

import key_schedule_pkg::*;

module write_key_deriver (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] traffic_secret,        // Input traffic secret
    output logic [127:0] write_key,             // 128-bit AES write key
    output logic valid_out
);

    logic [255:0] expanded_key;
    logic expand_valid;

    hkdf_expand_label u_key_expand (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .prk            (traffic_secret),
        .hkdf_context   (128'd0),               // Empty context
        .label_id       (8'd4),                 // "key" label
        .desired_length (16'd128),              // 128-bit key
        .okm            (expanded_key),
        .valid_out      (expand_valid)
    );

    // Extract only the lower 128 bits
    assign write_key = expanded_key[127:0];
    assign valid_out = expand_valid;

endmodule : write_key_deriver

// ============================================================================
// write_iv_deriver.sv
// Derives 96-bit IV from traffic secret
// Computes: write_iv = HKDF-Expand-Label(secret, "iv", "", 96)
// ============================================================================

module write_iv_deriver (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] traffic_secret,        // Input traffic secret
    output logic [95:0]  write_iv,              // 96-bit IV for GCM
    output logic valid_out
);

    logic [255:0] expanded_iv;
    logic expand_valid;

    hkdf_expand_label u_iv_expand (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .prk            (traffic_secret),
        .hkdf_context   (128'd0),               // Empty context
        .label_id       (8'd5),                 // "iv" label
        .desired_length (16'd96),               // 96-bit IV
        .okm            (expanded_iv),
        .valid_out      (expand_valid)
    );

    // Extract only the lower 96 bits
    assign write_iv = expanded_iv[95:0];
    assign valid_out = expand_valid;

endmodule : write_iv_deriver
