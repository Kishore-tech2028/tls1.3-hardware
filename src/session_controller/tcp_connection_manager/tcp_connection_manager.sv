`timescale 1ns / 1ps
module tcp_connection_manager #(parameter DATA_WIDTH = 32)(
    input logic clk, rst_n,
    // TCP Interface
    output logic tcp_tx_valid, input logic tcp_tx_ready, output logic [DATA_WIDTH-1:0] tcp_tx_data,
    input logic tcp_rx_valid, output logic tcp_rx_ready, input logic [DATA_WIDTH-1:0] tcp_rx_data,
    // TLS Internal Interface
    input logic tls_tx_valid, output logic tls_tx_ready, input logic [DATA_WIDTH-1:0] tls_tx_data,
    output logic tls_rx_valid, input logic tls_rx_ready, output logic [DATA_WIDTH-1:0] tls_rx_data
);
    logic tx_full, tx_empty, rx_full, rx_empty;
    assign tls_tx_ready = ~tx_full;
    assign tcp_tx_valid = ~tx_empty;
    assign tls_rx_valid = ~rx_empty;
    assign tcp_rx_ready = ~rx_full;

    circular_buffer #(.DATA_WIDTH(DATA_WIDTH)) tx_buf(
        .clk(clk), .rst_n(rst_n),
        .write_en(tls_tx_valid && tls_tx_ready), .write_data(tls_tx_data), .full(tx_full),
        .read_en(tcp_tx_valid && tcp_tx_ready), .read_data(tcp_tx_data), .empty(tx_empty)
    );

    circular_buffer #(.DATA_WIDTH(DATA_WIDTH)) rx_buf(
        .clk(clk), .rst_n(rst_n),
        .write_en(tcp_rx_valid && tcp_rx_ready), .write_data(tcp_rx_data), .full(rx_full),
        .read_en(tls_rx_valid && tls_rx_ready), .read_data(tls_rx_data), .empty(rx_empty)
    );
endmodule
