`timescale 1ns / 1ps

// ============================================================================
// tx_record_framer.sv
// Main TX path coordinator: frames handshake/app-data messages → TLS records
// Wraps payloads with record headers and buffers to TX FIFO
// ============================================================================

import record_layer_pkg::*;

module tx_record_framer (
    input  logic clk,
    input  logic rst_n,

    // Handshake message input
    input  logic [7:0]  hs_payload_byte,
    input  logic        hs_payload_valid,
    output logic        hs_payload_ready,

    // Application data message input
    input  logic [7:0]  app_payload_byte,
    input  logic        app_payload_valid,
    output logic        app_payload_ready,

    // TX FIFO interface (to session_controller)
    output logic [31:0] tx_fifo_data,
    output logic        tx_fifo_valid,
    input  logic        tx_fifo_ready,

    // Record metadata outputs (for debugging/monitoring)
    output logic [7:0]  record_type_out,
    output logic [15:0] record_version_out,
    output logic [13:0] record_length_out,
    output logic        record_framed_valid
);

    // ========================================================================
    // TX Framing State Machine
    // ========================================================================
    tx_framer_state_t state_r, state_w;

    // Record state
    logic [7:0]  record_type_r, record_type_w;
    logic [15:0] record_version_r, record_version_w;
    logic [13:0] payload_length_r, payload_length_w;
    logic [31:0] payload_buffer_r, payload_buffer_w;
    logic [4:0]  payload_bytes_count_r, payload_bytes_count_w;
    logic [7:0]  payload_length_msb;
    logic [7:0]  payload_length_lsb;

    assign payload_length_msb = payload_length_r[13:8];
    assign payload_length_lsb = payload_length_r[7:0];

    // Framing outputs
    logic frame_complete;

    // ========================================================================
    // Sequential Logic
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r               <= TX_IDLE;
            record_type_r         <= '0;
            record_version_r      <= TLS_VERSION_LEGACY;
            payload_length_r      <= '0;
            payload_buffer_r      <= '0;
            payload_bytes_count_r <= '0;
        end else begin
            state_r               <= state_w;
            record_type_r         <= record_type_w;
            record_version_r      <= record_version_w;
            payload_length_r      <= payload_length_w;
            payload_buffer_r      <= payload_buffer_w;
            payload_bytes_count_r <= payload_bytes_count_w;
        end
    end

    // ========================================================================
    // Next State Logic
    // ========================================================================
    always_comb begin
        state_w               = state_r;
        record_type_w         = record_type_r;
        record_version_w      = record_version_r;
        payload_length_w      = payload_length_r;
        payload_buffer_w      = payload_buffer_r;
        payload_bytes_count_w = payload_bytes_count_r;

        hs_payload_ready      = 1'b0;
        app_payload_ready     = 1'b0;
        tx_fifo_valid         = 1'b0;
        tx_fifo_data          = 32'h00000000;
        record_framed_valid   = 1'b0;
        frame_complete        = 1'b0;

        case (state_r)
            TX_IDLE: begin
                // Wait for payload input (either handshake or app-data)
                if (hs_payload_valid) begin
                    record_type_w = 8'h16;  // HANDSHAKE
                    record_version_w = TLS_VERSION_LEGACY;
                    state_w = TX_ENCODE_HEADER;
                    hs_payload_ready = 1'b1;
                    payload_buffer_w[7:0] = hs_payload_byte;
                    payload_bytes_count_w = 5'h01;
                    payload_length_w = 14'h0001;
                end else if (app_payload_valid) begin
                    record_type_w = 8'h17;  // APPLICATION_DATA
                    record_version_w = TLS_VERSION_LEGACY;
                    state_w = TX_ENCODE_HEADER;
                    app_payload_ready = 1'b1;
                    payload_buffer_w[7:0] = app_payload_byte;
                    payload_bytes_count_w = 5'h01;
                    payload_length_w = 14'h0001;
                end
            end

            TX_ENCODE_HEADER: begin
                // Frame record: [type | version | length | payload]
                // Output header bytes (5 bytes) + payload
                if (tx_fifo_ready && payload_bytes_count_r < MAX_RECORD_PLAINTEXT) begin
                    // Continue buffering payload or start transmitting
                    
                    // For now: simple implementation - just buffer and forward
                    // Full implementation would pipeline header + payload
                    
                    if (record_type_r == 8'h16 && hs_payload_valid) begin
                        payload_buffer_w = (payload_buffer_r << 8) | hs_payload_byte;
                        payload_bytes_count_w = payload_bytes_count_r + 5'h01;
                        payload_length_w = payload_length_r + 14'h0001;
                        hs_payload_ready = 1'b1;
                    end else if (record_type_r == 8'h17 && app_payload_valid) begin
                        payload_buffer_w = (payload_buffer_r << 8) | app_payload_byte;
                        payload_bytes_count_w = payload_bytes_count_r + 5'h01;
                        payload_length_w = payload_length_r + 14'h0001;
                        app_payload_ready = 1'b1;
                    end else begin
                        // No more input - transmit what we have
                        state_w = TX_PAYLOAD;
                    end
                end else if (tx_fifo_ready) begin
                    state_w = TX_PAYLOAD;
                end
            end

            TX_PAYLOAD: begin
                // Send framed record
                // Header: [type(1) | version(2) | length(2)]
                // Followed by payload
                if (tx_fifo_ready) begin
                    // Transmit header + first 3 bytes of payload
                    tx_fifo_data = {
                        record_type_r,           // [31:24]
                        record_version_r,        // [23:8]
                        payload_length_msb,
                        payload_length_lsb       // [7:0]
                    };
                    tx_fifo_valid = 1'b1;
                    record_framed_valid = 1'b1;
                    state_w = TX_IDLE;
                    frame_complete = 1'b1;
                end
            end

            default: state_w = TX_IDLE;
        endcase
    end

    // ========================================================================
    // Output Assignment
    // ========================================================================
    assign record_type_out    = record_type_r;
    assign record_version_out = record_version_r;
    assign record_length_out  = payload_length_r;

endmodule : tx_record_framer
