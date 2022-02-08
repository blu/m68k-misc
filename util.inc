; control symbols:
; ea_text0 (address): channel A text
; ea_texa0 (address): channel A attr
; ea_text1 (address): channel B text
; ea_texa1 (address): channel B attr
; tx0_w (numerical): channel A width
; tx0_h (numerical): channel A height
; tx1_w (numerical): channel B width
; tx1_h (numerical): channel B height

	inline
; clear tx0-sized text channel A
; a0: pattern ptr
; clobbers d0-d3, a1
clear_text0:
	movem.l	(a0),d0-d3
	movea.l	#ea_text0,a0
	lea	tx0_w*tx0_h(a0),a1
.loop:
	movem.l	d0-d3,(a0)
	adda.w	#4*4,a0
	cmpa.l	a1,a0
	blt	.loop
	rts

	einline

	inline
; clear tx0-sized attr channel A
; a0: pattern ptr
; clobbers d0-d3, a1
clear_texa0:
	movem.l (a0),d0-d3
	movea.l	#ea_texa0,a0
	lea	tx0_w*tx0_h(a0),a1
.loop:
	movem.l	d0-d3,(a0)
	adda.w	#4*4,a0
	cmpa.l	a1,a0
	blt	.loop
	rts

	einline

	inline
; clear tx1-sized text channel B
; a0: pattern ptr
; clobbers d0-d3, a1
clear_text1:
	movem.l	(a0),d0-d3
	movea.l	#ea_text1,a0
	lea	tx1_w*tx1_h(a0),a1
.loop:
	movem.l	d0-d3,(a0)
	adda.w	#4*4,a0
	cmpa.l	a1,a0
	blt	.loop
	rts

	einline

	inline
; clear tx1-sized attr channel B
; a0: pattern ptr
; clobbers d0-d3, a1
clear_texa1:
	movem.l (a0),d0-d3
	movea.l	#ea_texa1,a0
	lea	tx1_w*tx1_h(a0),a1
.loop:
	movem.l	d0-d3,(a0)
	adda.w	#4*4,a0
	cmpa.l	a1,a0
	blt	.loop
	rts

	einline

	inline
; produce ascii from word
; d0.w: word to print
; a0: output address
; clobbers: d1, a1
print_u16:
	lea	4(a0),a1
.nibble:
	rol.w	#4,d0
	move.b	d0,d1
	andi.b	#$f,d1
	addi.b	#'0',d1
	cmpi.b	#'0'+10,d1
	bcs	.digit_ready
	addi.b	#'a'-'9'-1,d1
.digit_ready:
	move.b	d1,(a0)+
	cmpa.l	a1,a0
	bcs	.nibble
	rts

	einline

; spinloop
; d0: number of cycles
spin:
	subi.l	#1,d0
	bne	spin
	rts
