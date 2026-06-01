`timescale 1ns / 1ps

// ============================================================================
// handshake_secret_deriver.sv
// Derives the handshake secret from ECDHE shared secret
// State B: handshake_secret = HKDF-Extract(early_secret, ecdhe_shared_secret)
// ============================================================================

import key_schedule_pkg::*;

module handshake_secret_deriver (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] early_secret,          // Salt from State A
    input  logic [255:0] ecdhe_shared_secret,   // IKM from x25519
    output logic [255:0] handshake_secret,
    output logic valid_out
);

    hkdf_extract u_extract (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(valid_in),
        .salt    (early_secret),
        .ikm     (ecdhe_shared_secret),
        .prk     (handshake_secret),
        .valid_out(valid_out)
    );

endmodule : handshake_secret_deriver

// ============================================================================
// master_secret_deriver.sv
// Derives the master secret from handshake secret
// State D: First computes derived_secret = HKDF-Expand(handshake_secret, "derived", "")
//          Then: master_secret = HKDF-Extract(derived_secret, IKM=0)
// ============================================================================

module master_secret_deriver (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] handshake_secret,      // Input handshake secret
    output logic [255:0] master_secret,
    output logic valid_out
);

    // Stage 1: Compute derived_secret using HKDF-Expand with "derived" label
    logic [255:0] derived_secret;
    logic derived_valid;

    derive_secret_intermediate u_derive (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .secret_in (handshake_secret),
        .derived_secret(derived_secret),
        .valid_out (derived_valid)
    );

    // Stage 2: Extract with IKM=0 to produce master_secret
    hkdf_extract u_extract (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(derived_valid),
        .salt    (derived_secret),
        .ikm     (256'd0),                      // IKM = 0
        .prk     (master_secret),
        .valid_out(valid_out)
    );

endmodule : master_secret_deriver
