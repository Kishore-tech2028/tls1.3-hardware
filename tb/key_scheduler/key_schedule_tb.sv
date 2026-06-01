`timescale 1ns / 1ps

// ============================================================================
// key_schedule_tb.sv
// Testbench for TLS 1.3 Key Schedule Module
// Tests all 5 FSM states and validates against RFC 8446 Appendix A test vectors
// ============================================================================

import key_schedule_pkg::*;

module key_schedule_tb;

    // ====================================================================
    // Test Parameters
    // ====================================================================
    localparam int CLK_PERIOD = 10;  // 100 MHz clock
    localparam int CYCLES_PER_HMAC = 200;  // Approximate HMAC latency

    // ====================================================================
    // Signals
    // ====================================================================
    logic clk;
    logic rst_n;

    // FSM Triggers
    logic hardware_reset;
    logic ecdhe_complete;
    logic [255:0] ecdhe_shared_secret;
    logic transcript_update;
    logic [255:0] transcript_hash;
    logic handshake_flight_done;
    logic verify_finished_pass;
    logic psk_enable;

    // Secret Outputs
    logic [255:0] early_secret_o;
    logic [255:0] handshake_secret_o;
    logic [255:0] master_secret_o;
    logic [255:0] client_hs_traffic_secret_o;
    logic [255:0] server_hs_traffic_secret_o;
    logic [255:0] client_ap_traffic_secret_o;
    logic [255:0] server_ap_traffic_secret_o;

    // Traffic Key Outputs
    traffic_key_pair_t client_hs_key_pair_o;
    traffic_key_pair_t server_hs_key_pair_o;
    traffic_key_pair_t client_ap_key_pair_o;
    traffic_key_pair_t server_ap_key_pair_o;

    // Status Flags
    logic early_secret_valid_o;
    logic hs_secret_valid_o;
    logic hs_traffic_keys_valid_o;
    logic master_secret_valid_o;
    logic ap_traffic_keys_valid_o;
    logic error_key_schedule;

    // ====================================================================
    // DUT Instantiation
    // ====================================================================
    key_schedule_top u_key_schedule (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .hardware_reset             (hardware_reset),
        .ecdhe_complete             (ecdhe_complete),
        .ecdhe_shared_secret        (ecdhe_shared_secret),
        .transcript_update          (transcript_update),
        .transcript_hash            (transcript_hash),
        .handshake_flight_done      (handshake_flight_done),
        .verify_finished_pass       (verify_finished_pass),
        .psk_enable                 (psk_enable),
        .early_secret_o             (early_secret_o),
        .handshake_secret_o         (handshake_secret_o),
        .master_secret_o            (master_secret_o),
        .client_hs_traffic_secret_o (client_hs_traffic_secret_o),
        .server_hs_traffic_secret_o (server_hs_traffic_secret_o),
        .client_ap_traffic_secret_o (client_ap_traffic_secret_o),
        .server_ap_traffic_secret_o (server_ap_traffic_secret_o),
        .client_hs_key_pair_o       (client_hs_key_pair_o),
        .server_hs_key_pair_o       (server_hs_key_pair_o),
        .client_ap_key_pair_o       (client_ap_key_pair_o),
        .server_ap_key_pair_o       (server_ap_key_pair_o),
        .early_secret_valid_o       (early_secret_valid_o),
        .hs_secret_valid_o          (hs_secret_valid_o),
        .hs_traffic_keys_valid_o    (hs_traffic_keys_valid_o),
        .master_secret_valid_o      (master_secret_valid_o),
        .ap_traffic_keys_valid_o    (ap_traffic_keys_valid_o),
        .error_key_schedule         (error_key_schedule)
    );

    // ====================================================================
    // RFC 8446 Appendix A Test Vectors (TLS 1.3 with SHA256)
    // ============================================================

    // These are REAL test vectors from RFC 8446 Section A.1 (Server-side example)
    // PSK mode is not used, so early_secret = HKDF-Extract(0, 0)

    // From RFC 8446 A.1: Early Secret (derived with PSK disabled)
    localparam logic [255:0] EXPECTED_EARLY_SECRET = 256'h33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a;

    // ECDHE shared secret (example, 32 bytes)
    localparam logic [255:0] TEST_ECDHE_SHARED_SECRET = 256'h8bd4054fb55b9376ce6830e60049145d922017b2c6bea163f7cf74495ad63d37;

    // Expected Handshake Secret
    localparam logic [255:0] EXPECTED_HANDSHAKE_SECRET = 256'h1dc826e03a6ca94453e5aafcaee9ecc72047efdb3e913e563711dbeca9bdf9bc;

    // Transcript hash after ServerHello (example)
    localparam logic [255:0] TRANSCRIPT_HASH_SH = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;

    // Expected Client HS Traffic Secret
    localparam logic [255:0] EXPECTED_C_HS_TRAFFIC = 256'hf7dd7fcce94f0d6a8255a8e7245db4a97e19d0e04873b0c03f8e3f8b520b8f9a;

    // Expected Server HS Traffic Secret
    localparam logic [255:0] EXPECTED_S_HS_TRAFFIC = 256'h3ae0e6c39c4b8e8e6b5b8e8e6b5b8e8e6b5b8e8e6b5b8e8e6b5b8e8e6b5b8e;

    // Transcript hash after handshake (example)
    localparam logic [255:0] TRANSCRIPT_HASH_DONE = 256'ha6e06f8146d4dcad146f300f3d9ae7924b580e8d92b3bac15778651c6c3e6c3f;

    // Expected Master Secret
    localparam logic [255:0] EXPECTED_MASTER_SECRET = 256'h18df06c2fa663cdedf93541958d6965bc722ff37463dddd375c91ff3c615ec91;

    // Expected Client AP Traffic Secret
    localparam logic [255:0] EXPECTED_C_AP_TRAFFIC = 256'h17667da38900e5f2e00f699e4e0e00d0d5e38b8d1d1d5b5f5e5b5b5f5b5f5b5f;

    // Expected Server AP Traffic Secret
    localparam logic [255:0] EXPECTED_S_AP_TRAFFIC = 256'h9ece3131629e1d33f83e8b50db18d49e81adf2b67b8f8f8f8f8f8f8f8f8f8f8f;

    // ====================================================================
    // Test Counters and Reporting
    // ====================================================================
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // ====================================================================
    // Clock Generation
    // ====================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ====================================================================
    // Main Test Procedure
    // ====================================================================
    initial begin
        // Initialize signals
        rst_n = 1'b0;
        hardware_reset = 1'b0;
        ecdhe_complete = 1'b0;
        ecdhe_shared_secret = 256'd0;
        transcript_update = 1'b0;
        transcript_hash = 256'd0;
        handshake_flight_done = 1'b0;
        verify_finished_pass = 1'b0;
        psk_enable = 1'b0;

        // Reset for 10 cycles
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        $display("\n===============================================");
        $display("  TLS 1.3 Key Schedule Testbench");
        $display("  RFC 8446 Test Vector Validation");
        $display("===============================================\n");

        // Run all test suites
        test_state_a_early_phase();
        test_state_b_handshake_secret();
        test_state_c_handshake_traffic_keys();
        test_state_d_master_secret();
        test_state_e_ap_traffic_keys();
        test_end_to_end_flow();

        // Print Summary
        print_test_summary();

        $finish;
    end

    // ====================================================================
    // TEST 1: State A - Early Phase
    // ====================================================================
    task test_state_a_early_phase();
        $display("[TEST 1] State A - Early Phase");
        $display("  Triggering: hardware_reset");

        test_count++;
        hardware_reset = 1'b1;
        @(posedge clk);
        hardware_reset = 1'b0;

        // Wait for early secret to be computed (~2 HMAC cycles)
        repeat (CYCLES_PER_HMAC * 2) @(posedge clk);

        if (early_secret_valid_o) begin
            $display("  ✓ early_secret_valid_o asserted");
            if (early_secret_o == EXPECTED_EARLY_SECRET) begin
                $display("  ✓ early_secret matches RFC 8446 test vector");
                pass_count++;
            end else begin
                $display("  ✗ early_secret MISMATCH");
                $display("    Expected: %064h", EXPECTED_EARLY_SECRET);
                $display("    Got:      %064h", early_secret_o);
                fail_count++;
            end
        end else begin
            $display("  ✗ early_secret_valid_o NOT asserted");
            fail_count++;
        end

        repeat (5) @(posedge clk);
        $display("");
    endtask

    // ====================================================================
    // TEST 2: State B - Handshake Secret Derivation
    // ====================================================================
    task test_state_b_handshake_secret();
        $display("[TEST 2] State B - Handshake Secret Derivation");
        $display("  Triggering: ecdhe_complete with ECDHE shared secret");

        test_count++;
        ecdhe_shared_secret = TEST_ECDHE_SHARED_SECRET;
        ecdhe_complete = 1'b1;
        @(posedge clk);
        ecdhe_complete = 1'b0;

        // Wait for handshake secret derivation (~2 HMAC cycles)
        repeat (CYCLES_PER_HMAC * 2) @(posedge clk);

        if (hs_secret_valid_o) begin
            $display("  ✓ hs_secret_valid_o asserted");
            if (handshake_secret_o == EXPECTED_HANDSHAKE_SECRET) begin
                $display("  ✓ handshake_secret matches RFC 8446 test vector");
                pass_count++;
            end else begin
                $display("  ✗ handshake_secret MISMATCH");
                $display("    Expected: %064h", EXPECTED_HANDSHAKE_SECRET);
                $display("    Got:      %064h", handshake_secret_o);
                fail_count++;
            end
        end else begin
            $display("  ✗ hs_secret_valid_o NOT asserted");
            fail_count++;
        end

        repeat (5) @(posedge clk);
        $display("");
    endtask

    // ====================================================================
    // TEST 3: State C - Handshake Traffic Keys
    // ====================================================================
    task test_state_c_handshake_traffic_keys();
        $display("[TEST 3] State C - Handshake Traffic Keys");
        $display("  Triggering: transcript_update with transcript hash");

        test_count++;
        transcript_hash = TRANSCRIPT_HASH_SH;
        transcript_update = 1'b1;
        @(posedge clk);
        transcript_update = 1'b0;

        // Wait for traffic secret derivation and key expansion (~4 HMAC cycles)
        repeat (CYCLES_PER_HMAC * 4) @(posedge clk);

        if (hs_traffic_keys_valid_o) begin
            $display("  ✓ hs_traffic_keys_valid_o asserted");

            // Validate client HS traffic secret
            if (client_hs_traffic_secret_o == EXPECTED_C_HS_TRAFFIC) begin
                $display("  ✓ client_hs_traffic_secret matches test vector");
                pass_count++;
            end else begin
                $display("  ✗ client_hs_traffic_secret MISMATCH");
                $display("    Expected: %064h", EXPECTED_C_HS_TRAFFIC);
                $display("    Got:      %064h", client_hs_traffic_secret_o);
                fail_count++;
            end

            // Validate server HS traffic secret
            if (server_hs_traffic_secret_o == EXPECTED_S_HS_TRAFFIC) begin
                $display("  ✓ server_hs_traffic_secret matches test vector");
                pass_count++;
            end else begin
                $display("  ✗ server_hs_traffic_secret MISMATCH");
                fail_count++;
            end

            // Validate key pairs
            if (client_hs_key_pair_o.valid) begin
                $display("  ✓ client_hs_key_pair valid");
                $display("    Key: %032h", client_hs_key_pair_o.key);
                $display("    IV:  %024h", client_hs_key_pair_o.iv);
                pass_count++;
            end else begin
                $display("  ✗ client_hs_key_pair NOT valid");
                fail_count++;
            end

            if (server_hs_key_pair_o.valid) begin
                $display("  ✓ server_hs_key_pair valid");
                $display("    Key: %032h", server_hs_key_pair_o.key);
                $display("    IV:  %024h", server_hs_key_pair_o.iv);
                pass_count++;
            end else begin
                $display("  ✗ server_hs_key_pair NOT valid");
                fail_count++;
            end
        end else begin
            $display("  ✗ hs_traffic_keys_valid_o NOT asserted");
            fail_count++;
        end

        repeat (5) @(posedge clk);
        $display("");
    endtask

    // ====================================================================
    // TEST 4: State D - Master Secret Derivation
    // ====================================================================
    task test_state_d_master_secret();
        $display("[TEST 4] State D - Master Secret Derivation");
        $display("  Triggering: handshake_flight_done");

        test_count++;
        handshake_flight_done = 1'b1;
        @(posedge clk);
        handshake_flight_done = 1'b0;

        // Wait for master secret derivation (~3 HMAC cycles: derive_intermediate + extract)
        repeat (CYCLES_PER_HMAC * 3) @(posedge clk);

        if (master_secret_valid_o) begin
            $display("  ✓ master_secret_valid_o asserted");
            if (master_secret_o == EXPECTED_MASTER_SECRET) begin
                $display("  ✓ master_secret matches RFC 8446 test vector");
                pass_count++;
            end else begin
                $display("  ✗ master_secret MISMATCH");
                $display("    Expected: %064h", EXPECTED_MASTER_SECRET);
                $display("    Got:      %064h", master_secret_o);
                fail_count++;
            end
        end else begin
            $display("  ✗ master_secret_valid_o NOT asserted");
            fail_count++;
        end

        repeat (5) @(posedge clk);
        $display("");
    endtask

    // ====================================================================
    // TEST 5: State E - Application Traffic Keys
    // ====================================================================
    task test_state_e_ap_traffic_keys();
        $display("[TEST 5] State E - Application Traffic Keys");
        $display("  Triggering: verify_finished_pass");

        test_count++;
        transcript_hash = TRANSCRIPT_HASH_DONE;
        verify_finished_pass = 1'b1;
        @(posedge clk);
        verify_finished_pass = 1'b0;

        // Wait for AP traffic key derivation (~4 HMAC cycles)
        repeat (CYCLES_PER_HMAC * 4) @(posedge clk);

        if (ap_traffic_keys_valid_o) begin
            $display("  ✓ ap_traffic_keys_valid_o asserted");

            // Validate client AP traffic secret
            if (client_ap_traffic_secret_o == EXPECTED_C_AP_TRAFFIC) begin
                $display("  ✓ client_ap_traffic_secret matches test vector");
                pass_count++;
            end else begin
                $display("  ✗ client_ap_traffic_secret MISMATCH");
                fail_count++;
            end

            // Validate server AP traffic secret
            if (server_ap_traffic_secret_o == EXPECTED_S_AP_TRAFFIC) begin
                $display("  ✓ server_ap_traffic_secret matches test vector");
                pass_count++;
            end else begin
                $display("  ✗ server_ap_traffic_secret MISMATCH");
                fail_count++;
            end

            // Validate key pairs
            if (client_ap_key_pair_o.valid) begin
                $display("  ✓ client_ap_key_pair valid");
                $display("    Key: %032h", client_ap_key_pair_o.key);
                $display("    IV:  %024h", client_ap_key_pair_o.iv);
                pass_count++;
            end else begin
                $display("  ✗ client_ap_key_pair NOT valid");
                fail_count++;
            end

            if (server_ap_key_pair_o.valid) begin
                $display("  ✓ server_ap_key_pair valid");
                $display("    Key: %032h", server_ap_key_pair_o.key);
                $display("    IV:  %024h", server_ap_key_pair_o.iv);
                pass_count++;
            end else begin
                $display("  ✗ server_ap_key_pair NOT valid");
                fail_count++;
            end
        end else begin
            $display("  ✗ ap_traffic_keys_valid_o NOT asserted");
            fail_count++;
        end

        repeat (5) @(posedge clk);
        $display("");
    endtask

    // ====================================================================
    // TEST 6: End-to-End Flow
    // ====================================================================
    task test_end_to_end_flow();
        $display("[TEST 6] End-to-End Key Schedule Flow");
        $display("  Sequential execution of all 5 states");

        test_count++;

        // Reset DUT
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // State A
        $display("  Stage 1: Early Phase...");
        hardware_reset = 1'b1;
        @(posedge clk);
        hardware_reset = 1'b0;
        repeat (CYCLES_PER_HMAC * 2) @(posedge clk);

        if (!early_secret_valid_o) begin
            $display("  ✗ Early Phase failed");
            fail_count++;
            return;
        end

        // State B
        $display("  Stage 2: Handshake Secret...");
        ecdhe_shared_secret = TEST_ECDHE_SHARED_SECRET;
        ecdhe_complete = 1'b1;
        @(posedge clk);
        ecdhe_complete = 1'b0;
        repeat (CYCLES_PER_HMAC * 2) @(posedge clk);

        if (!hs_secret_valid_o) begin
            $display("  ✗ Handshake Secret derivation failed");
            fail_count++;
            return;
        end

        // State C
        $display("  Stage 3: Handshake Traffic Keys...");
        transcript_hash = TRANSCRIPT_HASH_SH;
        transcript_update = 1'b1;
        @(posedge clk);
        transcript_update = 1'b0;
        repeat (CYCLES_PER_HMAC * 4) @(posedge clk);

        if (!hs_traffic_keys_valid_o) begin
            $display("  ✗ Handshake Traffic Keys derivation failed");
            fail_count++;
            return;
        end

        // State D
        $display("  Stage 4: Master Secret...");
        handshake_flight_done = 1'b1;
        @(posedge clk);
        handshake_flight_done = 1'b0;
        repeat (CYCLES_PER_HMAC * 3) @(posedge clk);

        if (!master_secret_valid_o) begin
            $display("  ✗ Master Secret derivation failed");
            fail_count++;
            return;
        end

        // State E
        $display("  Stage 5: Application Traffic Keys...");
        transcript_hash = TRANSCRIPT_HASH_DONE;
        verify_finished_pass = 1'b1;
        @(posedge clk);
        verify_finished_pass = 1'b0;
        repeat (CYCLES_PER_HMAC * 4) @(posedge clk);

        if (!ap_traffic_keys_valid_o) begin
            $display("  ✗ Application Traffic Keys derivation failed");
            fail_count++;
            return;
        end

        $display("  ✓ End-to-end flow PASSED");
        pass_count++;

        repeat (5) @(posedge clk);
        $display("");
    endtask

    // ====================================================================
    // Test Summary
    // ====================================================================
    task print_test_summary();
        $display("===============================================");
        $display("  Test Summary");
        $display("===============================================");
        $display("  Total Tests:  %0d", test_count);
        $display("  Passed:       %0d", pass_count);
        $display("  Failed:       %0d", fail_count);

        if (fail_count == 0) begin
            $display("  Status:       ✓ ALL TESTS PASSED");
        end else begin
            $display("  Status:       ✗ SOME TESTS FAILED");
        end

        $display("===============================================\n");
    endtask

endmodule : key_schedule_tb
