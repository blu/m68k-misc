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

	; create shape definition along vertical axis of symmetry
	lea	arr,a0
	move.w	#15,d0
init:
	move.w	#0,(a0)+
	subi.w	#1,d0
	bne	init
	; foliage
	lea	arr,a0
	jsr	add4
	jsr	add4
	jsr	add4
	lea	arr+8,a0
	jsr	add4
	jsr	add4
	lea	arr+16,a0
	jsr	add4
	; trunk
	move.l	#$20002,(a0)

	; draw symmetrically by newly-created definition
	lea	arr,a0
	movea.l	#ea_text1,a1
row:
	move.w	(a0)+,d0
	beq	quit
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

; a0: output
add4:
	addi.l	#$10002,(a0)+
	addi.l	#$30004,(a0)+
	rts

arr:
