`timescale 1ns / 1ps
module circular_buffer #(parameter DATA_WIDTH = 32, parameter ADDR_WIDTH = 12)
(
    input  logic clk, rst_n, write_en, read_en,
    input  logic [DATA_WIDTH-1:0] write_data,
    output logic [DATA_WIDTH-1:0] read_data,
    output logic full, empty
);
    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) wr_ptr <= '0;
        else if (write_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= write_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rd_ptr <= '0; read_data <= '0; 
        end
        else if (read_en && !empty) begin
            read_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
endmodule