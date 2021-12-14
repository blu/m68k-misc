ea_user  equ $020000
ea_stack equ $080000
ea_vicky equ $c40000
ea_text0 equ $c60000
ea_texa0 equ $c68000
ea_text1 equ $ca0000
ea_texa1 equ $ca8000

tx0_w	equ 72
tx0_h	equ 56

tx1_w	equ 80
tx1_h	equ 60

paddlen	equ 9
padd_y	equ tx1_h-3

ball_w	equ 1
ball_h	equ 1

spins	equ $8000

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_user

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#ea_stack,a1
	move.l	a1,usp
	andi.w	#$dfff,sr

	moveq	#tx1_w/2,d4  ; curr_x
	moveq	#padd_y-1,d5 ; curr_y
	moveq	#-1,d6       ; step_x
	moveq   #-1,d7       ; step_y
frame:
	lea.l	pattern,a0
	jsr	clear_texa1

	move.w	d4,d0
	move.w	d5,d1
	jsr	ball

	move.w	d4,d0
	jsr	paddle

	; update positions
	add.w	d6,d4
	beq	neg_step_x
	cmpi.w	#tx1_w-ball_w,d4
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
	move.l	#spins,d0
	jsr	spin

	bra	frame

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

; clear text attr channel B
; a0: pattern ptr
; clobbers d0-d3
clear_texa1:
	movem.l (a0),d0-d3
	movea.l	#ea_texa1,a0
LLloop:
	movem.l	d0-d3,(a0)
	adda.l	#$4*4,a0 ; emits lea (an,16),an
	cmpa.l	#ea_texa1+tx1_w*tx1_h,a0
	blt	LLloop
	rts

; memset a buffer to a given value; does unaligned writes
; a0: target
; d0: content; value splatted to long word
; d1: length
; returns: a0: last_written_address + 1
; clobbers: d2
memset:
	move.l	d1,d2
	and.l	#-4,d2
	beq	Ltail0
Lloop4:
	move.l	d0,(a0)+
	subi.l	#4,d2
	bne	Lloop4
Ltail0:
	btst	#1,d1
	beq	Ltail1
	move.w	d0,(a0)+
Ltail1:
	btst	#0,d1
	beq	Ltail2
	move.b	d0,(a0)+
Ltail2:
	rts

; spinloop
; d0: number of cycles
spin:
	subi.l	#1,d0
	bne	spin
	rts

; draw ball
; d0.w: x-coord -- left of ball
; d1.w: y-coord -- top of ball
; clobbers: a0
ball:
	movea.w	d0,a0
	adda.l	#ea_texa1,a0
	mulu.w	#tx1_w,d1
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
	cmpi.w	#tx1_w-paddlen,d0
	ble	max_done
	moveq	#tx1_w-paddlen,d0
max_done:
	movea.w	d0,a0
	adda.l	#ea_texa1+tx1_w*padd_y,a0
	move.l	#$41414141,d0
	moveq.l	#paddlen,d1
	jsr	memset
	rts

	align 2
pattern:
	dcb.l	4, $42434243
