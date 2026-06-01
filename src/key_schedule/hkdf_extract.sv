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

    // ====================================================================
    // HMAC-SHA256 Core (assumed as black-box)
    // In a real implementation, this would be connected to shared crypto_core
    // ====================================================================

    logic hmac_start;
    logic hmac_busy;
    logic [255:0] hmac_output;
    logic hmac_valid;

    // Simple state machine to control HMAC
    typedef enum logic [1:0] {
        IDLE,
        COMPUTING,
        DONE
    } state_t;

    state_t state, next_state;

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

    // Placeholder: In real implementation, connect to shared crypto_core
    // For now, assume 2-cycle latency for HMAC
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

    assign prk = hmac_output_r;
    assign valid_out = hmac_valid_r;

endmodule : hkdf_extract
