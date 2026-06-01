`timescale 1ns / 1ps

module role_config (
    input  logic clk,
    input  logic rst_n,
    input  logic config_write_en,   // pulse to latch new role
    input  logic config_is_server,  // 1 = server, 0 = client
    output logic is_server          // registered role
);
    // Reset default: server mode (safe default for a server FPGA).
    // Driving config_write_en=1 with config_is_server=0 switches to client.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)              is_server <= 1'b1;
        else if (config_write_en) is_server <= config_is_server;
    end

endmodule