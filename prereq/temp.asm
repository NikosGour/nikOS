; Declare constants used for creating a multiboot header.
%define ALIGN       (1 << 0)             ; align loaded modules on page boundaries
%define MEMINFO     (1 << 1)             ; provide memory map
%define FLAGS       (ALIGN | MEMINFO)    ; this is the Multiboot 'flag' field
%define MAGIC       0x1BADB002            ; magic number
%define CHECKSUM    -(MAGIC + FLAGS)     ; checksum

; Declare a header as in the Multiboot Standard.
section .multiboot
align 4
    dd MAGIC
    dd FLAGS
    dd CHECKSUM


; Currently ESP points at anything and using it may cause massive harm.
; Instead, provide our own stack.
section .bootstrap_stack nobits
align 16

stack_bottom:
    resb 16384                            ; 16 KiB
stack_top:


; Kernel entry point.
section .text
global _start
extern go_0kernel.Main
_start:
    ; Set up our stack. The stack grows downward.
    mov esp, stack_top

    ; Execute Go code.
    call go_0kernel.Main

    ; If Main returns, halt forever.
    cli

.Lhang:
    hlt
    jmp .Lhang


; Go runtime stubs.

global __go_register_gc_roots

__go_register_gc_roots:
    ret


global __go_runtime_error

__go_runtime_error:
    ret
