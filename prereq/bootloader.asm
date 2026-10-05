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
    ; initialize data and extra segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; initialize stack
    mov ss, ax
    mov sp, 0x7C00

    ; some BIOSes might start at 0x7C00
    push es
    push word .after
    retf

.after:
    
    ; read something from floppy disk
    mov [ebr_drive_number], dl ;BIOS should set DL to the drive number of boot device
    
    mov ax, 1 ;read second sector (LBA = 1)
    mov cl, 1 ;read 1 sector
    mov bx, 0x7E00 ;read into memory at 0x7E00, data should be after bootloader
    call disk_read

    ; print hello world
    mov si, msg_loading
    call puts

    push es
    mov ah, 0x8
    int 0x13
    jc floppy_error
    pop es

    and cl, 0x3F ;remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx ;sector count

    inc dh
    mov [bdb_heads], dh ;head count

    ; compute LBA of root directory = reserved + fats * sectors_per_fat
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx ;ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors] ;ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5 ;ax *= 32
    xor dx, dx 
    div word [bdb_bytes_per_sector] ; number of sectors we need to read

    test dx, dx ;if dx != 0 add 1
    jz .root_dir_after
    inc ax ;remainder != 0 add 1
           ;this means we have a sector only partially filled with entries

.root_dir_after:

    ; read root directory
    mov cl, al ;cl = number of sectors to read = size of root directory
    pop ax ; ax = LBA of root directory
    mov dl, [ebr_drive_number] ; dl = drive number
    mov bx, buffer ;es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11 ; compare up to 11 chars
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ; kernel not found
    jmp kernel_not_found_error

.found_kernel:
    ; di should have the address to the entry
    mov ax, [di + 26] ;first logical cluster field (offset 26)
    mov [kernel_cluster], ax

    ; load FAT from disk into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read
    
    ; read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    ; Read next cluster
    mov ax, [kernel_cluster]
    add ax, 31

    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]
    or dx, dx
    jz .even
.odd: 
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8 ;end of chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    ; jump to our kernel
    mov dl, [ebr_drive_number] ;boot device in dl
    mov ax, KERNEL_LOAD_SEGMENT ;set segement registers
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot

    ; halts the CPU.
    cli
    hlt

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot


wait_key_and_reboot:
    mov ah, 0
    int 0x16 ;wait for keypress
    jmp 0xFFFF:0 ;jump to beggining of BIOS to reboot the system

.halt:
    cli ;disable interrupts, this way the CPU can't get out of halted state
    hlt

puts:
    ; save registers to stack, prologue
    push si
    push ax
    push bx

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
    pop bx
    pop ax
    pop si
    ret
    

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

msg_loading: db "loading", ENDL, 0
msg_read_failed: db "disk fail", ENDL, 0
msg_kernel_not_found: db "Couldn't find kernel", ENDL, 0
file_kernel_bin: db "KERNEL  BIN"
kernel_cluster: dw 0

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET equ 0

; pad the bootloader to 512 bytes, required by BIOS
; $ = memory offset of the line, $$ = memory offset of the start of the current section
times 510 - ($ - $$) db 0
dw 0xAA55

buffer: 
