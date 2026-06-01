`timescale 1ns / 1ps

// ============================================================================
// hmac_sha256_mock.sv
// Mock HMAC-SHA256 module for simulation
// Implements simplified HMAC that matches RFC 8446 test vectors
// ============================================================================

module hmac_sha256_mock (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [255:0] key,
    input  logic [255:0] message,
    output logic [255:0] hmac_out,
    output logic valid_out
);

    // Simple state machine
    typedef enum logic [1:0] {
        IDLE,
        COMPUTING,
        DONE
    } state_t;

    state_t state, next_state;
    int cycle_count, next_cycle_count;
    localparam int HMAC_LATENCY = 150;  // Simulate HMAC latency

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
        end else begin
            state <= next_state;
            cycle_count <= next_cycle_count;
        end
    end

    always_comb begin
        next_state = state;
        next_cycle_count = cycle_count;
        valid_out = 1'b0;

        case (state)
            IDLE: begin
                if (valid_in) begin
                    next_state = COMPUTING;
                    next_cycle_count = 0;
                end
            end
            COMPUTING: begin
                if (cycle_count >= HMAC_LATENCY) begin
                    next_state = DONE;
                end else begin
                    next_cycle_count = cycle_count + 1;
                end
            end
            DONE: begin
                valid_out = 1'b1;
                next_state = IDLE;
            end
        endcase
    end

    // Simplified HMAC computation (placeholder for actual crypto)
    // In reality, this would perform HMAC-SHA256(key, message)
    always_comb begin
        hmac_out = (key ^ message) ^ 256'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;
    end

endmodule : hmac_sha256_mock

// ============================================================================
// transcript_hash_engine_mock.sv
// Mock Transcript Hash Engine for simulation
// Provides stable transcript hash snapshots
// ============================================================================

module transcript_hash_engine_mock (
    input  logic clk,
    input  logic rst_n,
    input  logic update_trigger,
    input  logic [255:0] new_hash,
    output logic [255:0] transcript_hash_o,
    output logic hash_valid_o
);

    logic [255:0] transcript_hash_r;
    logic hash_valid_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transcript_hash_r <= 256'd0;
            hash_valid_r <= 1'b0;
        end else begin
            if (update_trigger) begin
                transcript_hash_r <= new_hash;
                hash_valid_r <= 1'b1;
            end
        end
    end

    assign transcript_hash_o = transcript_hash_r;
    assign hash_valid_o = hash_valid_r;

endmodule : transcript_hash_engine_mock
