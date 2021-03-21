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
;;;  Bonfire
;;;
;;;
;;; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$



BonfireUpdate:
;;; bc - self
        push    bc

        ld      h, b
        ld      l, c

        ld      bc, 7
        add     hl, bc                  ; position of animation in entity

        ld      c, 6
        ld      d, 5
        call    AnimationAdvance
        or      a
        jr      Z, .done
        ld      a, 1
        pop     bc                       ; restore pointer to start of entity
        ld      [bc], a                  ; set texture swap flag

        jp      EntityUpdateLoopResume

.done:
        pop     bc
        jp      EntityUpdateLoopResume


;;; ----------------------------------------------------------------------------

BonfireNew:
;;; b - x
;;; c - y
        push    bc
        push    bc

        call    AllocateEntity
        ld      a, 0
        or      h
        or      l
        jr      Z, .failedAlloc

        push    hl
        push    hl
        pop     de
	call    EntityBufferEnqueue

        pop     hl
        pop     bc

        ld      a, 1
        ld      [hl], a

        call    EntitySetPos

        ld      a, SPRID_BONFIRE
        call    EntitySetFrameBase

        ;; Fixme: allocate texture slots dynamically
        push    hl
        call    AllocateTexture
        cp      0

.texturePoolLeak:
        jr      Z, .texturePoolLeak

        pop     hl
        call    EntitySetTexture

        ld      a, 1
        call    EntitySetPalette

        ld      a, 0
        call    EntitySetDisplayFlags

        ld      a, ENTITY_TYPE_BONFIRE
        call    EntitySetType

        ld      de, BonfireUpdate
        call    EntitySetUpdateFn

        pop     bc
        call    LcdOff
        srl     b
        srl     b
        srl     b
        dec     b
        dec     b
        ld      a, b
        srl     c
        srl     c
        srl     c
        dec     c
        dec     c
        ld      d, c
        ld      e, $80
        ld      c, 1
        call    SetBackgroundTile32x32
        call    LcdOn
        ret

.failedAlloc:
        pop     bc
        pop     bc
        ret


;;; ----------------------------------------------------------------------------
