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


GREYWOLF_VAR_COLOR_COUNTER EQU 0
GREYWOLF_VAR_COUNTER       EQU 1
GREYWOLF_VAR_STAMINA       EQU 2


;;; ----------------------------------------------------------------------------


r9_GreywolfIdleSetFacing:
        call    EntityGetPos
        ld      a, [var_player_coord_x]
        cp      b
        jr      C, .faceLeft

        ld      a, SPRID_GREYWOLF_R

        call    EntityGetFrameBase
        cp      b
        jr      Z, .skip

        call    EntitySetFrameBase

        ld      a, ENTITY_TEXTURE_SWAP_FLAG
        ld      [hl], a

        ret

.faceLeft:
        call    EntityGetFrameBase
        cp      b
        jr      Z, .skip

        ld      a, SPRID_GREYWOLF_L
        call    EntitySetFrameBase

        ld      a, ENTITY_TEXTURE_SWAP_FLAG
        ld      [hl], a

.skip:
        ret


;;; ----------------------------------------------------------------------------


r9_GreywolfUpdateColor:
        ld      bc, GREYWOLF_VAR_COLOR_COUNTER
        call    EntityGetSlack
        ld      a, [bc]
        cp      a, 0
        jr      NZ, .decColorCounter

	ld      a, 3
        call    EntitySetPalette

        ret

.decColorCounter:
        dec     a
        ld      [bc], a
        ret


;;; ----------------------------------------------------------------------------


r9_GreywolfUpdateIdleImpl:
;;; bc - self
        ld      h, b                    ; \ Update functions are invoked through
        ld      l, c                    ; / hl, so it can't be a param :/

        ld      bc, GREYWOLF_VAR_COUNTER
        call    EntityGetSlack
        ld      a, [bc]
        inc     a
        ld      [bc], a
        cp      64
        jr      Z, .run

        call    r9_GreywolfIdleSetFacing

        call    r9_GreywolfUpdateColor
        call    r9_GreywolfMessageLoop

        ret

.run:
        ld      a, 0
        ld      [bc], a

        ld      de, GreywolfUpdateRun
        call    EntitySetUpdateFn

        ld      a, SPRID_GREYWOLF_RUN_L
        call    EntitySetFrameBase

        ld      a, [hl]
        or      ENTITY_TEXTURE_SWAP_FLAG
        ld      [hl], a

        ret


;;; ----------------------------------------------------------------------------


r9_GreywolfUpdateRunImpl:
;;; bc - self
        ld      h, b                    ; \ Update functions are invoked through
        ld      l, c                    ; / hl, so it can't be a param :/


        ld      e, 5
        ld      d, 5
        call    EntityAnimationAdvance


        ld      bc, GREYWOLF_VAR_COUNTER
        call    EntityGetSlack
        ld      a, [bc]
        inc     a
        ld      [bc], a
        cp      255
        jr      Z, .idle


        call    r9_GreywolfUpdateColor
        call    r9_GreywolfMessageLoop

        ret
.idle:
        ld      a, 0
        ld      [bc], a

        ld      de, GreywolfUpdate
        call    EntitySetUpdateFn

        call    EntityAnimationResetKeyframe

        ret



;;; ----------------------------------------------------------------------------


r9_GreywolfMessageLoop:
;;; trashes hl, should probably be called last
        push    hl                      ; Store entity pointer on stack

        call    EntityGetMessageQueue
        call    MessageQueueLoad

        pop     de                      ; Pass entity pointer in de
        ld      bc, r9_GreywolfOnMessage
	call    MessageQueueDrain

        ret


;;; ----------------------------------------------------------------------------


r9_GreywolfOnMessage:
;;; bc - message pointer
;;; de - self
        ld      a, [bc]
        cp      a, MESSAGE_PLAYER_KNIFE_ATTACK
        jr      Z, .onPlayerKnifeAttack

        ret

.onPlayerKnifeAttack:
        ld      h, d
        ld      l, e

        ld      a, 7
        call    EntitySetPalette

        ld      bc, GREYWOLF_VAR_STAMINA
        call    EntityGetSlack

        ld      bc, GREYWOLF_VAR_COLOR_COUNTER
        call    EntityGetSlack
        ld      a, 20
        ld      [bc], a

        ret


;;; ----------------------------------------------------------------------------