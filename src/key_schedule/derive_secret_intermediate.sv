`timescale 1ns / 1ps

// ============================================================================
// derive_secret_intermediate.sv
// Computes the intermediate derived secret using HKDF-Expand with "derived" label
// RFC 8446 § 7.1: derived_secret = HKDF-Expand-Label(secret, "derived", "", Hash.length)
// ============================================================================

import key_schedule_pkg::*;

module derive_secret_intermediate (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] secret_in,             // Input secret
    output logic [255:0] derived_secret,        // Intermediate "derived" value
    output logic valid_out
);

    hkdf_expand_label u_expand (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .prk            (secret_in),
        .context        (128'd0),               // Empty context for derived
        .label_id       (8'd4),                 // "derived" label ID
        .desired_length (16'd256),              // Output = 256 bits (32 bytes)
        .okm            (derived_secret),
        .valid_out      (valid_out)
    );

endmodule : derive_secret_intermediate
