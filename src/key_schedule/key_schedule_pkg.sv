`timescale 1ns / 1ps

// ============================================================================
// key_schedule_pkg.sv
// Package containing parameters, typedefs, and constants for TLS 1.3 Key Schedule
// ============================================================================

package key_schedule_pkg;

    // ========================================================================
    // Global Parameters (TLS 1.3 with SHA256)
    // ========================================================================

    // Hash and HMAC
    localparam int HASH_LENGTH          = 32;      // SHA256 = 256 bits = 32 bytes
    localparam int HASH_WIDTH           = 256;
    localparam int HMAC_OUTPUT_WIDTH    = 256;
    localparam int HMAC_KEY_WIDTH       = 256;

    // AES-GCM Parameters
    localparam int TRAFFIC_KEY_WIDTH    = 128;    // 128-bit AES key
    localparam int TRAFFIC_IV_WIDTH     = 96;     // 96-bit IV

    // HKDF-Expand Label Input Parameters
    localparam int HKDF_LABEL_LENGTH_BITS = 16;   // Length of label in HKDF-Expand
    localparam int HKDF_INFO_MAX_SIZE    = 128;   // Max info size (label + context)

    // ========================================================================
    // Key Schedule FSM States (5 states as per TLS 1.3)
    // ========================================================================

    typedef enum logic [2:0] {
        KS_EARLY                 = 3'b000,  // State A: Early Phase
        KS_HS_SECRET             = 3'b001,  // State B: Handshake Secret Derivation
        KS_HS_TRAFFIC            = 3'b010,  // State C: Handshake Traffic Keys
        KS_MASTER_SECRET         = 3'b011,  // State D: Master Secret Derivation
        KS_AP_TRAFFIC            = 3'b100   // State E: Application Traffic Keys
    } ks_state_t;

    // ========================================================================
    // Crypto Core Operation Types (for multiplexer)
    // ========================================================================

    typedef enum logic [2:0] {
        CRYPTO_IDLE              = 3'b000,
        CRYPTO_HKDF_EXTRACT      = 3'b001,  // HMAC-SHA256(salt, ikm)
        CRYPTO_HKDF_EXPAND_LABEL = 3'b010,  // HMAC-SHA256 with TLS label expansion
        CRYPTO_DERIVE_DERIVED    = 3'b011   // HKDF-Expand with "derived" label
    } crypto_op_t;

    // ========================================================================
    // Derived Secret Types (for internal routing)
    // ========================================================================

    typedef enum logic [2:0] {
        SECRET_EARLY             = 3'b000,
        SECRET_HS                = 3'b001,  // Handshake Secret
        SECRET_MASTER            = 3'b010,  // Master Secret
        SECRET_DERIVED           = 3'b011,  // Intermediate "derived" secret
        SECRET_C_HS_TRAFFIC      = 3'b100,  // Client Handshake Traffic Secret
        SECRET_S_HS_TRAFFIC      = 3'b101,  // Server Handshake Traffic Secret
        SECRET_C_AP_TRAFFIC      = 3'b110,  // Client Application Traffic Secret
        SECRET_S_AP_TRAFFIC      = 3'b111   // Server Application Traffic Secret
    } secret_type_t;

    // ========================================================================
    // HKDF-Expand Label Constants (RFC 8446)
    // ========================================================================

    // Label strings for key derivation
    parameter string LABEL_C_HS_TRAFFIC  = "c hs traffic";
    parameter string LABEL_S_HS_TRAFFIC  = "s hs traffic";
    parameter string LABEL_C_AP_TRAFFIC  = "c ap traffic";
    parameter string LABEL_S_AP_TRAFFIC  = "s ap traffic";
    parameter string LABEL_DERIVED       = "derived";
    parameter string LABEL_KEY           = "key";
    parameter string LABEL_IV            = "iv";
    parameter string LABEL_FINISHED      = "finished";

    // ========================================================================
    // Secrets Storage (packed structures)
    // ========================================================================

    // 256-bit secrets (SHA256 output = 32 bytes = 256 bits)
    typedef struct packed {
        logic [255:0] secret;
        logic         valid;
    } secret_register_t;

    // Traffic Key (key + IV pair)
    typedef struct packed {
        logic [127:0] key;                  // 128-bit AES key
        logic [95:0]  iv;                   // 96-bit IV
        logic         valid;
    } traffic_key_pair_t;

    // Finished key (for verify_data in Finished message)
    typedef struct packed {
        logic [255:0] finished_key;         // HMAC key for Finished message
        logic         valid;
    } finished_key_t;

    // ========================================================================
    // Transcript Snapshot Registers
    // ========================================================================

    typedef struct packed {
        logic [255:0] hash_after_sh;        // Transcript hash after ServerHello
        logic [255:0] hash_after_cert;      // Transcript hash after Certificate(s)
        logic [255:0] hash_after_cert_verify; // Transcript hash after CertificateVerify
        logic [255:0] hash_at_finished;     // Transcript hash at Finished
    } transcript_snapshot_t;

    // ========================================================================
    // Control Signals for Key Schedule FSM
    // ========================================================================

    // Trigger signals from session controller / lower layers
    typedef struct packed {
        logic hardware_reset;               // Start early phase
        logic ecdhe_complete;               // Shared secret ready
        logic transcript_after_sh;          // Transcript hash updated after ServerHello
        logic handshake_done;               // Handshake flight complete
        logic finished_verify_pass;         // verify_finished passed
    } ks_trigger_t;

    // Output completion flags to session controller
    typedef struct packed {
        logic early_secret_valid;
        logic hs_secret_valid;
        logic hs_traffic_keys_valid;
        logic master_secret_valid;
        logic ap_traffic_keys_valid;
    } ks_status_t;

endpackage : key_schedule_pkg
