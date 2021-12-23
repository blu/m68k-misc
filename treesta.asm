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

	; draw symmetrically by static definition
	lea	arr,a0
	movea.l	#ea_text1,a1
row:
	move.b	(a0)+,d0
	beq	quit
	ext.w	d0
symmetrical_dots:
	neg.w	d0
	move.b	#'*',15(a1,d0.w)
	neg.w	d0
	move.b	#'*',13(a1,d0.w)
	subi.w	#1,d0
	bne	symmetrical_dots
	lea	tx1_w(a1),a1
	bra	row
quit:
	moveq	#0,d0 ; syscall_exit
	trap	#15
arr:
	dc.b	$1, $2, $3, $4, $2, $4, $6, $8
	dc.b	$3, $6, $9, $c, $2, $2, $0
