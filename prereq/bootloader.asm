; start of bootloader for BIOS
org 0x7C00
; assembler emits 16bit code because CPU always starts in 16bit mode
bits 16

; Helper macro for endline
%define ENDL 0x0D, 0x0A

; FAT12 headers
jmp short start
nop

bdb_oem: db 'MSWIN4.1'
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1 
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors: dw 2880
bdb_media_descriptor_type: db 0F0h
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2 
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

; extended boot record
ebr_drive_number: db 0
db 0
ebr_signature: db 29h
ebr_volume_id: db 12h, 34h, 56h, 78h
ebr_volume_label: db 'NIKOS      '
ebr_system_id: db 'FAT12   '

; needed to always start at main, skip the defined functions
start:
    jmp main

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
    

main:
    ; initialize data and extra segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; initialize stack
    mov ss, ax
    mov sp, 0x7C00

    ; print hello world
    mov si, msg_hello
    call puts

    ; halts the CPU.
    hlt

.halt:
    jmp .halt

msg_hello: db "Hello, World!", ENDL, 0

; pad the bootloader to 512 bytes, required by BIOS
; $ = memory offset of the line, $$ = memory offset of the start of the current section
times 510 - ($ - $$) db 0
dw 0AA55h
