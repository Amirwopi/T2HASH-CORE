; ================================================================
;  asm_udp_hz_dpi.asm — DPI-Resilient Transport (HZ/Receiver Side)
;  T2HASH V3.0
;
;  Key enhancements over legacy:
;   - 8 rotating XOR masks (packet-counter-driven rotation)
;   - Random packet padding (1-128 bytes per packet)
;   - Microsecond timing jitter between sends
;   - 1-byte mode header for fallback compatibility
;   - Journald logging via stderr writes
; ================================================================

section .data
    ; sockaddr_in for bind — 0.0.0.0:443
    bind_addr   db 0x02, 0x00, 0x01, 0xBB, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    ; sockaddr_in for gost — 127.0.0.1:1080
    gost_addr   db 0x02, 0x00, 0x04, 0x38, 0x7F, 0x00, 0x00, 0x01
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    opt_one     dd 1
    opt_bufsize dd 26214400

    ; 8 rotating 64-bit XOR masks — eliminates static signature
    ; Generated from CSPRNG entropy, distributed across the 8-byte space
    mask0       dq 0x6B3A8E1F4C7D2A9F
    mask1       dq 0x3D7F2C5A9E1B8F4C
    mask2       dq 0x7E4C1A6B3D8F2E5A
    mask3       dq 0x1F8D5C2B4E9A7F3D
    mask4       dq 0x8C3E5A1B7D2F6E4A
    mask5       dq 0x2A7D4F1C3B8E5D6F
    mask6       dq 0x5F1B3D6E2C8A4F7B
    mask7       dq 0x4E8A2C6F1B3D5E7A

    ; Timespec structs for nanosleep (jitter between packets)
    ; tv_sec=0, tv_nsec will be randomized up to ~500,000ns (0.5ms)
    jitter_sec  dq 0
    jitter_nsec dq 0

    ; Log messages (null-terminated)
    log_start   db "[T2HASH-DPI] HZ relay bound on 0.0.0.0:443", 10, 0
    log_pkt     db "[T2HASH-DPI] HZ packet processed", 10, 0
    log_drop    db "[T2HASH-DPI] HZ dropping — no Iran peer yet", 10, 0
    log_peer    db "[T2HASH-DPI] HZ Iran peer registered", 10, 0
    log_legacy  db "[T2HASH-DPI] HZ fallback: legacy packet received", 10, 0

    mode_byte   db 0x01              ; DPI transport identifier
    max_pad     equ 128              ; maximum padding bytes

section .bss
    fd          resq 1
    buffer      resb 65536           ; 64 KB recv buffer
    send_buf    resb 65536           ; 64 KB send buffer (mode+payload+pad)
    ir_addr     resb 16
    peer_addr   resb 16
    peer_len    resq 1
    pkt_counter resq 1               ; rotating mask selector
    mask_ptr    resq 1               ; pointer to current mask
    pad_buf     resb 128             ; pre-generated padding bytes
    pad_len     resb 1               ; current packet padding length
    jitter_ns   resq 1               ; randomized nanosleep value

section .text
    global _start

; ----------------------------------------------------------------
;  Log helper — writes null-terminated string to stderr (fd 2)
;  Input: rsi = pointer to string
; ----------------------------------------------------------------
log_msg:
    push    rsi
    push    rcx
    ; find string length
    xor     rcx, rcx
.strlen:
    cmp     byte [rsi + rcx], 0
    je      .dowrite
    inc     rcx
    jmp     .strlen
.dowrite:
    mov     rax, 1                  ; sys_write
    mov     rdi, 2                  ; stderr
    ; rsi already set
    mov     rdx, rcx
    syscall
    pop     rcx
    pop     rsi
    ret

; ----------------------------------------------------------------
;  Jitter: sleep for a random number of microseconds
; ----------------------------------------------------------------
apply_jitter:
    push    rax
    push    rdx
    push    rdi
    push    rsi

    ; Use rdtsc for entropy — low 12 bits give 0-4095 * 125ns ≈ 0-511us
    rdtsc
    and     rax, 0xFFF              ; 0-4095
    imul    rax, 125                ; convert to nanoseconds (rough)
    mov     [rel jitter_nsec], rax
    mov     qword [rel jitter_nsec + 8], 0   ; clear upper bits if struct padded

    ; sys_nanosleep(&jitter_sec, NULL)
    mov     rax, 35                 ; sys_nanosleep
    lea     rdi, [rel jitter_sec]
    xor     rsi, rsi                ; NULL rem
    syscall

    pop     rsi
    pop     rdi
    pop     rdx
    pop     rax
    ret

; ----------------------------------------------------------------
;  Generate random padding bytes into pad_buf
;  Uses rdtsc + multiply for simple PRNG
; ----------------------------------------------------------------
gen_padding:
    push    rax
    push    rcx
    push    rdi

    rdtsc
    xor     edx, edx
    mov     ecx, 128
    div     ecx                     ; edx = remainder 0-127
    inc     edx                     ; 1-128
    mov     [rel pad_len], dl

    movzx   rcx, byte [rel pad_len]
    lea     rdi, [rel pad_buf]
.fill:
    rdtsc
    ; mix bits for better distribution
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

; ----------------------------------------------------------------
;  Select rotating mask based on pkt_counter % 8
;  Returns: rax = selected mask value
; ----------------------------------------------------------------
select_mask:
    push    rbx
    mov     rax, [rel pkt_counter]
    and     rax, 7                  ; counter % 8
    shl     rax, 3                  ; * 8 (offset into mask array)
    mov     rbx, [rel mask0 + rax]  ; load mask value
    mov     [rel mask_ptr], rbx
    mov     rax, rbx
    pop     rbx
    ret

; ----------------------------------------------------------------
_start:
    ; --- socket(AF_INET=2, SOCK_DGRAM=2, 0) ---
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

    ; --- bind(fd, &bind_addr, 16) ---
    mov     rax, 49
    mov     rdi, [fd]
    lea     rsi, [rel bind_addr]
    mov     rdx, 16
    syscall
    test    rax, rax
    js      .fatal

    ; --- Startup log ---
    lea     rsi, [rel log_start]
    call    log_msg

    ; Initialize packet counter
    mov     qword [rel pkt_counter], 0

; ----------------------------------------------------------------
.main_loop:
    ; --- recvfrom(fd, buffer, 65536, 0, &peer_addr, &peer_len) ---
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

    mov     r12, rax                ; r12 = received byte count

    ; --- Inspect mode byte ---
    movzx   eax, byte [rel buffer]
    cmp     al, 0x00
    je      .handle_legacy
    cmp     al, 0x01
    je      .handle_dpi
    ; Unknown mode — drop silently
    jmp     .main_loop

; ----------------------------------------------------------------
;  DPI Mode Handler
;  Packet format: [0x01][XORed_payload][pad_len_byte][padding_bytes]
; ----------------------------------------------------------------
.handle_dpi:
    ; Advance counter and select mask
    inc     qword [rel pkt_counter]
    call    select_mask             ; rax = current mask

    ; XOR payload in place (skip mode byte at buffer[0])
    ; Payload length = r12 - 1 (minus mode byte)
    mov     r14, r12
    dec     r14                     ; r14 = payload bytes to process
    jz      .dpi_done               ; empty payload, skip

    xor     r13, r13
    mov     rbx, rax                ; rbx = mask for bulk XOR

    ; Bulk XOR: 8 bytes at a time
.xor_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r14
    jg      .xor_tail
    xor     qword [rel buffer + 1 + r13], rbx
    add     r13, 8
    jmp     .xor_bulk

    ; Tail: byte-by-byte
.xor_tail:
    cmp     r13, r14
    jge     .dpi_done
    ; Use low byte of mask for tail
    mov     bl, [rel buffer + 1 + r13]
    xor     bl, byte [rel mask_ptr]
    mov     [rel buffer + 1 + r13], bl
    inc     r13
    jmp     .xor_tail

.dpi_done:
    ; Strip padding: read last byte for padding length
    ; The received packet has: [mode][payload][pad_len][padding]
    ; Read the byte at buffer[r12-1] which is pad_len
    movzx   ebx, byte [rel buffer + r12 - 1]
    cmp     ebx, 0
    je      .dpi_no_pad
    cmp     ebx, 128
    jg      .dpi_no_pad              ; sanity check, skip if > 128
    ; Strip 1 + padding bytes from total
    sub     r12, rbx
    dec     r12                     ; also remove the pad_len byte itself

.dpi_no_pad:
    ; Route decision
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    je      .dpi_from_gost

    ; --- From Iran: save peer, forward to Gost ---
.dpi_from_ir:
    mov     rax, qword [rel peer_addr]
    mov     qword [rel ir_addr], rax
    mov     rax, qword [rel peer_addr + 8]
    mov     qword [rel ir_addr + 8], rax

    lea     rsi, [rel log_peer]
    call    log_msg

    ; sendto(fd, buffer, r12, 0, &gost_addr, 16)
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

    ; --- From Gost: forward to Iran ---
.dpi_from_gost:
    movzx   eax, word [rel ir_addr]
    test    eax, eax
    jnz     .dpi_do_send

    lea     rsi, [rel log_drop]
    call    log_msg
    jmp     .main_loop

.dpi_do_send:
    ; Build DPI send packet in send_buf:
    ; [mode_byte][XORed_payload][pad_len][padding_bytes]
    mov     byte [rel send_buf], 0x01     ; mode byte

    ; Copy payload from buffer (skip recv mode byte) to send_buf+1
    ; Payload is r12 bytes (already includes padding from sender, we pass through)
    mov     rcx, r12
    dec     rcx                     ; don't copy mode byte
    lea     rsi, [rel buffer + 1]
    lea     rdi, [rel send_buf + 1]
    rep     movsb

    ; XOR the payload in send_buf with rotating mask
    call    select_mask
    mov     rbx, rax
    mov     r14, r12
    dec     r14
    xor     r13, r13
.xor_out_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r14
    jg      .xor_out_tail
    xor     qword [rel send_buf + 1 + r13], rbx
    add     r13, 8
    jmp     .xor_out_bulk
.xor_out_tail:
    cmp     r13, r14
    jge     .xor_out_pad
    mov     bl, [rel send_buf + 1 + r13]
    xor     bl, byte [rel mask_ptr]
    mov     [rel send_buf + 1 + r13], bl
    inc     r13
    jmp     .xor_out_tail

.xor_out_pad:
    ; Generate and append padding
    call    gen_padding
    movzx   rcx, byte [rel pad_len]
    mov     [rel send_buf + r14 + 1], cl   ; pad_len byte after payload
    lea     rsi, [rel pad_buf]
    lea     rdi, [rel send_buf + r14 + 2]
    rep     movsb                           ; copy padding bytes

    ; Total send size = 1 (mode) + r14 (payload) + 1 (pad_len) + pad_len
    mov     rdx, r14
    add     rdx, 2
    add     rdx, rcx                        ; rdx = final size

    ; sendto
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

; ----------------------------------------------------------------
;  Legacy Mode Handler (fallback, identical to V2.0)
; ----------------------------------------------------------------
.handle_legacy:
    lea     rsi, [rel log_legacy]
    call    log_msg

    ; Static XOR with 0x5A
    xor     r13, r13
    mov     rax, 0x5A5A5A5A5A5A5A5A
.legacy_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r12
    jg      .legacy_byte
    xor     [rel buffer + r13], rax
    add     r13, 8
    jmp     .legacy_bulk
.legacy_byte:
    cmp     r13, r12
    jge     .legacy_route
    mov     bl, [rel buffer + r13]
    xor     bl, 0x5A
    mov     [rel buffer + r13], bl
    inc     r13
    jmp     .legacy_byte

.legacy_route:
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    je      .legacy_from_gost

    ; From Iran
.legacy_from_ir:
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

.legacy_from_gost:
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

; ----------------------------------------------------------------
.fatal:
    mov     rax, 60
    mov     rdi, 1
    syscall
