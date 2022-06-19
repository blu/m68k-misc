ea_vicky .equ 0xc40000
ea_text0 .equ 0xc60000
ea_texa0 .equ 0xc68000
ea_text1 .equ 0xca0000
ea_texa1 .equ 0xca8000

tx0_w	.equ 72
tx0_h	.equ 56

tx1_w	.equ 80
tx1_h	.equ 60

fb_w	.equ tx1_w
fb_h	.equ tx1_h

spins	.equ 0x8000

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#0x080000,a1
	move.l	a1,usp
	andi.w	#0xdfff,sr

	; plot graph paper on channel B -- symbols
	lea.l	pattern,a0
	jsr	clear_text1
frame$:
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

	#ifdef do_wait
	move.l	#spins,d0
	jsr	spin
	#endif

	bra	frame$

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

; struct r3
r3_x	.equ	0 ; word x1
r3_y	.equ	2 ; word x1
r3_z	.equ	4 ; word x1
r3_size .equ	6

; struct tri
tri_p0	.equ	0  ; word x3 ; r3
tri_p1	.equ	6  ; word x3 ; r3
tri_p2	.equ	12 ; word x3 ; r3
tri_size .equ	18

mat_size .equ r3_size*3

trig15:
	; compute scr coords for obj-space tris
	lea	tri_obj_0,a0
	lea	tri_scr_0,a1
	movea.l	a1,a2
	movea.l	#ea_texa1,a5
	lea	sinLUT15,a6

	move.w	angle,d5
	moveq	#15,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7  ; 68000 addx cannot do imm
vert$:
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
	bcs	vert$

	; scan-convert the scr-space tri edges
	movea.l	a1,a3
	move.b	#0x41,color
tri$:
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
	bne	tri$
	rts

trig14:
	; compute scr coords for obj-space tris
	lea	sinLUT14,a6

	moveq	#14,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7  ; 68000 addx cannot do imm

	move.w	angle,d4
	move.w	d4,d0
	jsr	lut_cos14
	move.w	d0,d1
	move.w	d4,d0
	jsr	lut_sin14

	moveq	#1,d4
	asl.w	d6,d4

	; prepare rotation around x-axis
	lea	roto,a0
	move.w	d4,(a0)+
	move.w	d7,(a0)+
	move.w	d7,(a0)+

	move.w	d7,(a0)+
	move.w	d1,(a0)+
	move.w	d0,(a0)+
	neg.w	d0
	move.w	d7,(a0)+
	move.w	d0,(a0)+
	move.w	d1,(a0)+
	neg.w	d0

	; prepare rotation around z-axis
	move.w	d1,(a0)+
	move.w	d0,(a0)+
	move.w	d7,(a0)+
	neg.w	d0
	move.w	d0,(a0)+
	move.w	d1,(a0)+
	move.w	d7,(a0)+

	move.w	d7,(a0)+
	move.w	d7,(a0)+
	move.w	d4,(a0)+

	; multiply roto_x by roto_z
	lea	roto,a4

	move.w	r3_x(a4),d0
	move.w	r3_y(a4),d1
	move.w	r3_z(a4),d2
	lea	-mat_size(a0),a0
	jsr	mul_vec3_mat
	move.l	a1,d0
	move.l	a2,d1
	move.l	a3,d2
	; fx16.14 -> fx16
	asr.l	d6,d0
	addx.w	d7,d0
	asr.l	d6,d1
	addx.w	d7,d1
	asr.l	d6,d2
	addx.w	d7,d2
	move.w	d0,(a4)+
	move.w	d1,(a4)+
	move.w	d2,(a4)+

	move.w	r3_x(a4),d0
	move.w	r3_y(a4),d1
	move.w	r3_z(a4),d2
	lea	-mat_size(a0),a0
	jsr	mul_vec3_mat
	move.l	a1,d0
	move.l	a2,d1
	move.l	a3,d2
	; fx16.14 -> fx16
	asr.l	d6,d0
	addx.w	d7,d0
	asr.l	d6,d1
	addx.w	d7,d1
	asr.l	d6,d2
	addx.w	d7,d2
	move.w	d0,(a4)+
	move.w	d1,(a4)+
	move.w	d2,(a4)+

	move.w	r3_x(a4),d0
	move.w	r3_y(a4),d1
	move.w	r3_z(a4),d2
	lea	-mat_size(a0),a0
	jsr	mul_vec3_mat
	move.l	a1,d0
	move.l	a2,d1
	move.l	a3,d2
	; fx16.14 -> fx16
	asr.l	d6,d0
	addx.w	d7,d0
	asr.l	d6,d1
	addx.w	d7,d1
	asr.l	d6,d2
	addx.w	d7,d2
	move.w	d0,(a4)+
	move.w	d1,(a4)+
	move.w	d2,(a4)+

	movea.l	a4,a0
	lea	tri_obj_0,a4
	lea	tri_scr_0,a5
	movea.l	a5,a6
vert$:
	move.w	(a4)+,d0 ; v_in.x
	move.w	(a4)+,d1 ; v_in.y
	move.w	(a4)+,d2 ; v_in.z

	lea	-mat_size(a0),a0
	jsr	mul_vec3_mat
	move.l	a1,d0
	move.l	a2,d1
	move.l	a3,d2

	; fx16.14 -> int16
	asr.l	d6,d0
	addx.w	d7,d0
	asr.l	d6,d1
	addx.w	d7,d1
	asr.l	d6,d2
	addx.w	d7,d2

	addi.w	#tx1_w/2+2,d0
	addi.w	#tx1_h/2-1,d1

	move.w	d0,(a5)+ ; v_out.x
	move.w	d1,(a5)+ ; v_out.y
	move.w	d2,(a5)+ ; v_out.z

	cmpa.l	a6,a4
	bcs	vert$

	; scan-convert the scr-space tri edges
	movea.l	a5,a3
	movea.l	#ea_texa1,a5
	move.b	#0x44,color
tri$:
	move.w	tri_p0+r3_x(a6),d0
	move.w	tri_p0+r3_y(a6),d1
	move.w	tri_p1+r3_x(a6),d2
	move.w	tri_p1+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	tri_p1+r3_x(a6),d0
	move.w	tri_p1+r3_y(a6),d1
	move.w	tri_p2+r3_x(a6),d2
	move.w	tri_p2+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	tri_p2+r3_x(a6),d0
	move.w	tri_p2+r3_y(a6),d1
	move.w	tri_p0+r3_x(a6),d2
	move.w	tri_p0+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	adda.l	#tri_size,a6
	cmpa.l	a3,a6
	bne	tri$
	rts

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
	rts

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
	rts

; multiply by sine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; a6: sinLUT15 ptr
; returns: d0.l: sine product as fx16.15 (d0[31] replicates sign)
mul_sin15:
	and.w	#0xff,d1
	cmpi.b	#0x80,d1
	bcs	sign_done$
	neg.w	d0
	subi.b	#0x80,d1
sign_done$:
	cmpi.b	#0x40,d1
	bcs	fetch$
	bne	not_maximum$
	swap	d0
	move.w	#0,d0
	asr.l	#1,d0
	rts
not_maximum$:
	subi.b	#0x80,d1
	neg.b	d1
fetch$:
	add.w	d1,d1
	muls.w	0(a6,d1.w),d0
	rts

; multiply by cosine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; a6: sinLUT15 ptr
; returns; d0.l: cosine product as fx16.15 (d0[31] replicates sign)
mul_cos15:
	addi.w	#0x40,d1
	bra	mul_sin15

; multiply by sine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; a6: sinLUT14 ptr
; returns: d0.l: sine product as fx16.14 (d0[31-30] replicate sign)
mul_sin14:
	and.w	#0xff,d1
	cmpi.b	#0x80,d1
	bcs	sign_done$
	neg.w	d0
	subi.b	#0x80,d1
sign_done$:
	cmpi.b	#0x40,d1
	bcs	fetch$
	bne	not_maximum$
	swap	d0
	move.w	#0,d0
	asr.l	#2,d0
	rts
not_maximum$:
	subi.b	#0x80,d1
	neg.b	d1
fetch$:
	add.w	d1,d1
	muls.w	0(a6,d1.w),d0
	rts

; multiply by cosine
; d0.w: multiplicand
; d1.w: angle ticks -- [0, 2pi) -> [0, 256)
; a6: sinLUT14 ptr
; returns; d0.l: cosine product as fx16.14 (d0[31-30] replicate sign)
mul_cos14:
	addi.w	#0x40,d1
	bra	mul_sin14

; get sine
; d0.w: angle ticks -- [0, 2pi) -> [0, 256)
; d6.w: constant 14
; a6: sinLUT14 ptr
; returns: d0.w: sine as fx2.14
lut_sin14:
	and.w	#0xff,d0
	cmpi.b	#0x80,d0
	bcs	positive$
	subi.b	#0x80,d0 ; rotate back to positive

	cmpi.b	#0x40,d0
	bcs	fetch_negative$
	bne	nonextrem_negative$
	moveq	#-1,d0
	asl.w	d6,d0
	rts
nonextrem_negative$:
	subi.b	#0x80,d0
	neg.b	d0
fetch_negative$:
	add.w	d0,d0
	move.w	0(a6,d0.w),d0
	neg.w	d0
	rts

positive$:
	cmpi.b	#0x40,d0
	bcs	fetch_positive$
	bne	nonextrem_positive$
	moveq	#1,d0
	asl.w	d6,d0
	rts
nonextrem_positive$:
	subi.b	#0x80,d0
	neg.b	d0
fetch_positive$:
	add.w	d0,d0
	move.w	0(a6,d0.w),d0
	rts

; get cosine
; d0.w: angle ticks -- [0, 2pi) -> [0, 256)
; d6.w: constant 14
; a6: sinLUT14 ptr
; returns; d0.w: cosine as fx2.14
lut_cos14:
	addi.w	#0x40,d0
	bra	lut_sin14

	#include "util.inc"
	#include "line.inc"

pattern: ; fb clear pattern
	.long	0x30313233, 0x34353637, 0x38394142, 0x43444546
	.long	0x42434243, 0x42434243, 0x42434243, 0x42434243
angle:	; current angle
	.word	0
roto:	; rotation matrix
	.space	9*2 ; word x9
	.space	9*2 ; word x9
frame_i: ; frame index
	.word	0
color:	; primitive color
	.space	1

	.align 16
sinLUT15:
	#include "sinLUT15_64.inc"
sinLUT14:
	#include "sinLUT14_64.inc"
tri_obj_0:
	.word	  0, -29,  0
	.word	 25,  14,  0
	.word	-25,  14,  0
tri_scr_0:
	.space	tri_scr_0-tri_obj_0
