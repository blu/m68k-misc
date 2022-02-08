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

fb_w	equ tx1_w
fb_h	equ tx1_h

color	equ $41

fract	equ 15

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

	; plot graph paper on channel B -- symbols
	lea.l	pattern,a0
	jsr	clear_text1
.frame:
	; plot graph paper on channel B -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa1

	; compute scr coords for obj-space tris
	lea	tri_obj_0,a0
	lea	tri_scr_0,a1
	movea.l	a1,a2
	move.w	angle,d5
	moveq	#fract,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7     ; 68000 addx cannot do imm
.vert:
	move.w	(a0)+,d3 ; v_in.x
	move.w	(a0)+,d4 ; v_in.y

	; transform vertex x-coord: cos * x - sin * y
	move.w	d3,d0
	move.w	d5,d1
	jsr	mul_cos
	move.l	d0,d2

	move.w	d4,d0
	move.w	d5,d1
	jsr	mul_sin

	sub.l	d0,d2
	; fx16.15 -> int16
	asr.l	d6,d2
	addx.w	d7,d2

	addi.w	#tx1_w/2,d2
	move.w	d2,(a1)+ ; v_out.x

	; transform vertex y-coord: sin * x + cos * y
	move.w	d3,d0
	move.w	d5,d1
	jsr	mul_sin
	move.l	d0,d2

	move.w	d4,d0
	move.w	d5,d1
	jsr	mul_cos

	add.l	d0,d2
	; fx16.15 -> int16
	asr.l	d6,d2
	addx.w	d7,d2

	addi.w	#tx1_h/2,d2
	move.w	d2,(a1)+ ; v_out.y

	cmpa.l	a2,a0
	bcs	.vert

	; scan-convert the scr-space tri edges
	lea	tri_scr_0,a2
	lea	tri_end,a3
	movea.l	#ea_texa1,a6
.tri:
	move.w	tri_p0+r2_x(a2),d0
	move.w	tri_p0+r2_y(a2),d1
	move.w	tri_p1+r2_x(a2),d2
	move.w	tri_p1+r2_y(a2),d3
	movea.l	a6,a0
	jsr	line

	move.w	tri_p1+r2_x(a2),d0
	move.w	tri_p1+r2_y(a2),d1
	move.w	tri_p2+r2_x(a2),d2
	move.w	tri_p2+r2_y(a2),d3
	movea.l	a6,a0
	jsr	line

	move.w	tri_p2+r2_x(a2),d0
	move.w	tri_p2+r2_y(a2),d1
	move.w	tri_p0+r2_x(a2),d2
	move.w	tri_p0+r2_y(a2),d3
	movea.l	a6,a0
	jsr	line

	adda.l	#tri_size,a2
	cmpa.l	a3,a2
	bne	.tri

	addi.w	#1,angle
	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text1+tx1_w-4,a0
	jsr	print_u16

	ifd do_wait
	move.l	#spins,d0
	jsr	spin
	endif

	bra	.frame

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

; struct r2
	clrso
r2_x	so.w 1
r2_y	so.w 1
r2_size = __SO

; struct tri
	clrso
tri_p0	so.w 2 ; r2
tri_p1	so.w 2 ; r2
tri_p2	so.w 2 ; r2
tri_size = __SO

	inline
; multiply by sine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns: d0.l: sine product as fx16.15 (d0[31] replicates sign)
	mc68020
mul_sin:
	and.w	#$ff,d1
	cmpi.b	#$80,d1
	bcs	.sign_done
	neg.w	d0
	subi.b	#$80,d1
.sign_done:
	cmpi.b	#$40,d1
	bcs	.fetch
	bne	.not_maximum
	swap	d0
	move.w	#0,d0
	asr.l	#1,d0
	rts
.not_maximum:
	subi.b	#$80,d1
	neg.b	d1
.fetch:
	muls.w	sinLUT(d1.w*2),d0
	rts

	einline

; multiply by cosine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns; d0.l: cosine product as fx16.15 (d0[31] replicates sign)
	mc68000
mul_cos:
	addi.w	#$40,d1
	bra	mul_sin

	include "util.inc"
	include	"line.inc"

pattern:
	dc.l	'0123', '4567', '89ab', 'cdef'
	dcb.l	4, $42434243
angle:
	dc.w	0
frame_i:
	dc.w	0

	align 4
sinLUT:
	dc.w $0000, $0324, $0648, $096B, $0C8C, $0FAB, $12C8, $15E2
	dc.w $18F9, $1C0C, $1F1A, $2224, $2528, $2827, $2B1F, $2E11
	dc.w $30FC, $33DF, $36BA, $398D, $3C57, $3F17, $41CE, $447B
	dc.w $471D, $49B4, $4C40, $4EC0, $5134, $539B, $55F6, $5843
	dc.w $5A82, $5CB4, $5ED7, $60EC, $62F2, $64E9, $66D0, $68A7
	dc.w $6A6E, $6C24, $6DCA, $6F5F, $70E3, $7255, $73B6, $7505
	dc.w $7642, $776C, $7885, $798A, $7A7D, $7B5D, $7C2A, $7CE4
	dc.w $7D8A, $7E1E, $7E9D, $7F0A, $7F62, $7FA7, $7FD9, $7FF6
tri_obj_0:
	dc.w	  0, -29
	dc.w	 25,  14
	dc.w	-25,  14
tri_scr_0:
	ds.w	(tri_scr_0-tri_obj_0)/2
tri_end:
