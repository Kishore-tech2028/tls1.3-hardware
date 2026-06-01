`timescale 1ns / 1ps
// TLS 1.3 alert codes (RFC 8446 §6):
//   bad_record_mac        = 20  (0x14)
//   decode_error          = 50  (0x32)
//   bad_certificate       = 42  (0x2A)
//   record_overflow       = 22  (0x16)
//   unexpected_message    = 10  (0x0A)

module error_aggregator (
    input  logic clk,
    input  logic rst_n,
    // Error sources (any can be level or pulse; aggregator latches them)
    input  logic err_mac,          // AEAD tag verification failure
    input  logic err_cert,         // certificate chain validation failure
    input  logic err_decode,       // handshake message parse error       (NEW)
    input  logic err_record_len,   // record > 16384+256 bytes            (NEW)
    input  logic err_seq_overflow, // sequence number reached 2^64-1      (NEW)
    // Control
    input  logic alert_clear,      // pulse: session_controller clears after ALERT handled
    // Outputs
    output logic        fatal_alert,
    output logic [7:0]  alert_code  // 8-bit RFC 8446 AlertDescription
);

    // ------------------------------------------------------------------ //
    //  Combinational priority encoder (lowest index = highest priority)
    // ------------------------------------------------------------------ //
    logic        any_error;
    logic [7:0]  code_next;

    always_comb begin
        any_error = 1'b0;
        code_next = 8'h00;
        if      (err_mac)          begin any_error = 1'b1; code_next = 8'd20; end  // bad_record_mac
        else if (err_cert)         begin any_error = 1'b1; code_next = 8'd42; end  // bad_certificate
        else if (err_decode)       begin any_error = 1'b1; code_next = 8'd50; end  // decode_error
        else if (err_record_len)   begin any_error = 1'b1; code_next = 8'd22; end  // record_overflow
        else if (err_seq_overflow) begin any_error = 1'b1; code_next = 8'd10; end  // unexpected_message
    end

    // ------------------------------------------------------------------ //
    //  Latch: first-fault, clearable
    // ------------------------------------------------------------------ //
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fatal_alert <= 1'b0;
            alert_code  <= 8'h00;
        end else if (alert_clear) begin
            // Session controller has processed the alert; clear for reuse
            fatal_alert <= 1'b0;
            alert_code  <= 8'h00;
        end else if (any_error && !fatal_alert) begin
            // Latch only the first error (first-fault policy)
            fatal_alert <= 1'b1;
            alert_code  <= code_next;
        end
        // While fatal_alert is high and no clear, hold current code
    end

endmodule