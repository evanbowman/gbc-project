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
;;;  Overworld Scene
;;;
;;;
;;; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$


OverworldSceneFadeInVBlank:
        ld      a, [var_temp]
	ld      c, a
        sub     4
        jr      C, .transition
	jr      .continue

.transition:
        ld      de, OverworldSceneOnVBlank
        call    SceneSetVBlankFn

.continue:
        ld      [var_temp], a
        call    Fade

	call    VBlankCopySpriteTextures
        ret


;;; ----------------------------------------------------------------------------

OverworldSceneEnter:
        call    VBlankIntrWait

        ld      c, 255
        call    Fade

        call    VBlankIntrWait
        call    UpdateStaminaBar


        SET_BANK 7

        ld      hl, OverlayTiles
        ld      bc, OverlayTilesEnd - OverlayTiles
        ld      de, $9000
        call    VramSafeMemcpy

        ld      hl, BackgroundTiles
        ld      bc, BackgroundTilesEnd - BackgroundTiles
        ld      de, $8800
        call    VramSafeMemcpy

        ld      hl, SpriteDropShadow
        ld      bc, SpriteDropShadowEnd - SpriteDropShadow
        ld      de, $87c0
        call    VramSafeMemcpy

        call    VBlankIntrWait

        ld      a, 136
        ld      [rWY], a

        ld      a, 7
        ld      [rWX], a

        call    TestOverlay

;;; TODO: reload map tiles

        ld      de, OverworldSceneUpdate
        call    SceneSetUpdateFn

        ;; ld      de, OverworldSceneOnVBlank

        ld      a, 255
        ld      [var_temp], a

        ld      de, OverworldSceneFadeInVBlank
        call    SceneSetVBlankFn


        ret


;;; ----------------------------------------------------------------------------


OverworldSceneUpdateView:
        ld      a, [var_player_coord_x]
        ld      d, a
        ld      a, 175                  ; 255 - (screen_width / 2)
        cp      d
        jr      C, .xFixedRight
        ld      a, d
        ld      d, 80
	sub     d
        jr      C, .xFixedLeft
        ld      [var_view_x], a

        jr      .setY

.xFixedLeft:
        ld      a, 0
        ld      [var_view_x], a
        jr      .setY

.xFixedRight:
        ld      a, 95                   ; 255 - screen_width
        ld      [var_view_x], a

.setY:
        ld      a, [var_player_coord_y]
        add     a, 8                    ; Menu bar takes up one row, add offset
        ld      d, a
        ld      a, (183 + 19)           ; FIXME: why does this val work?
        cp      d
        jr      C, .yFixedBottom
        ld      a, d
        ld      d, 80
        sub     d
        jr      C, .yFixedTop
        ld      [var_view_y], a

        jr      .done

.yFixedTop:
        ld      a, 0
        ld      [var_view_y], a
        jr      .done

.yFixedBottom:
        ld      a, 121                  ; FIXME: how'd I decide on this number?
        ld      [var_view_y], a

.done:
        ret


;;; ----------------------------------------------------------------------------


OverworldSceneUpdate:
        ld      de, var_entity_buffer
        ld      a, [var_entity_buffer_size]

;;; intentional fallthrough
EntityUpdateLoop:
        cp      0               ; compare loop counter in a
        jr      Z, EntityUpdateLoopDone
        dec     a
        push    af

        ld      a, [de]         ; \
        ld      h, a            ; |
        inc     de              ; |  entity pointer from buffer into hl
        ld      a, [de]         ; |
        ld      l, a            ; |
        inc     de              ; /

	push    de              ; save entity buffer pointer on stack

        ld      e, 13           ; \
        ld      d, 0            ; | jump to position of update routine in entity
        add     hl, de          ; /

        ld      d, [hl]         ; \
        inc     hl              ; | load entity update function ptr
        ld      e, [hl]         ; /

        ld      h, d            ; \
        ld      l, e            ; | Jump to entity update address
        jp      hl              ; /

;;; Now, we could push the stack pointer, thus allowing entity update functions
;;; to be actual functions. For now, entity update functions need to jump back
;;; to this address.
EntityUpdateLoopResume:

        pop     de              ; restore entity buffer pointer
        pop     af              ; restore loop counter
        jr      EntityUpdateLoop

;;; intentional fallthrough
EntityUpdateLoopDone:


;;; If it wasn't for view scrolling, the update and draw stuff could be done in
;;; the same loop.
        call    OverworldSceneUpdateView

        call    DrawEntities

        call    OverworldSceneTryRoomTransition

;;; TODO: left, right, up transitions. The level map that I drew only has an
;;; exit on one side.

        ret


;;; ----------------------------------------------------------------------------


VBlankCopySpriteTextures:
;;; Now, this entity buffer code looks pretty nasty. But, we are just doing a
;;; bunch of work upfront, because we do not always need to actually run the
;;; dma. Iterate through each entity, check its swap flag. If the entity
;;; requires a texture swap, map the texture into vram with GDMA.
        SET_BANK SPRITESHEET1_ROM_BANK

        ld      de, var_entity_buffer
        ld      a, [var_entity_buffer_size]

.textureCopyLoop:
        cp      0
        jr      Z, .textureCopyLoopDone
        dec     a
        push    af              ; store loop counter

;;; Even with DMA, we can only fit so many texture copies into the vblank
;;; window. If we think that we're going to exceed the vblank, defer the
;;; copies to the next iteration. The code is just checking entities for
;;; a flag which indicates that a texture copy is needed, so we can just as
;;; easily process the texture copy after the next frame.
        ld      a, [rLY]
        ld      b, a
        ld      a, 153 - 4
        cp      b
        jr      C, .textureCopyLoopTimeout


        ld      a, [de]         ; \
        ld      h, a            ; |
        inc     de              ; |  Fetch entity pointer from entity buffer
        ld      a, [de]         ; /
        ld      l, a            ; Now we have the entity pointer in hl
        inc     de

        ld      a, [hl]         ; load texture swap flag from entity
        or      a
        jr      Z, .noTextureCopy ; swap flag false, nothing to do
        ld      a, 0
        ld      [hl], a         ; We're swapping the texture, zero the flag

        push    de              ; store entity buffer pointer on stack

        ld      d, 0
        ld      e, 1 + FIXNUM_SIZE * 2 + 1
	add     hl, de          ; jump to offset of keyframe in entity

        ld      a, [hl+]
        ld      d, [hl]         ; load frame base
        inc     hl
        ld      b, [hl]
.test:
        add     d               ; keyframe + framebase is spritesheet index
        ld      h, a            ; pass spritesheet index in h
        call    MapSpriteBlock  ; DMA copy the sprite into vram

        pop     de              ; restore entity buffer pointer
.noTextureCopy:

        pop     af              ; restore loop counter
        jr      .textureCopyLoop


.textureCopyLoopTimeout:
        pop     af              ; Was pushed at the top of the loop

;;; intentional fallthrough

.textureCopyLoopDone:
;;; The whole point of the above loop was to copy sprites from various rom banks
;;; into vram. So we should set the rom bank back to one, which is the standard
;;; rom bank for most purposes.
.done:
        SET_BANK 1

        ret


;;; ----------------------------------------------------------------------------

OverworldSceneOnVBlank:
        call    UpdateStaminaBar

	call    VBlankCopySpriteTextures
        ret


;;; ----------------------------------------------------------------------------


OverworldSceneStartTransition:
;;; de - transition fn
	call    SceneSetUpdateFn

        call    EntityBufferReset

        ld      de, var_player_struct
        call    EntityBufferEnqueue

        ld      a, [var_joypad_raw]
        ld      [var_room_load_joypad_cache], a
        ret


OverworldSceneTryRoomTransition:
        ld      a, [var_player_coord_y]
        cp      246
        jr      C, .tryUpTransition

        ld      de, RoomTransitionSceneDownUpdate
        call    OverworldSceneStartTransition

        ld      de, RoomTransitionSceneDownVBlank
        call    SceneSetVBlankFn

        call    MapLoad2

        ld      a, 0
        ld      [var_room_load_counter], a
        ld      c, a
        LONG_CALL MapExpandRow, 1

        jr      .done

.tryUpTransition:

        ld      a, [var_player_coord_y]
        ld      b, a
        ld      a, 8
        cp      b
        jr      C, .tryRightTransition

        ld      de, RoomTransitionSceneUpUpdate
        call    OverworldSceneStartTransition

        ld      de, RoomTransitionSceneUpVBlank
        call    SceneSetVBlankFn

        call    MapLoad0

        ld      a, 31
        ld      [var_room_load_counter], a
        ld      c, a
        LONG_CALL MapExpandRow, 1

        jr      .done

.tryRightTransition:
        ld      a, [var_player_coord_x]
        cp      246
        jr      C, .tryLeftTransition

        ld      de, RoomTransitionSceneRightUpdate
        call    OverworldSceneStartTransition

        ld      de, RoomTransitionSceneRightVBlank
        call    SceneSetVBlankFn

        call    MapLoad3

        ld      a, 0
        ld      [var_room_load_counter], a
        ld      c, a
        LONG_CALL MapExpandColumn, 1

        jr      .done

.tryLeftTransition:
        ld      a, [var_player_coord_x]
        ld      b, a
        ld      a, 8
        cp      b
        jr      C, .done

        ld      de, RoomTransitionSceneLeftUpdate
        call    OverworldSceneStartTransition

        ld      de, RoomTransitionSceneLeftVBlank
        call    SceneSetVBlankFn

        call    MapLoad2

        ld      a, 31
        ld      [var_room_load_counter], a
        ld      c, a
        LONG_CALL MapExpandColumn, 1

.done:
        ret