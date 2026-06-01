`timescale 1ns / 1ps

// ============================================================================
// record_layer_top.sv
// Top-level TLS 1.3 Record Layer module
// Integrates RX path, TX path, encryption, and decryption
// RFC 8446 compliant record handling
// ============================================================================

import record_layer_pkg::*;

module record_layer_top (
    input  logic clk,
    input  logic rst_n,

    // ========================================================================
    // Session Controller Interface (TCP Stream)
    // ========================================================================
    // RX path: TCP bytes from session_controller
    input  logic        tcp_rx_valid,
    input  logic [31:0] tcp_rx_data,
    output logic        tcp_rx_ready,

    // TX path: Framed records to session_controller
    output logic        tcp_tx_valid,
    output logic [31:0] tcp_tx_data,
    input  logic        tcp_tx_ready,

    // ========================================================================
    // State Control (from session_controller)
    // ========================================================================
    input  logic en_handshake,   // Allow HANDSHAKE records
    input  logic en_app_data,    // Allow APPLICATION_DATA records

    // ========================================================================
    // Key Schedule Interface
    // ========================================================================
    // TX (client/server write key)
    input  traffic_key_t tx_key,
    input  logic         tx_key_valid,

    // RX (client/server read key)
    input  traffic_key_t rx_key,
    input  logic         rx_key_valid,

    // ========================================================================
    // Handshake Engine Interface (RX Output)
    // ========================================================================
    // HANDSHAKE records
    output logic [7:0]  hs_record_type,
    output logic [15:0] hs_version,
    output logic [13:0] hs_length,
    output logic [7:0]  hs_payload_byte,
    output logic        hs_payload_valid,
    input  logic        hs_payload_ready,

    // APPLICATION_DATA records
    output logic [7:0]  app_record_type,
    output logic [15:0] app_version,
    output logic [13:0] app_length,
    output logic [7:0]  app_payload_byte,
    output logic        app_payload_valid,
    input  logic        app_payload_ready,

    // ========================================================================
    // Handshake Engine Interface (TX Input)
    // ========================================================================
    // Outgoing handshake messages
    input  logic [7:0]  tx_hs_payload_byte,
    input  logic        tx_hs_payload_valid,
    output logic        tx_hs_payload_ready,

    // Outgoing application data
    input  logic [7:0]  tx_app_payload_byte,
    input  logic        tx_app_payload_valid,
    output logic        tx_app_payload_ready,

    // ========================================================================
    // Error Signals (to session_controller)
    // ========================================================================
    output logic        err_record_length,
    output logic        err_invalid_type,
    output logic        err_decode,
    output logic        err_encrypt_failed,
    output logic        err_decrypt_failed
);

    // ========================================================================
    // Internal FIFOs
    // ========================================================================
    logic        rx_fifo_read_en;
    logic [31:0] rx_fifo_read_data;
    logic        rx_fifo_read_valid;
    logic        rx_fifo_read_ready;

    logic        tx_fifo_write_en;
    logic [31:0] tx_fifo_write_data;
    logic        tx_fifo_write_ready;
    logic        tx_fifo_write_almost_full;

    // ========================================================================
    // RX FIFO Instantiation
    // ========================================================================
    rx_record_fifo rx_fifo_inst (
        .clk               (clk),
        .rst_n             (rst_n),
        .write_en          (tcp_rx_valid),
        .write_data        (tcp_rx_data),
        .write_ready       (tcp_rx_ready),
        .write_almost_full (),
        .read_en           (rx_fifo_read_en),
        .read_data         (rx_fifo_read_data),
        .read_valid        (rx_fifo_read_valid),
        .read_almost_empty (),
        .fifo_count        ()
    );

    // ========================================================================
    // TX FIFO Instantiation
    // ========================================================================
    tx_record_fifo tx_fifo_inst (
        .clk               (clk),
        .rst_n             (rst_n),
        .write_en          (tx_fifo_write_en),
        .write_data        (tx_fifo_write_data),
        .write_ready       (tx_fifo_write_ready),
        .write_almost_full (tx_fifo_write_almost_full),
        .read_en           (tcp_tx_valid && tcp_tx_ready),
        .read_data         (tcp_tx_data),
        .read_valid        (tcp_tx_valid),
        .read_almost_empty (),
        .fifo_count        ()
    );

    assign tcp_tx_ready = tcp_tx_ready;  // Placeholder - will be from FIFO

    // ========================================================================
    // RX Record Parser Instantiation
    // ========================================================================
    rx_record_parser rx_parser_inst (
        .clk               (clk),
        .rst_n             (rst_n),
        .en_handshake      (en_handshake),
        .en_app_data       (en_app_data),
        .fifo_read_en      (rx_fifo_read_en),
        .fifo_read_data    (rx_fifo_read_data),
        .fifo_read_valid   (rx_fifo_read_valid),
        .fifo_read_ready   (rx_fifo_read_ready),
        .hs_type           (hs_record_type),
        .hs_version        (hs_version),
        .hs_length         (hs_length),
        .hs_valid          (hs_payload_valid),
        .hs_ready          (hs_payload_ready),
        .app_type          (app_record_type),
        .app_version       (app_version),
        .app_length        (app_length),
        .app_valid         (app_payload_valid),
        .app_ready         (app_payload_ready),
        .alert_type        (),
        .alert_version     (),
        .alert_length      (),
        .alert_valid       (),
        .alert_ready       (1'b1),
        .err_record_length (err_record_length),
        .err_invalid_type  (err_invalid_type),
        .err_decode        (err_decode)
    );

    // Placeholder: payload streaming from parser
    assign hs_payload_byte = '0;
    assign app_payload_byte = '0;

    // ========================================================================
    // TX Record Framer Instantiation
    // ========================================================================
    tx_record_framer tx_framer_inst (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .hs_payload_byte         (tx_hs_payload_byte),
        .hs_payload_valid        (tx_hs_payload_valid),
        .hs_payload_ready        (tx_hs_payload_ready),
        .app_payload_byte        (tx_app_payload_byte),
        .app_payload_valid       (tx_app_payload_valid),
        .app_payload_ready       (tx_app_payload_ready),
        .tx_fifo_data            (tx_fifo_write_data),
        .tx_fifo_valid           (tx_fifo_write_en),
        .tx_fifo_ready           (tx_fifo_write_ready),
        .record_type_out         (),
        .record_version_out      (),
        .record_length_out       (),
        .record_framed_valid     ()
    );

    // ========================================================================
    // AEAD Encryption Dispatch
    // ========================================================================
    aead_encrypt_dispatch encrypt_inst (
        .clk                (clk),
        .rst_n              (rst_n),
        .tx_key             (tx_key),
        .tx_key_valid       (tx_key_valid),
        .plaintext_byte     (tx_fifo_write_data[7:0]),
        .plaintext_valid    (tx_fifo_write_en),
        .plaintext_ready    (tx_fifo_write_ready),
        .inner_content_type (8'h16),
        .inner_ct_valid     (1'b1),
        .inner_ct_ready     (),
        .ciphertext_byte    (),
        .ciphertext_valid   (),
        .ciphertext_ready   (1'b1),
        .auth_tag_out       (),
        .auth_tag_valid     (),
        .auth_tag_ready     (1'b1),
        .err_encrypt_failed (err_encrypt_failed)
    );

    // ========================================================================
    // AEAD Decryption Dispatch
    // ========================================================================
    aead_decrypt_dispatch decrypt_inst (
        .clk                         (clk),
        .rst_n                       (rst_n),
        .rx_key                      (rx_key),
        .rx_key_valid                (rx_key_valid),
        .ciphertext_byte             (rx_fifo_read_data[7:0]),
        .ciphertext_valid            (rx_fifo_read_valid),
        .ciphertext_ready            (rx_fifo_read_ready),
        .auth_tag_in                 (128'h00000000000000000000000000000000),
        .auth_tag_valid              (1'b0),
        .auth_tag_ready              (),
        .plaintext_byte              (),
        .plaintext_valid             (),
        .plaintext_ready             (1'b1),
        .inner_content_type          (),
        .inner_ct_valid              (),
        .inner_ct_ready              (1'b1),
        .err_decrypt_failed          (err_decrypt_failed),
        .err_tag_verification_failed ()
    );

endmodule : record_layer_top
