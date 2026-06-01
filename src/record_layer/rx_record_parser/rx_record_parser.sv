`timescale 1ns / 1ps

// ============================================================================
// rx_record_parser.sv
// Main RX path coordinator: parses TCP stream → TLS records
// Reads from RX FIFO, extracts headers, validates, demuxes to handlers
// ============================================================================

import record_layer_pkg::*;

module rx_record_parser (
    input  logic clk,
    input  logic rst_n,

    // State gating (from session_controller)
    input  logic en_handshake,  // Allow HANDSHAKE records
    input  logic en_app_data,   // Allow APPLICATION_DATA records

    // RX FIFO interface (reads TCP stream)
    output logic                fifo_read_en,
    input  logic [31:0]         fifo_read_data,
    input  logic                fifo_read_valid,
    output logic                fifo_read_ready,

    // HANDSHAKE record output
    output logic [7:0]  hs_type,
    output logic [15:0] hs_version,
    output logic [13:0] hs_length,
    output logic        hs_valid,
    input  logic        hs_ready,

    // APPLICATION_DATA record output
    output logic [7:0]  app_type,
    output logic [15:0] app_version,
    output logic [13:0] app_length,
    output logic        app_valid,
    input  logic        app_ready,

    // ALERT record output
    output logic [7:0]  alert_type,
    output logic [15:0] alert_version,
    output logic [13:0] alert_length,
    output logic        alert_valid,
    input  logic        alert_ready,

    // Error signals (to session_controller)
    output logic        err_record_length,
    output logic        err_invalid_type,
    output logic        err_decode
);

    // ========================================================================
    // Parse State Machine
    // ========================================================================
    rx_parser_state_t state_r, state_w;
    logic [4:0]       byte_count_r, byte_count_w;  // Count bytes in record

    // Header buffers
    logic [7:0]  parsed_type_r, parsed_type_w;
    logic [15:0] parsed_version_r, parsed_version_w;
    logic [13:0] parsed_length_r, parsed_length_w;

    // ========================================================================
    // Extract Bytes from 32-bit FIFO data
    // ========================================================================
    logic [7:0] byte0, byte1, byte2, byte3;
    assign byte0 = fifo_read_data[7:0];
    assign byte1 = fifo_read_data[15:8];
    assign byte2 = fifo_read_data[23:16];
    assign byte3 = fifo_read_data[31:24];

    // ========================================================================
    // Sequential Logic
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r           <= RX_IDLE;
            byte_count_r      <= '0;
            parsed_type_r     <= '0;
            parsed_version_r  <= '0;
            parsed_length_r   <= '0;
        end else begin
            state_r           <= state_w;
            byte_count_r      <= byte_count_w;
            parsed_type_r     <= parsed_type_w;
            parsed_version_r  <= parsed_version_w;
            parsed_length_r   <= parsed_length_w;
        end
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always_comb begin
        state_w           = state_r;
        byte_count_w      = byte_count_r;
        parsed_type_w     = parsed_type_r;
        parsed_version_w  = parsed_version_r;
        parsed_length_w   = parsed_length_r;

        fifo_read_en      = 1'b0;
        fifo_read_ready   = 1'b0;

        hs_valid          = 1'b0;
        app_valid         = 1'b0;
        alert_valid       = 1'b0;

        err_record_length = 1'b0;
        err_invalid_type  = 1'b0;
        err_decode        = 1'b0;

        case (state_r)
            RX_IDLE: begin
                // Wait for FIFO data
                if (fifo_read_valid) begin
                    state_w = RX_HEADER;
                    byte_count_w = 5'b0;
                end
                fifo_read_ready = 1'b1;
            end

            RX_HEADER: begin
                // Read header bytes (type, version MSB, version LSB, length MSB, length LSB)
                if (fifo_read_valid && byte_count_r < 5) begin
                    fifo_read_en = 1'b1;

                    // Parse based on byte position
                    case (byte_count_r)
                        5'h0: parsed_type_w[7:0]     = byte0;  // Type
                        5'h1: parsed_version_w[15:8] = byte0;  // Version MSB
                        5'h2: parsed_version_w[7:0]  = byte0;  // Version LSB
                        5'h3: parsed_length_w[13:8]  = byte0[5:0];  // Length MSB (14 bits)
                        5'h4: parsed_length_w[7:0]   = byte0;  // Length LSB
                    endcase

                    byte_count_w = byte_count_r + 5'h1;

                    if (byte_count_r == 5'h4) begin
                        state_w = RX_VERIFY;
                    end
                end
                fifo_read_ready = 1'b1;
            end

            RX_VERIFY: begin
                // Validate record structure
                if (parsed_length_r > MAX_RECORD_PLAINTEXT) begin
                    err_record_length = 1'b1;
                    state_w = RX_ERROR;
                end else if (parsed_type_r == 8'hFF || 
                            (parsed_type_r != 8'h14 && parsed_type_r != 8'h15 && 
                             parsed_type_r != 8'h16 && parsed_type_r != 8'h17)) begin
                    err_invalid_type = 1'b1;
                    state_w = RX_ERROR;
                end else begin
                    // Route to appropriate handler
                    state_w = RX_IDLE;
                    case (parsed_type_r)
                        8'h16: begin  // HANDSHAKE
                            if (en_handshake && hs_ready) begin
                                hs_valid = 1'b1;
                            end
                        end
                        8'h17: begin  // APPLICATION_DATA
                            if (en_app_data && app_ready) begin
                                app_valid = 1'b1;
                            end
                        end
                        8'h15: begin  // ALERT
                            if (alert_ready) begin
                                alert_valid = 1'b1;
                            end
                        end
                        8'h14: begin  // CHANGE_CIPHER_SPEC (silently drop)
                            // Do nothing
                        end
                    endcase
                end
            end

            RX_ERROR: begin
                err_decode = 1'b1;
                state_w = RX_IDLE;
            end

            default: state_w = RX_IDLE;
        endcase
    end

    // ========================================================================
    // Output Assignment
    // ========================================================================
    assign hs_type     = parsed_type_r;
    assign hs_version  = parsed_version_r;
    assign hs_length   = parsed_length_r;

    assign app_type    = parsed_type_r;
    assign app_version = parsed_version_r;
    assign app_length  = parsed_length_r;

    assign alert_type     = parsed_type_r;
    assign alert_version  = parsed_version_r;
    assign alert_length   = parsed_length_r;

endmodule : rx_record_parser
