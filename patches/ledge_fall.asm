; ============================================================
; GnG Enhanced — Ledge Fall Patch
; ============================================================
; Makes Arthur enter the full airborne state when walking off
; a ledge, enabling air control and double jump during falls.
;
; Apply AFTER air_control.asm:
;   asar patches/ledge_fall.asm rom/gng_enhanced.sfc
;
; How it works:
;   The walk handler at $01CFC8 is Arthur's main on-ground
;   walking loop. Each frame it calls:
;
;     $CFD5: JSR $DD45     ; gravity + position update
;     $CFD8: JSR $D985     ; screen boundary check
;     $CFDB: BNE / BRK / BRA $CFD5   ; loop
;
;   The walk handler has NO ground collision detection — when
;   Arthur walks off a ledge, $DD45 applies gravity and he
;   falls, but the walk handler keeps running. Arthur drops
;   straight down with no air control or double jump.
;
;   We replace JSR $DD45 at $CFD5 with JSR WalkFallCheck.
;   After calling $DD45 (gravity applied), we check speed_y.
;   On solid ground $DD45's position update clamps Arthur to
;   the floor and speed_y stays zero. Off a ledge, gravity
;   increases speed_y with no floor to stop it.
;
;   When speed_y > 0 (falling detected): set up the airborne
;   state and JMP $CF53 to enter the airborne loop, which has
;   our air control hook and double jump check.
; ============================================================

asar 1.81
lorom

incsrc "../config.asm"

; ============================================================
; Object struct field offsets (direct page relative)
; ============================================================

!obj_flags        = $09        ; bit 0 = airborne
!obj_direction    = $11        ; 0=right, 1=left (movement sign)
!obj_facing       = $12        ; 0=right, 1=left (sprite flip)
!obj_speed_y_sub  = $19        ; speed_y fractional byte
!obj_speed_y_mid  = $1A        ; speed_y integer byte

; ============================================================
; Constants
; ============================================================

!airborne_bit     = $01        ; bit mask for airborne flag in obj_flags
!anim_jump        = $2B        ; animation ID for jump/fall sprite

; ============================================================
; ROM addresses
; ============================================================

!set_animation    = $018053    ; JSL target — sets animation from A
!cap_fall_speed   = $DD45      ; gravity + position update + speed cap
!airborne_loop    = $CF53      ; top of the airborne frame loop

if !ledge_fall_enabled

; ============================================================
; STEP 1: Patch the walk handler's gravity call
; ============================================================
; $01CFD5 is JSR $DD45 inside the walk handler loop. This runs
; every frame while Arthur walks on the ground. We replace it
; with a call to our hook, which calls $DD45 and then checks
; whether Arthur is still on the ground.

org $01CFD5
    jsr WalkFallCheck

; ============================================================
; STEP 2: Walk fall check subroutine
; ============================================================
; Placed at $01FD5A — free space after air_control code
; (which ends at $01FD58).
;
; Entry: Direct page = Arthur object base ($043C)
; Exit:  If on ground: RTS (walk handler continues normally)
;        If falling:   never returns — enters airborne loop

org $01FD5A

WalkFallCheck:
    jsr !cap_fall_speed

    ; speed_y = 0 on solid ground (floor collision resets it).
    ; Off a ledge, gravity increases speed_y with no floor to stop it.
    lda.b !obj_speed_y_mid
    ora.b !obj_speed_y_sub
    beq .on_ground

    ; Falling — set up airborne state and leave the walk handler.
    lda.b !obj_facing
    sta.b !obj_direction

    lda #!anim_jump
    jsl !set_animation

    lda #!airborne_bit
    ora.b !obj_flags
    sta.b !obj_flags

    pla                       ; pop return address from JSR at $CFD5
    pla
    jmp !airborne_loop

.on_ground:
    rts

; Safety: must not overflow into throw_cancel at $FD80
warnpc $01FD80

endif

; ============================================================
; END OF PATCH
; ============================================================
