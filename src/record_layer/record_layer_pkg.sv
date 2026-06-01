`timescale 1ns / 1ps

// ============================================================================
// record_layer_pkg.sv
// Package containing parameters, typedefs, and constants for TLS 1.3 Record Layer
// ============================================================================

package record_layer_pkg;

    // ========================================================================
    // TLS Record Type Definitions (RFC 8446)
    // ========================================================================
    typedef enum logic [7:0] {
        CHANGE_CIPHER_SPEC     = 8'h14,  // 20
        ALERT                  = 8'h15,  // 21
        HANDSHAKE              = 8'h16,  // 22
        APPLICATION_DATA       = 8'h17,  // 23
        INVALID_RECORD_TYPE    = 8'hFF
    } record_type_t;

    // ========================================================================
    // Inner Content Type (for padding detection after decryption)
    // ========================================================================
    typedef enum logic [7:0] {
        ICT_INVALID            = 8'h00,
        ICT_ALERT              = 8'h15,
        ICT_HANDSHAKE          = 8'h16,
        ICT_APPLICATION_DATA   = 8'h17
    } inner_content_type_t;

    // ========================================================================
    // Handshake Type Definitions (used in RX demux)
    // ========================================================================
    typedef enum logic [7:0] {
        HS_CLIENT_HELLO        = 8'h01,
        HS_SERVER_HELLO        = 8'h02,
        HS_CERTIFICATE         = 8'h0B,
        HS_CERT_VERIFY         = 8'h0F,
        HS_FINISHED            = 8'h14
    } handshake_type_t;

    // ========================================================================
    // Global Parameters
    // ========================================================================

    // Record Frame Parameters
    localparam int RECORD_HEADER_SIZE    = 5;      // type(1) + version(2) + length(2)
    localparam int MAX_RECORD_LENGTH     = 16385;  // 2^14 + 1 (16,384 bytes for encrypted record)
    localparam int MAX_RECORD_PLAINTEXT  = 16384;  // 2^14 bytes max plaintext
    localparam int RECORD_LENGTH_BITS    = 14;     // RFC 8446: max_record_length is 14 bits

    // Handshake Frame Parameters
    localparam int HS_HEADER_SIZE        = 4;      // msg_type(1) + length(3)
    localparam int MAX_HS_MSG_LENGTH     = 16777215; // 2^24 - 1 (16 MB max handshake message)

    // GCM AEAD Parameters (for AES-128-GCM)
    localparam int GCM_TAG_LENGTH        = 16;     // 128-bit authentication tag
    localparam int GCM_IV_LENGTH         = 12;     // 96-bit implicit IV
    localparam int GCM_KEY_LENGTH        = 16;     // 128-bit key

    // FIFO Parameters
    localparam int FIFO_DEPTH            = 256;    // 256 * 32-bit entries = 1 KB per FIFO
    localparam int FIFO_ADDR_WIDTH       = 8;      // log2(256)

    // Sequence Counter (for nonce generation)
    localparam int SEQ_COUNTER_WIDTH     = 64;     // RFC 8446: 64-bit sequence numbers

    // Data Path Width
    localparam int DATA_WIDTH            = 32;     // 32-bit data path
    localparam int BYTE_WIDTH            = 8;      // 8-bit bytes

    // ========================================================================
    // TLS Version Constants
    // ========================================================================
    localparam logic [15:0] TLS_VERSION_1_2  = 16'h0303;  // For legacy record layer
    localparam logic [15:0] TLS_VERSION_1_3  = 16'h0304;  // TLS 1.3 version
    localparam logic [15:0] TLS_VERSION_LEGACY = 16'h0303; // Legacy version field (RFC 8446 §5.1)

    // ========================================================================
    // Error Codes (extended from session_controller)
    // ========================================================================
    typedef enum logic [7:0] {
        ERR_NONE                = 8'h00,
        ERR_RECORD_LENGTH       = 8'h01,
        ERR_DECRYPT_FAILED      = 8'h02,
        ERR_RECORD_TYPE_INVALID = 8'h03,
        ERR_CONTENT_TYPE_INVALID= 8'h04,
        ERR_FIFO_OVERFLOW       = 8'h05
    } record_error_t;

    // ========================================================================
    // State Machine Definitions
    // ========================================================================

    // RX Record Parser States
    typedef enum logic [2:0] {
        RX_IDLE              = 3'b000,
        RX_HEADER            = 3'b001,  // Reading 5-byte header
        RX_PAYLOAD           = 3'b010,  // Reading payload
        RX_VERIFY            = 3'b011,  // Verify record structure
        RX_DECRYPT           = 3'b100,  // Decrypt (if needed)
        RX_ERROR             = 3'b101
    } rx_parser_state_t;

    // TX Record Framer States
    typedef enum logic [2:0] {
        TX_IDLE              = 3'b000,
        TX_ENCODE_HEADER     = 3'b001,
        TX_ENCODE_LENGTH     = 3'b010,
        TX_PAYLOAD           = 3'b011,
        TX_ENCRYPT           = 3'b100
    } tx_framer_state_t;

    // ========================================================================
    // Structs for Internal Signaling
    // ========================================================================

    // Record Frame (decoded header + payload metadata)
    typedef struct packed {
        logic [7:0]  record_type;           // record_type_t
        logic [15:0] version;               // TLS version
        logic [13:0] length;                // Actual payload length (< 2^14)
        logic [FIFO_ADDR_WIDTH-1:0] addr;   // FIFO read pointer
    } record_frame_t;

    // Traffic Key (derived from key schedule)
    typedef struct packed {
        logic [127:0] key;                  // 128-bit AES key
        logic [95:0]  iv;                   // 96-bit implicit IV
        logic [63:0]  seq_num;              // 64-bit sequence number
    } traffic_key_t;

endpackage : record_layer_pkg
