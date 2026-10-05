org 0
; assembler emits 16bit code because CPU always starts in 16bit mode
bits 16

; Helper macro for endline
%define ENDL 0x0D, 0x0A

; needed to always start at main, skip the defined functions
start:
    ; print hello world
    mov si, msg_hello
    call puts

.halt:
    ; halts the CPU.
    cli
    hlt

puts:
    ; save registers to stack, prologue
    push si
    push ax

.loop:
    ; read char from DS:SI into AL and increment SI
    lodsb
    ; if char is \0, string is finished
    or al, al
    jz .done

    ; print char in AL to screen using BIOS interrupt 0x10
    mov ah, 0x0E
    mov bh, 0
    int 0x10

    jmp .loop

.done:
    ; restore registers from stack, epilogue
    pop ax
    pop si
    ret

msg_hello: db "Hello, World!", ENDL, 0

; pad the bootloader to 512 bytes, required by BIOS
; $ = memory offset of the line, $$ = memory offset of the start of the current section
times 510 - ($ - $$) db 0
dw 0AA55h
