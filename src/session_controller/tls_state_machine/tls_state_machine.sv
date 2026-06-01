`timescale 1ns / 1ps

module tls_state_machine (
    input  logic clk,
    input  logic rst_n,
    // Connection events
    input  logic tcp_conn,       // single-cycle pulse: new TCP connection
    input  logic tcp_disc,       // level: TCP disconnected
    // Handshake events
    input  logic ch_valid,       // ClientHello parsed OK
    input  logic sh_done,        // ServerHello fully transmitted  (NEW)
    input  logic keys_done,      // key schedule complete
    input  logic cert_done,      // Certificate + CertVerify transmitted (NEW)
    // Error
    input  logic fatal_alert,
    // Enables to downstream engines
    output logic en_sh,          // enable ServerHello builder
    output logic en_cert,        // enable Certificate builder
    output logic en_app_data,    // enable application-data path
    output logic send_alert      // pulse alert_tx_builder
);

    typedef enum logic [3:0] {
        IDLE      = 4'd0,
        WAIT_CH   = 4'd1,
        SEND_SH   = 4'd2,
        WAIT_KEYS = 4'd3,
        SEND_CERT = 4'd4,
        APP_DATA  = 4'd5,
        ALERT     = 4'd6
    } state_t;

    state_t state, next_state;
    logic send_alert_r;  // Registered send_alert to hold throughout ALERT state

    // ------------------------------------------------------------------ //
    //  State register
    // ------------------------------------------------------------------ //
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) state <= IDLE;
        else        state <= next_state;

    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) send_alert_r <= 1'b0;
        else if (state == ALERT) send_alert_r <= 1'b1;
        else if (!fatal_alert) send_alert_r <= 1'b0;

    assign send_alert = send_alert_r;

    // ------------------------------------------------------------------ //
    //  Next-state logic
    // ------------------------------------------------------------------ //
    always_comb begin
        next_state  = state;
        en_sh       = 1'b0;
        en_cert     = 1'b0;
        en_app_data = 1'b0;

        // Fatal or disconnect is a priority escape from any *active* state.
        // We do NOT apply it in IDLE or ALERT itself to avoid locking up.
        if ((tcp_disc || fatal_alert) && state != IDLE && state != ALERT) begin
            next_state = ALERT;
        end else begin
            case (state)
                IDLE: begin
                    if (tcp_conn) next_state = WAIT_CH;
                end

                WAIT_CH: begin
                    if (ch_valid) next_state = SEND_SH;
                end

                SEND_SH: begin
                    en_sh = 1'b1;
                    // Stay here until the ServerHello engine signals completion
                    if (sh_done) next_state = WAIT_KEYS;
                end

                WAIT_KEYS: begin
                    if (keys_done) next_state = SEND_CERT;
                end

                SEND_CERT: begin
                    en_cert = 1'b1;
                    // Stay here until Certificate + Finished are all sent
                    if (cert_done) next_state = APP_DATA;
                end

                APP_DATA: begin
                    en_app_data = 1'b1;
                end

                ALERT: begin
                    // Return to IDLE once disconnect clears and alert is no longer flagged
                    if (!tcp_disc && !fatal_alert) next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

endmodule