`timescale 1ns / 1ps

// ============================================================================
// key_schedule_top.sv
// Top-level Key Schedule Module for TLS 1.3
// Integrates FSM and all cryptographic derivation modules
// ============================================================================

import key_schedule_pkg::*;

module key_schedule_top (
    input  logic clk,
    input  logic rst_n,

    // ====== Handshake Triggers ======
    input  logic hardware_reset,                // Initiate early phase
    input  logic ecdhe_complete,                // x25519 shared secret ready
    input  logic [255:0] ecdhe_shared_secret,   // Raw ECDHE secret
    input  logic transcript_update,             // Transcript hash has changed
    input  logic [255:0] transcript_hash,       // Current transcript hash
    input  logic handshake_flight_done,         // Handshake flight complete
    input  logic verify_finished_pass,          // Finished message verified
    input  logic psk_enable,                    // Enable PSK mode (not yet implemented)

    // ====== Secret Outputs (for upper layers) ======
    output logic [255:0] early_secret_o,
    output logic [255:0] handshake_secret_o,
    output logic [255:0] master_secret_o,
    output logic [255:0] client_hs_traffic_secret_o,
    output logic [255:0] server_hs_traffic_secret_o,
    output logic [255:0] client_ap_traffic_secret_o,
    output logic [255:0] server_ap_traffic_secret_o,

    // ====== Traffic Key Outputs (for record layer) ======
    output traffic_key_pair_t client_hs_key_pair_o,
    output traffic_key_pair_t server_hs_key_pair_o,
    output traffic_key_pair_t client_ap_key_pair_o,
    output traffic_key_pair_t server_ap_key_pair_o,

    // ====== Status Signals ======
    output logic early_secret_valid_o,
    output logic hs_secret_valid_o,
    output logic hs_traffic_keys_valid_o,
    output logic master_secret_valid_o,
    output logic ap_traffic_keys_valid_o,

    // ====== Error Reporting ======
    output logic error_key_schedule
);

    // ====================================================================
    // Instantiate Main FSM
    // ====================================================================
    key_schedule_fsm u_ks_fsm (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .hardware_reset             (hardware_reset),
        .ecdhe_complete             (ecdhe_complete),
        .ecdhe_shared_secret        (ecdhe_shared_secret),
        .transcript_after_sh        (transcript_update),
        .transcript_hash_sh         (transcript_hash),
        .handshake_done             (handshake_flight_done),
        .transcript_hash_done       (transcript_hash),
        .finished_verify_pass       (verify_finished_pass),

        .early_secret               (early_secret_o),
        .handshake_secret           (handshake_secret_o),
        .master_secret              (master_secret_o),
        .client_hs_traffic_secret   (client_hs_traffic_secret_o),
        .server_hs_traffic_secret   (server_hs_traffic_secret_o),
        .client_ap_traffic_secret   (client_ap_traffic_secret_o),
        .server_ap_traffic_secret   (server_ap_traffic_secret_o),

        .client_hs_key_pair         (client_hs_key_pair_o),
        .server_hs_key_pair         (server_hs_key_pair_o),
        .client_ap_key_pair         (client_ap_key_pair_o),
        .server_ap_key_pair         (server_ap_key_pair_o),

        .early_secret_valid         (early_secret_valid_o),
        .hs_secret_valid            (hs_secret_valid_o),
        .hs_traffic_keys_valid      (hs_traffic_keys_valid_o),
        .master_secret_valid        (master_secret_valid_o),
        .ap_traffic_keys_valid      (ap_traffic_keys_valid_o)
    );

    // ====================================================================
    // Error Handling (for future expansion)
    // ====================================================================
    assign error_key_schedule = 1'b0;  // No error conditions yet

endmodule : key_schedule_top
