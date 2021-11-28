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

	; plot graph paper on channel B
	movem.l	patt,d0-d3
	movem.l patt+4*4,d4-d7
	movea.l	#ea_text1,a0
	movea.l	#ea_texa1,a1
screen:
	movem.l	d0-d3,(a0)
	movem.l	d4-d7,(a1)
	adda.l	#$4*4,a0 ; emits lea (an,16),an
	adda.l	#$4*4,a1
	cmpa.l	#ea_text1+tx1_w*tx1_h,a0
	blt	screen

	; test memset on channel B
	movea.l	#ea_texa1,a1
	movea.l	#ea_texa1+tx1_w*LINES,a2
	moveq	#1,d3
	moveq	#1,d4
line:
	movea.l	a1,a0
	move.l	#$41414141,d0
	move.l	d4,d1
	jsr	memset

	cmpi.w	#LINES/(COLUMNS-LINES),d3
	bne	param0
	clr.w	d3
	adda.w	#1,a1
param0:
	addi.w	#1,d3
	addi.w	#1,d4

	adda.w	#tx1_w,a1
	cmpa.l	a2,a1
	blt	line

	; police-lights on channel A border
	clr.l	d2 ; save-buf index; emits moveq
	lea.l	save_buf,a1 ; emits pc-rel
	move.l	#$808080,d0
	movea.l	#ea_vicky,a0
loop:
	move.l	d0,($8,a0) ; set border color
	addi.l	#1,d0
	move.l	($8,a0),d1 ; read back color
	; store to buffer just because
	move.l	d1,(a1,d2.w*4)
	addi.b	#1,d2
	andi.b	#3,d2
	bra	loop ; emits bras

	; some day
	clr.w	d0 ; syscall_exit
	trap	#15

	pad_code 3
patt:
	dc.l	'0123', '4567', '89ab', 'cdef'
	dc.l	$42434243, $42434243, $42434243, $42434243

save_buf:
	ds.l	4

; memset a buffer to a given value; does unaligned writes
; a0: target
; d0: content; value splatted to long word
; d1: length
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
	move.b	d0,(a0)
Ltail2:
	rts
