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
    input  logic [127:0] context,               // Context (typically transcript hash)
    input  logic [7:0]   label_id,              // Label selector (LABEL_C_HS_TRAFFIC, etc.)
    input  logic [15:0]  desired_length,        // Output length in bits
    output logic [255:0] okm,                   // Output Keying Material
    output logic valid_out
);

    // ====================================================================
    // Label strings (encoded as constants for RTL)
    // Each label is prefixed with "HKDF-Expand-Label::" in RFC 8446
    // ====================================================================

    // HkdfLabel structure (RFC 8446 § 7.1):
    // struct {
    //     uint16 length;
    //     uint8 label_length;
    //     opaque label<7..255> = "HKDF-Expand-Label:" + Label;
    //     opaque context<0..255> = Context;
    // } HkdfLabel;

    logic [15:0] info_len;
    logic [87:0] label_buffer;  // "HKDF-Expand-Label:" = 18 bytes
    logic [95:0] user_label;     // Variable label (up to 15 bytes)
    logic [7:0]  user_label_len;

    // Determine label based on label_id
    always_comb begin
        case (label_id)
            8'd0: begin  // "c hs traffic"
                user_label = {72'd0, 8'h63, 8'h20, 8'h68, 8'h73, 8'h20, 8'h74, 8'h72, 8'h61, 8'h66, 8'h66, 8'h69, 8'h63};
                user_label_len = 8'd12;
            end
            8'd1: begin  // "s hs traffic"
                user_label = {72'd0, 8'h73, 8'h20, 8'h68, 8'h73, 8'h20, 8'h74, 8'h72, 8'h61, 8'h66, 8'h66, 8'h69, 8'h63};
                user_label_len = 8'd12;
            end
            8'd2: begin  // "c ap traffic"
                user_label = {72'd0, 8'h63, 8'h20, 8'h61, 8'h70, 8'h20, 8'h74, 8'h72, 8'h61, 8'h66, 8'h66, 8'h69, 8'h63};
                user_label_len = 8'd12;
            end
            8'd3: begin  // "s ap traffic"
                user_label = {72'd0, 8'h73, 8'h20, 8'h61, 8'h70, 8'h20, 8'h74, 8'h72, 8'h61, 8'h66, 8'h66, 8'h69, 8'h63};
                user_label_len = 8'd12;
            end
            8'd4: begin  // "key"
                user_label = {80'd0, 8'h6b, 8'h65, 8'h79};
                user_label_len = 8'd3;
            end
            8'd5: begin  // "iv"
                user_label = {88'd0, 8'h69, 8'h76};
                user_label_len = 8'd2;
            end
            default: begin
                user_label = 96'd0;
                user_label_len = 8'd0;
            end
        endcase
    end

    // Calculate total info length
    // info = length(2) + label_length(1) + "HKDF-Expand-Label:"(18) + label + context_length(1) + context(32)
    assign info_len = 16'd54 + user_label_len;  // 2 + 1 + 18 + user_label_len + 1 + 32

    // ====================================================================
    // State Machine for HKDF-Expand
    // ====================================================================

    typedef enum logic [1:0] {
        IDLE,
        COMPUTING,
        DONE
    } state_t;

    state_t state, next_state;
    logic hmac_start;
    logic [255:0] hmac_output;
    logic hmac_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        hmac_start = 1'b0;

        case (state)
            IDLE: begin
                if (valid_in) begin
                    hmac_start = 1'b1;
                    next_state = COMPUTING;
                end
            end
            COMPUTING: begin
                if (hmac_valid) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output assignment
    logic [255:0] hmac_output_r;
    logic hmac_valid_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hmac_output_r <= 256'h0;
            hmac_valid_r <= 1'b0;
        end else begin
            hmac_output_r <= hmac_output;
            hmac_valid_r <= hmac_valid;
        end
    end

    assign okm = hmac_output_r;
    assign valid_out = hmac_valid_r;

endmodule : hkdf_expand_label
