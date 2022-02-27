; control symbols:
; target_cpu (numerical): select target cpu
;	0: 68000
;	1: 68010
;	2: 68020
; 	3: 68030
;	4: 68040
;	6: 68060
; do_wait (define): enforce spinloop at end of frame
; do_clear (define): enforce fb clear at start of frame
; do_morfe (define): enforce morfe compatibility
; alt_memset (numerical, optional): select memset routine for use by paddle routine

	ifnd alt_memset
alt_memset equ 1
	endif
	if alt_memset < 1 || alt_memset > 16 || (alt_memset & (alt_memset - 1))
	fail "alt_memset must be power-of-two between 1 and 16"
	endif

	if alt_plat == 0
	include	"plat_a2560u.inc"
	else
	include "plat_a2560k.inc"
	endif

tx0_w	equ 80
tx0_h	equ 60

tx1_w	equ 80
tx1_h	equ 60

paddlen	equ 9
padd_y	equ tx0_h-3

ball_w	equ 1
ball_h	equ 1

spins	equ $8000

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code

	ifd do_morfe
	org	$020000

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#$080000,a0
	move.l	a0,usp
	andi.w	#$dfff,sr

	else
	; FoenixMCP PGX header
	org	$010000

	dc.b	"PGX", $02
	dc.l	start
start:
	endif
	; hide border and cursor
	movea.l	#ea_vicky,a0
	move.l	hw_vicky_border(a0),d0
	move.l	hw_vicky_cursor(a0),d1
	and.b	#reset_border_enable,d0
	move.l	d0,hw_vicky_border(a0)
	and.b	#reset_cursor_enable,d1
	move.l	d1,hw_vicky_cursor(a0)

	ifd do_clear
	lea.l	pattern,a0
	jsr	clear_text0
	endif

	moveq	#tx0_w/2,d4  ; curr_x
	moveq	#padd_y-1,d5 ; curr_y
	moveq	#-1,d6       ; step_x
	moveq   #-1,d7       ; step_y
frame:
	lea.l	pattern+4*4,a0
	jsr	clear_texa0

	move.w	d4,d0
	move.w	d5,d1
	jsr	ball

	move.w	d4,d0
	jsr	paddle

	; update positions
	add.w	d6,d4
	beq	neg_step_x
	cmpi.w	#tx0_w-ball_w,d4
	bcs	done_x
neg_step_x:
	neg.w	d6
done_x:
	add.w	d7,d5
	beq	neg_step_y
	cmpi.w	#padd_y-ball_h,d5
	bcs	done_y
neg_step_y:
	neg.w	d7
done_y:
	ifd do_wait
	move.l	#spins,d0
	jsr	spin
	endif

	bra	frame

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

; draw ball
; d0.w: x-coord -- left of ball
; d1.w: y-coord -- top of ball
; clobbers: a0
ball:
	movea.w	d0,a0
	adda.l	#ea_texa0,a0
	mulu.w	#tx0_w,d1
	adda.l	d1,a0
	move.b	#$f,(a0)
	rts

; draw paddle
; d0.w: x-coord -- middle of paddle
; clobbers: d1-d2, a0
paddle:
	subi.w	#paddlen/2,d0
	bge	min_done
	moveq	#0,d0
	bra	max_done
min_done:
	cmpi.w	#tx0_w-paddlen,d0
	ble	max_done
	moveq	#tx0_w-paddlen,d0
max_done:
	movea.w	d0,a0
	adda.l	#ea_texa0+tx0_w*padd_y,a0
	move.l	#$41414141,d0
	moveq.l	#paddlen,d1
	jsr	memset1
	rts

	include "util.inc"
	include "memset.inc"

	align 2
pattern:
	dcb.l	4, '    '
	dcb.l	4, $42434243
