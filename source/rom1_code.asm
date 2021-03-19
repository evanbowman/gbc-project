;;; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
;;;
;;; ASM Source code for Red GBC, by Evan Bowman, 2021
;;;
;;;
;;; The following licence covers the source code included in this file. The
;;; game's characters and artwork belong to Evan Bowman, and should not be used
;;; without permission.
;;;
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;;
;;; 1. Redistributions of source code must retain the above copyright notice,
;;; this list of conditions and the following disclaimer.
;;;
;;; 2. Redistributions in binary form must reproduce the above copyright notice,
;;; this list of conditions and the following disclaimer in the documentation
;;; and/or other materials provided with the distribution.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.
;;;
;;; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$


;;; ############################################################################


SECTION "ROM1_CODE", ROMX, BANK[1]


;;; ----------------------------------------------------------------------------

VBlankPoll:
; Intended for waiting on vblank while interrupts are disabled, but the screen
; is still on.
        ld      a, [rLY]
        cp      SCRN_Y
        jr      nz, VBlankPoll
        ret


;;; ----------------------------------------------------------------------------

GameboyColorNotDetected:
        nop
        jr      GameboyColorNotDetected
        ret


;;; ----------------------------------------------------------------------------

GameboyAdvanceDetected:
        ld      a, 1
        ldh     [agb_detected], a
        jr      GameboyAdvanceDetected
	ret


;;; ----------------------------------------------------------------------------

InitWRam:
        ld      a, 0
        ld      hl, _RAM
        ;; We don't want to zero the stack, or how will we return from this fn?
        ld      bc, STACK_END - _RAM
        call    Memset

        ld      d, 1
.loop:
        ld      a, d
        cp      8
        jr      Z, .done

        ld      [rSVBK], a

        ld      hl, _RAMBANK
        ld      bc, ($DFFF - _RAMBANK) - 1
        ld      a, 0
        call    Memset

        inc     d
        jr      .loop

.done:
        ld      a, 0
        ld      [rSVBK], a


        ret


InitRam:
;;; trashes hl, bc, a
        ld      a, 0

        ld      hl, _HRAM
        ld      bc, $80
        call    Memset

        call    InitWRam

        ret


;;; ----------------------------------------------------------------------------

SetCpuFast:
        ld      a, [rKEY1]
        bit     7, a
        jr      z, .impl
        ret

.impl:
        ld      a, $30
        ld      [rP1], a
        ld      a, $01
        ld      [rKEY1], a

        stop
        ret


;;; ----------------------------------------------------------------------------

CopyDMARoutine:
        ld      hl, DMARoutine
        ld      b, DMARoutineEnd - DMARoutine ; Number of bytes to copy
        ld      c, LOW(hOAMDMA) ; Low byte of the destination address
.copy
        ld      a, [hli]
        ldh     [c], a
        inc     c
        dec     b
        jr      nz, .copy
        ret

DMARoutine:
        ldh     [rDMA], a

        ld      a, 40
.wait
        dec     a
        jr      nz, .wait
        ret
DMARoutineEnd:


;;; ----------------------------------------------------------------------------

MapExpandRow:
;;; c - row
        ld      e, c

;;; Because tiles are 16x16
        bit     0, e                    ; Determine which row we are in
        ld      a, 0
        jr      Z, .setParity
        ld      a, 1
.setParity:
        ld      [var_room_load_parity], a

        srl     e                       ; 32x32 index as input, downsample
        ld      d, 0

        ;; Map tiles are 16x16. Multiply y by 16 and add, to jump to row.
        swap    e

        ld      hl, var_map_info
        add     hl, de
        ld      d, h
        ld      e, l

        ld      hl, var_room_load_slab

        ld      b, 0
.copy:
        ld      a, [var_room_load_parity]
        or      a
        ld      a, [de]
        jr      Z, .evenParity


        sla     a                       ; \ Four tiles per metatile in vram,
        sla     a                       ; / so multiply by four
        add     $90                     ; $90 is the first map tile in vram

        ;; For odd parity, skip to the next two vram indices
        inc     a
        inc     a
        jr      .meta

.evenParity:
        sla     a                       ; \ Four tiles per metatile in vram,
        sla     a                       ; / so multiply by four
        add     $90                     ; $90 is the first map tile in vram

.meta:
        ld      [hl], a

        inc     hl

        inc     a
        ld      [hl], a

        inc     hl

        inc     de

        inc     b
        ld      a, b
        cp      16
        jr      NZ, .copy

        ret

;;; ----------------------------------------------------------------------------


MapShowRow:
;;; c - row
        push    bc                      ; \
        ld      hl, _SCRN0              ; |
        ld      e, 32                   ; |
        ld      d, 0                    ; |
.loop:                                  ; | seek offset in vram
        ld      a, 0                    ; |
        or      c                       ; |
	jr      Z, .ready               ; |
        dec     c                       ; |
        add     hl, de                  ; |
        jr      .loop                   ; /
.ready:
        pop     bc

        ;; Now, hl contains pointer to correct row in vram

        ld      de, var_room_load_slab

        ld      b, 0
.copy:
        ld      a, [de]
        ld      [hl], a
        inc     de

        ld	a, 1                    ; \
	ld	[rVBK], a               ; |
        ld      a, 2                    ; | Set Palette
        ld      [hl], a                 ; |
        ld      a, 0                    ; |
	ld	[rVBK], a               ; /

        inc     hl

        ld      a, [de]
        ld      [hl], a

        ld	a, 1                    ; \
	ld	[rVBK], a               ; |
        ld      a, 2                    ; | Set Palette
        ld      [hl], a                 ; |
        ld      a, 0                    ; |
	ld	[rVBK], a               ; /

        inc     hl

        inc     de

        inc     b
        ld      a, b
        cp      16
        jr      NZ, .copy

        ret


;;; ----------------------------------------------------------------------------

;;; Fills var_room_slab with expanded tile data. Then, the vblank handler just
;;; needs to copy stuff.
MapExpandColumn:
        ld      e, c
        bit     0, e
        ld      a, 0
        jr      Z, .setParity
        ld      a, 1
.setParity:
        ld      [var_room_load_parity], a


        ld      hl, var_map_info

        ld      e, c
	srl     e
        ld      d, 0

        add     hl, de
        ld      d, h
        ld      e, l

        ld      hl, var_room_load_slab

        ld      b, 0
.copy:
        ld      a, [var_room_load_parity]
        or      a
        ld      a, [de]
        jr      Z, .evenParity

        sla     a                       ; \ Four tiles per metatile in vram,
        sla     a                       ; / so multiply by four
        add     $90                     ; $90 is the first map tile in vram

        inc     a                       ; Inc 1, to second column of 16x16p tile
        jr      .meta

.evenParity:

        sla     a
        sla     a
        add     $90
.meta:

        ld      [hl], a

        inc     a                       ; \ Go to next column tile in 16x16px
        inc     a                       ; / meta tile.

        inc     hl

        ld      [hl], a

        inc     hl

        push    hl                      ; \
        ld      l, 16                   ; |
        ld      h, 0                    ; |
        add     hl, de                  ; | Jump to next row in tile map
        ld      d, h                    ; |
        ld      e, l                    ; |
        pop     hl                      ; /

        inc     b
        ld      a, b
        cp      16
        jr      NZ, .copy

        ret


;;; ----------------------------------------------------------------------------

MapShowColumn:
;;; c - column

        ld      hl, _SCRN0

        ld      d, 0                    ; \
        ld      e, c                    ; | Jump to proper column
        add     hl, de                  ; /

        ld      de, var_room_load_slab

        ld      b, 0
.copy:
        ld      a, [de]
        ld      [hl], a

        inc     de

        ld	a, 1                    ; \
	ld	[rVBK], a               ; |
        ld      a, 2                    ; | Set Palette
        ld      [hl], a                 ; |
        ld      a, 0                    ; |
	ld	[rVBK], a               ; /


        push    de                      ; \
        ld      e, 32                   ; |
	ld      d, 0                    ; | Jump down a full row in vram
        add     hl, de                  ; |
        pop     de                      ; /

        ld      a, [de]
        ld      [hl], a

        inc     de

        ld	a, 1                    ; \
	ld	[rVBK], a               ; |
        ld      a, 2                    ; | Set Palette
        ld      [hl], a                 ; |
        ld      a, 0                    ; |
	ld	[rVBK], a               ; /

        push    de                      ; \
        ld      e, 32                   ; |
	ld      d, 0                    ; | Jump down a full row in vram
        add     hl, de                  ; |
        pop     de                      ; /

        inc     b
        ld      a, b
        cp      16
        jr      NZ, .copy

        ret


;;; ----------------------------------------------------------------------------

ReadKeys:
; b - returns raw state
; c - returns debounced state (edge-triggered)
; d - trashed
        ldh     a, [var_joypad_raw]
        ld      d, a

        ld      a, $20                  ; read P15 - returns a, b, select, start
        ldh     [rP1], a
        ldh     a, [rP1]                ; mandatory
        ldh     a, [rP1]
        cpl                             ; rP1 returns not pressed keys as 1 and pressed as 0, invert it to make result more readable
        and     $0f                     ; lower nibble has a, b, select, start state
        swap    a
        ld      b, a

        ld      a, $10                  ; read P14 - returns up, down, left, right
        ldh     [rP1], a
        ldh     a, [rP1]                ; mandatory
        ldh     a, [rP1]
        ldh     a, [rP1]
        ldh     a, [rP1]
        ldh     a, [rP1]
        ldh     a, [rP1]
        cpl                             ; rP1 returns not pressed keys as 1 and pressed as 0, invert it to make result more readable
        and     $0f                     ; lower nibble has up, down, left, right state
        or      b                       ; combine P15 and P14 states in one byte
        ld      b, a                    ; store it

        ldh     a, [var_joypad_previous]; this is when important part begins, load previous P15 & P14 state
        xor     b                       ; result will be 0 if it's the same as current read
        and     b                       ; keep buttons that were pressed during this read only
        ldh     [var_joypad_current], a ; store final result in variable and register
        ld      c, a
        ld      a, b                    ; current P15 & P14 state will be previous in next read
        ldh     [var_joypad_previous], a

        ld      a, $30                  ; reset rP1
        ldh     [rP1], a

        ld      a, b
        ldh     [var_joypad_raw], a

        cpl                             ; cpl of current == not pressed keys
        and     d                       ; and with prev keys == released
        ldh     [var_joypad_released], a
        ret


;;; ---------------------------------------------------------------------------


;;; SECTION ROM1_CODE


;;; ############################################################################