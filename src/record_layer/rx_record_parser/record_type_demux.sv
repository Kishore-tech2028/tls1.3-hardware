`timescale 1ns / 1ps

// ============================================================================
// record_type_demux.sv
// Routes parsed records to appropriate handlers based on content type
// Separates: HANDSHAKE, APPLICATION_DATA, ALERT, CHANGE_CIPHER_SPEC
// ============================================================================

import record_layer_pkg::*;

module record_type_demux (
    input  logic clk,
    input  logic rst_n,

    // State gating inputs (from session_controller)
    input  logic en_handshake,  // Allow HANDSHAKE records
    input  logic en_app_data,   // Allow APPLICATION_DATA records

    // Incoming record header + payload
    input  logic [7:0]  record_type_in,
    input  logic [15:0] version_in,
    input  logic [13:0] length_in,
    input  logic        record_valid_in,
    output logic        record_ready_out,

    // Outgoing record streams (for each record type)
    // HANDSHAKE stream
    output logic [7:0]  hs_record_type,
    output logic [15:0] hs_version,
    output logic [13:0] hs_length,
    output logic        hs_valid,
    input  logic        hs_ready,

    // APPLICATION_DATA stream
    output logic [7:0]  app_record_type,
    output logic [15:0] app_version,
    output logic [13:0] app_length,
    output logic        app_valid,
    input  logic        app_ready,

    // ALERT stream
    output logic [7:0]  alert_record_type,
    output logic [15:0] alert_version,
    output logic [13:0] alert_length,
    output logic        alert_valid,
    input  logic        alert_ready,

    // Error indication
    output logic        err_invalid_type
);

    // ========================================================================
    // Decode Record Type and Route
    // ========================================================================
    record_type_t current_type;
    assign current_type = record_type_t'(record_type_in);

    always_comb begin
        // Default: no outputs valid
        hs_valid         = 1'b0;
        app_valid        = 1'b0;
        alert_valid      = 1'b0;
        err_invalid_type = 1'b0;
        record_ready_out = 1'b0;

        // Default outputs
        hs_record_type    = '0;
        hs_version        = '0;
        hs_length         = '0;
        app_record_type   = '0;
        app_version       = '0;
        app_length        = '0;
        alert_record_type = '0;
        alert_version     = '0;
        alert_length      = '0;

        if (record_valid_in) begin
            case (current_type)
                HANDSHAKE: begin
                    if (en_handshake && hs_ready) begin
                        hs_record_type = record_type_in;
                        hs_version     = version_in;
                        hs_length      = length_in;
                        hs_valid       = 1'b1;
                        record_ready_out = 1'b1;
                    end
                end

                APPLICATION_DATA: begin
                    if (en_app_data && app_ready) begin
                        app_record_type = record_type_in;
                        app_version     = version_in;
                        app_length      = length_in;
                        app_valid       = 1'b1;
                        record_ready_out = 1'b1;
                    end
                end

                ALERT: begin
                    if (alert_ready) begin
                        alert_record_type = record_type_in;
                        alert_version     = version_in;
                        alert_length      = length_in;
                        alert_valid       = 1'b1;
                        record_ready_out  = 1'b1;
                    end
                end

                CHANGE_CIPHER_SPEC: begin
                    // Silently drop CCS records (RFC 8446: only for compatibility)
                    record_ready_out = 1'b1;
                end

                default: begin
                    err_invalid_type = 1'b1;
                    record_ready_out = 1'b1;  // Drop invalid record
                end
            endcase
        end
    end

endmodule : record_type_demux
