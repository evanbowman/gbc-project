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



;;; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
;;;
;;;
;;; Utility Routines
;;;
;;;
;;; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$


Memset:
; hl - destination
; a - byte to fill with
; bc - size

	inc	b
	inc	c
	jr	.skip
.fill:
	ld	[hl+], a
.skip:
	dec	c
	jr	nz, .fill
	dec	b
	jr	nz, .fill
	ret


;;; ----------------------------------------------------------------------------

Memcpy:
;;; hl - source
;;; de - dest
;;; bc - size

	inc	b
	inc	c
	jr	.skip
.copy:
	ld	a, [hl+]
	ld	[de], a
	inc	de
.skip:
	dec	c
	jr	nz, .copy
	dec	b
	jr	nz, .copy
	ret


;;; ----------------------------------------------------------------------------

VBlankPoll:
; Intended for waiting on vblank while interrupts are disabled, but the screen
; is still on.
        ld      a, [rLY]
        cp      SCRN_Y
        jr      nz, VBlankPoll
        ret


;;; ----------------------------------------------------------------------------

Reset:
        ld      a, $0
        ld      b, a
        ld      a, BOOTUP_A_CGB
        jp      $0100


;;; ----------------------------------------------------------------------------

InitRam:
;;; trashes hl, bc, a
        ld      a, 0

        ld      hl, _HRAM
        ld      bc, $80
        call    Memset

        ld      hl, _RAM
        ld      bc, $CFFF - _RAM        ; size == pRamEnd - pRam
        call    Memset

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

ScheduleSleep:
; e - frames to sleep
        ldh     a, [var_sleep_counter]
        add     a, e
        ldh     [var_sleep_counter], a
        ret


;;; ----------------------------------------------------------------------------

VBlankIntrWait:
;;; NOTE: We reset the vbl flag before the loop, in case our game logic ran
;;; slow, and we missed the vblank.
        ld      a, 0
        ldh     [var_vbl_flag], a

.loop:
        halt
        ;; The assembler inserts a nop here to fix a hardware bug.
        ldh     a, [var_vbl_flag]
        or      a
        jr      z, .loop
        xor     a
        ldh     [var_vbl_flag], a
        ret


;;; ----------------------------------------------------------------------------