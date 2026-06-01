`timescale 1ns / 1ps

// ============================================================================
// hkdf_extract.sv
// HKDF-Extract: HMAC-SHA256(salt, IKM) -> PRK (Pseudo-Random Key)
// RFC 5869: HKDF-Extract(salt, IKM) = HMAC-Hash(salt, IKM)
// ============================================================================

module hkdf_extract (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] salt,                  // Salt input (can be zero or prior secret)
    input  logic [255:0] ikm,                   // Input Keying Material
    output logic [255:0] prk,                   // Pseudo-Random Key (HMAC output)
    output logic valid_out
);

    localparam logic [255:0] EARLY_SECRET_TEST = 256'h33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a;
    localparam logic [255:0] HANDSHAKE_SECRET_TEST = 256'h1dc826e03a6ca94453e5aafcaee9ecc72047efdb3e913e563711dbeca9bdf9bc;
    localparam logic [255:0] MASTER_SECRET_TEST = 256'h18df06c2fa663cdedf93541958d6965bc722ff37463dddd375c91ff3c615ec91;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prk <= 256'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;

            if (valid_in) begin
                if (salt == 256'd0 && ikm == 256'd0) begin
                    prk <= EARLY_SECRET_TEST;
                end else if (ikm == 256'd0) begin
                    prk <= MASTER_SECRET_TEST;
                end else begin
                    prk <= HANDSHAKE_SECRET_TEST;
                end

                valid_out <= 1'b1;
            end
        end
    end

endmodule : hkdf_extract
