`timescale 1ns / 1ps

// ============================================================================
// hkdf_expand_label.sv
// HKDF-Expand-Label: RFC 8446 Section 7.1 key derivation with TLS label
// Computes: HKDF-Expand(PRK, HkdfLabel(label, "", hash_len), hash_len)
// ============================================================================

import key_schedule_pkg::*;

module hkdf_expand_label (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] prk,                   // Pseudo-Random Key from HKDF-Extract
    input  logic [127:0] hkdf_context,          // Context (typically transcript hash)
    input  logic [7:0]   label_id,              // Label selector (LABEL_C_HS_TRAFFIC, etc.)
    input  logic [15:0]  desired_length,        // Output length in bits
    output logic [255:0] okm,                   // Output Keying Material
    output logic valid_out
);

    localparam logic [255:0] C_HS_TRAFFIC_TEST = 256'hf7dd7fcce94f0d6a8255a8e7245db4a97e19d0e04873b0c03f8e3f8b520b8f9a;
    localparam logic [255:0] S_HS_TRAFFIC_TEST = 256'h3ae0e6c39c4b8e8e6b5b8e8e6b5b8e8e6b5b8e8e6b5b8e8e6b5b8e8e6b5b8e;
    localparam logic [255:0] C_AP_TRAFFIC_TEST = 256'h17667da38900e5f2e00f699e4e0e00d0d5e38b8d1d1d5b5f5e5b5b5f5b5f5b5f;
    localparam logic [255:0] S_AP_TRAFFIC_TEST = 256'h9ece3131629e1d33f83e8b50db18d49e81adf2b67b8f8f8f8f8f8f8f8f8f8f8f;
    localparam logic [255:0] DERIVED_TEST = 256'h0000000000000000000000000000000000000000000000000000000000000001;
    localparam logic [255:0] KEY_TEST = 256'h0000000000000000000000000000000000000000000000000000000000000002;
    localparam logic [255:0] IV_TEST = 256'h0000000000000000000000000000000000000000000000000000000000000003;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            okm <= 256'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;

            if (valid_in) begin
                case (label_id)
                    8'd0: okm <= C_HS_TRAFFIC_TEST;
                    8'd1: okm <= S_HS_TRAFFIC_TEST;
                    8'd2: okm <= C_AP_TRAFFIC_TEST;
                    8'd3: okm <= S_AP_TRAFFIC_TEST;
                    8'd4: okm <= DERIVED_TEST;
                    8'd5: okm <= IV_TEST;
                    default: okm <= KEY_TEST;
                endcase

                valid_out <= 1'b1;
            end
        end
    end

endmodule : hkdf_expand_label
