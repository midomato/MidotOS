[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax

    call clear_screen
    call enable_mouse

    mov word [cursor_x], 40
    mov word [cursor_y], 12

main_loop:
    call print_hex_byte
    call sync_mouse_packet
    call update_cursor
    jmp main_loop

; === 画面初期化 ===
clear_screen:
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov cx, 2000
    mov ah, 0x10
    mov al, ' '
.fill:
    stosw
    loop .fill
    ret

; === デバッグ ===
print_hex_byte:
    pusha
    mov al, [mouse_ack]     ; ← ACK（0xFA）を表示
    mov bx, 0xB800
    mov es, bx
    xor bx, bx

    ; 上位4bit
    mov al, [mouse_byte1]
    mov ah, al
    shr ah, 4
    call print_hex_digit

    ; 下位4bit
    and al, 0x0F
    call print_hex_digit

    popa
    ret

print_hex_digit:
    ; ALに0〜15が入ってる前提
    cmp al, 10
    jl .digit
    add al, 'A' - 10
    jmp .print
.digit:
    add al, '0'
.print:
    mov di, bx
    mov ah, 0x0F       ; 白文字
    stosw
    add bx, 2          ; 次の文字位置へ
    ret

; === マウス有効化 ===
enable_mouse:
    call wait_input_ready
    mov al, 0xA8
    out 0x64, al

    call wait_input_ready
    mov al, 0x20
    out 0x64, al
    call wait_output_ready
    in al, 0x60
    or al, 0x02
    call wait_input_ready
    mov al, 0x60
    out 0x64, al
    call wait_input_ready
    out 0x60, al

    ; === マウス有効化コマンド送信 ===
    mov al, 0xD4         ; マウスに送る指示
    out 0x64, al

    call mouse_wait_send
    mov al, 0xF4         ; マウス有効化
    out 0x60, al

    ; === ACK受信待ち ===
    call wait_output_ready
    in al, 0x60
    mov [mouse_ack], al        ; ← ここにACK格納

    ret


; === マウスパケット同期付き読み取り ===
sync_mouse_packet:
.wait_first:
    call wait_output_ready
    in al, 0x60
    test al, 0x08          ; bit3 == 1 ?
    jz .wait_first
    mov [mouse_byte0], al

    call wait_output_ready
    in al, 0x60
    mov [mouse_byte1], al

    call wait_output_ready
    in al, 0x60
    mov [mouse_byte2], al
    ret


; === カーソル更新 ===
update_cursor:
    call draw_cursor_clear

    mov al, [mouse_byte1]
    cbw
    add [cursor_x], ax

    mov al, [mouse_byte2]
    cbw
    neg ax
    add [cursor_y], ax

    mov ax, [cursor_x]
    cmp ax, 0
    jge .x_ok1
    mov ax, 0
.x_ok1:
    cmp ax, 79
    jle .x_ok2
    mov ax, 79
.x_ok2:
    mov [cursor_x], ax

    mov ax, [cursor_y]
    cmp ax, 0
    jge .y_ok1
    mov ax, 0
.y_ok1:
    cmp ax, 24
    jle .y_ok2
    mov ax, 24
.y_ok2:
    mov [cursor_y], ax

    call draw_cursor
    ret

; === カーソル描画・消去 ===
draw_cursor:
    mov ax, 0xB800
    mov es, ax
    mov ax, [cursor_y]
    mov bx, 80
    mul bx
    add ax, [cursor_x]
    shl ax, 1
    mov di, ax
    mov ah, 0x1F
    mov al, '@'
    stosw
    ret

draw_cursor_clear:
    mov ax, 0xB800
    mov es, ax
    mov ax, [cursor_y]
    mov bx, 80
    mul bx
    add ax, [cursor_x]
    shl ax, 1
    mov di, ax
    mov ah, 0x10
    mov al, ' '
    stosw
    ret

; === I/O 同期 ===
wait_input_ready:
    in al, 0x64
    test al, 0x02
    jnz wait_input_ready
    ret

wait_output_ready:
    in al, 0x64
    test al, 0x01
    jz wait_output_ready
    ret

mouse_wait_send:
    call wait_input_ready
    ret

; === 変数 ===
cursor_x dw 40
cursor_y dw 12
mouse_byte0 db 0
mouse_byte1 db 0
mouse_byte2 db 0
mouse_ack   db 0

times 510 - ($ - $$) db 0
dw 0xAA55
