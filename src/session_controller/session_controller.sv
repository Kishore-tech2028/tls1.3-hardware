`timescale 1ns / 1ps

module session_controller (
    input  logic clk,
    input  logic rst_n,

    // TCP connection events
    input  logic tcp_conn,          // single-cycle: new connection
    input  logic tcp_disc,          // level: disconnected

    // Role configuration (typically driven once at startup)
    input  logic config_write_en,
    input  logic config_is_server,

    // Error sources from downstream engines
    input  logic err_mac,
    input  logic err_cert,
    input  logic err_decode,        // NEW — from handshake_framer
    input  logic err_record_len,    // NEW — from rx_record_parser
    input  logic err_seq_overflow,  // NEW — from nonce_manager

    // Handshake completion inputs from downstream engines / TB
    input  logic ch_valid,
    input  logic sh_done,
    input  logic keys_done,
    input  logic cert_done,

    // TCP byte-stream interface (to/from tcp_interface)
    output logic        tcp_tx_valid,
    input  logic        tcp_tx_ready,
    output logic [31:0] tcp_tx_data,
    input  logic        tcp_rx_valid,
    input  logic [31:0] tcp_rx_data,

    // TLS byte-stream interface (to/from record_layer)
    input  logic        tls_tx_valid,
    output logic        tls_tx_ready,
    input  logic [31:0] tls_tx_data,
    output logic        tls_rx_valid,
    input  logic        tls_rx_ready,
    output logic [31:0] tls_rx_data,

    // Handshake-engine enables
    output logic en_sh,
    output logic en_cert,
    output logic en_app_data,
    output logic send_alert,

    // Role and alert outputs (for higher-level / debug)
    output logic       is_server_o,
    output logic [7:0] alert_code_o
);

    // ------------------------------------------------------------------ //
    //  Internal wires
    // ------------------------------------------------------------------ //
    logic        is_server;
    logic        fatal_alert;
    logic [7:0]  alert_code;

    // send_alert is registered in FSM; here we detect when alert should clear.
    // alert_clear: TCP disconnect triggers alert clear only after fatal_alert is set.
    logic alert_clear;
    assign alert_clear = tcp_disc & fatal_alert;

    // ------------------------------------------------------------------ //
    //  Sub-modules
    // ------------------------------------------------------------------ //
    role_config u_cfg (
        .clk             (clk),
        .rst_n           (rst_n),
        .config_write_en (config_write_en),
        .config_is_server(config_is_server),
        .is_server       (is_server)
    );
    assign is_server_o = is_server;

    error_aggregator u_err (
        .clk            (clk),
        .rst_n          (rst_n),
        .err_mac        (err_mac),
        .err_cert       (err_cert),
        .err_decode     (err_decode),
        .err_record_len (err_record_len),
        .err_seq_overflow (err_seq_overflow),
        .alert_clear    (alert_clear),
        .fatal_alert    (fatal_alert),
        .alert_code     (alert_code)
    );
    assign alert_code_o = alert_code;

    tls_state_machine u_fsm (
        .clk         (clk),
        .rst_n       (rst_n),
        .tcp_conn    (tcp_conn),
        .tcp_disc    (tcp_disc),
        .ch_valid    (ch_valid),
        .sh_done     (sh_done),
        .keys_done   (keys_done),
        .cert_done   (cert_done),
        .fatal_alert (fatal_alert),
        .en_sh       (en_sh),
        .en_cert     (en_cert),
        .en_app_data (en_app_data),
        .send_alert  (send_alert)
    );

    tcp_connection_manager #(.DATA_WIDTH(32)) u_tcp (
        .clk          (clk),
        .rst_n        (rst_n),
        // TCP side
        .tcp_tx_valid (tcp_tx_valid),
        .tcp_tx_ready (tcp_tx_ready),
        .tcp_tx_data  (tcp_tx_data),
        .tcp_rx_valid (tcp_rx_valid),
        .tcp_rx_data  (tcp_rx_data),
        // TLS internal side (record_layer will drive these)
        .tls_tx_valid (tls_tx_valid),
        .tls_tx_ready (tls_tx_ready),
        .tls_tx_data  (tls_tx_data),
        .tls_rx_valid (tls_rx_valid),
        .tls_rx_ready (tls_rx_ready),
        .tls_rx_data  (tls_rx_data)
    );

endmodule