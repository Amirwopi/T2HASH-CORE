rm -f install.sh
cat << 'EOF' > install.sh
#!/bin/bash

# ================================================================
#  ASM-TUN v3.0 — T2HASH Layer-0 Assembly Tunnel
#  NEW: DPI-Resilient transport mode, fallback chain, config profiles
#  Optimized by: Amirwopi — Architecture & hardening
# ================================================================

set -euo pipefail

RED='\033[38;5;196m'
PINK='\033[38;5;198m'
DARK='\033[38;5;236m'
GREY='\033[38;5;245m'
WHITE='\033[1;37m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;226m'
CYAN='\033[38;5;51m'
RESET='\033[0m'

# Environment/configurable defaults (can override via env)
BUF_SIZE=${T2HASH_BUF_SIZE:-26214400}
IR_PORT=${T2HASH_IR_PORT:-7777}
HZ_PORT=${T2HASH_HZ_PORT:-443}
GOST_PORT=${T2HASH_GOST_PORT:-1080}
SOCKS_PORT=${T2HASH_SOCKS_PORT:-8081}
GOST_VERSION=${T2HASH_GOST_VERSION:-2.11.5}
MTU_SIZE=${T2HASH_MTU:-1350}
KCP_MODE=${T2HASH_KCP_MODE:-normal}
PAD_MIN=${T2HASH_PAD_MIN:-1}
PAD_MAX=${T2HASH_PAD_MAX:-128}
JITTER_MAX_US=${T2HASH_JITTER_MAX_US:-500}
FALLBACK_TIMEOUT=${T2HASH_FALLBACK_TIMEOUT:-15}
LOG_LEVEL=${T2HASH_LOG_LEVEL:-info}

# ----------------------------------------------------------------
#  Helper Functions
# ----------------------------------------------------------------
die() { echo -e "      ${RED}[FATAL]${RESET} $1" >&2; exit 1; }
info() { echo -e "      ${DARK}[+]${RESET} ${GREY}$1${RESET}"; }
ok()   { echo -e "      ${GREEN}[✓]${RESET} $1"; }
warn() { echo -e "      ${YELLOW}[!]${RESET} $1"; }
note() { echo -e "      ${CYAN}[~]${RESET} $1"; }

validate_ipv4() {
    local ip="$1"
    local IFS='.'
    local -a parts
    read -ra parts <<< "$ip"
    [[ ${#parts[@]} -ne 4 ]] && return 1
    for part in "${parts[@]}"; do
        [[ "$part" =~ ^[0-9]+$ ]] || return 1
        (( part >= 0 && part <= 255 )) || return 1
    done
    return 0
}

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    (( port >= 1 && port <= 65535 )) || return 1
    return 0
}

clear

echo -e "${RED}"
echo "  ▄▄▄█████▓ ▀████▄     ▄▄▄█████▓ ██░ ██  ▄▄▄       ██████  ██░ ██ "
echo "  ▓  ██▒ ▓▒   ██▀ ▀█   ▓  ██▒ ▓▒▓██░ ██▒▒████▄   ▒██    ▒ ▓██░ ██▒"
echo "  ▒ ▓██░ ▒░  ██   ▄▄▄  ▒ ▓██░ ▒░▒██▀▀██░▒██  ▀█▄ ░ ▓██▄   ▒██▀▀██░"
echo "  ░ ▓██▓ ░   ██▄▄▄██   ░ ▓██▓ ░ ░▓█ ░██ ░██▄▄▄▄██  ▒   ██▒░▓█ ░██ "
echo "    ▒██▒ ░    ▀▀▀▀██▒    ▒██▒ ░ ░▓█▒░██▓ ▓█   ▓██▒▒██████▒▒░▓█▒░██▓"
echo "    ▒ ░░      ░   ▒▒     ▒ ░░    ▒ ░░▒░▒ ▒▒   ▓▒█░▒ ▒▓▒ ▒ ░ ▒ ░░▒░▒"
echo "      ░       ░   ▒        ░     ▒ ░▒░ ░  ▒   ▒▒ ░░ ░▒  ░ ░ ▒ ░▒░ ░"
echo "    ░             ░      ░       ░  ░░ ░  ░   ▒   ░  ░  ░   ░  ░░ ░"
echo -e "${RESET}"
echo -e "      ${DARK}======================================================${RESET}"
echo -e "              ${PINK}Created by T2HASH  —  Layer-0 Assembly${RESET}"
echo -e "              ${CYAN}DPI-Resilient Transport  —  v3.0${RESET}"
echo -e "      ${DARK}======================================================${RESET}"
echo ""

# ----------------------------------------------------------------
#  Step 1: Server Type
# ----------------------------------------------------------------
echo -e "             ${WHITE}[ 1 ] ${GREY}Server Kharej (Hetzner / Receiver)${RESET}"
echo -e "             ${WHITE}[ 2 ] ${GREY}Server Iran (Sender)${RESET}"
echo ""
echo -e "      ${DARK}------------------------------------------------------${RESET}"
echo -ne "      ${PINK}root@t2hash${WHITE}:~#${RESET} Koodom server ro dari config mikoni? [1 ya 2]: "
read -r RAW_TYPE
SERVER_TYPE=$(echo "$RAW_TYPE" | tr -d '\r\n ')
[[ "$SERVER_TYPE" != "1" && "$SERVER_TYPE" != "2" ]] && \
    die "Entekhab eshtebah ast! Faghat 1 ya 2 vared kon."

# ----------------------------------------------------------------
#  Step 2: Transport Mode Selection (NEW in V3.0)
# ----------------------------------------------------------------
if [ "$SERVER_TYPE" == "2" ]; then
    echo ""
    while true; do
        echo -ne "      ${PINK}root@t2hash${WHITE}:~#${RESET} IP Server Kharej ro vared kon: "
        read -r RAW_IP
        OUT_IP=$(echo "$RAW_IP" | tr -d '\r\n ')
        if validate_ipv4 "$OUT_IP"; then
            IFS='.' read -r i1 i2 i3 i4 <<< "$OUT_IP"
            HEX_IP=$(printf "0x%02X, 0x%02X, 0x%02X, 0x%02X" "$i1" "$i2" "$i3" "$i4")
            ok "IP be Hex tabdil shod: ${PINK}${HEX_IP}${RESET}"
            break
        else
            warn "IP format eshtebah ast! (e.g. 1.2.3.4)"
        fi
    done
fi

echo ""
echo -e "      ${DARK}------------------------------------------------------${RESET}"
echo -e "      ${WHITE}Entekhab-e Mode Transport:${RESET}"
echo ""
echo -e "      ${WHITE}[ 1 ]${RESET} ${GREY}Legacy${RESET}     — XOR Static (V2.0 compatible, asli)"
echo -e "      ${WHITE}[ 2 ]${RESET} ${CYAN}DPI-Safe${RESET}    — Multi-mask + padding + jitter (jadid)"
echo -e "      ${WHITE}[ 3 ]${RESET} ${GREEN}Hybrid${RESET}     — DPI-Safe pishfarz + fallback be Legacy"
echo ""
echo -e "      ${DARK}------------------------------------------------------${RESET}"
echo -ne "      ${PINK}root@t2hash${WHITE}:~#${RESET} Kodoom mode? [1, 2, ya 3]: "
read -r RAW_MODE
TRANSPORT_MODE=$(echo "$RAW_MODE" | tr -d '\r\n ')
[[ "$TRANSPORT_MODE" != "1" && "$TRANSPORT_MODE" != "2" && "$TRANSPORT_MODE" != "3" ]] && \
    die "Entekhab eshtebah ast! Faghat 1, 2, ya 3 vared kon."

# ----------------------------------------------------------------
#  Step 2.5: Transport Profile (NEW for DPI-Safe/Hybrid modes)
# ----------------------------------------------------------------
TRANSPORT_PROFILE="balanced"
if [ "$TRANSPORT_MODE" == "2" ] || [ "$TRANSPORT_MODE" == "3" ]; then
    echo ""
    echo -e "      ${DARK}------------------------------------------------------${RESET}"
    echo -e "      ${WHITE}Entekhab-e Profile Transport (DPI-Resilient):${RESET}"
    echo ""
    echo -e "      ${WHITE}[ 1 ]${RESET} ${GREY}Balanced${RESET}    — Padding 1-128, jitter 0-500us (pishfarz)"
    echo -e "      ${WHITE}[ 2 ]${RESET} ${YELLOW}Aggressive${RESET}  — Padding 64-256, jitter 0-2000us (bishtar amniat)"
    echo -e "      ${WHITE}[ 3 ]${RESET} ${GREEN}Stealth${RESET}     — Padding 1-64, jitter 0-250us (sor'at bala, amniat kam)"
    echo ""
    echo -e "      ${DARK}------------------------------------------------------${RESET}"
    echo -ne "      ${PINK}root@t2hash${WHITE}:~#${RESET} Kodoom profile? [1, 2, ya 3]: "
    read -r RAW_PROFILE
    PROF_CHOICE=$(echo "$RAW_PROFILE" | tr -d '\r\n ')

    case "$PROF_CHOICE" in
        2)
            TRANSPORT_PROFILE="aggressive"
            PAD_MIN=64
            PAD_MAX=256
            JITTER_MAX_US=2000
            ;;
        3)
            TRANSPORT_PROFILE="stealth"
            PAD_MIN=1
            PAD_MAX=64
            JITTER_MAX_US=250
            ;;
        *)
            TRANSPORT_PROFILE="balanced"
            PAD_MIN=1
            PAD_MAX=128
            JITTER_MAX_US=500
            ;;
    esac
    note "Profile: ${TRANSPORT_PROFILE} (pad=${PAD_MIN}-${PAD_MAX}, jitter=0-${JITTER_MAX_US}us)"
fi

# ----------------------------------------------------------------
#  Step 2.6: Port configuration (NEW — configurable)
# ----------------------------------------------------------------
echo ""
echo -e "      ${DARK}------------------------------------------------------${RESET}"
echo -e "      ${WHITE}Port ha (Enter = pishfarz):${RESET}"
echo ""

# HZ port
if [ "$SERVER_TYPE" == "1" ]; then
    echo -ne "      ${GREY}Port daryaft (HZ) [pishfarz: ${HZ_PORT}]:${RESET} "
    read -r RAW_PORT
    CUSTOM_HZ=$(echo "${RAW_PORT:-$HZ_PORT}" | tr -d '\r\n ')
    validate_port "$CUSTOM_HZ" || die "Port eshtebah ast!"
    HZ_PORT=$CUSTOM_HZ
fi

# IR port
if [ "$SERVER_TYPE" == "2" ]; then
    echo -ne "      ${GREY}Port daryaft (IR) [pishfarz: ${IR_PORT}]:${RESET} "
    read -r RAW_PORT
    CUSTOM_IR=$(echo "${RAW_PORT:-$IR_PORT}" | tr -d '\r\n ')
    validate_port "$CUSTOM_IR" || die "Port eshtebah ast!"
    IR_PORT=$CUSTOM_IR
fi

# SOCKS port
if [ "$SERVER_TYPE" == "2" ]; then
    echo -ne "      ${GREY}Port SOCKS5 [pishfarz: ${SOCKS_PORT}]:${RESET} "
    read -r RAW_PORT
    CUSTOM_SOCKS=$(echo "${RAW_PORT:-$SOCKS_PORT}" | tr -d '\r\n ')
    validate_port "$CUSTOM_SOCKS" || die "Port eshtebah ast!"
    SOCKS_PORT=$CUSTOM_SOCKS
fi

echo ""
echo -e "      ${DARK}------------------------------------------------------${RESET}"

# Convert HZ port to hex bytes
HZ_PORT_HEX=$(printf "0x%02X, 0x%02X" $(( (HZ_PORT >> 8) & 0xFF )) $(( HZ_PORT & 0xFF )))
IR_PORT_HEX=$(printf "0x%02X, 0x%02X" $(( (IR_PORT >> 8) & 0xFF )) $(( IR_PORT & 0xFF )))
GOST_PORT_HEX=$(printf "0x%02X, 0x%02X" $(( (GOST_PORT >> 8) & 0xFF )) $(( GOST_PORT & 0xFF )))

# ----------------------------------------------------------------
#  Cleanup Previous Versions
# ----------------------------------------------------------------
echo -e "      ${RED}[1/7]${RESET} ${GREY}Pak kardan nuskhe haye ghabli...${RESET}"
systemctl stop  asm-hz gost-hz asm-ir gost-ir asm-hz-dpi asm-ir-dpi t2hash-fallback 2>/dev/null || true
systemctl disable asm-hz gost-hz asm-ir gost-ir asm-hz-dpi asm-ir-dpi t2hash-fallback 2>/dev/null || true
rm -f /etc/systemd/system/asm-hz.service  \
      /etc/systemd/system/gost-hz.service \
      /etc/systemd/system/asm-ir.service  \
      /etc/systemd/system/gost-ir.service \
      /etc/systemd/system/asm-hz-dpi.service \
      /etc/systemd/system/asm-ir-dpi.service \
      /etc/systemd/system/t2hash-fallback.service \
      /root/asm_udp_hz /root/asm_udp_hz.asm /root/asm_udp_hz.o \
      /root/asm_udp_ir /root/asm_udp_ir.asm /root/asm_udp_ir.o \
      /root/asm_udp_hz_dpi /root/asm_udp_hz_dpi.asm /root/asm_udp_hz_dpi.o \
      /root/asm_udp_ir_dpi /root/asm_udp_ir_dpi.asm /root/asm_udp_ir_dpi.o \
      /root/t2hash-fallback.sh \
      /etc/t2hash/t2hash.conf
systemctl daemon-reload
ok "Pak sazi anjam shod."

# ----------------------------------------------------------------
#  [2/7] Install prerequisites
# ----------------------------------------------------------------
echo -e "      ${RED}[2/7]${RESET} ${GREY}Nasb pish-niaz ha...${RESET}"
apt-get update -qq
apt-get install -y -qq nasm build-essential wget gzip > /dev/null 2>&1 \
    || die "Nasb pish-niaz ha shekast khord!"
ok "Pish-niaz ha nasb shodand."

# ----------------------------------------------------------------
#  [3/7] Download GOST
# ----------------------------------------------------------------
echo -e "      ${RED}[3/7]${RESET} ${GREY}Danload / barresi Gost...${RESET}"
if [ ! -f /usr/local/bin/gost ]; then
    wget -q --show-progress \
         "https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-amd64-${GOST_VERSION}.gz" \
         -O /tmp/gost.gz \
         || die "Danload Gost shekast khord!"
    gzip -d /tmp/gost.gz
    chmod +x /tmp/gost
    mv /tmp/gost /usr/local/bin/gost
    ok "Gost v${GOST_VERSION} nasb shod."
else
    ok "Gost ghablan nasb shode, skip..."
fi

# ----------------------------------------------------------------
#  [4/7] Optimize kernel buffers
# ----------------------------------------------------------------
echo -e "      ${RED}[4/7]${RESET} ${GREY}Behin-sazi kernel buffer (anti packet-loss)...${RESET}"
sysctl -w net.core.rmem_max=$BUF_SIZE     >/dev/null
sysctl -w net.core.rmem_default=$BUF_SIZE >/dev/null
sysctl -w net.core.wmem_max=$BUF_SIZE     >/dev/null
sysctl -w net.core.wmem_default=$BUF_SIZE >/dev/null
sysctl -w net.core.netdev_max_backlog=5000 >/dev/null
grep -q "rmem_max" /etc/sysctl.conf 2>/dev/null || cat >> /etc/sysctl.conf << SYSCTL
# T2HASH kernel tuning (v3.0)
net.core.rmem_max=$BUF_SIZE
net.core.rmem_default=$BUF_SIZE
net.core.wmem_max=$BUF_SIZE
net.core.wmem_default=$BUF_SIZE
net.core.netdev_max_backlog=5000
SYSCTL
ok "Kernel buffer behin sazi anjam shod (persistent)."

# ----------------------------------------------------------------
#  [5/7] Generate Assembly code and compile
# ----------------------------------------------------------------
echo -e "      ${RED}[5/7]${RESET} ${GREY}Sakht kode Assembly va compile...${RESET}"

# ================================================================
#  LEGACY ASSEMBLY (V2.0 compatible — always built for fallback)
# ================================================================
compile_legacy_hz() {
cat << 'IN_EOF' > /root/asm_udp_hz.asm
; ASM-TUN v2.0 Legacy — HZ Side
section .data
    bind_addr   db 0x02, 0x00, __BIND_PORT__, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    gost_addr   db 0x02, 0x00, __GOST_PORT__, 0x7F, 0x00, 0x00, 0x01
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    opt_one     dd 1
    opt_bufsize dd __BUF__
    xor_mask_64 dq 0x5A5A5A5A5A5A5A5A
section .bss
    fd          resq 1
    buffer      resb 65536
    ir_addr     resb 16
    peer_addr   resb 16
    peer_len    resq 1
section .text
    global _start
_start:
    mov     rax, 41
    mov     rdi, 2
    mov     rsi, 2
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .fatal
    mov     [fd], rax
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 2
    lea     r10, [rel opt_one]
    mov     r8,  4
    syscall
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 8
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 7
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall
    mov     rax, 49
    mov     rdi, [fd]
    lea     rsi, [rel bind_addr]
    mov     rdx, 16
    syscall
    test    rax, rax
    js      .fatal
.loop:
    mov     qword [peer_len], 16
    mov     rax, 45
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, 65536
    xor     r10, r10
    lea     r8,  [rel peer_addr]
    lea     r9,  [rel peer_len]
    syscall
    cmp     rax, 0
    jle     .loop
    mov     r12, rax
    xor     r13, r13
    mov     rax, [rel xor_mask_64]
.x_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r12
    jg      .x_byte
    xor     [rel buffer + r13], rax
    add     r13, 8
    jmp     .x_bulk
.x_byte:
    cmp     r13, r12
    jge     .x_done
    mov     bl, [rel buffer + r13]
    xor     bl, 0x5A
    mov     [rel buffer + r13], bl
    inc     r13
    jmp     .x_byte
.x_done:
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    je      .from_gost
    mov     rax, qword [rel peer_addr]
    mov     qword [rel ir_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel ir_addr + 8], rax
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel gost_addr]
    mov     r9,  16
    syscall
    jmp     .loop
.from_gost:
    movzx   eax, word [rel ir_addr]
    test    eax, eax
    jz      .loop
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel ir_addr]
    mov     r9,  16
    syscall
    jmp     .loop
.fatal:
    mov     rax, 60
    mov     rdi, 1
    syscall
IN_EOF
    sed -i "s/__BIND_PORT__/${HZ_PORT_HEX}/g" /root/asm_udp_hz.asm
    sed -i "s/__GOST_PORT__/${GOST_PORT_HEX}/g" /root/asm_udp_hz.asm
    sed -i "s/__BUF__/${BUF_SIZE}/g" /root/asm_udp_hz.asm
    nasm -f elf64 /root/asm_udp_hz.asm -o /root/asm_udp_hz.o || die "NASM legacy hz compile failed!"
    ld /root/asm_udp_hz.o -o /root/asm_udp_hz || die "Linker legacy hz failed!"
    ok "Legacy ASM (hz) compiled."
}

compile_legacy_ir() {
cat << IN_EOF > /root/asm_udp_ir.asm
; ASM-TUN v2.0 Legacy — IR Side
section .data
    bind_addr   db 0x02, 0x00, __IR_PORT__, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    hz_addr     db 0x02, 0x00, __HZ_PORT__, ${HEX_IP}
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    opt_one     dd 1
    opt_bufsize dd __BUF__
    xor_mask_64 dq 0x5A5A5A5A5A5A5A5A
section .bss
    fd          resq 1
    buffer      resb 65536
    gost_addr   resb 16
    peer_addr   resb 16
    peer_len    resq 1
section .text
    global _start
_start:
    mov     rax, 41
    mov     rdi, 2
    mov     rsi, 2
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .fatal
    mov     [fd], rax
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 2
    lea     r10, [rel opt_one]
    mov     r8,  4
    syscall
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 8
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 7
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall
    mov     rax, 49
    mov     rdi, [fd]
    lea     rsi, [rel bind_addr]
    mov     rdx, 16
    syscall
    test    rax, rax
    js      .fatal
.loop:
    mov     qword [peer_len], 16
    mov     rax, 45
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, 65536
    xor     r10, r10
    lea     r8,  [rel peer_addr]
    lea     r9,  [rel peer_len]
    syscall
    cmp     rax, 0
    jle     .loop
    mov     r12, rax
    xor     r13, r13
    mov     rax, [rel xor_mask_64]
.x_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r12
    jg      .x_byte
    xor     [rel buffer + r13], rax
    add     r13, 8
    jmp     .x_bulk
.x_byte:
    cmp     r13, r12
    jge     .x_done
    mov     bl, [rel buffer + r13]
    xor     bl, 0x5A
    mov     [rel buffer + r13], bl
    inc     r13
    jmp     .x_byte
.x_done:
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    jne     .from_hz
    mov     rax, qword [rel peer_addr]
    mov     qword [rel gost_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel gost_addr + 8], rax
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel hz_addr]
    mov     r9,  16
    syscall
    jmp     .loop
.from_hz:
    movzx   eax, word [rel gost_addr]
    test    eax, eax
    jz      .loop
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel gost_addr]
    mov     r9,  16
    syscall
    jmp     .loop
.fatal:
    mov     rax, 60
    mov     rdi, 1
    syscall
IN_EOF
    sed -i "s/__IR_PORT__/${IR_PORT_HEX}/g" /root/asm_udp_ir.asm
    sed -i "s/__HZ_PORT__/${HZ_PORT_HEX}/g" /root/asm_udp_ir.asm
    sed -i "s/__BUF__/${BUF_SIZE}/g" /root/asm_udp_ir.asm
    nasm -f elf64 /root/asm_udp_ir.asm -o /root/asm_udp_ir.o || die "NASM legacy ir compile failed!"
    ld /root/asm_udp_ir.o -o /root/asm_udp_ir || die "Linker legacy ir failed!"
    ok "Legacy ASM (ir) compiled."
}

# ================================================================
#  DPI-RESILIENT ASSEMBLY (V3.0 — compiled as standalone .asm files)
# ================================================================
compile_dpi_hz() {
    # Write the full DPI HZ assembly with port/buffer injection
    cat << IN_EOF > /root/asm_udp_hz_dpi.asm
; asm_udp_hz_dpi.asm — DPI-Resilient Transport (HZ Side)
section .data
    bind_addr   db 0x02, 0x00, ${HZ_PORT_HEX}, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    gost_addr   db 0x02, 0x00, ${GOST_PORT_HEX}, 0x7F, 0x00, 0x00, 0x01
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    opt_one     dd 1
    opt_bufsize dd ${BUF_SIZE}
    mask0       dq 0x6B3A8E1F4C7D2A9F
    mask1       dq 0x3D7F2C5A9E1B8F4C
    mask2       dq 0x7E4C1A6B3D8F2E5A
    mask3       dq 0x1F8D5C2B4E9A7F3D
    mask4       dq 0x8C3E5A1B7D2F6E4A
    mask5       dq 0x2A7D4F1C3B8E5D6F
    mask6       dq 0x5F1B3D6E2C8A4F7B
    mask7       dq 0x4E8A2C6F1B3D5E7A
    jitter_sec  dq 0
    jitter_nsec dq 0
    log_start   db "[T2HASH-DPI] HZ relay (profile=${TRANSPORT_PROFILE}) bound on port ${HZ_PORT}", 10, 0
    log_pkt     db "[T2HASH-DPI] HZ packet processed", 10, 0
    log_drop    db "[T2HASH-DPI] HZ dropping - no Iran peer yet", 10, 0
    log_peer    db "[T2HASH-DPI] HZ Iran peer registered", 10, 0
    log_legacy  db "[T2HASH-DPI] HZ fallback: legacy packet received", 10, 0
section .bss
    fd          resq 1
    buffer      resb 65536
    send_buf    resb 65536
    ir_addr     resb 16
    peer_addr   resb 16
    peer_len    resq 1
    pkt_counter resq 1
    mask_ptr    resq 1
    pad_buf     resb 256
    pad_len     resb 1
    jitter_ns   resq 1
section .text
    global _start

log_msg:
    push    rsi
    push    rcx
    xor     rcx, rcx
.strlen:
    cmp     byte [rsi + rcx], 0
    je      .dowrite
    inc     rcx
    jmp     .strlen
.dowrite:
    mov     rax, 1
    mov     rdi, 2
    mov     rdx, rcx
    syscall
    pop     rcx
    pop     rsi
    ret

apply_jitter:
    push    rax
    push    rdx
    push    rdi
    push    rsi
    rdtsc
    mov     rdx, ${JITTER_MAX_US}
    div     rdx
    imul    rdx, 1000
    mov     [rel jitter_nsec], rdx
    mov     qword [rel jitter_nsec + 8], 0
    mov     rax, 35
    lea     rdi, [rel jitter_sec]
    xor     rsi, rsi
    syscall
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rax
    ret

gen_padding:
    push    rax
    push    rcx
    push    rdi
    rdtsc
    xor     edx, edx
    mov     ecx, $((PAD_MAX - PAD_MIN + 1))
    div     ecx
    add     edx, ${PAD_MIN}
    mov     [rel pad_len], dl
    movzx   rcx, byte [rel pad_len]
    lea     rdi, [rel pad_buf]
.fill:
    rdtsc
    ror     eax, 7
    xor     al, ah
    add     al, dl
    stosb
    dec     rcx
    jnz     .fill
    pop     rdi
    pop     rcx
    pop     rax
    ret

select_mask:
    push    rbx
    mov     rax, [rel pkt_counter]
    and     rax, 7
    imul    rax, 8
    mov     rbx, [rel mask0 + rax]
    mov     [rel mask_ptr], rbx
    mov     rax, rbx
    pop     rbx
    ret

_start:
    mov     rax, 41
    mov     rdi, 2
    mov     rsi, 2
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .fatal
    mov     [fd], rax
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 2
    lea     r10, [rel opt_one]
    mov     r8,  4
    syscall
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 8
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 7
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall
    mov     rax, 49
    mov     rdi, [fd]
    lea     rsi, [rel bind_addr]
    mov     rdx, 16
    syscall
    test    rax, rax
    js      .fatal
    lea     rsi, [rel log_start]
    call    log_msg
    mov     qword [rel pkt_counter], 0

.main_loop:
    mov     qword [peer_len], 16
    mov     rax, 45
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, 65536
    xor     r10, r10
    lea     r8,  [rel peer_addr]
    lea     r9,  [rel peer_len]
    syscall
    cmp     rax, 0
    jle     .main_loop
    mov     r12, rax
    movzx   eax, byte [rel buffer]
    cmp     al, 0x00
    je      .handle_legacy
    cmp     al, 0x01
    je      .handle_dpi
    jmp     .main_loop

.handle_dpi:
    inc     qword [rel pkt_counter]
    call    select_mask
    mov     r14, r12
    dec     r14
    jz      .dpi_route
    xor     r13, r13
    mov     rbx, rax
.dpi_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r14
    jg      .dpi_tail
    xor     qword [rel buffer + 1 + r13], rbx
    add     r13, 8
    jmp     .dpi_bulk
.dpi_tail:
    cmp     r13, r14
    jge     .dpi_route
    mov     bl, [rel buffer + 1 + r13]
    xor     bl, byte [rel mask_ptr]
    mov     [rel buffer + 1 + r13], bl
    inc     r13
    jmp     .dpi_tail

.dpi_route:
    movzx   ebx, byte [rel buffer + r12 - 1]
    cmp     ebx, 0
    je      .dpi_clean
    cmp     ebx, ${PAD_MAX}
    jg      .dpi_clean
    sub     r12, rbx
    dec     r12
.dpi_clean:
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    je      .dpi_gost

    ; From Iran
    mov     rax, qword [rel peer_addr]
    mov     qword [rel ir_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel ir_addr + 8], rax
    lea     rsi, [rel log_peer]
    call    log_msg
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel gost_addr]
    mov     r9,  16
    syscall
    call    apply_jitter
    lea     rsi, [rel log_pkt]
    call    log_msg
    jmp     .main_loop

.dpi_gost:
    movzx   eax, word [rel ir_addr]
    test    eax, eax
    jnz     .dpi_send
    lea     rsi, [rel log_drop]
    call    log_msg
    jmp     .main_loop

.dpi_send:
    mov     byte [rel send_buf], 0x01
    mov     rcx, r12
    dec     rcx
    lea     rsi, [rel buffer + 1]
    lea     rdi, [rel send_buf + 1]
    rep     movsb
    call    select_mask
    mov     rbx, rax
    mov     r14, r12
    dec     r14
    xor     r13, r13
.dpi_out_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r14
    jg      .dpi_out_tail
    xor     qword [rel send_buf + 1 + r13], rbx
    add     r13, 8
    jmp     .dpi_out_bulk
.dpi_out_tail:
    cmp     r13, r14
    jge     .dpi_out_pad
    mov     bl, [rel send_buf + 1 + r13]
    xor     bl, byte [rel mask_ptr]
    mov     [rel send_buf + 1 + r13], bl
    inc     r13
    jmp     .dpi_out_tail

.dpi_out_pad:
    call    gen_padding
    movzx   rcx, byte [rel pad_len]
    mov     [rel send_buf + r14 + 1], cl
    lea     rsi, [rel pad_buf]
    lea     rdi, [rel send_buf + r14 + 2]
    rep     movsb
    mov     rdx, r14
    add     rdx, 2
    add     rdx, rcx
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel send_buf]
    mov     r10, 0
    lea     r8,  [rel ir_addr]
    mov     r9,  16
    syscall
    call    apply_jitter
    lea     rsi, [rel log_pkt]
    call    log_msg
    jmp     .main_loop

.handle_legacy:
    lea     rsi, [rel log_legacy]
    call    log_msg
    xor     r13, r13
    mov     rax, 0x5A5A5A5A5A5A5A5A
.l_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r12
    jg      .l_byte
    xor     [rel buffer + r13], rax
    add     r13, 8
    jmp     .l_bulk
.l_byte:
    cmp     r13, r12
    jge     .l_route
    mov     bl, [rel buffer + r13]
    xor     bl, 0x5A
    mov     [rel buffer + r13], bl
    inc     r13
    jmp     .l_byte
.l_route:
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    je      .l_gost
    mov     rax, qword [rel peer_addr]
    mov     qword [rel ir_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel ir_addr + 8], rax
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel gost_addr]
    mov     r9,  16
    syscall
    jmp     .main_loop
.l_gost:
    movzx   eax, word [rel ir_addr]
    test    eax, eax
    jz      .main_loop
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel ir_addr]
    mov     r9,  16
    syscall
    jmp     .main_loop
.fatal:
    mov     rax, 60
    mov     rdi, 1
    syscall
IN_EOF
    nasm -f elf64 /root/asm_udp_hz_dpi.asm -o /root/asm_udp_hz_dpi.o || die "NASM DPI hz compile failed!"
    ld /root/asm_udp_hz_dpi.o -o /root/asm_udp_hz_dpi || die "Linker DPI hz failed!"
    ok "DPI-Resilient ASM (hz) compiled [${TRANSPORT_PROFILE}]."
}

compile_dpi_ir() {
    cat << IN_EOF > /root/asm_udp_ir_dpi.asm
; asm_udp_ir_dpi.asm — DPI-Resilient Transport (IR Side)
section .data
    bind_addr   db 0x02, 0x00, ${IR_PORT_HEX}, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    hz_addr     db 0x02, 0x00, ${HZ_PORT_HEX}, ${HEX_IP}
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    opt_one     dd 1
    opt_bufsize dd ${BUF_SIZE}
    mask0       dq 0x6B3A8E1F4C7D2A9F
    mask1       dq 0x3D7F2C5A9E1B8F4C
    mask2       dq 0x7E4C1A6B3D8F2E5A
    mask3       dq 0x1F8D5C2B4E9A7F3D
    mask4       dq 0x8C3E5A1B7D2F6E4A
    mask5       dq 0x2A7D4F1C3B8E5D6F
    mask6       dq 0x5F1B3D6E2C8A4F7B
    mask7       dq 0x4E8A2C6F1B3D5E7A
    jitter_sec  dq 0
    jitter_nsec dq 0
    log_start   db "[T2HASH-DPI] IR relay (profile=${TRANSPORT_PROFILE}) bound on port ${IR_PORT}", 10, 0
    log_pkt     db "[T2HASH-DPI] IR packet processed", 10, 0
    log_drop    db "[T2HASH-DPI] IR dropping - no client/Gost yet", 10, 0
    log_peer    db "[T2HASH-DPI] IR client registered", 10, 0
    log_legacy  db "[T2HASH-DPI] IR fallback: legacy packet received", 10, 0
section .bss
    fd          resq 1
    buffer      resb 65536
    send_buf    resb 65536
    gost_addr   resb 16
    peer_addr   resb 16
    peer_len    resq 1
    pkt_counter resq 1
    mask_ptr    resq 1
    pad_buf     resb 256
    pad_len     resb 1
    jitter_ns   resq 1
section .text
    global _start

log_msg:
    push    rsi
    push    rcx
    xor     rcx, rcx
.strlen:
    cmp     byte [rsi + rcx], 0
    je      .dowrite
    inc     rcx
    jmp     .strlen
.dowrite:
    mov     rax, 1
    mov     rdi, 2
    mov     rdx, rcx
    syscall
    pop     rcx
    pop     rsi
    ret

apply_jitter:
    push    rax
    push    rdx
    push    rdi
    push    rsi
    rdtsc
    mov     rdx, ${JITTER_MAX_US}
    div     rdx
    imul    rdx, 1000
    mov     [rel jitter_nsec], rdx
    mov     qword [rel jitter_nsec + 8], 0
    mov     rax, 35
    lea     rdi, [rel jitter_sec]
    xor     rsi, rsi
    syscall
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rax
    ret

gen_padding:
    push    rax
    push    rcx
    push    rdi
    rdtsc
    xor     edx, edx
    mov     ecx, $((PAD_MAX - PAD_MIN + 1))
    div     ecx
    add     edx, ${PAD_MIN}
    mov     [rel pad_len], dl
    movzx   rcx, byte [rel pad_len]
    lea     rdi, [rel pad_buf]
.fill:
    rdtsc
    ror     eax, 7
    xor     al, ah
    add     al, dl
    stosb
    dec     rcx
    jnz     .fill
    pop     rdi
    pop     rcx
    pop     rax
    ret

select_mask:
    push    rbx
    mov     rax, [rel pkt_counter]
    and     rax, 7
    imul    rax, 8
    mov     rbx, [rel mask0 + rax]
    mov     [rel mask_ptr], rbx
    mov     rax, rbx
    pop     rbx
    ret

_start:
    mov     rax, 41
    mov     rdi, 2
    mov     rsi, 2
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .fatal
    mov     [fd], rax
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 2
    lea     r10, [rel opt_one]
    mov     r8,  4
    syscall
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 8
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 7
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall
    mov     rax, 49
    mov     rdi, [fd]
    lea     rsi, [rel bind_addr]
    mov     rdx, 16
    syscall
    test    rax, rax
    js      .fatal
    lea     rsi, [rel log_start]
    call    log_msg
    mov     qword [rel pkt_counter], 0

.main_loop:
    mov     qword [peer_len], 16
    mov     rax, 45
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, 65536
    xor     r10, r10
    lea     r8,  [rel peer_addr]
    lea     r9,  [rel peer_len]
    syscall
    cmp     rax, 0
    jle     .main_loop
    mov     r12, rax
    movzx   eax, byte [rel buffer]
    cmp     al, 0x00
    je      .handle_legacy
    cmp     al, 0x01
    je      .handle_dpi
    jmp     .main_loop

.handle_dpi:
    inc     qword [rel pkt_counter]
    call    select_mask
    mov     r14, r12
    dec     r14
    jz      .dpi_route
    xor     r13, r13
    mov     rbx, rax
.dpi_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r14
    jg      .dpi_tail
    xor     qword [rel buffer + 1 + r13], rbx
    add     r13, 8
    jmp     .dpi_bulk
.dpi_tail:
    cmp     r13, r14
    jge     .dpi_route
    mov     bl, [rel buffer + 1 + r13]
    xor     bl, byte [rel mask_ptr]
    mov     [rel buffer + 1 + r13], bl
    inc     r13
    jmp     .dpi_tail

.dpi_route:
    movzx   ebx, byte [rel buffer + r12 - 1]
    cmp     ebx, 0
    je      .dpi_clean
    cmp     ebx, ${PAD_MAX}
    jg      .dpi_clean
    sub     r12, rbx
    dec     r12
.dpi_clean:
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    je      .dpi_client

    ; From HZ
    movzx   eax, word [rel gost_addr]
    test    eax, eax
    jz      .dpi_drop
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel gost_addr]
    mov     r9,  16
    syscall
    call    apply_jitter
    lea     rsi, [rel log_pkt]
    call    log_msg
    jmp     .main_loop

.dpi_drop:
    lea     rsi, [rel log_drop]
    call    log_msg
    jmp     .main_loop

.dpi_client:
    mov     rax, qword [rel peer_addr]
    mov     qword [rel gost_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel gost_addr + 8], rax
    lea     rsi, [rel log_peer]
    call    log_msg

    ; Build outgoing DPI packet
    mov     byte [rel send_buf], 0x01
    mov     rcx, r12
    dec     rcx
    lea     rsi, [rel buffer + 1]
    lea     rdi, [rel send_buf + 1]
    rep     movsb
    call    select_mask
    mov     rbx, rax
    mov     r14, r12
    dec     r14
    xor     r13, r13
.dpi_out_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r14
    jg      .dpi_out_tail
    xor     qword [rel send_buf + 1 + r13], rbx
    add     r13, 8
    jmp     .dpi_out_bulk
.dpi_out_tail:
    cmp     r13, r14
    jge     .dpi_out_pad
    mov     bl, [rel send_buf + 1 + r13]
    xor     bl, byte [rel mask_ptr]
    mov     [rel send_buf + 1 + r13], bl
    inc     r13
    jmp     .dpi_out_tail

.dpi_out_pad:
    call    gen_padding
    movzx   rcx, byte [rel pad_len]
    mov     [rel send_buf + r14 + 1], cl
    lea     rsi, [rel pad_buf]
    lea     rdi, [rel send_buf + r14 + 2]
    rep     movsb
    mov     rdx, r14
    add     rdx, 2
    add     rdx, rcx
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel send_buf]
    mov     r10, 0
    lea     r8,  [rel hz_addr]
    mov     r9,  16
    syscall
    call    apply_jitter
    lea     rsi, [rel log_pkt]
    call    log_msg
    jmp     .main_loop

.handle_legacy:
    lea     rsi, [rel log_legacy]
    call    log_msg
    xor     r13, r13
    mov     rax, 0x5A5A5A5A5A5A5A5A
.l_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r12
    jg      .l_byte
    xor     [rel buffer + r13], rax
    add     r13, 8
    jmp     .l_bulk
.l_byte:
    cmp     r13, r12
    jge     .l_route
    mov     bl, [rel buffer + r13]
    xor     bl, 0x5A
    mov     [rel buffer + r13], bl
    inc     r13
    jmp     .l_byte
.l_route:
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    jne     .l_hz
    mov     rax, qword [rel peer_addr]
    mov     qword [rel gost_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel gost_addr + 8], rax
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel hz_addr]
    mov     r9,  16
    syscall
    jmp     .main_loop
.l_hz:
    movzx   eax, word [rel gost_addr]
    test    eax, eax
    jz      .main_loop
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel gost_addr]
    mov     r9,  16
    syscall
    jmp     .main_loop
.fatal:
    mov     rax, 60
    mov     rdi, 1
    syscall
IN_EOF
    nasm -f elf64 /root/asm_udp_ir_dpi.asm -o /root/asm_udp_ir_dpi.o || die "NASM DPI ir compile failed!"
    ld /root/asm_udp_ir_dpi.o -o /root/asm_udp_ir_dpi || die "Linker DPI ir failed!"
    ok "DPI-Resilient ASM (ir) compiled [${TRANSPORT_PROFILE}]."
}

# Compile based on server type and transport mode
case "${SERVER_TYPE}:${TRANSPORT_MODE}" in
    1:1)  # HZ + Legacy only
        compile_legacy_hz
        ;;
    1:2)  # HZ + DPI only
        compile_dpi_hz
        ;;
    1:3)  # HZ + Hybrid (both)
        compile_dpi_hz
        compile_legacy_hz
        ;;
    2:1)  # IR + Legacy only
        compile_legacy_ir
        ;;
    2:2)  # IR + DPI only
        compile_dpi_ir
        ;;
    2:3)  # IR + Hybrid (both)
        compile_dpi_ir
        compile_legacy_ir
        ;;
esac

# ----------------------------------------------------------------
#  [6/7] Systemd Service Setup
# ----------------------------------------------------------------
echo -e "      ${RED}[6/7]${RESET} ${GREY}Sakht va rah-andazi service haye systemd...${RESET}"

mkdir -p /etc/t2hash

# Write config file for reference
cat > /etc/t2hash/t2hash.conf << CONF
# T2HASH v3.0 Configuration
# Generated: $(date)
server_type=${SERVER_TYPE}
transport_mode=${TRANSPORT_MODE}
transport_profile=${TRANSPORT_PROFILE}
hz_port=${HZ_PORT}
ir_port=${IR_PORT}
gost_port=${GOST_PORT}
socks_port=${SOCKS_PORT}
buf_size=${BUF_SIZE}
pad_min=${PAD_MIN}
pad_max=${PAD_MAX}
jitter_max_us=${JITTER_MAX_US}
fallback_timeout=${FALLBACK_TIMEOUT}
gost_version=${GOST_VERSION}
mtu=${MTU_SIZE}
kcp_mode=${KCP_MODE}
CONF

if [ "$SERVER_TYPE" == "1" ]; then
    # ---- HZ Services ----

    # DPI service (if mode 2 or 3)
    if [ "$TRANSPORT_MODE" == "2" ] || [ "$TRANSPORT_MODE" == "3" ]; then
        cat << 'IN_EOF' > /etc/systemd/system/asm-hz-dpi.service
[Unit]
Description=T2HASH DPI-Resilient UDP Receiver (HZ)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/root/asm_udp_hz_dpi
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal
SyslogIdentifier=t2hash-hz-dpi
LimitNOFILE=65536
LimitNPROC=1024
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF
    fi

    # Legacy service (if mode 1 or 3)
    if [ "$TRANSPORT_MODE" == "1" ] || [ "$TRANSPORT_MODE" == "3" ]; then
        cat << 'IN_EOF' > /etc/systemd/system/asm-hz.service
[Unit]
Description=T2HASH Legacy UDP Receiver (HZ)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/root/asm_udp_hz
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal
SyslogIdentifier=t2hash-hz-legacy
LimitNOFILE=65536
LimitNPROC=1024
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF
    fi

    # Gost service
    cat << IN_EOF > /etc/systemd/system/gost-hz.service
[Unit]
Description=T2HASH Gost KCP Receiver (HZ)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost \
    -L "kcp://127.0.0.1:${GOST_PORT}?mode=${KCP_MODE}&mtu=${MTU_SIZE}&nocomp=true&smux=true&keepalive=true&interval=50&resend=2&nc=1"
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal
SyslogIdentifier=t2hash-gost-hz
LimitNOFILE=65536
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF

    # Fallback watchdog for hybrid mode
    if [ "$TRANSPORT_MODE" == "3" ]; then
        cat << IN_EOF > /root/t2hash-fallback.sh
#!/bin/bash
# T2HASH V3.0 Fallback Watchdog
# Monitors DPI relay health and falls back to legacy if it fails

DPI_ACTIVE=0
LEGACY_ACTIVE=0
CHECK_COUNT=0
MAX_CHECKS=${FALLBACK_TIMEOUT}

while true; do
    if systemctl is-active --quiet asm-hz-dpi 2>/dev/null; then
        DPI_ACTIVE=1
        if [ \$LEGACY_ACTIVE -eq 1 ]; then
            echo "[T2HASH-FALLBACK] DPI service recovered, stopping legacy fallback"
            systemctl stop asm-hz 2>/dev/null || true
            LEGACY_ACTIVE=0
        fi
        CHECK_COUNT=0
    else
        if [ \$DPI_ACTIVE -eq 1 ]; then
            CHECK_COUNT=\$((CHECK_COUNT + 1))
            echo "[T2HASH-FALLBACK] DPI service down (\$CHECK_COUNT/\$MAX_CHECKS)..."
            if [ \$CHECK_COUNT -ge \$MAX_CHECKS ]; then
                echo "[T2HASH-FALLBACK] Activating legacy fallback!"
                systemctl start asm-hz 2>/dev/null || true
                LEGACY_ACTIVE=1
                DPI_ACTIVE=0
            fi
        fi
    fi
    sleep 5
done
IN_EOF
        chmod +x /root/t2hash-fallback.sh

        cat << 'IN_EOF' > /etc/systemd/system/t2hash-fallback.service
[Unit]
Description=T2HASH Fallback Watchdog
After=network-online.target asm-hz-dpi.service asm-hz.service
Wants=asm-hz-dpi.service

[Service]
Type=simple
ExecStart=/root/t2hash-fallback.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=t2hash-fallback

[Install]
WantedBy=multi-user.target
IN_EOF
    fi

    # Enable services
    systemctl daemon-reload

    case "$TRANSPORT_MODE" in
        1)
            systemctl enable --now asm-hz gost-hz || die "Service start failed!"
            ;;
        2)
            systemctl enable --now asm-hz-dpi gost-hz || die "Service start failed!"
            ;;
        3)
            systemctl enable --now asm-hz-dpi gost-hz t2hash-fallback || die "Service start failed!"
            ;;
    esac

else
    # ---- IR Services ----

    if [ "$TRANSPORT_MODE" == "2" ] || [ "$TRANSPORT_MODE" == "3" ]; then
        cat << 'IN_EOF' > /etc/systemd/system/asm-ir-dpi.service
[Unit]
Description=T2HASH DPI-Resilient UDP Sender (IR)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/root/asm_udp_ir_dpi
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal
SyslogIdentifier=t2hash-ir-dpi
LimitNOFILE=65536
LimitNPROC=1024
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF
    fi

    if [ "$TRANSPORT_MODE" == "1" ] || [ "$TRANSPORT_MODE" == "3" ]; then
        cat << 'IN_EOF' > /etc/systemd/system/asm-ir.service
[Unit]
Description=T2HASH Legacy UDP Sender (IR)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/root/asm_udp_ir
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal
SyslogIdentifier=t2hash-ir-legacy
LimitNOFILE=65536
LimitNPROC=1024
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF
    fi

    cat << IN_EOF > /etc/systemd/system/gost-ir.service
[Unit]
Description=T2HASH Gost KCP Sender (IR)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost \
    -L socks5://:${SOCKS_PORT} \
    -F "kcp://127.0.0.1:${IR_PORT}?mode=${KCP_MODE}&mtu=${MTU_SIZE}&nocomp=true&smux=true&keepalive=true&interval=50&resend=2&nc=1"
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal
SyslogIdentifier=t2hash-gost-ir
LimitNOFILE=65536
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF

    # Fallback watchdog for hybrid mode
    if [ "$TRANSPORT_MODE" == "3" ]; then
        cat << IN_EOF > /root/t2hash-fallback.sh
#!/bin/bash
# T2HASH V3.0 Fallback Watchdog (IR Side)
DPI_ACTIVE=0
LEGACY_ACTIVE=0
CHECK_COUNT=0
MAX_CHECKS=${FALLBACK_TIMEOUT}

while true; do
    if systemctl is-active --quiet asm-ir-dpi 2>/dev/null; then
        DPI_ACTIVE=1
        if [ \$LEGACY_ACTIVE -eq 1 ]; then
            echo "[T2HASH-FALLBACK] DPI service recovered, stopping legacy fallback"
            systemctl stop asm-ir 2>/dev/null || true
            LEGACY_ACTIVE=0
        fi
        CHECK_COUNT=0
    else
        if [ \$DPI_ACTIVE -eq 1 ]; then
            CHECK_COUNT=\$((CHECK_COUNT + 1))
            echo "[T2HASH-FALLBACK] DPI service down (\$CHECK_COUNT/\$MAX_CHECKS)..."
            if [ \$CHECK_COUNT -ge \$MAX_CHECKS ]; then
                echo "[T2HASH-FALLBACK] Activating legacy fallback!"
                systemctl start asm-ir 2>/dev/null || true
                LEGACY_ACTIVE=1
                DPI_ACTIVE=0
            fi
        fi
    fi
    sleep 5
done
IN_EOF
        chmod +x /root/t2hash-fallback.sh

        cat << 'IN_EOF' > /etc/systemd/system/t2hash-fallback.service
[Unit]
Description=T2HASH Fallback Watchdog
After=network-online.target asm-ir-dpi.service asm-ir.service
Wants=asm-ir-dpi.service

[Service]
Type=simple
ExecStart=/root/t2hash-fallback.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=t2hash-fallback

[Install]
WantedBy=multi-user.target
IN_EOF
    fi

    systemctl daemon-reload

    case "$TRANSPORT_MODE" in
        1)
            systemctl enable --now asm-ir gost-ir || die "Service start failed!"
            ;;
        2)
            systemctl enable --now asm-ir-dpi gost-ir || die "Service start failed!"
            ;;
        3)
            systemctl enable --now asm-ir-dpi gost-ir t2hash-fallback || die "Service start failed!"
            ;;
    esac
fi

# ----------------------------------------------------------------
#  [7/7] Final status and verification
# ----------------------------------------------------------------
echo -e "      ${RED}[7/7]${RESET} ${GREY}Barresi vaziat servis ha...${RESET}"
sleep 3

if [ "$SERVER_TYPE" == "1" ]; then
    echo ""
    echo -e "      ${DARK}======================================================${RESET}"
    echo -e "      ${GREEN} NASB V3.0 KAMEL — Server Kharej${RESET}"
    echo ""
    echo -e "      ${WHITE}Mode:${RESET}     ${PINK}$(case $TRANSPORT_MODE in 1)echo 'Legacy (V2.0)';;
        2)echo 'DPI-Resilient [${TRANSPORT_PROFILE}]';;
        3)echo 'Hybrid (DPI + Legacy fallback) [${TRANSPORT_PROFILE}]';;esac)${RESET}"
    echo -e "      ${WHITE}Port:${RESET}     ${PINK}${HZ_PORT}/UDP${RESET}"
    echo -e "      ${WHITE}Gost:${RESET}     ${PINK}127.0.0.1:${GOST_PORT}${RESET}"
    echo ""
    echo -e "      ${GREEN}Active services:${RESET}"
    for svc in asm-hz asm-hz-dpi gost-hz t2hash-fallback; do
        if [ -f "/etc/systemd/system/${svc}.service" ]; then
            status=$(systemctl is-active "$svc" 2>/dev/null || echo "failed")
            echo -e "      ${WHITE}  ${svc}:${RESET}  ${status}"
        fi
    done
    echo ""
    echo -e "      ${CYAN}Logs:${RESET} journalctl -u asm-hz-dpi -f"
    echo -e "      ${CYAN}Config:${RESET} /etc/t2hash/t2hash.conf"
else
    echo ""
    echo -e "      ${DARK}======================================================${RESET}"
    echo -e "      ${GREEN} NASB V3.0 KAMEL — Server Iran${RESET}"
    echo ""
    echo -e "      ${WHITE}Mode:${RESET}     ${PINK}$(case $TRANSPORT_MODE in 1)echo 'Legacy (V2.0)';;
        2)echo 'DPI-Resilient [${TRANSPORT_PROFILE}]';;
        3)echo 'Hybrid (DPI + Legacy fallback) [${TRANSPORT_PROFILE}]';;esac)${RESET}"
    echo -e "      ${WHITE}IR Port:${RESET}  ${PINK}${IR_PORT}/UDP${RESET}"
    echo -e "      ${WHITE}SOCKS5:${RESET}   ${PINK}0.0.0.0:${SOCKS_PORT}${RESET}"
    echo -e "      ${WHITE}HZ IP:${RESET}    ${PINK}${OUT_IP}:${HZ_PORT}${RESET}"
    echo ""
    echo -e "      ${GREEN}Active services:${RESET}"
    for svc in asm-ir asm-ir-dpi gost-ir t2hash-fallback; do
        if [ -f "/etc/systemd/system/${svc}.service" ]; then
            status=$(systemctl is-active "$svc" 2>/dev/null || echo "failed")
            echo -e "      ${WHITE}  ${svc}:${RESET}  ${status}"
        fi
    done
    echo ""
    echo -e "      ${CYAN}Logs:${RESET} journalctl -u asm-ir-dpi -f"
    echo -e "      ${CYAN}Config:${RESET} /etc/t2hash/t2hash.conf"
fi

echo -e "      ${DARK}======================================================${RESET}"
echo ""
EOF
chmod +x install.sh
