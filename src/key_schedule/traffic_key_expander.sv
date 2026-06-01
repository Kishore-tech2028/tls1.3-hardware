`timescale 1ns / 1ps

// ============================================================================
// traffic_key_expander.sv
// Expands a traffic secret into key and IV pair
// Instantiates write_key_deriver and write_iv_deriver
// ============================================================================

import key_schedule_pkg::*;

module traffic_key_expander (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] traffic_secret,        // Input traffic secret
    output traffic_key_pair_t traffic_key_pair, // Output key + IV pair
    output logic valid_out
);

    logic [127:0] write_key;
    logic [95:0]  write_iv;
    logic key_valid, iv_valid;
    logic traffic_key_pair_valid_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            traffic_key_pair_valid_r <= 1'b0;
        end else if (key_valid & iv_valid) begin
            traffic_key_pair_valid_r <= 1'b1;
        end
    end

    write_key_deriver u_key_deriver (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .traffic_secret (traffic_secret),
        .write_key      (write_key),
        .valid_out      (key_valid)
    );

    write_iv_deriver u_iv_deriver (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .traffic_secret (traffic_secret),
        .write_iv       (write_iv),
        .valid_out      (iv_valid)
    );

    // Both derivers should complete at the same time
    assign traffic_key_pair.key   = write_key;
    assign traffic_key_pair.iv    = write_iv;
    assign traffic_key_pair.valid = traffic_key_pair_valid_r;
    assign valid_out              = traffic_key_pair_valid_r;

endmodule : traffic_key_expander
