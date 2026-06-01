`timescale 1ns / 1ps

// ============================================================================
// client_hs_traffic_deriver.sv
// Derives client handshake traffic secret
// Computes: client_hs_traffic_secret = HKDF-Expand-Label(handshake_secret, "c hs traffic", transcript_hash)
// ============================================================================

import key_schedule_pkg::*;

module client_hs_traffic_deriver (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] handshake_secret,      // Input handshake secret
    input  logic [255:0] transcript_hash,       // Transcript hash snapshot
    output logic [255:0] client_hs_traffic_secret,
    output logic valid_out
);

    hkdf_expand_label u_expand (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .prk            (handshake_secret),
        .context        (transcript_hash[127:0]),  // Lower 128 bits as context
        .label_id       (8'd0),                 // "c hs traffic" label
        .desired_length (16'd256),              // 256-bit output
        .okm            (client_hs_traffic_secret),
        .valid_out      (valid_out)
    );

endmodule : client_hs_traffic_deriver

// ============================================================================
// server_hs_traffic_deriver.sv
// Derives server handshake traffic secret
// Computes: server_hs_traffic_secret = HKDF-Expand-Label(handshake_secret, "s hs traffic", transcript_hash)
// ============================================================================

module server_hs_traffic_deriver (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] handshake_secret,      // Input handshake secret
    input  logic [255:0] transcript_hash,       // Transcript hash snapshot
    output logic [255:0] server_hs_traffic_secret,
    output logic valid_out
);

    hkdf_expand_label u_expand (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .prk            (handshake_secret),
        .context        (transcript_hash[127:0]),  // Lower 128 bits as context
        .label_id       (8'd1),                 // "s hs traffic" label
        .desired_length (16'd256),              // 256-bit output
        .okm            (server_hs_traffic_secret),
        .valid_out      (valid_out)
    );

endmodule : server_hs_traffic_deriver

// ============================================================================
// client_ap_traffic_deriver.sv
// Derives client application traffic secret
// Computes: client_ap_traffic_secret = HKDF-Expand-Label(master_secret, "c ap traffic", transcript_hash)
// ============================================================================

module client_ap_traffic_deriver (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] master_secret,         // Input master secret
    input  logic [255:0] transcript_hash,       // Final transcript hash
    output logic [255:0] client_ap_traffic_secret,
    output logic valid_out
);

    hkdf_expand_label u_expand (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .prk            (master_secret),
        .context        (transcript_hash[127:0]),  // Lower 128 bits as context
        .label_id       (8'd2),                 // "c ap traffic" label
        .desired_length (16'd256),              // 256-bit output
        .okm            (client_ap_traffic_secret),
        .valid_out      (valid_out)
    );

endmodule : client_ap_traffic_deriver

// ============================================================================
// server_ap_traffic_deriver.sv
// Derives server application traffic secret
// Computes: server_ap_traffic_secret = HKDF-Expand-Label(master_secret, "s ap traffic", transcript_hash)
// ============================================================================

module server_ap_traffic_deriver (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] master_secret,         // Input master secret
    input  logic [255:0] transcript_hash,       // Final transcript hash
    output logic [255:0] server_ap_traffic_secret,
    output logic valid_out
);

    hkdf_expand_label u_expand (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .prk            (master_secret),
        .context        (transcript_hash[127:0]),  // Lower 128 bits as context
        .label_id       (8'd3),                 // "s ap traffic" label
        .desired_length (16'd256),              // 256-bit output
        .okm            (server_ap_traffic_secret),
        .valid_out      (valid_out)
    );

endmodule : server_ap_traffic_deriver
