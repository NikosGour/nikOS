org 0x7C00 ;start of bootloader for BIOS
bits 16 ;assembler emits 16bit code because CPU always starts in 16bit mode

%define ENDL 0x0D, 0x0A ;Helper macro for endline

; FAT12 headers
jmp short start
nop

bdb_oem: db 'MSWIN4.1'
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1 
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0xE0
bdb_total_sectors: dw 2880
bdb_media_descriptor_type: db 0xF0
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2 
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

; extended boot record
ebr_drive_number: db 0
db 0
ebr_signature: db 0x29
ebr_volume_id: db 0x12, 0x34, 0x56, 0x78
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
    lodsb ;read char from DS:SI into AL and increment SI
    or al, al ;if char is \0, string is finished
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
    
    ; read something from floppy disk
    mov [ebr_drive_number], dl ;BIOS should set DL to the drive number of boot device
    
    mov ax, 1 ;read second sector (LBA = 1)
    mov cl, 1 ;read 1 sector
    mov bx, 0x7E00 ;read into memory at 0x7E00, data should be after bootloader
    call disk_read

    ; print hello world
    mov si, msg_hello
    call puts

    ; halts the CPU.
    cli
    hlt

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 0x16 ;wait for keypress
    jmp 0xFFFF:0 ;jump to beggining of BIOS to reboot the system

.halt:
    cli ;disable interrupts, this way the CPU can't get out of halted state
    hlt

; Disk functions

;; LBA -> CHS
; params: ax = LBA
; returns: cx[0:5] = sector, cx[6:15] = track/cylinder, dh = head
lba_to_chs:
    push ax
    push dx

    xor dx, dx ;clear dx
    div word [bdb_sectors_per_track] ;ax = LBA / sectors_per_track
                                     ;dx = LBA % sectors_per_track
    inc dx                           ;dx = (LBA % sectors_per_track) + 1
    mov cx, dx ;cx = sector

    xor dx, dx ;clear dx
    div word [bdb_heads] ;ax = (LBA / sectors_per_track) / heads = track/cylinder
                         ;dx = (LBA / sectors_per_track) % heads = head
    mov dh, dl ;dh = head
    mov ch, al ;ch = track/cylinder (low 8 bits)
    shl ah, 6   
    or cl, ah ;cl = track/cylinder (high 2 bits) + sector (low 6 bits)

    pop ax
    mov dl, al
    pop ax
    ret

;; Read sector from disk
; params: ax = LBA, cl = number of sectors to read, dl = drive_number, es:bx = buffer to read in
disk_read:
    
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax

    mov ah, 0x2 ;read disk interrupt
    mov di, 3 ;retry count

.retry:
    pusha ;save all registers to stack
    stc ;set carry flag, some BIOSes don't set it
    int 0x13
    jnc .done
    
    ; read failed, retry
    popa ;restore all registers from stack
    call disk_reset
    
    dec di
    test di, di
    jnz .retry

.fail: 
    ; max retries reached
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;; Resets disk controller
; params: dl = drive_number
disk_reset:  
    pusha
    mov ah, 0
    stc
    int 0x13
    jc floppy_error
    popa
    ret

msg_hello: db "Hello, World!", ENDL, 0
msg_read_failed: db "Failed to read from disk", ENDL, 0

; pad the bootloader to 512 bytes, required by BIOS
; $ = memory offset of the line, $$ = memory offset of the start of the current section
times 510 - ($ - $$) db 0
dw 0xAA55
