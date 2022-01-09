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

	jsr	trig15
	jsr	trig14

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

	include "util.inc"

; struct r3
	clrso
r3_x	so.w 1
r3_y	so.w 1
r3_z	so.w 1
r3_size = __SO

; struct tri
	clrso
tri_p0	so.w 3 ; r3
tri_p1	so.w 3 ; r3
tri_p2	so.w 3 ; r3
tri_size = __SO

	inline
trig15:
	; compute scr coords for obj-space tris
	lea	tri_obj_0,a0
	lea	tri_scr_0,a1
	movea.l	a1,a2
	movea.l	#ea_texa1,a5

	move.w	angle,d5
	moveq	#15,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7  ; 68000 addx cannot do imm
.vert:
	move.w	r3_x(a0),d3 ; v_in.x
	move.w	r3_y(a0),d4 ; v_in.y
	adda.w	#r3_size,a0

	; transform vertex x-coord: cos * x - sin * y
	move.w	d3,d0
	move.w	d5,d1
	jsr	mul_cos15
	move.l	d0,d2

	move.w	d4,d0
	move.w	d5,d1
	jsr	mul_sin15

	sub.l	d0,d2
	; fx16.15 -> int16
	asr.l	d6,d2
	addx.w	d7,d2

	addi.w	#tx1_w/2,d2
	move.w	d2,r3_x(a1) ; v_out.x

	; transform vertex y-coord: sin * x + cos * y
	move.w	d3,d0
	move.w	d5,d1
	jsr	mul_sin15
	move.l	d0,d2

	move.w	d4,d0
	move.w	d5,d1
	jsr	mul_cos15

	add.l	d0,d2
	; fx16.15 -> int16
	asr.l	d6,d2
	addx.w	d7,d2

	addi.w	#tx1_h/2,d2
	move.w	d2,r3_y(a1) ; v_out.y

	adda.w	#r3_size,a1
	cmpa.l	a2,a0
	bcs	.vert

	; scan-convert the scr-space tri edges
	movea.l	a1,a3
	move.b	#$41,color
.tri:
	move.w	tri_p0+r3_x(a2),d0
	move.w	tri_p0+r3_y(a2),d1
	move.w	tri_p1+r3_x(a2),d2
	move.w	tri_p1+r3_y(a2),d3
	movea.l	a5,a0
	jsr	line

	move.w	tri_p1+r3_x(a2),d0
	move.w	tri_p1+r3_y(a2),d1
	move.w	tri_p2+r3_x(a2),d2
	move.w	tri_p2+r3_y(a2),d3
	movea.l	a5,a0
	jsr	line

	move.w	tri_p2+r3_x(a2),d0
	move.w	tri_p2+r3_y(a2),d1
	move.w	tri_p0+r3_x(a2),d2
	move.w	tri_p0+r3_y(a2),d3
	movea.l	a5,a0
	jsr	line

	adda.l	#tri_size,a2
	cmpa.l	a3,a2
	bne	.tri
	rts

	einline

	inline
trig14:
	; compute scr coords for obj-space tris
	lea	tri_obj_0,a0
	lea	tri_scr_0,a1
	lea	sinLUT14,a6
	movea.l	a1,a2
	movea.l	#ea_texa1,a5

	moveq	#14,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7  ; 68000 addx cannot do imm

	move.w	angle,d4
	move.w	d4,d0
	jsr	lut_cos14
	move.w	d0,d1
	move.w	d4,d0
	jsr	lut_sin14
.vert:
	move.w	r3_x(a0),d2 ; v_in.x
	move.w	r3_y(a0),d3 ; v_in.y
	adda.w	#r3_size,a0

	; transform vertex x-coord: cos * x - sin * y
	move.w	d2,d4
	muls.w	d1,d4
	move.w	d3,d5
	muls.w	d0,d5

	sub.l	d5,d4
	; fx16.14 -> int16
	asr.l	d6,d4
	addx.w	d7,d4

	addi.w	#tx1_w/2+2,d4
	move.w	d4,r3_x(a1) ; v_out.x

	; transform vertex y-coord: sin * x + cos * y
	move.w	d2,d4
	muls.w	d0,d4
	move.w	d3,d5
	muls.w	d1,d5

	add.l	d5,d4
	; fx16.14 -> int16
	asr.l	d6,d4
	addx.w	d7,d4

	addi.w	#tx1_h/2-1,d4
	move.w	d4,r3_y(a1) ; v_out.y

	adda.w	#r3_size,a1
	cmpa.l	a2,a0
	bcs	.vert

	; scan-convert the scr-space tri edges
	movea.l	a1,a3
	move.b	#$44,color
.tri:
	move.w	tri_p0+r3_x(a2),d0
	move.w	tri_p0+r3_y(a2),d1
	move.w	tri_p1+r3_x(a2),d2
	move.w	tri_p1+r3_y(a2),d3
	movea.l	a5,a0
	jsr	line

	move.w	tri_p1+r3_x(a2),d0
	move.w	tri_p1+r3_y(a2),d1
	move.w	tri_p2+r3_x(a2),d2
	move.w	tri_p2+r3_y(a2),d3
	movea.l	a5,a0
	jsr	line

	move.w	tri_p2+r3_x(a2),d0
	move.w	tri_p2+r3_y(a2),d1
	move.w	tri_p0+r3_x(a2),d2
	move.w	tri_p0+r3_y(a2),d3
	movea.l	a5,a0
	jsr	line

	adda.l	#tri_size,a2
	cmpa.l	a3,a2
	bne	.tri
	rts

	einline

	inline
; multiply a 3d vector by a 3d row-major matrix:
; | v0, v1, v2 | * | x0, x1, x2 |
;                  | y0, y1, y2 |
;                  | z0, z1, z2 |
; input vector elements are fx16, matrix elements are in the range [-1, 1]
; in format fx2.14; product elements are in format fx16.14 (bits [31-30]
; replicate the sign)
; d0.w: v0
; d1.w: v1
; d2.w: v2
; a0: matrix ptr
; returns:
; a1: rv0 as fx16.14 (bits [31-30] replicate the sign)
; a2: rv1 as fx16.14 (bits [31-30] replicate the sign)
; a3: rv2 as fx16.14 (bits [31-30] replicate the sign)
; clobbers: d3-d5
mul_vec3_mat:
	move.w	d0,d3
	move.w	d0,d4
	move.w	d0,d5
	muls.w	(a0)+,d3
	muls.w	(a0)+,d4
	muls.w	(a0)+,d5
	movea.l	d3,a1
	movea.l	d4,a2
	movea.l	d5,a3

	move.w	d1,d3
	move.w	d1,d4
	move.w	d1,d5
	muls.w	(a0)+,d3
	muls.w	(a0)+,d4
	muls.w	(a0)+,d5
	adda.l	d3,a1
	adda.l	d4,a2
	adda.l	d5,a3

	move.w	d2,d3
	move.w	d2,d4
	move.w	d2,d5
	muls.w	(a0)+,d3
	muls.w	(a0)+,d4
	muls.w	(a0)+,d5
	adda.l	d3,a1
	adda.l	d4,a2
	adda.l	d5,a3

	suba.w	#18,a0
	rts

	einline

	inline
; multiply a 3d vector by a 3d row-major matrix and translate:
; | v0, v1, v2 | * | x0, x1, x2 | + | t0, t1, t2 |
;                  | y0, y1, y2 |
;                  | z0, z1, z2 |
; input vector elements are fx16, matrix elements are in the range [-1, 1]
; in format fx2.14; product elements are in format fx16.14 (bits [31-30]
; replicate the sign)
; d0.w: v0
; d1.w: v1
; d2.w: v2
; a0: matrix ptr
; a1: t0 as fx16.14 (bits [31-30] replicate the sign)
; a2: t1 as fx16.14 (bits [31-30] replicate the sign)
; a3: t2 as fx16.14 (bits [31-30] replicate the sign)
; returns:
; a1: rv0 as fx16.14 (bits [31-30] replicate the sign)
; a2: rv1 as fx16.14 (bits [31-30] replicate the sign)
; a3: rv2 as fx16.14 (bits [31-30] replicate the sign)
; clobbers: d3-d5
mul_vec3_mat_tr:
	move.w	d0,d3
	move.w	d0,d4
	move.w	d0,d5
	muls.w	(a0)+,d3
	muls.w	(a0)+,d4
	muls.w	(a0)+,d5
	adda.l	d3,a1
	adda.l	d4,a2
	adda.l	d5,a3

	move.w	d1,d3
	move.w	d1,d4
	move.w	d1,d5
	muls.w	(a0)+,d3
	muls.w	(a0)+,d4
	muls.w	(a0)+,d5
	adda.l	d3,a1
	adda.l	d4,a2
	adda.l	d5,a3

	move.w	d2,d3
	move.w	d2,d4
	move.w	d2,d5
	muls.w	(a0)+,d3
	muls.w	(a0)+,d4
	muls.w	(a0)+,d5
	adda.l	d3,a1
	adda.l	d4,a2
	adda.l	d5,a3

	suba.w	#18,a0
	rts

	einline

	inline
; multiply by sine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns: d0.l: sine product as fx16.15 (d0[31] replicates sign)
	mc68020
mul_sin15:
	and.w	#$ff,d1
	cmpi.b	#$80,d1
	bcs	.sign_done
	neg.w	d0
	subi.b	#$80,d1
.sign_done:
	cmpi.b	#$40,d1
	bne	.not_maximum
	swap	d0
	move.w	#0,d0
	asr.l	#1,d0
	rts
.not_maximum:
	bcs	.symmetry_done
	subi.b	#$80,d1
	neg.b	d1
.symmetry_done:
	muls.w	sinLUT15(d1.w*2),d0
	rts

	einline

; multiply by cosine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns; d0.l: cosine product as fx16.15 (d0[31] replicates sign)
	mc68000
mul_cos15:
	addi.w	#$40,d1
	bra	mul_sin15

	inline
; multiply by sine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns: d0.l: sine product as fx16.14 (d0[31-30] replicate sign)
	mc68020
mul_sin14:
	and.w	#$ff,d1
	cmpi.b	#$80,d1
	bcs	.sign_done
	neg.w	d0
	subi.b	#$80,d1
.sign_done:
	cmpi.b	#$40,d1
	bne	.not_maximum
	swap	d0
	move.w	#0,d0
	asr.l	#2,d0
	rts
.not_maximum:
	bcs	.symmetry_done
	subi.b	#$80,d1
	neg.b	d1
.symmetry_done:
	muls.w	sinLUT14(d1.w*2),d0
	rts

	einline

; multiply by cosine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns; d0.l: cosine product as fx16.14 (d0[31-30] replicate sign)
	mc68000
mul_cos14:
	addi.w	#$40,d1
	bra	mul_sin14

	inline
; get sine
; d0.w: angle ticks -- [0, 2pi) -> [0, 256)
; d6.w: constant 14
; a6: sinLUT14 ptr
; returns: d0.w: sine as fx2.14
	mc68020
lut_sin14:
	and.w	#$ff,d0
	cmpi.b	#$80,d0
	bcs	.positive
	subi.b	#$80,d0 ; rotate back to positive

	cmpi.b	#$40,d0
	bcs	.fetch_negative
	bne	.nonextrem_negative
	moveq	#-1,d0
	asl.w	d6,d0
	rts
.nonextrem_negative:
	subi.b	#$80,d0
	neg.b	d0
.fetch_negative:
	move.w	(a6,d0.w*2),d0
	neg.w	d0
	rts

.positive:
	cmpi.b	#$40,d0
	bcs	.fetch_positive
	bne	.nonextrem_positive
	moveq	#1,d0
	asl.w	d6,d0
	rts
.nonextrem_positive:
	subi.b	#$80,d0
	neg.b	d0
.fetch_positive:
	move.w	(a6,d0.w*2),d0
	rts

	einline

; get cosine
; d0.w: angle ticks -- [0, 2pi) -> [0, 256)
; d6.w: constant 14
; a6: sinLUT14 ptr
; returns; d0.w: cosine as fx2.14
	mc68000
lut_cos14:
	addi.w	#$40,d0
	bra	lut_sin14

	inline
; draw a line in tx1-sized fb; line must be longer than a single dot
; d0.w: x0
; d1.w: y0
; d2.w: x1
; d3.w: y1
; a0: fb start addr
; clobbers: d4-d7, a1
line:
	; compute x0,y0 addr in fb
	move.w	d1,d4
	muls.w	#tx1_w,d4
	adda.l	d4,a0
	adda.w	d0,a0

	moveq	#1,d6
	move.w	d2,d4
	sub.w	d0,d4 ; dx
	bge	.dx_done
	neg.w	d4
	neg.w	d6
.dx_done:
	moveq	#1,d7
	movea.w	#tx1_w,a1
	move.w	d3,d5
	sub.w	d1,d5 ; dy
	bge	.dy_done
	neg.w	d5
	neg.w	d7
	movea.w	#-tx1_w,a1
.dy_done:
	cmp.w	d4,d5
	bge	.high_slope

	; low slope: iterate along x
	add.w	d5,d5 ; 2 dy
	move.w	d5,d3
	sub.w	d4,d3 ; 2 dy - dx
	add.w	d4,d4 ; 2 dx
.loop_x:
	ifd do_clip
	cmp.w	#tx1_w,d0
	bcc	.advance_x
	cmp.w	#tx1_h,d1
	bcc	.advance_x
	endif
	move.b	color,(a0)
.advance_x:
	adda.w	d6,a0
	add.w	d6,d0
	tst.w	d3
	ble	.x_done
	adda.w	a1,a0
	sub.w	d4,d3
	add.w	d7,d1
.x_done:
	add.w	d5,d3
	cmp.w	d0,d2
	bne	.loop_x
	rts
.high_slope: ; iterate along y
	add.w	d4,d4 ; 2 dx
	move.w	d4,d2
	sub.w	d5,d2 ; 2 dx - dy
	add.w	d5,d5 ; 2 dy
.loop_y:
	ifd do_clip
	cmp.w	#tx1_w,d0
	bcc	.advance_y
	cmp.w	#tx1_h,d1
	bcc	.advance_y
	endif
	move.b	color,(a0)
.advance_y:
	adda.w	a1,a0
	add.w	d7,d1
	tst.w	d2
	ble	.y_done
	adda.w	d6,a0
	sub.w	d5,d2
	add.w	d6,d0
.y_done:
	add.w	d4,d2
	cmp.w	d1,d3
	bne	.loop_y
	rts

	einline
angle:
	dc.w	0
frame_i:
	dc.w	0
color:
	ds.b	2
pattern:
	dc.l	'0123', '4567', '89ab', 'cdef'
	dcb.l	4, $42434243

	align 4
sinLUT15:
	include "sinLUT15_64.inc"
sinLUT14:
	include "sinLUT14_64.inc"
tri_obj_0:
	dc.w	  0, -29,  0
	dc.w	 25,  14,  0
	dc.w	-25,  14,  0
tri_scr_0:
	ds.w	(tri_scr_0-tri_obj_0)/2
tri_end:
