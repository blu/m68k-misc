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

COLUMNS	equ 64
LINES	equ 48

SPINS	equ $10000

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

	; plot graph paper on channel B -- glyphs
	lea.l	pattern,a0
	jsr	clear_text1
again:
	move.b	#18,d5
	movea.l	#ea_texa1,a3
forward:
	; plot graph paper on channel B -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa1

	jsr	frame
	adda.l	#1,a3

	move.l	#SPINS,d0
	jsr	spin

	subi.b	#1,d5
	bne	forward

	move.b	#18,d5
reverse:
	; plot graph paper on channel B -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa1

	suba.l	#1,a3
	jsr	frame

	move.l	#SPINS,d0
	jsr	spin

	subi.b	#1,d5
	bne	reverse

	bra	again

	; some day
	clr.w	d0 ; syscall_exit
	trap	#15

	pad_code 1
pattern:
	dc.l	'0123', '4567', '89ab', 'cdef'
	dc.l	$42434243, $42434243, $42434243, $42434243

; memset a buffer to a given value; only aligned writes
; a0: target
; d0: content; value splatted to long word
; d1: length
; returns: a0: last_written_address + 1
; clobbers: d2
memset:
	move.l	a0,d2

	btst	#0,d2
	beq	Lhead0
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.l	#1,d1
Lhead0:
	cmp	#2,d1
	bcs	Ltail1

	btst	#1,d2
	beq	Lhead1
	move.w	d0,(a0)+
	addi.l	#2,d2
	subi.l	#2,d1
Lhead1:
	cmp	#4,d1
	bcs	Ltail0

	move.l	d1,d2
	lsr.l	#2,d2
Lloop4:
	move.l	#$40404040,(a0)+ ; imm just for the unit test; correct src: d0
	subi.l	#1,d2
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

; plot one memset test frame on channel B
; a3: where to start the plot
; clobbers: d0-d4,a0-a2
frame:
	movea.l	a3,a1
	movea.l	#ea_texa1+tx1_w*LINES,a2
	moveq	#1,d3
	moveq	#1,d4
line:
	movea.l	a1,a0
	move.l	#$41414141,d0
	move.l	d4,d1
	jsr	memset

	cmpi.w	#LINES/(COLUMNS-LINES),d3
	bne	param
	clr.w	d3
	adda.w	#1,a1
param:
	addi.w	#1,d3
	addi.w	#1,d4

	adda.w	#tx1_w,a1
	cmpa.l	a2,a1
	blt	line
	rts

; clear text channel B
; a0: pattern ptr
; clobbers d0, d1, d2, d3, d4, d5, d6, d7
clear_text1:
	movem.l	(a0),d0-d3
	movea.l	#ea_text1,a0
Lloop:
	movem.l	d0-d3,(a0)
	adda.l	#$4*4,a0 ; emits lea (an,16),an
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

; spinloop
; d0: number of cycles
spin:
	subi.l	#1,d0
	bne	spin
	rts
