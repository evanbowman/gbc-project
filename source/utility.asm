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
.done:
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

SystemReboot:
        ld      a, $0
        ld      b, a
        ld      a, BOOTUP_A_CGB
        jp      $0100


;;; ----------------------------------------------------------------------------

ScheduleSleep:
;;; e - frames to sleep
        ldh     a, [hvar_sleep_counter]
        cp      e
        jr      C, .set
        ret
.set:
        add     a, e
        ldh     [hvar_sleep_counter], a
        ret



;;; ----------------------------------------------------------------------------

VBlankIntrWait:
;;; NOTE: We reset the vbl flag before the loop, in case our game logic ran
;;; slow, and we missed the vblank.
        ld      a, 0
        ldh     [hvar_vbl_flag], a

.loop:
        halt
        ;; The assembler inserts a nop here to fix a hardware bug.
        ldh     a, [hvar_vbl_flag]
        or      a
        jr      z, .loop
        xor     a
        ldh     [hvar_vbl_flag], a
        ret


;;; ----------------------------------------------------------------------------

;;; This function should only be used for loading stuff during scene
;;; transitions, when you don't want to turn off the lcd. High overhead.
;;; Note: do not assume anything about the scanline position after calling this
;;; function. VramSafeMemcpy may likely return during the blank window, but
;;; don't assume anything.
;;; Also note: this is a blocking call, and the cpu will be halted outside of
;;; the vblank window.
VramSafeMemcpy:
;;; hl - source
;;; de - dest
;;; bc - size

;;; TODO: technically, we can also speed this up by copying during the hblanks,
;;; right?

        ld      a, [rLY]
        cp      145
        jr      C, .needsInitialVSync
	jr      .start

.needsInitialVSync:
        call    VBlankIntrWait

.start:
	inc	b
	inc	c
	jr	.skip
.top:
        ld      a, [rLY]
        ; We could keep copying during line 153, but that's a bit dicey.
        cp      152
        jr      Z, .vsync
        jr      .copy

.vsync:
	call    VBlankIntrWait

.copy:
	ld	a, [hl+]
	ld	[de], a
	inc	de
.skip:
	dec	c
	jr	nz, .top
	dec	b
	jr	nz, .top

	ret


;;; ----------------------------------------------------------------------------

;;; Copied from implementation of memcpy. Works fine, as long as your dest is
;;; left (at a lower address) of the source.
MemmoveLeft:
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


IntegerToString:
;;; hl - integer
;;; de - dest string buffer
;;; return de - pointer to beginning of string in buffer
        call    .impl
        ld      a, 0
        ld      [de], a         ; Add null terminator
        ret

.impl:
;;; hl - integer
;;; de - dest string buffer
        ld      bc, -10000
        call    .one
        ld      bc, -1000
        call    .one
        ld      bc, -100
        call    .one
        ld      bc, -10
        call    .one
        ld      c, -1
.one
        ld      a, "0"-1
.two
        inc     a
        add     hl, bc
        jr      c, .two
        push    bc
        push    af
        ld      a, b
        cpl
        ld      b, a
        ld      a, c
        cpl
        ld      c, a
        inc     bc
        call    c, .carry
        pop     af
        add     hl, bc
        pop     bc
        ld      [de], a
        inc     de
        ret

.carry;
        dec     bc
        ret


;;; ----------------------------------------------------------------------------


SmallStrlen:
;;; hl - text
;;; return c - len
        ld      c, 0
.loop:
        ld      a, [hl]
        cp      0
        ret     Z

        inc     c
        inc     hl
        jr      .loop


;;; ----------------------------------------------------------------------------
