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

	mc68020
	movea.l	#ea_text1,a0

	; positive case
	move.l	#$3f800000,d0
	move.l	#$3f800000,d1

	jsr	_Float32EQ
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*0(a0)

	jsr	f32eq0
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*1(a0)

	jsr	f32eq1
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*2(a0)

	; positive case
	move.l	#$00000000,d0
	move.l	#$80000000,d1

	jsr	_Float32EQ
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*3(a0)

	jsr	f32eq0
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*4(a0)

	jsr	f32eq1
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*5(a0)

	; negative case
	move.l	#$7f800042,d0
	move.l	#$7f800042,d1

	jsr	_Float32EQ
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*6(a0)

	jsr	f32eq0
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*7(a0)

	jsr	f32eq1
	move.w	ccr,d2
	andi.w	#4,d2
	move.l	msg(d2),d2
	move.l	d2,tx1_w*8(a0)

	moveq	#0,d0 ; syscall_exit
	trap	#15

	mc68000
msg:
	dc.l	'fals', 'true'

; next function taken verbatim from Calypsi-68k src/lib/lowlevel/float32.s

;;; ***************************************************************************
;;;
;;; _Float32EQ - 32-bit float compare equal
;;;
;;; In: d0 - operand 1
;;;     d1 - operand 2
;;;
;;; Out: Z flag - result
;;;
;;; Destroys:
;;;
;;; ***************************************************************************

_Float32EQ:   movem.l d0-d2,-(sp)
              lsl.l   #1,d0         ; left align exponents
              lsl.l   #1,d1
              move.l  #$01000000,d2
              add.l   d2,d0         ; op1 all bits set in exponent?
              bcc.s   10$           ; no
              bne.s   100$          ; any bits set in mantissa means NaN
10$:          add.l   d2,d1         ; op2 all bits set in exponent?
              bcc.s   20$           ;  no
              bne.s   100$          ; any bits set in mantissa means NaN
20$:          sub.l   d2,d0         ; restore exponent op1
              bne.s   nonZero
              sub.l   d2,d1         ; restore exponent op2
100$:         movem.l (sp)+,d0-d2
              rts
nonZero:      movem.l (sp)+,d0-d2
              cmp.l   d0,d1
              rts

; next functions modelled after the above, aiming at better perf at statistically-significant classes of inputs

; better performance at input of two zeroes
f32eq0:
	movem.l	d0-d2,-(sp)
	lsl.l	#1,d0
	lsl.l	#1,d1
	move.l	d1,d2
	or.l	d0,d2
	beq	.nan_zero ; zero
	move.l	#$01000000,d2
	add.l	d2,d0
	bcc	.a_num
	bne	.nan_zero ; NaN
.a_num:
	add.l	d2,d1
	bcc	.b_num
	bne	.nan_zero ; NaN
.b_num:
	movem.l	(sp)+,d0-d2
	cmp.l	d0,d1
	rts
.nan_zero:
	movem.l	(sp)+,d0-d2
	rts

; better performance at input of two zeroes or two numbers
f32eq1:
	movem.l	d0-d2,-(sp)
	lsl.l	#1,d0
	lsl.l	#1,d1
	move.l	d1,d2
	or.l	d0,d2
	beq	.nan_zero ; zero
	move.l	#$01000000,d2
	add.l	d2,d0
	bcc	.num
	beq	.num
	add.l	d2,d1
	bcc	.num
	beq	.num
.nan_zero:
	movem.l	(sp)+,d0-d2
	rts
.num:
	movem.l	(sp)+,d0-d2
	cmp.l	d0,d1
	rts
