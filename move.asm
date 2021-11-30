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

SPINS	equ $4000

; don't use align lest intelHex loading breaks; use pad_code instead

; contrary to what vasm docs say, macro definition order is "<name> macro"
pad_code macro ; <num_words>
	dcb.w	\1,$4afc ; illegal instruction; traps
endm

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_user

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode

	movea.l	#ea_stack,a1
	move.l	a1,usp
	andi.w	#$dfff,sr

again:
	movea.l	#ea_texa1+tx1_h*tx1_w,a3
	movea.l	#ea_texa1+3,a2
move_dn:
	; vsync?
	lea.l	pattern+4*4,a0
	jsr	clear_texa1

	movea.l	a2,a0
	move.l	#$41414141,d0
	moveq.l	#17,d1
	jsr	memset

	move.l	#SPINS,d0
	jsr	spin

	adda.w	#tx1_w,a2
	cmpa.l	a3,a2
	blt	move_dn

	movea.l	#ea_texa1,a3
	suba.w	#tx1_w,a2
move_up:
	; vsync?
	lea.l	pattern+4*4,a0
	jsr	clear_texa1

	movea.l	a2,a0
	move.l	#$41414141,d0
	moveq.l	#17,d1
	jsr	memset

	move.l	#SPINS,d0
	jsr	spin

	suba.w	#tx1_w,a2
	cmpa.l	a3,a2
	bgt	move_up

	bra	again

	; some day
	clr.w	d0 ; syscall_exit
	trap	#15

; clear text channel B
; a0: pattern ptr
; clobbers d0, d1, d2, d3, d4, d5, d6, d7, a1
clear_texta1:
	movem.l	(a0),d0-d3
	movem.l 4*4(a0),d4-d7
	movea.l	#ea_text1,a0
	movea.l	#ea_texa1,a1
Lloop:
	movem.l	d0-d3,(a0)
	movem.l	d4-d7,(a1)
	adda.l	#$4*4,a0 ; emits lea (an,16),an
	adda.l	#$4*4,a1
	cmpa.l	#ea_text1+tx1_w*tx1_h,a0
	blt	Lloop
	rts

; clear attr channel B
; a0: pattern ptr
; clobbers d0, d1, d2, d3, d4, d5, d6, d7
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

	pad_code 1
pattern:
	dcb.l	4, '    '
	dcb.l	4, $42434243
