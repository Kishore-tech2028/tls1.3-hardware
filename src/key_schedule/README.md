# TLS 1.3 Key Schedule Hardware Implementation

## Overview

This module implements the complete TLS 1.3 key schedule for hardware RTL, following RFC 8446. The implementation derives all cryptographic secrets and traffic keys through five distinct states, optimized for resource sharing and high performance.

## Architecture

### Module Hierarchy

```
key_schedule_top.sv (Top-level module)
│
├── key_schedule_fsm.sv (5-state FSM orchestrator)
│   │
│   ├── State A: Early Phase
│   │   └── hkdf_extract (early_secret = HKDF-Extract(0, 0))
│   │
│   ├── State B: Handshake Secret
│   │   ├── handshake_secret_deriver
│   │   └── hkdf_extract (hs_secret = HKDF-Extract(early_secret, ECDHE))
│   │
│   ├── State C: Handshake Traffic Keys
│   │   ├── client_hs_traffic_deriver
│   │   │   └── hkdf_expand_label ("c hs traffic")
│   │   ├── server_hs_traffic_deriver
│   │   │   └── hkdf_expand_label ("s hs traffic")
│   │   ├── traffic_key_expander (for each)
│   │   │   ├── write_key_deriver → hkdf_expand_label ("key")
│   │   │   └── write_iv_deriver → hkdf_expand_label ("iv")
│   │
│   ├── State D: Master Secret
│   │   ├── master_secret_deriver
│   │   │   ├── derive_secret_intermediate
│   │   │   │   └── hkdf_expand_label ("derived")
│   │   │   └── hkdf_extract (master = HKDF-Extract(derived, 0))
│   │
│   └── State E: Application Traffic Keys
│       ├── client_ap_traffic_deriver
│       │   └── hkdf_expand_label ("c ap traffic")
│       ├── server_ap_traffic_deriver
│       │   └── hkdf_expand_label ("s ap traffic")
│       ├── traffic_key_expander (for each)
│       │   ├── write_key_deriver → hkdf_expand_label ("key")
│       │   └── write_iv_deriver → hkdf_expand_label ("iv")
```

## Key Schedule States

### State A: Early Phase
**Trigger:** Hardware reset / Initializing handshake
**Operation:** Derives early secret for PSK mode (when applicable)
```
early_secret = HKDF-Extract(salt=0, ikm=0)
```
**Output:** Early Secret (256 bits)

### State B: Handshake Secret Derivation
**Trigger:** x25519_scalar_mul completes (ECDHE shared secret ready)
**Operation:** Uses early secret as salt and ECDHE output as IKM
```
handshake_secret = HKDF-Extract(salt=early_secret, ikm=ecdhe_shared_secret)
```
**Output:** Handshake Secret (256 bits)

### State C: Generating Handshake Traffic Keys
**Trigger:** Transcript hash available after ServerHello
**Modules:** client_hs_traffic_deriver, server_hs_traffic_deriver, traffic_key_expander
**Operation:** Uses HKDF-Expand-Label with transcript snapshot
```
client_hs_traffic_secret = HKDF-Expand-Label(handshake_secret, "c hs traffic", transcript_hash, 256)
server_hs_traffic_secret = HKDF-Expand-Label(handshake_secret, "s hs traffic", transcript_hash, 256)

client_hs_key = HKDF-Expand-Label(client_hs_traffic_secret, "key", "", 128)
client_hs_iv = HKDF-Expand-Label(client_hs_traffic_secret, "iv", "", 96)
```
**Output:** 4 traffic key pairs (client/server × handshake traffic keys + IVs)

### State D: Master Secret Derivation
**Trigger:** Handshake flight completes successfully
**Operation:** Two-stage process
```
Stage 1: derived = HKDF-Expand-Label(handshake_secret, "derived", "", 256)
Stage 2: master_secret = HKDF-Extract(salt=derived, ikm=0)
```
**Output:** Master Secret (256 bits)

### State E: Generating Application Traffic Keys
**Trigger:** verify_finished passes (Handshake finishes successfully)
**Modules:** client_ap_traffic_deriver, server_ap_traffic_deriver, traffic_key_expander
**Operation:** Similar to State C, but using master secret and final transcript hash
```
client_ap_traffic_secret = HKDF-Expand-Label(master_secret, "c ap traffic", final_transcript_hash, 256)
server_ap_traffic_secret = HKDF-Expand-Label(master_secret, "s ap traffic", final_transcript_hash, 256)

client_ap_key = HKDF-Expand-Label(client_ap_traffic_secret, "key", "", 128)
client_ap_iv = HKDF-Expand-Label(client_ap_traffic_secret, "iv", "", 96)
```
**Output:** 4 traffic key pairs (client/server × application traffic keys + IVs)

## Hardware Implementation Considerations

### 1. Resource Sharing (Critical for Area Efficiency)

**Problem:** Multiple modules (hkdf_extract, hkdf_expand_label) need HMAC-SHA256, leading to area bloat if instantiated separately.

**Solution:** 
- Instantiate a single, shared `crypto_core` (HMAC/SHA256 block)
- Implement a multiplexer driven by the key_schedule_fsm to route:
  - Input parameters (salts, labels, context hashes)
  - Operation types (extract vs expand)
  - Arbitration between parallel requests

**Current Implementation Note:**
The provided RTL instantiates separate modules for clarity. For production:
1. Create a central `hmac_sha256_core.sv` with handshake protocol
2. Implement `crypto_core_mux.sv` to arbitrate 4-8 requesters
3. Replace HMAC instantiations with mux outputs
4. This reduces HMAC blocks from 8+ to 1, saving ~80% crypto area

### 2. Transcript Isolation (Critical for Timing Safety)

**Problem:** Modules need transcript hash at different stages, but reading from live hash engine during computation causes race conditions.

**Solution:**
- Maintain stable snapshot registers (`transcript_snapshot_t`)
- Key registers:
  - `snap_after_sh`: Transcript hash after ServerHello (used for handshake traffic derivation)
  - `snap_after_cert`: Transcript hash after Certificate(s)
  - `snap_after_cert_verify`: Transcript hash after CertificateVerify
  - `snap_at_finished`: Final transcript hash after all handshake messages
- FSM updates snapshots at well-defined points, not during derivation
- All derivers read only from stable snapshots

**Current Implementation:**
- Snapshots captured as inputs from external transcript_hash_engine
- FSM coordinates timing of snapshot updates with derivation triggers
- Future: Add snapshot register file to key_schedule module

### 3. Pipeline and Latency Optimization

**Two-cycle vs. One-cycle Design:**
- HMAC-SHA256 requires ~100-200 cycles in hardware
- Each traffic secret derivation (hkdf_expand_label) takes 2+ HMAC operations
- Architecture overlaps computation where possible:
  - Client and server traffic derivers run in parallel
  - Key and IV derivation happen in parallel within traffic_key_expander

**Latency Path:**
```
State A: 1 HMAC → early_secret (100+ cycles)
State B: 1 HMAC → handshake_secret (100+ cycles)
State C: 4 HMACs in parallel (2 traffic secrets + 4 key/IV pairs) (~200 cycles total)
State D: 1 Expand + 1 Extract → master_secret (~300+ cycles)
State E: 4 HMACs in parallel → AP traffic keys (~200 cycles total)
```

**Total handshake latency with key schedule: ~1000+ cycles** (assuming 100MHz clock)

## Module Interfaces

### key_schedule_top

**Input Signals:**
- `clk`, `rst_n`: Clock and reset
- `hardware_reset`: Trigger State A
- `ecdhe_complete`: Trigger State B
- `ecdhe_shared_secret[255:0]`: x25519 output
- `transcript_update`: Trigger snapshot update
- `transcript_hash[255:0]`: Latest transcript hash
- `handshake_flight_done`: Trigger State D
- `verify_finished_pass`: Trigger State E

**Output Signals:**
- `early_secret_o[255:0]`
- `handshake_secret_o[255:0]`
- `master_secret_o[255:0]`
- `client_hs_traffic_secret_o[255:0]`, `server_hs_traffic_secret_o[255:0]`
- `client_ap_traffic_secret_o[255:0]`, `server_ap_traffic_secret_o[255:0]`
- `client_hs_key_pair_o`, `server_hs_key_pair_o`, `client_ap_key_pair_o`, `server_ap_key_pair_o`
  - Each `traffic_key_pair_t` contains: `key[127:0]`, `iv[95:0]`, `valid`
- Status flags: `*_valid_o`

## Integration with Other Modules

### With Session Controller
- The session_controller triggers state transitions via `hardware_reset`, `handshake_flight_done`, etc.
- Polls `*_valid_o` flags to gate downstream operations

### With Record Layer
- Record layer consumes traffic key pairs (`client_hs_key_pair_o`, `server_ap_key_pair_o`, etc.)
- Uses keys for AES-GCM encryption/decryption

### With Transcript Hash Engine
- Key schedule reads transcript snapshots from external engine
- Depends on transcript_hash_engine keeping `snap_after_sh`, `snap_after_cert`, etc. stable

## Testing and Verification

### Test Vectors (RFC 8446 Appendix A)
All modules should be verified against official TLS 1.3 test vectors:
- Early secret, handshake secret, master secret
- Handshake traffic secrets and keys
- Application traffic secrets and keys

### Key Schedule Validation
1. Verify HKDF-Extract correctness (HMAC-SHA256)
2. Verify HKDF-Expand-Label with TLS label prefix
3. End-to-end test: input ECDHE secret → verify all 8 secrets
4. Latency measurement: cycle count from reset to `ap_traffic_keys_valid_o`

## Future Enhancements

1. **PSK (Pre-Shared Key) Mode:** Currently skeleton; implement resumption path
2. **Exporter Support:** RFC 8446 § 7.5 exporters
3. **Crypto Core Integration:** Replace individual HMAC modules with shared hardware block
4. **Performance Counters:** Add instrumentation for cycle profiling
5. **Key Wrapping:** Support for RFC 3394 key wrap for export to secure storage
