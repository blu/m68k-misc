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

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_user

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#ea_stack,a1
	move.l	a1,usp
	andi.w	#$dfff,sr

	movea.l	#ea_text1,a0
	move.l	#$180,d4
.iter:
	move.l	d4,d0
	jsr	print_u16
	addq	#1,a0

	jsr	u32root

	ifd do_count
	move.l	d7,d0
	endif

	jsr	print_u16
	addq	#1,a0

	subq	#1,d4
	bne	.iter

	moveq	#0,d0 ; syscall_exit
	trap	#15

	inline
; integer square root of u32; returns the largest n for which n * n <= arg
; d0.l: arg
; returns: d0.l: largest n for which n * n <= arg
; clobbers: d1-d3
	mc68020
u32root:
	tst.l	d0
	bne	.not_zero
	rts
.not_zero:
	ifd do_count
	moveq	#1,d7
	endif

	; compute an initial estimate: the largest POT
	; not greater than sqrt
	bfffo	d0{0:32},d3
	sub.l	#31,d3
	neg.l	d3
	lsr.l	d3
	moveq	#1,d1
	lsl.l	d3,d1

	; apply one iteration of Heron's method utilizing
	; the fact the 1st est is POT
	move.l	d0,d2
	lsr.l	d3,d2
	add.l	d1,d2
	lsr.l	d2

	move.l	d2,d3
	sub.l	d1,d3
	cmp.l	#2,d3
	bcc	.iter

	; the 1st iteration is always an ascend: the new
	; est could be the result, if not then old is
	move.l	d2,d3
	mulu.l	d3,d3
	cmp.l	d3,d0
	bcs	.first
	move.l	d2,d0
	rts
.first:
	move.l	d1,d0
	rts

.iter: ; descent until we get within minimal distance
	ifd do_count
	addq	#1,d7
	endif

	move.l	d2,d1

	move.l	d0,d2
	divu.l	d1,d2
	add.l	d1,d2
	lsr.l	d2

	move.l	d1,d3
	sub.l	d2,d3
	cmpi.l	#2,d3
	bcc	.iter

	move.l	d2,d3
	mulu.l	d3,d3
	cmp.l	d3,d0
	bcs	.iter

	move.l	d2,d0
	rts

	einline

	mc68000

	include "util.inc"
