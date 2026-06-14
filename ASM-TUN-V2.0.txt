rm -f install.sh
cat << 'EOF' > install.sh
#!/bin/bash

# ================================================================
#  ASM-TUN v2.0 — T2HASH Layer-0 Assembly Tunnel
#  Optimized by: Amirwopi — Bug fixes & hardening
# ================================================================

set -euo pipefail

RED='\033[38;5;196m'
PINK='\033[38;5;198m'
DARK='\033[38;5;236m'
GREY='\033[38;5;245m'
WHITE='\033[1;37m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;226m'
RESET='\033[0m'

# ----------------------------------------------------------------
#  Helper Functions
# ----------------------------------------------------------------
die() { echo -e "      ${RED}[FATAL]${RESET} $1" >&2; exit 1; }
info() { echo -e "      ${DARK}[+]${RESET} ${GREY}$1${RESET}"; }
ok()   { echo -e "      ${GREEN}[✓]${RESET} $1"; }
warn() { echo -e "      ${YELLOW}[!]${RESET} $1"; }

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
echo -e "              ${GREY}Optimized & Hardened — v2.0${RESET}"
echo -e "      ${DARK}======================================================${RESET}"
echo ""
echo -e "             ${WHITE}[ 1 ] ${GREY}Server Kharej (Hetzner / Receiver)${RESET}"
echo -e "             ${WHITE}[ 2 ] ${GREY}Server Iran (Sender)${RESET}"
echo ""
echo -e "      ${DARK}------------------------------------------------------${RESET}"
echo -ne "      ${PINK}root@t2hash${WHITE}:~#${RESET} Koodom server ro dari config mikoni? [1 ya 2]: "
read -r RAW_TYPE
SERVER_TYPE=$(echo "$RAW_TYPE" | tr -d '\r\n ')

[[ "$SERVER_TYPE" != "1" && "$SERVER_TYPE" != "2" ]] && \
    die "Entekhab eshtebah ast! Faghat 1 ya 2 vared kon."

OUT_IP=""
HEX_IP=""

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

# ----------------------------------------------------------------
#  Cleanup Previous Versions
# ----------------------------------------------------------------
echo -e "      ${RED}[1/6]${RESET} ${GREY}Pak kardan nuskhe haye ghabli...${RESET}"
systemctl stop  asm-hz gost-hz asm-ir gost-ir 2>/dev/null || true
systemctl disable asm-hz gost-hz asm-ir gost-ir 2>/dev/null || true
rm -f /etc/systemd/system/asm-hz.service  \
      /etc/systemd/system/gost-hz.service \
      /etc/systemd/system/asm-ir.service  \
      /etc/systemd/system/gost-ir.service \
      /root/asm_udp_hz /root/asm_udp_hz.asm /root/asm_udp_hz.o \
      /root/asm_udp_ir /root/asm_udp_ir.asm /root/asm_udp_ir.o
systemctl daemon-reload
ok "Pak sazi anjam shod."

# ----------------------------------------------------------------
#  [2/6] Install prerequisites
# ----------------------------------------------------------------
echo -e "      ${RED}[2/6]${RESET} ${GREY}Nasb pish-niaz ha...${RESET}"
apt-get update -qq
apt-get install -y -qq nasm build-essential wget gzip > /dev/null 2>&1 \
    || die "Nasb pish-niaz ha shekast khord!"
ok "Pish-niaz ha nasb shodand."

# ----------------------------------------------------------------
#  Download GOST
# ----------------------------------------------------------------
echo -e "      ${RED}[3/6]${RESET} ${GREY}Danload / barresi Gost...${RESET}"
GOST_SHA256="a3b4f5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4"  # placeholder
if [ ! -f /usr/local/bin/gost ]; then
    wget -q --show-progress \
         https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz \
         -O /tmp/gost.gz \
         || die "Danload Gost shekast khord!"
    gzip -d /tmp/gost.gz
    chmod +x /tmp/gost
    mv /tmp/gost /usr/local/bin/gost
    ok "Gost nasb shod."
else
    ok "Gost ghablan nasb shode, skip..."
fi

# ----------------------------------------------------------------
#  Optimize kernel buffers (anti packet loss)
# ----------------------------------------------------------------
echo -e "      ${RED}[4/6]${RESET} ${GREY}Behin-sazi kernel buffer (anti packet-loss)...${RESET}"
BUF=26214400
sysctl -w net.core.rmem_max=$BUF     >/dev/null
sysctl -w net.core.rmem_default=$BUF >/dev/null
sysctl -w net.core.wmem_max=$BUF     >/dev/null
sysctl -w net.core.wmem_default=$BUF >/dev/null
sysctl -w net.core.netdev_max_backlog=5000 >/dev/null
# Persist across reboots
grep -q "rmem_max" /etc/sysctl.conf 2>/dev/null || cat >> /etc/sysctl.conf << SYSCTL
# T2HASH kernel tuning
net.core.rmem_max=$BUF
net.core.rmem_default=$BUF
net.core.wmem_max=$BUF
net.core.wmem_default=$BUF
net.core.netdev_max_backlog=5000
SYSCTL
ok "Kernel buffer behin sazi anjam shod (persistent)."

# ----------------------------------------------------------------
#  Generate Assembly code and services
# ----------------------------------------------------------------
echo -e "      ${RED}[5/6]${RESET} ${GREY}Sakht kode Assembly va compile...${RESET}"

# ================================================================
#  SERVER KHAREJ (HZ) — Receiver
#  Port 443 UDP: receives from Iran ASM, forwards to Gost KCP 1080
#                receives from Gost KCP 1080, forwards back to Iran
#
#  FIXES APPLIED:
#  1. SO_REUSEADDR via setsockopt (syscall 54) before bind
#  2. SO_RCVBUF / SO_SNDBUF set to 26MB at socket level
#  3. XOR loop uses r13/bl instead of rcx/al to avoid rax clobber
#  4. peer_len reset BEFORE recvfrom args setup (was after)
#  5. ir_addr zero-initialized in .bss (already, but now guarded)
#  6. 8-byte bulk XOR for packets >= 8 bytes (throughput optimized)
# ================================================================
if [ "$SERVER_TYPE" == "1" ]; then

cat << 'IN_EOF' > /root/asm_udp_hz.asm
; ================================================================
;  ASM-TUN v2.0 — HZ Side (Receiver / Kharej)
;  Binds: 0.0.0.0:443 UDP
;  Gost:  127.0.0.1:1080 KCP
; ================================================================

section .data
    ; sockaddr_in for bind — 0.0.0.0:443
    bind_addr   db 0x02, 0x00, 0x01, 0xBB, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    ; sockaddr_in for gost — 127.0.0.1:1080
    gost_addr   db 0x02, 0x00, 0x04, 0x38, 0x7F, 0x00, 0x00, 0x01
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    ; setsockopt values
    opt_one     dd 1                    ; SO_REUSEADDR = 1
    opt_bufsize dd 26214400             ; 25 MB socket buffer

    ; XOR mask replicated across 8 bytes for bulk processing
    xor_mask_64 dq 0x5A5A5A5A5A5A5A5A

section .bss
    fd          resq 1
    buffer      resb 65536              ; 64 KB — fits any UDP packet
    ir_addr     resb 16                 ; last seen Iran peer address
    peer_addr   resb 16                 ; recvfrom source address
    peer_len    resq 1
    opt_tmp     resd 1                  ; temp for setsockopt return area

section .text
    global _start

; ----------------------------------------------------------------
_start:
; --- socket(AF_INET=2, SOCK_DGRAM=2, 0) = fd ---
    mov     rax, 41
    mov     rdi, 2
    mov     rsi, 2
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .fatal
    mov     [fd], rax

; --- setsockopt(fd, SOL_SOCKET=1, SO_REUSEADDR=2, &1, 4) ---
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1                      ; SOL_SOCKET
    mov     rdx, 2                      ; SO_REUSEADDR
    lea     r10, [rel opt_one]
    mov     r8,  4
    syscall

; --- setsockopt(fd, SOL_SOCKET=1, SO_RCVBUF=8, &bufsize, 4) ---
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 8                      ; SO_RCVBUF
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall

; --- setsockopt(fd, SOL_SOCKET=1, SO_SNDBUF=7, &bufsize, 4) ---
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 7                      ; SO_SNDBUF
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall

; --- bind(fd, &bind_addr, 16) ---
    mov     rax, 49
    mov     rdi, [fd]
    lea     rsi, [rel bind_addr]
    mov     rdx, 16
    syscall
    test    rax, rax
    js      .fatal

; ----------------------------------------------------------------
.loop:
; --- recvfrom(fd, buffer, 65536, 0, &peer_addr, &peer_len) ---
    mov     qword [peer_len], 16        ; MUST reset before each call
    mov     rax, 45
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, 65536
    xor     r10, r10                    ; flags = 0
    lea     r8,  [rel peer_addr]
    lea     r9,  [rel peer_len]
    syscall
    cmp     rax, 0
    jle     .loop                       ; skip on error / zero-byte

    mov     r12, rax                    ; r12 = bytes received

; --- XOR obfuscation ---
; r13 = index, bl = byte scratch (no rax clobber)
    xor     r13, r13

; Bulk: 8 bytes at a time while remaining >= 8
    mov     rax, [rel xor_mask_64]
.xor_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r12
    jg      .xor_byte                   ; less than 8 bytes left
    xor     [rel buffer + r13], rax
    add     r13, 8
    jmp     .xor_bulk

; Tail: byte-by-byte for remainder
.xor_byte:
    cmp     r13, r12
    jge     .xor_done
    mov     bl, [rel buffer + r13]
    xor     bl, 0x5A
    mov     [rel buffer + r13], bl
    inc     r13
    jmp     .xor_byte
.xor_done:

; --- Route decision: is peer 127.0.0.1? ---
; peer_addr[4..7] = IP in network order (0x7F000001 for localhost)
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F             ; 127.0.0.1 in little-endian memory
    je      .from_gost

; ----------------------------------------------------------------
.from_ir:
; Save Iran peer address for reverse path
    mov     rax, qword [rel peer_addr]
    mov     qword [rel ir_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel ir_addr + 8], rax

; sendto(fd, buffer, r12, 0, &gost_addr, 16)
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel gost_addr]
    mov     r9,  16
    syscall
    jmp     .loop

; ----------------------------------------------------------------
.from_gost:
; Guard: if ir_addr is not yet set (family=0), drop packet
    movzx   eax, word [rel ir_addr]
    test    eax, eax
    jz      .loop                       ; drop — no Iran peer known yet

; sendto(fd, buffer, r12, 0, &ir_addr, 16)
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel ir_addr]
    mov     r9,  16
    syscall
    jmp     .loop

; ----------------------------------------------------------------
.fatal:
; exit(1) on socket/bind failure
    mov     rax, 60
    mov     rdi, 1
    syscall
IN_EOF

    # Compile
    nasm -f elf64 /root/asm_udp_hz.asm -o /root/asm_udp_hz.o \
        || die "NASM compile shekast khord (hz)!"
    ld /root/asm_udp_hz.o -o /root/asm_udp_hz \
        || die "Linker shekast khord (hz)!"
    ok "ASM binary (hz) sakht shod."

    # Systemd — ASM
    cat << 'IN_EOF' > /etc/systemd/system/asm-hz.service
[Unit]
Description=T2HASH Assembly UDP Receiver (HZ)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/root/asm_udp_hz
Restart=always
RestartSec=2
LimitNOFILE=65536
LimitNPROC=1024
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF

    # Systemd — GOST
    cat << 'IN_EOF' > /etc/systemd/system/gost-hz.service
[Unit]
Description=T2HASH Gost KCP Stealth Receiver (HZ)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost \
    -L "kcp://127.0.0.1:1080?mode=normal&mtu=1350&nocomp=true&smux=true&keepalive=true&interval=50&resend=2&nc=1"
Restart=always
RestartSec=2
LimitNOFILE=65536
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF

    systemctl daemon-reload
    systemctl enable --now asm-hz gost-hz \
        || die "Enable/start services shekast khord!"

# ================================================================
#  SERVER IRAN (IR) — Sender
#  Port 7777 UDP: receives from local Gost, forwards to HZ:443
#                 receives from HZ:443, forwards back to local Gost
#
#  FIXES APPLIED:
#  1. SO_REUSEADDR + SO_RCVBUF/SO_SNDBUF
#  2. gost_addr (client addr) guard: drop if not yet seen
#  3. XOR uses r13/bl — no rax clobber
#  4. peer_len reset before each recvfrom
#  5. 8-byte bulk XOR
#  6. hz_addr IP injected at build time from validated input
# ================================================================
elif [ "$SERVER_TYPE" == "2" ]; then

cat << IN_EOF > /root/asm_udp_ir.asm
; ================================================================
;  ASM-TUN v2.0 — IR Side (Sender / Iran)
;  Binds: 0.0.0.0:7777 UDP
;  HZ:    ${OUT_IP}:443  (${HEX_IP})
; ================================================================

section .data
    ; sockaddr_in for bind — 0.0.0.0:7777 (0x1E61)
    bind_addr   db 0x02, 0x00, 0x1E, 0x61, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    ; sockaddr_in for HZ — ${OUT_IP}:443
    hz_addr     db 0x02, 0x00, 0x01, 0xBB, ${HEX_IP}
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    opt_one     dd 1
    opt_bufsize dd 26214400

    xor_mask_64 dq 0x5A5A5A5A5A5A5A5A

section .bss
    fd          resq 1
    buffer      resb 65536
    gost_addr   resb 16                 ; last local Gost client address
    peer_addr   resb 16
    peer_len    resq 1

section .text
    global _start

_start:
; --- socket(AF_INET, SOCK_DGRAM, 0) ---
    mov     rax, 41
    mov     rdi, 2
    mov     rsi, 2
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .fatal
    mov     [fd], rax

; --- setsockopt SO_REUSEADDR ---
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 2
    lea     r10, [rel opt_one]
    mov     r8,  4
    syscall

; --- setsockopt SO_RCVBUF ---
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 8
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall

; --- setsockopt SO_SNDBUF ---
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 7
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall

; --- bind ---
    mov     rax, 49
    mov     rdi, [fd]
    lea     rsi, [rel bind_addr]
    mov     rdx, 16
    syscall
    test    rax, rax
    js      .fatal

.loop:
; --- recvfrom ---
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

; --- XOR bulk then tail ---
    xor     r13, r13
    mov     rax, [rel xor_mask_64]
.xor_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r12
    jg      .xor_byte
    xor     [rel buffer + r13], rax
    add     r13, 8
    jmp     .xor_bulk
.xor_byte:
    cmp     r13, r12
    jge     .xor_done
    mov     bl, [rel buffer + r13]
    xor     bl, 0x5A
    mov     [rel buffer + r13], bl
    inc     r13
    jmp     .xor_byte
.xor_done:

; --- Route: is peer 127.0.0.1? ---
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    jne     .from_hz

; ----------------------------------------------------------------
.from_client:
; Save local Gost client address
    mov     rax, qword [rel peer_addr]
    mov     qword [rel gost_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel gost_addr + 8], rax

; sendto -> HZ
    mov     rax, 44
    mov     rdi, [fd]
    lea     rsi, [rel buffer]
    mov     rdx, r12
    xor     r10, r10
    lea     r8,  [rel hz_addr]
    mov     r9,  16
    syscall
    jmp     .loop

; ----------------------------------------------------------------
.from_hz:
; Guard: drop if local client not yet connected
    movzx   eax, word [rel gost_addr]
    test    eax, eax
    jz      .loop

; sendto -> local Gost client
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

    nasm -f elf64 /root/asm_udp_ir.asm -o /root/asm_udp_ir.o \
        || die "NASM compile shekast khord (ir)!"
    ld /root/asm_udp_ir.o -o /root/asm_udp_ir \
        || die "Linker shekast khord (ir)!"
    ok "ASM binary (ir) sakht shod."

    cat << 'IN_EOF' > /etc/systemd/system/asm-ir.service
[Unit]
Description=T2HASH Assembly UDP Sender (IR)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/root/asm_udp_ir
Restart=always
RestartSec=2
LimitNOFILE=65536
LimitNPROC=1024
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF

    cat << 'IN_EOF' > /etc/systemd/system/gost-ir.service
[Unit]
Description=T2HASH Gost KCP Stealth Sender (IR)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost \
    -L socks5://:8081 \
    -F "kcp://127.0.0.1:7777?mode=normal&mtu=1350&nocomp=true&smux=true&keepalive=true&interval=50&resend=2&nc=1"
Restart=always
RestartSec=2
LimitNOFILE=65536
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
IN_EOF

    systemctl daemon-reload
    systemctl enable --now asm-ir gost-ir \
        || die "Enable/start services shekast khord!"
fi

# ----------------------------------------------------------------
# Final status
# ----------------------------------------------------------------
echo -e "      ${RED}[6/6]${RESET} ${GREY}Barresi vaziat servis ha...${RESET}"
sleep 2

if [ "$SERVER_TYPE" == "1" ]; then
    ASM_SVC="asm-hz"
    GOST_SVC="gost-hz"
else
    ASM_SVC="asm-ir"
    GOST_SVC="gost-ir"
fi

ASM_STATUS=$(systemctl is-active "$ASM_SVC"  2>/dev/null || echo "failed")
GOST_STATUS=$(systemctl is-active "$GOST_SVC" 2>/dev/null || echo "failed")

echo ""
echo -e "      ${DARK}======================================================${RESET}"
if [ "$SERVER_TYPE" == "1" ]; then
    echo -e "      ${GREEN}✅  NASB KAMEL SHOD — Server Kharej${RESET}"
    echo ""
    echo -e "      ${WHITE}Port:${RESET}  ${PINK}443/UDP${RESET}  (ASM receiver)"
    echo -e "      ${WHITE}Gost:${RESET}  ${PINK}127.0.0.1:1080${RESET}  (KCP local)"
else
    echo -e "      ${GREEN}✅  NASB KAMEL SHOD — Server Iran${RESET}"
    echo ""
    echo -e "      ${WHITE}Port:${RESET}  ${PINK}7777/UDP${RESET}  (ASM listener)"
    echo -e "      ${WHITE}SOCKS5:${RESET} ${PINK}0.0.0.0:8081${RESET}  (vasl be in)"
    echo -e "      ${WHITE}HZ IP:${RESET} ${PINK}${OUT_IP}${RESET}"
fi
echo ""
echo -e "      ${WHITE}$ASM_SVC:${RESET}   ${ASM_STATUS}"
echo -e "      ${WHITE}$GOST_SVC:${RESET}  ${GOST_STATUS}"
echo -e "      ${DARK}======================================================${RESET}"
echo ""
EOF
chmod +x install.sh
