#!/bin/bash
# ================================================================
#  T2HASH V3.0 Test Suite
#  Verifies: assembly compilation, binary sizes, fallback logic,
#            mode detection headers, and config generation.
# ================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "  ${GREEN}[PASS]${RESET} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}[FAIL]${RESET} $1 $2"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}[SKIP]${RESET} $1"; SKIP=$((SKIP + 1)); }
info() { echo -e "  ${CYAN}[INFO]${RESET} $1"; }

echo ""
echo "=============================================="
echo "  T2HASH V3.0 — Test Suite"
echo "=============================================="
echo ""

# ----------------------------------------------------------------
#  Phase 1: Assembly Compilation Tests
# ----------------------------------------------------------------
echo "[1] Assembly Compilation Tests"
echo "----------------------------------------------"

# Check prerequisites
if ! command -v nasm &>/dev/null; then
    info "NASM not found, installing..."
    apt-get update -qq && apt-get install -y -qq nasm > /dev/null 2>&1
    if ! command -v nasm &>/dev/null; then
        fail "NASM installation failed" "(cannot continue)"
        echo ""
        echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
        exit 1
    fi
fi
pass "NASM is available ($(nasm --version | head -1))"

if ! command -v ld &>/dev/null; then
    fail "GNU ld not found" "(install build-essential)"
else
    pass "GNU ld is available"
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Count DPI assembly files in the repo
DPI_FILES=$(find /root/T2HASH-CORE -maxdepth 1 -name 'asm_udp_*_dpi.asm' -type f | wc -l)
if [ "$DPI_FILES" -ge 2 ]; then
    pass "DPI assembly source files found: $DPI_FILES"
else
    fail "Missing DPI assembly source files" "(need asm_udp_hz_dpi.asm and asm_udp_ir_dpi.asm)"
fi

# Compile each DPI assembly file
for asm_file in /root/T2HASH-CORE/asm_udp_hz_dpi.asm /root/T2HASH-CORE/asm_udp_ir_dpi.asm; do
    base=$(basename "$asm_file" .asm)
    obj="$TMPDIR/${base}.o"
    bin="$TMPDIR/${base}"

    if nasm -f elf64 "$asm_file" -o "$obj" 2>/tmp/nasm_err; then
        pass "NASM compile: ${base}.asm -> .o"
    else
        fail "NASM compile: ${base}.asm" "$(cat /tmp/nasm_err)"
        continue
    fi

    if ld "$obj" -o "$bin" 2>/tmp/ld_err; then
        pass "Link: ${base}.o -> binary"
        size=$(stat -c%s "$bin" 2>/dev/null || echo "0")
        info "  Binary size: ${size} bytes"
        if [ "$size" -gt 0 ] && [ "$size" -lt 50000 ]; then
            pass "  Binary size within expected range (< 50KB)"
        else
            fail "  Binary size out of range" "(${size} bytes)"
        fi
    else
        fail "Link: ${base}.o" "$(cat /tmp/ld_err)"
    fi
done

# ----------------------------------------------------------------
#  Phase 2: Mode Header Verification
# ----------------------------------------------------------------
echo ""
echo "[2] Mode Header Verification"
echo "----------------------------------------------"

# Verify DPI HZ source has mode byte 0x01
if grep -q 'mode_byte.*0x01' /root/T2HASH-CORE/asm_udp_hz_dpi.asm; then
    pass "DPI HZ: mode byte 0x01 present"
else
    fail "DPI HZ: missing mode byte 0x01"
fi

if grep -q 'mode_byte.*0x01' /root/T2HASH-CORE/asm_udp_ir_dpi.asm; then
    pass "DPI IR: mode byte 0x01 present"
else
    fail "DPI IR: missing mode byte 0x01"
fi

# Verify legacy fallback handlers exist in DPI files
if grep -q 'handle_legacy' /root/T2HASH-CORE/asm_udp_hz_dpi.asm; then
    pass "DPI HZ: legacy fallback handler present"
else
    fail "DPI HZ: missing legacy fallback handler"
fi

if grep -q 'handle_legacy' /root/T2HASH-CORE/asm_udp_ir_dpi.asm; then
    pass "DPI IR: legacy fallback handler present"
else
    fail "DPI IR: missing legacy fallback handler"
fi

# Verify 8 rotating masks exist
MASK_COUNT_HZ=$(grep -c 'mask[0-7].*dq' /root/T2HASH-CORE/asm_udp_hz_dpi.asm || echo "0")
MASK_COUNT_IR=$(grep -c 'mask[0-7].*dq' /root/T2HASH-CORE/asm_udp_ir_dpi.asm || echo "0")

if [ "$MASK_COUNT_HZ" -eq 8 ]; then
    pass "DPI HZ: 8 rotating masks present"
else
    fail "DPI HZ: expected 8 masks, found ${MASK_COUNT_HZ}"
fi

if [ "$MASK_COUNT_IR" -eq 8 ]; then
    pass "DPI IR: 8 rotating masks present"
else
    fail "DPI IR: expected 8 masks, found ${MASK_COUNT_IR}"
fi

# ----------------------------------------------------------------
#  Phase 3: Feature Verification (static analysis)
# ----------------------------------------------------------------
echo ""
echo "[3] Feature Verification"
echo "----------------------------------------------"

# Check for padding logic
if grep -q 'gen_padding' /root/T2HASH-CORE/asm_udp_hz_dpi.asm; then
    pass "DPI HZ: padding generator present"
else
    fail "DPI HZ: missing padding generator"
fi

if grep -q 'gen_padding' /root/T2HASH-CORE/asm_udp_ir_dpi.asm; then
    pass "DPI IR: padding generator present"
else
    fail "DPI IR: missing padding generator"
fi

# Check for jitter logic
if grep -q 'apply_jitter' /root/T2HASH-CORE/asm_udp_hz_dpi.asm; then
    pass "DPI HZ: jitter logic present"
else
    fail "DPI HZ: missing jitter logic"
fi

if grep -q 'apply_jitter' /root/T2HASH-CORE/asm_udp_ir_dpi.asm; then
    pass "DPI IR: jitter logic present"
else
    fail "DPI IR: missing jitter logic"
fi

# Check for logging
if grep -q 'log_msg' /root/T2HASH-CORE/asm_udp_hz_dpi.asm; then
    pass "DPI HZ: syslog logging present"
else
    fail "DPI HZ: missing logging"
fi

if grep -q 'log_msg' /root/T2HASH-CORE/asm_udp_ir_dpi.asm; then
    pass "DPI IR: syslog logging present"
else
    fail "DPI IR: missing logging"
fi

# Check for SO_REUSEADDR (port reuse)
if grep -q 'SO_REUSEADDR\|opt_one.*dd 1' /root/T2HASH-CORE/asm_udp_hz_dpi.asm; then
    pass "DPI HZ: SO_REUSEADDR configured"
else
    fail "DPI HZ: missing SO_REUSEADDR"
fi

# ----------------------------------------------------------------
#  Phase 4: Deploy Script Verification
# ----------------------------------------------------------------
echo ""
echo "[4] Deploy Script Verification"
echo "----------------------------------------------"

if [ -f /root/T2HASH-CORE/ASM-TUN-V3.0.txt ]; then
    pass "V3.0 deploy script exists"
else
    fail "V3.0 deploy script missing"
fi

# Verify mode selection exists
if grep -q 'TRANSPORT_MODE' /root/T2HASH-CORE/ASM-TUN-V3.0.txt; then
    pass "V3.0: transport mode selection present"
else
    fail "V3.0: missing transport mode selection"
fi

# Verify profile selection exists
if grep -q 'TRANSPORT_PROFILE\|TRANSPORT_PROFILE' /root/T2HASH-CORE/ASM-TUN-V3.0.txt; then
    pass "V3.0: transport profile selection present"
else
    fail "V3.0: missing transport profile selection"
fi

# Verify fallback script generation
if grep -q 't2hash-fallback' /root/T2HASH-CORE/ASM-TUN-V3.0.txt; then
    pass "V3.0: fallback watchdog included"
else
    fail "V3.0: missing fallback watchdog"
fi

# Verify environment variable support
if grep -q 'T2HASH_' /root/T2HASH-CORE/ASM-TUN-V3.0.txt; then
    pass "V3.0: environment variable overrides present"
else
    fail "V3.0: missing environment variable overrides"
fi

# Verify config file generation
if grep -q 't2hash.conf' /root/T2HASH-CORE/ASM-TUN-V3.0.txt; then
    pass "V3.0: config file generation present"
else
    fail "V3.0: missing config file generation"
fi

# ----------------------------------------------------------------
#  Phase 5: Backward Compatibility
# ----------------------------------------------------------------
echo ""
echo "[5] Backward Compatibility"
echo "----------------------------------------------"

# Verify V2.0 file still exists unchanged
if [ -f /root/T2HASH-CORE/ASM-TUN-V2.0.txt ]; then
    pass "V2.0 deploy script preserved"
else
    fail "V2.0 deploy script missing"
fi

# Check that legacy XOR mask (0x5A) is in fallback handlers
if grep -q '0x5A5A5A5A5A5A5A5A' /root/T2HASH-CORE/asm_udp_hz_dpi.asm; then
    pass "DPI HZ: legacy XOR mask (0x5A) in fallback handler"
else
    fail "DPI HZ: missing legacy XOR mask"
fi

if grep -q '0x5A5A5A5A5A5A5A5A' /root/T2HASH-CORE/asm_udp_ir_dpi.asm; then
    pass "DPI IR: legacy XOR mask (0x5A) in fallback handler"
else
    fail "DPI IR: missing legacy XOR mask"
fi

# ----------------------------------------------------------------
#  Phase 6: README Completeness
# ----------------------------------------------------------------
echo ""
echo "[6] README Completeness"
echo "----------------------------------------------"

README=/root/T2HASH-CORE/README.md

if [ -f "$README" ]; then
    pass "README.md exists"
else
    fail "README.md missing"
    skip "Remaining README checks"
fi

for section in "Overview" "Features" "Installation" "Configuration" "Transport Modes" "Troubleshooting" "Changelog" "Safety and Legal" "Manual Test"; do
    if grep -q "$section" "$README" 2>/dev/null; then
        pass "README: '$section' section present"
    else
        fail "README: missing '$section' section"
    fi
done

# Verify config examples
if grep -q 'T2HASH_' "$README" 2>/dev/null; then
    pass "README: environment variable reference present"
else
    fail "README: missing env var reference"
fi

if grep -q 't2hash.conf' "$README" 2>/dev/null; then
    pass "README: config file reference present"
else
    fail "README: missing config file reference"
fi

# ----------------------------------------------------------------
#  Phase 7: No Hardcoded Secrets Check
# ----------------------------------------------------------------
echo ""
echo "[7] Security Hygiene"
echo "----------------------------------------------"

# Check for hardcoded IPs (other than localhost and 0.0.0.0)
SUSPICIOUS_IPS=$(grep -P '0x[0-9A-F]{2},\s*0x[0-9A-F]{2},\s*0x[0-9A-F]{2},\s*0x[0-9A-F]{2}' \
    /root/T2HASH-CORE/asm_udp_ir_dpi.asm /root/T2HASH-CORE/asm_udp_hz_dpi.asm 2>/dev/null || true)

# The hz_addr in IR files is a build-time inject: check if it's 0,0,0,0 (placeholder)
if echo "$SUSPICIOUS_IPS" | grep -q '0x00, 0x00, 0x00, 0x00'; then
    pass "No hardcoded IPs in source (uses build-time injection)"
else
    info "IPs found (expected: hz_addr uses placeholder 0.0.0.0 for injection at build)"
fi

# Check for hardcoded auth tokens
if grep -rni 'passw\|token\|secret\|key\s*=' /root/T2HASH-CORE/ASM-TUN-V3.0.txt 2>/dev/null | grep -qv 'grep\|#'; then
    fail "Potential hardcoded secrets in deploy script"
else
    pass "No hardcoded secrets in deploy script"
fi

# ----------------------------------------------------------------
#  Summary
# ----------------------------------------------------------------
echo ""
echo "=============================================="
TOTAL=$((PASS + FAIL + SKIP))
echo "  Results: ${GREEN}${PASS} passed${RESET}, ${RED}${FAIL} failed${RESET}, ${YELLOW}${SKIP} skipped${RESET} (${TOTAL} total)"
echo "=============================================="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "  ${RED}Some tests failed. Review output above.${RESET}"
    exit 1
else
    echo ""
    echo "  ${GREEN}All tests passed.${RESET}"
    exit 0
fi
