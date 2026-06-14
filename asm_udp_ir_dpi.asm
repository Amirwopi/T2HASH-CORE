; ================================================================
;  asm_udp_ir_dpi.asm — DPI-Resilient Transport (IR/Sender Side)
;  T2HASH V3.0
;
;  Key enhancements:
;   - 8 rotating XOR masks
;   - Random packet padding (1-128 bytes)
;   - Microsecond jitter between sends
;   - 1-byte mode header for fallback compatibility
; ================================================================

section .data
    ; sockaddr_in for bind — 0.0.0.0:7777
    bind_addr   db 0x02, 0x00, 0x1E, 0x61, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    ; sockaddr_in for HZ — [IP_INJECTED_AT_BUILD]:443
    hz_addr     db 0x02, 0x00, 0x01, 0xBB, 0x00, 0x00, 0x00, 0x00
                db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    opt_one     dd 1
    opt_bufsize dd 26214400

    ; 8 rotating XOR masks
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

    log_start   db "[T2HASH-DPI] IR relay bound on 0.0.0.0:7777", 10, 0
    log_pkt     db "[T2HASH-DPI] IR packet processed", 10, 0
    log_drop    db "[T2HASH-DPI] IR dropping — no client/Gost yet", 10, 0
    log_peer    db "[T2HASH-DPI] IR client registered", 10, 0
    log_legacy  db "[T2HASH-DPI] IR fallback: legacy packet received", 10, 0

    mode_byte   db 0x01
    max_pad     equ 128

section .bss
    fd          resq 1
    buffer      resb 65536
    send_buf    resb 65536
    gost_addr   resb 16
    peer_addr   resb 16
    peer_len    resq 1
    pkt_counter resq 1
    mask_ptr    resq 1
    pad_buf     resb 128
    pad_len     resb 1
    jitter_ns   resq 1

section .text
    global _start

; ----------------------------------------------------------------
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

; ----------------------------------------------------------------
apply_jitter:
    push    rax
    push    rdx
    push    rdi
    push    rsi
    rdtsc
    and     rax, 0xFFF
    imul    rax, 125
    mov     [rel jitter_nsec], rax
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

; ----------------------------------------------------------------
gen_padding:
    push    rax
    push    rcx
    push    rdi
    rdtsc
    xor     edx, edx
    mov     ecx, 128
    div     ecx
    inc     edx
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

; ----------------------------------------------------------------
select_mask:
    push    rbx
    mov     rax, [rel pkt_counter]
    and     rax, 7
    shl     rax, 3
    mov     rbx, [rel mask0 + rax]
    mov     [rel mask_ptr], rbx
    mov     rax, rbx
    pop     rbx
    ret

; ----------------------------------------------------------------
_start:
    mov     rax, 41
    mov     rdi, 2
    mov     rsi, 2
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .fatal
    mov     [fd], rax

    ; SO_REUSEADDR
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 2
    lea     r10, [rel opt_one]
    mov     r8,  4
    syscall

    ; SO_RCVBUF
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 8
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall

    ; SO_SNDBUF
    mov     rax, 54
    mov     rdi, [fd]
    mov     rsi, 1
    mov     rdx, 7
    lea     r10, [rel opt_bufsize]
    mov     r8,  4
    syscall

    ; bind
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

; ----------------------------------------------------------------
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

    ; Mode detection
    movzx   eax, byte [rel buffer]
    cmp     al, 0x00
    je      .handle_legacy
    cmp     al, 0x01
    je      .handle_dpi
    jmp     .main_loop

; ----------------------------------------------------------------
.handle_dpi:
    inc     qword [rel pkt_counter]
    call    select_mask

    ; Decode incoming payload (from HZ or local Gost)
    mov     r14, r12
    dec     r14
    jz      .dpi_done

    xor     r13, r13
    mov     rbx, rax
.xor_bulk:
    lea     rcx, [r13 + 8]
    cmp     rcx, r14
    jg      .xor_tail
    xor     qword [rel buffer + 1 + r13], rbx
    add     r13, 8
    jmp     .xor_bulk
.xor_tail:
    cmp     r13, r14
    jge     .dpi_done
    mov     bl, [rel buffer + 1 + r13]
    xor     bl, byte [rel mask_ptr]
    mov     [rel buffer + 1 + r13], bl
    inc     r13
    jmp     .xor_tail

.dpi_done:
    movzx   ebx, byte [rel buffer + r12 - 1]
    cmp     ebx, 0
    je      .dpi_no_pad
    cmp     ebx, 128
    jg      .dpi_no_pad
    sub     r12, rbx
    dec     r12

.dpi_no_pad:
    mov     eax, dword [rel peer_addr + 4]
    cmp     eax, 0x0100007F
    je      .dpi_from_client

    ; From HZ — forward to local Gost
.dpi_from_hz:
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

    ; From local Gost — forward to HZ
.dpi_from_client:
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

; ----------------------------------------------------------------
.handle_legacy:
    lea     rsi, [rel log_legacy]
    call    log_msg

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
    jne     .legacy_from_hz

.legacy_from_client:
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

.legacy_from_hz:
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
