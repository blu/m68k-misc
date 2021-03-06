; control symbols:
; target_cpu (numerical): select target cpu
;	0: 68000
;	1: 68010
;	2: 68020
; 	3: 68030
;	4: 68040
;	6: 68060
; do_clip (define): enforce clipping in primitives
; do_wait (define): enforce spinloop at end of frame
; do_clear (define): enforce fb clear at start of frame
; do_morfe (define): enforce morfe compatibility

	if alt_plat == 0
	include	"plat_a2560u.inc"
	else
	include "plat_a2560k.inc"
	endif

tx0_w	equ 100
tx0_h	equ 75

tx1_w	equ 80
tx1_h	equ 60

fb_w	equ tx0_w
fb_h	equ tx0_h

color	equ $41

spins	equ $8000

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code

	ifd do_morfe
	org	$020000

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#$080000,a0
	move.l	a0,usp
	andi.w	#$dfff,sr

	else
	; FoenixMCP PGX header
	org	$10000

	dc.b	"PGX", $02
	dc.l	start
start:
	endif
	; disable all vicky engines but text
	; set channel A to 800x600, text 100x75
	movea.l	#ea_vicky,a0
	move.l	hw_vicky_master(a0),d0
	move.l	hw_vicky_border(a0),d1
	move.l	hw_vicky_cursor(a0),d2
	and.w	#$ffff&(reset_master_mode&%01000000),d0
	or.w	#$ffff&(set_master_mode_800x600|%00000001),d0
	move.l	d0,hw_vicky_master(a0)
	and.b	#reset_border_enable,d1
	move.l	d1,hw_vicky_border(a0)
	and.b	#reset_cursor_enable,d2
	move.l	d2,hw_vicky_cursor(a0)

	; pre-bake non-per-frame transforms to obj-space
	lea	sinLUT14,a6

	moveq	#14,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7  ; 68000 addx cannot do imm

	move.w	#-$20,d4
	move.w	d4,d0
	jsr	lut_cos14
	move.w	d0,d1
	move.w	d4,d0
	jsr	lut_sin14

	moveq	#1,d4
	asl.w	d6,d4

	; prepare rotation around y-axis
	lea	roto,a0
	neg.w	d0
	move.w	d1,(a0)+
	move.w	d7,(a0)+
	move.w	d0,(a0)+

	move.w	d7,(a0)+
	move.w	d4,(a0)+
	move.w	d7,(a0)+
	neg.w	d0
	move.w	d0,(a0)+
	move.w	d7,(a0)+
	move.w	d1,(a0)+

	lea	prim_obj_0,a4
	lea	prim_scr_0,a5
.bvert:
	move.w	r3_x(a4),d0 ; v_in.x
	move.w	r3_y(a4),d1 ; v_in.y
	move.w	r3_z(a4),d2 ; v_in.z

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

	move.w	d0,(a4)+ ; v_out.x
	move.w	d1,(a4)+ ; v_out.y
	move.w	d2,(a4)+ ; v_out.z

	cmpa.l	a5,a4
	bcs	.bvert

	; clear channel A -- symbols
	lea.l	pattern,a0
	jsr	clear_text0
.frame:
	ifd do_clear
	; clear channel A -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa0
	endif

	; compute scr coords from obj-space coords
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
	rept	3
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
	endr

	movea.l	a4,a0
	lea	prim_obj_0,a4
	lea	prim_scr_0,a5
	movea.l	a5,a6
.vert:
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

	addi.w	#tx0_w/2,d0
	addi.w	#tx0_h/2,d1

	move.w	d0,(a5)+ ; v_out.x
	move.w	d1,(a5)+ ; v_out.y
	move.w	d2,(a5)+ ; v_out.z

	cmpa.l	a6,a4
	bcs	.vert

	; scan-convert the scr-space tri edges
	movea.l	a5,a3
	movea.l	#ea_texa0,a5
.prim:
	move.w	prim_p0+r3_x(a6),d0
	move.w	prim_p0+r3_y(a6),d1
	move.w	prim_p1+r3_x(a6),d2
	move.w	prim_p1+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p1+r3_x(a6),d0
	move.w	prim_p1+r3_y(a6),d1
	move.w	prim_p2+r3_x(a6),d2
	move.w	prim_p2+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p2+r3_x(a6),d0
	move.w	prim_p2+r3_y(a6),d1
	move.w	prim_p3+r3_x(a6),d2
	move.w	prim_p3+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p3+r3_x(a6),d0
	move.w	prim_p3+r3_y(a6),d1
	move.w	prim_p4+r3_x(a6),d2
	move.w	prim_p4+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p4+r3_x(a6),d0
	move.w	prim_p4+r3_y(a6),d1
	move.w	prim_p5+r3_x(a6),d2
	move.w	prim_p5+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p5+r3_x(a6),d0
	move.w	prim_p5+r3_y(a6),d1
	move.w	prim_p6+r3_x(a6),d2
	move.w	prim_p6+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p6+r3_x(a6),d0
	move.w	prim_p6+r3_y(a6),d1
	move.w	prim_p7+r3_x(a6),d2
	move.w	prim_p7+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p7+r3_x(a6),d0
	move.w	prim_p7+r3_y(a6),d1
	move.w	prim_p8+r3_x(a6),d2
	move.w	prim_p8+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p8+r3_x(a6),d0
	move.w	prim_p8+r3_y(a6),d1
	move.w	prim_p9+r3_x(a6),d2
	move.w	prim_p9+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_p9+r3_x(a6),d0
	move.w	prim_p9+r3_y(a6),d1
	move.w	prim_pa+r3_x(a6),d2
	move.w	prim_pa+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_pa+r3_x(a6),d0
	move.w	prim_pa+r3_y(a6),d1
	move.w	prim_pb+r3_x(a6),d2
	move.w	prim_pb+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_pb+r3_x(a6),d0
	move.w	prim_pb+r3_y(a6),d1
	move.w	prim_pc+r3_x(a6),d2
	move.w	prim_pc+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_pc+r3_x(a6),d0
	move.w	prim_pc+r3_y(a6),d1
	move.w	prim_pd+r3_x(a6),d2
	move.w	prim_pd+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_pd+r3_x(a6),d0
	move.w	prim_pd+r3_y(a6),d1
	move.w	prim_pe+r3_x(a6),d2
	move.w	prim_pe+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_pe+r3_x(a6),d0
	move.w	prim_pe+r3_y(a6),d1
	move.w	prim_pf+r3_x(a6),d2
	move.w	prim_pf+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_pf+r3_x(a6),d0
	move.w	prim_pf+r3_y(a6),d1
	move.w	prim_pg+r3_x(a6),d2
	move.w	prim_pg+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_pg+r3_x(a6),d0
	move.w	prim_pg+r3_y(a6),d1
	move.w	prim_ph+r3_x(a6),d2
	move.w	prim_ph+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	move.w	prim_ph+r3_x(a6),d0
	move.w	prim_ph+r3_y(a6),d1
	move.w	prim_p0+r3_x(a6),d2
	move.w	prim_p0+r3_y(a6),d3
	movea.l	a5,a0
	jsr	line

	adda.l	#prim_size,a6
	cmpa.l	a3,a6
	bne	.prim

	addi.w	#1,angle
	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text0+tx0_w-4,a0
	jsr	print_u16

	ifd do_wait
	move.l	#spins,d0
	jsr	spin
	endif

	bra	.frame

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

; struct r3
	clrso
r3_x	so.w 1
r3_y	so.w 1
r3_z	so.w 1
r3_size = __SO

; struct tri
	clrso
prim_p0	so.w 3 ; r3
prim_p1	so.w 3 ; r3
prim_p2	so.w 3 ; r3
prim_p3	so.w 3 ; r3
prim_p4	so.w 3 ; r3
prim_p5	so.w 3 ; r3
prim_p6	so.w 3 ; r3
prim_p7	so.w 3 ; r3
prim_p8	so.w 3 ; r3
prim_p9	so.w 3 ; r3
prim_pa	so.w 3 ; r3
prim_pb	so.w 3 ; r3
prim_pc	so.w 3 ; r3
prim_pd	so.w 3 ; r3
prim_pe	so.w 3 ; r3
prim_pf	so.w 3 ; r3
prim_pg	so.w 3 ; r3
prim_ph	so.w 3 ; r3
prim_size = __SO

mat_size equ r3_size*3

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
	rts

	einline

	inline
; get sine
; d0.w: angle ticks -- [0, 2pi) -> [0, 256)
; d6.w: constant 14
; a6: sinLUT14 ptr
; returns: d0.w: sine as fx2.14
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

	if target_cpu >= 2
	move.w	(a6,d0.w*2),d0

	else
	add.w	d0,d0
	move.w	(a6,d0.w),d0

	endif
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

	if target_cpu >= 2
	move.w	(a6,d0.w*2),d0

	else
	add.w	d0,d0
	move.w	(a6,d0.w),d0

	endif
	rts

	einline

; get cosine
; d0.w: angle ticks -- [0, 2pi) -> [0, 256)
; d6.w: constant 14
; a6: sinLUT14 ptr
; returns; d0.w: cosine as fx2.14
lut_cos14:
	addi.w	#$40,d0
	bra	lut_sin14

	include "util.inc"
	include "line.inc"

pattern: ; fb clear pattern
	dcb.l	4, '    '
	dcb.l	4, $70707070
angle:	; current angle
	dc.w	0
roto:	; rotation matrix
	ds.w	9
	ds.w	9
frame_i: ; frame index
	dc.w	0

	align 4
sinLUT14:
	include "sinLUT14_64.inc"
prim_obj_0:
	dc.w -16, -25,  25
	dc.w  16, -25,  25
	dc.w  16,  16,  25
	dc.w -25,  16,  25
	dc.w -25, -16,  25
	dc.w -25, -16, -16
	dc.w -25,  25, -16
	dc.w -25,  25,  16
	dc.w  16,  25,  16
	dc.w  16,  25, -25
	dc.w -16,  25, -25
	dc.w -16, -16, -25
	dc.w  25, -16, -25
	dc.w  25,  16, -25
	dc.w  25,  16,  16
	dc.w  25, -25,  16
	dc.w  25, -25, -16
	dc.w -16, -25, -16
prim_scr_0:
	ds.w	(prim_scr_0-prim_obj_0)/2
