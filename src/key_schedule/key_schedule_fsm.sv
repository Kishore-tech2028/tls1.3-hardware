`timescale 1ns / 1ps

// ============================================================================
// key_schedule_fsm.sv
// Key Schedule Finite State Machine (5 states)
// Orchestrates derivation of all secrets and traffic keys
// ============================================================================

import key_schedule_pkg::*;

module key_schedule_fsm (
    input  logic clk,
    input  logic rst_n,

    // ====== State Machine Triggers ======
    input  logic hardware_reset,                // Start early phase
    input  logic ecdhe_complete,                // ECDHE shared secret ready
    input  logic [255:0] ecdhe_shared_secret,   // x25519 output
    input  logic transcript_after_sh,           // Transcript hash ready after ServerHello
    input  logic [255:0] transcript_hash_sh,    // Transcript hash snapshot
    input  logic handshake_done,                // Handshake flight complete
    input  logic [255:0] transcript_hash_done,  // Final transcript hash
    input  logic finished_verify_pass,          // verify_finished passed

    // ====== Secret and Key Outputs ======
    output logic [255:0] early_secret,
    output logic [255:0] handshake_secret,
    output logic [255:0] master_secret,
    output logic [255:0] client_hs_traffic_secret,
    output logic [255:0] server_hs_traffic_secret,
    output logic [255:0] client_ap_traffic_secret,
    output logic [255:0] server_ap_traffic_secret,

    output traffic_key_pair_t client_hs_key_pair,
    output traffic_key_pair_t server_hs_key_pair,
    output traffic_key_pair_t client_ap_key_pair,
    output traffic_key_pair_t server_ap_key_pair,

    // ====== Status Flags ======
    output logic early_secret_valid,
    output logic hs_secret_valid,
    output logic hs_traffic_keys_valid,
    output logic master_secret_valid,
    output logic ap_traffic_keys_valid
);

    // ====================================================================
    // Internal Registers for Secrets (persistent storage)
    // ====================================================================
    logic [255:0] early_secret_r;
    logic [255:0] handshake_secret_r;
    logic [255:0] master_secret_r;
    logic [255:0] client_hs_traffic_secret_r;
    logic [255:0] server_hs_traffic_secret_r;
    logic [255:0] client_ap_traffic_secret_r;
    logic [255:0] server_ap_traffic_secret_r;

    logic early_secret_valid_r;
    logic hs_secret_valid_r;
    logic hs_traffic_keys_valid_r;
    logic master_secret_valid_r;
    logic ap_traffic_keys_valid_r;

    // ====================================================================
    // Sub-module Instantiation and Control Signals
    // ====================================================================

    // State A: Early Phase (produces early_secret)
    logic early_valid_out;
    logic early_trigger;
    assign early_trigger = hardware_reset;

    // For early phase, use all-zero IKM
    hkdf_extract u_early_phase (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(early_trigger),
        .salt    (256'd0),                      // No prior secret
        .ikm     (256'd0),                      // All zeros for early phase
        .prk     (early_secret),
        .valid_out(early_valid_out)
    );

    // State B: Handshake Secret Derivation
    logic hs_valid_out;
    logic hs_trigger;
    assign hs_trigger = ecdhe_complete;

    handshake_secret_deriver u_hs_deriver (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(hs_trigger),
        .early_secret(early_secret_r),
        .ecdhe_shared_secret(ecdhe_shared_secret),
        .handshake_secret(handshake_secret),
        .valid_out(hs_valid_out)
    );

    // State C: Handshake Traffic Keys
    logic c_hs_traffic_valid;
    logic s_hs_traffic_valid;
    logic hs_traffic_trigger;
    assign hs_traffic_trigger = transcript_after_sh;

    client_hs_traffic_deriver u_c_hs_traffic (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(hs_traffic_trigger),
        .handshake_secret(handshake_secret_r),
        .transcript_hash(transcript_hash_sh),
        .client_hs_traffic_secret(client_hs_traffic_secret),
        .valid_out(c_hs_traffic_valid)
    );

    server_hs_traffic_deriver u_s_hs_traffic (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(hs_traffic_trigger),
        .handshake_secret(handshake_secret_r),
        .transcript_hash(transcript_hash_sh),
        .server_hs_traffic_secret(server_hs_traffic_secret),
        .valid_out(s_hs_traffic_valid)
    );

    // Expand to actual keys and IVs
    traffic_key_expander u_c_hs_expand (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(c_hs_traffic_valid),
        .traffic_secret(client_hs_traffic_secret_r),
        .traffic_key_pair(client_hs_key_pair),
        .valid_out()
    );

    traffic_key_expander u_s_hs_expand (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(s_hs_traffic_valid),
        .traffic_secret(server_hs_traffic_secret_r),
        .traffic_key_pair(server_hs_key_pair),
        .valid_out()
    );

    // State D: Master Secret Derivation
    logic master_valid_out;
    logic master_trigger;
    assign master_trigger = handshake_done;

    master_secret_deriver u_master_deriver (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(master_trigger),
        .handshake_secret(handshake_secret_r),
        .master_secret(master_secret),
        .valid_out(master_valid_out)
    );

    // State E: Application Traffic Keys
    logic c_ap_traffic_valid;
    logic s_ap_traffic_valid;
    logic ap_traffic_trigger;
    assign ap_traffic_trigger = finished_verify_pass;

    client_ap_traffic_deriver u_c_ap_traffic (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(ap_traffic_trigger),
        .master_secret(master_secret_r),
        .transcript_hash(transcript_hash_done),
        .client_ap_traffic_secret(client_ap_traffic_secret),
        .valid_out(c_ap_traffic_valid)
    );

    server_ap_traffic_deriver u_s_ap_traffic (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(ap_traffic_trigger),
        .master_secret(master_secret_r),
        .transcript_hash(transcript_hash_done),
        .server_ap_traffic_secret(server_ap_traffic_secret),
        .valid_out(s_ap_traffic_valid)
    );

    // Expand to actual keys and IVs
    traffic_key_expander u_c_ap_expand (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(c_ap_traffic_valid),
        .traffic_secret(client_ap_traffic_secret_r),
        .traffic_key_pair(client_ap_key_pair),
        .valid_out()
    );

    traffic_key_expander u_s_ap_expand (
        .clk     (clk),
        .rst_n   (rst_n),
        .valid_in(s_ap_traffic_valid),
        .traffic_secret(server_ap_traffic_secret_r),
        .traffic_key_pair(server_ap_key_pair),
        .valid_out()
    );

    // ====================================================================
    // Sequential Logic: Store derived values and update validity flags
    // ====================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            early_secret_r               <= 256'd0;
            handshake_secret_r           <= 256'd0;
            master_secret_r              <= 256'd0;
            client_hs_traffic_secret_r   <= 256'd0;
            server_hs_traffic_secret_r   <= 256'd0;
            client_ap_traffic_secret_r   <= 256'd0;
            server_ap_traffic_secret_r   <= 256'd0;

            early_secret_valid_r         <= 1'b0;
            hs_secret_valid_r            <= 1'b0;
            hs_traffic_keys_valid_r      <= 1'b0;
            master_secret_valid_r        <= 1'b0;
            ap_traffic_keys_valid_r      <= 1'b0;
        end else begin
            // Stage A: Early secret
            if (early_valid_out) begin
                early_secret_r       <= early_secret;
                early_secret_valid_r <= 1'b1;
            end

            // Stage B: Handshake secret
            if (hs_valid_out) begin
                handshake_secret_r   <= handshake_secret;
                hs_secret_valid_r    <= 1'b1;
            end

            // Stage C: Handshake traffic secrets
            if (c_hs_traffic_valid) begin
                client_hs_traffic_secret_r   <= client_hs_traffic_secret;
            end
            if (s_hs_traffic_valid) begin
                server_hs_traffic_secret_r   <= server_hs_traffic_secret;
            end
            if (c_hs_traffic_valid & s_hs_traffic_valid) begin
                hs_traffic_keys_valid_r      <= 1'b1;
            end

            // Stage D: Master secret
            if (master_valid_out) begin
                master_secret_r      <= master_secret;
                master_secret_valid_r<= 1'b1;
            end

            // Stage E: Application traffic secrets
            if (c_ap_traffic_valid) begin
                client_ap_traffic_secret_r   <= client_ap_traffic_secret;
            end
            if (s_ap_traffic_valid) begin
                server_ap_traffic_secret_r   <= server_ap_traffic_secret;
            end
            if (c_ap_traffic_valid & s_ap_traffic_valid) begin
                ap_traffic_keys_valid_r      <= 1'b1;
            end
        end
    end

    // ====================================================================
    // Output Assignments
    // ====================================================================
    assign early_secret_valid       = early_secret_valid_r;
    assign hs_secret_valid          = hs_secret_valid_r;
    assign hs_traffic_keys_valid    = hs_traffic_keys_valid_r;
    assign master_secret_valid      = master_secret_valid_r;
    assign ap_traffic_keys_valid    = ap_traffic_keys_valid_r;

endmodule : key_schedule_fsm
