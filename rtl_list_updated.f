# Updated RTL File List for Record Layer

# ============================================================================
# TLS 1.3 Record Layer - Updated Build System
# ============================================================================

# PACKAGE AND INFRASTRUCTURE
src/record_layer/record_layer_pkg.sv

# BUFFERING
src/record_layer/rx_record_fifo.sv
src/record_layer/tx_record_fifo.sv

# RX PARSER PATH
src/record_layer/rx_record_parser/record_header_parser.sv
src/record_layer/rx_record_parser/record_type_demux.sv
src/record_layer/rx_record_parser/record_length_checker.sv
src/record_layer/rx_record_parser/rx_record_parser.sv

# TX FRAMER PATH
src/record_layer/tx_record_framer/record_header_writer.sv
src/record_layer/tx_record_framer/record_length_encoder.sv
src/record_layer/tx_record_framer/tx_record_framer.sv

# ENCRYPTION WRAPPER
src/record_layer/record_encrypt_wrapper/inner_content_type_appender.sv
src/record_layer/record_encrypt_wrapper/aead_encrypt_dispatch.sv
src/record_layer/record_encrypt_wrapper/record_encrypt_wrapper.sv

# DECRYPTION WRAPPER
src/record_layer/record_decrypt_wrapper/inner_content_type_extractor.sv
src/record_layer/record_decrypt_wrapper/aead_decrypt_dispatch.sv
src/record_layer/record_decrypt_wrapper/record_decrypt_wrapper.sv

# TOP-LEVEL INTEGRATION
src/record_layer/record_layer_top.sv

# ============================================================================
# Existing Session Manager Files (keep as-is)
# ============================================================================

src/session_controller/circular_buffer/circular_buffer.sv
src/session_controller/error_aggregator/error_aggregator.sv
src/session_controller/role_config/role_config.sv
src/session_controller/session_controller.sv
src/session_controller/tcp_connection_manager/tcp_connection_manager.sv
src/session_controller/tls_state_machine/tls_state_machine.sv
tb/record_layer/tb_record_layer_basic.sv
tb/session_controller/tb_session_controller_enhanced.sv
