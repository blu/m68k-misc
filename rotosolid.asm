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

	include "plat_a2560k.inc"

tx0_w	equ 100
tx0_h	equ 75

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

	; set channel A to 800x600, text 100x75 fb (8x8 char matrix)
	movea.l	#ea_vicky,a0
	move.l	hw_vicky_master(a0),d0
	move.l	hw_vicky_border(a0),d1
	move.l	hw_vicky_cursor(a0),d2
	and.w	#$ffff&reset_master_mode,d0
	or.w	#set_master_mode_800x600,d0
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

	lea	tri_obj_0,a4
	lea	tri_scr_0,a5
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
	lea	tri_obj_0,a4
	lea	tri_scr_0,a5
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
	movea.l	#ea_texa0,a4
	move.b	#$40,color
.tri:
	addi.b	#1,color

	move.w	tri_p0+r3_x(a6),d0
	move.w	tri_p0+r3_y(a6),d1
	move.w	tri_p1+r3_x(a6),d2
	move.w	tri_p1+r3_y(a6),d3
	move.w	tri_p2+r3_x(a6),d4
	move.w	tri_p2+r3_y(a6),d5
	lea	pb,a0
	jsr	init_pb
	ble	.tri_done

	ifd do_fill
	move.w	tri_p0+r3_x(a6),d0
	move.w	tri_p0+r3_y(a6),d1
	move.w	tri_p1+r3_x(a6),d2
	move.w	tri_p1+r3_y(a6),d3
	move.w	tri_p2+r3_x(a6),d4
	move.w	tri_p2+r3_y(a6),d5
	lea	pb,a0
	lea	bbox,a1
	movea.l	a4,a2
	jsr	tri

	else
	move.w	tri_p0+r3_x(a6),d0
	move.w	tri_p0+r3_y(a6),d1
	move.w	tri_p1+r3_x(a6),d2
	move.w	tri_p1+r3_y(a6),d3
	movea.l	a4,a0
	jsr	line

	move.w	tri_p1+r3_x(a6),d0
	move.w	tri_p1+r3_y(a6),d1
	move.w	tri_p2+r3_x(a6),d2
	move.w	tri_p2+r3_y(a6),d3
	movea.l	a4,a0
	jsr	line

	move.w	tri_p2+r3_x(a6),d0
	move.w	tri_p2+r3_y(a6),d1
	move.w	tri_p0+r3_x(a6),d2
	move.w	tri_p0+r3_y(a6),d3
	movea.l	a4,a0
	jsr	line

	endif
.tri_done:
	adda.l	#tri_size,a6
	cmpa.l	a5,a6
	bne	.tri

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

	include "util.inc"

; struct r2
	clrso
r2_x	so.w 1
r2_y	so.w 1
r2_size = __SO

; struct r3
	clrso
r3_x	so.w 1
r3_y	so.w 1
r3_z	so.w 1
r3_size = __SO

; struct box
	clrso
box_min	so.w 2 ; r2
box_max	so.w 2 ; r2
box_size = __SO

; struct tri
	clrso
tri_p0	so.w 3 ; r3
tri_p1	so.w 3 ; r3
tri_p2	so.w 3 ; r3
tri_size = __SO

; parallelogram basis
; a triangle defines a basis such that:
;   p0 is the basis origin;
;   p1-p0 is the 1st basis vector;
;   p2-p0 is the 2nd basis vector;
; basis is RH if positive area
; struct pb
	clrso
pb_p0	so.w 2 ; r2
pb_e01	so.w 2 ; r2
pb_e02	so.w 2 ; r2
pb_area	so.l 1
pb_size = __SO

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

	inline
; draw a line in tx0-sized fb; last pixel omitted
; d0.w: x0
; d1.w: y0
; d2.w: x1
; d3.w: y1
; a0: fb start addr
; clobbers: d4-d7, a1
line:
	; compute x0,y0 addr in fb
	move.w	d1,d4
	muls.w	#tx0_w,d4
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
	movea.w	#tx0_w,a1
	move.w	d3,d5
	sub.w	d1,d5 ; dy
	bge	.dy_done
	neg.w	d5
	neg.w	d7
	movea.w	#-tx0_w,a1
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
	cmp.w	#tx0_w,d0
	bcc	.advance_x
	cmp.w	#tx0_h,d1
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
	bne	.loop_y
	rts
.loop_y:
	ifd do_clip
	cmp.w	#tx0_w,d0
	bcc	.advance_y
	cmp.w	#tx0_h,d1
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

; compute parallelogram basis from a tri:
;   e01 = p1 - p0
;   e02 = p2 - p0
;   area = e01.x * e02.y - e02.x * e01.y
; d0.w: p0.x
; d1.w: p0.y
; d2.w: p1.x
; d3.w: p1.y
; d4.w: p2.x
; d5.w: p2.y
; a0: basis ptr
; returns: a0: basis_ptr + 1
;          cc: Z: zero area
;              N: negative area
init_pb:
	sub.w	d0,d2 ; e01.x = p1.x - p0.x
	sub.w	d1,d3 ; e01.y = p1.y - p0.y

	sub.w	d0,d4 ; e02.x = p2.x - p0.x
	sub.w	d1,d5 ; e02.y = p2.y - p0.y

	move.w	d0,(a0)+ ; pb_p0.x
	move.w	d1,(a0)+ ; pb_p0.y

	move.w	d2,(a0)+ ; pb_e01.x
	move.w	d3,(a0)+ ; pb_e01.y

	move.w	d4,(a0)+ ; pb_e02.x
	move.w	d5,(a0)+ ; pb_e02.y

	; area = e01.x * e02.y - e02.x * e01.y
	muls.w	d5,d2
	muls.w	d4,d3
	sub.l	d3,d2

	move.l	d2,(a0)+ ; pb_area
	rts

; get barycentric coords of the given point in the given parallelogram basis;
; coords are before normalization!
; a0: basis ptr
; d0.w: pt.x
; d1.w: pt.y
; returns: d0.l: s coord before normalization
;          d1.l: t coord before normalization
; clobbers: d2-d3
get_coord:
	; dx = p.x - pb.p0.x
	; dy = p.y - pb.p0.y
	sub.w	pb_p0+r2_x(a0),d0
	sub.w	pb_p0+r2_y(a0),d1
	; s = dx * pb.e02.y - dy * pb.e02.x
	; t = dy * pb.e01.x - dx * pb.e01.y
	move.w	d0,d2
	move.w	d1,d3
	muls.w	pb_e01+r2_x(a0),d1 ; dy * e01.x
	muls.w	pb_e01+r2_y(a0),d2 ; dx * e01.y
	muls.w	pb_e02+r2_x(a0),d3 ; dy * e02.x
	muls.w	pb_e02+r2_y(a0),d0 ; dx * e02.y
	sub.l	d3,d0
	sub.l	d2,d1
	rts

	inline
; draw a triangle in tx0-sized fb:
; 1. obtain the tri bounding box
; 2. obtain scan-conversion box as an intersection of tri box with fb box
; 3. scan the rows of the scan box left to right, by tri right edge(s):
;
;         |-----o      |
;         |----oooo    |
;         |---ooooooo  |
;         |--oooooooooo|
;         |-oooooo     |
;         |oo          |
;
; d0.w: p0.x
; d1.w: p0.y
; d2.w: p1.x
; d3.w: p1.y
; d4.w: p2.x
; d5.w: p2.y
; a0: basis ptr
; a1: bbox scratch ptr
; a2: fb ptr
; clobbers: d6-d7, a3
tri:
	; get the bounds of the tri
	move.w	d0,d6 ; min.x
	move.w	d0,d7 ; max.x

	cmp.w	d2,d6
	ble	.min_x1_done
	move.w	d2,d6
	bra	.max_x1_done
.min_x1_done:
	cmp.w	d2,d7
	bge	.max_x1_done
	move.w	d2,d7
.max_x1_done:
	cmp.w	d4,d6
	ble	.min_x2_done
	move.w	d4,d6
	bra	.max_x2_done
.min_x2_done:
	cmp.w	d4,d7
	bge	.max_x2_done
	move.w	d4,d7
.max_x2_done:
	move.w	d6,box_min+r2_x(a1)
	move.w	d7,box_max+r2_x(a1)

	move.w	d1,d6 ; min.y
	move.w	d1,d7 ; max.y

	cmp.w	d3,d6
	ble	.min_y1_done
	move.w	d3,d6
	bra	.max_y1_done
.min_y1_done:
	cmp.w	d3,d7
	bge	.max_y1_done
	move.w	d3,d7
.max_y1_done:
	cmp.w	d5,d6
	ble	.min_y2_done
	move.w	d5,d6
	bra	.max_y2_done
.min_y2_done:
	cmp.w	d5,d7
	bge	.max_y2_done
	move.w	d5,d7
.max_y2_done:
	move.w	d6,box_min+r2_y(a1)
	move.w	d7,box_max+r2_y(a1)

	; intersect tri bounds with screen bounds
	move.w	box_min+r2_x(a1),d4
	bge	.scr_x0_done
	moveq	#0,d4
.scr_x0_done:
	move.w	box_min+r2_y(a1),d5
	bge	.scr_y0_done
	moveq	#0,d5
.scr_y0_done:
	move.w	box_max+r2_x(a1),d2
	cmp.w	#tx0_w-1,d2
	ble	.scr_x1_done
	move.w	#tx0_w-1,d2
.scr_x1_done:
	move.w	box_max+r2_y(a1),d3
	cmp.w	#tx0_h-1,d3
	ble	.scr_y1_done
	move.w	#tx0_h-1,d3
.scr_y1_done:
	cmp.w	d4,d2
	bge	.valid_x
	rts
.valid_x:
	cmp.w	d5,d3
	bge	.valid_y
	rts
.valid_y:
	movea.l	a2,a3

	move.w	#tx0_w,d0
	mulu.w	d5,d0
	adda.w	d0,a2
	adda.w	d4,a2 ; min ptr

	move.w	#tx0_w,d0
	mulu.w	d3,d0
	adda.w	d0,a3
	adda.w	d2,a3 ; max ptr

	; repurpose tri bounds as { x1, x0 }
	move.w	d2,0(a1)
	move.w	d4,2(a1)

.pixel: ; scan-convert the scr-space tri
	move.w	d4,d0
	move.w	d5,d1
	jsr	get_coord

	; if {s|t} < 0 || (s+t) > area then pixel is outside
	move.l	d0,d6
	or.l	d1,d6
	blt	.advance
	add.l	d1,d0
	cmp.l	pb_area(a0),d0
	ble	.plot
.advance:
	addq.l	#1,a2
	addq.w	#1,d4
	cmp.w	0(a1),d4
	ble	.pixel
	bra	.row_done
.streak:
	move.w	d4,d0
	move.w	d5,d1
	jsr	get_coord

	; if {s|t} < 0 || (s+t) > area then pixel is outside
	move.l	d0,d6
	or.l	d1,d6
	blt	.row_done
	add.l	d1,d0
	cmp.l	pb_area(a0),d0
	bgt	.row_done
.plot:
	move.b	color,(a2)+
	addq.w	#1,d4
	cmp.w	0(a1),d4
	ble	.streak
.row_done:
	adda.w	#tx0_w,a2
	suba.w	d4,a2
	move.w	2(a1),d4
	addq.w	#1,d5
	adda.w	d4,a2
	cmpa.l	a3,a2
	bls	.pixel
	rts

	einline

pattern: ; fb clear pattern
	dcb.l	4, '    '
	dcb.l	4, $70707070
pb:	; parallelogram basis
	ds.w	pb_size/2
bbox:	; primitive aabb
	ds.w	box_size/2
angle:	; current angle
	dc.w	0
roto:	; rotation matrix
	ds.w	mat_size/2
	ds.w	mat_size/2
frame_i: ; frame index
	dc.w	0
color:	; primitive color
	ds.b	1

	align 4
sinLUT14:
	include "sinLUT14_64.inc"
tri_obj_0:
	; z-axis faces
	dc.w	-25, -25,  25
	dc.w	 25, -25,  25
	dc.w	-25,  25,  25

	dc.w	-25,  25,  25
	dc.w	 25, -25,  25
	dc.w	 25,  25,  25

	dc.w	-25, -25, -25
	dc.w	-25,  25, -25
	dc.w	 25, -25, -25

	dc.w	-25,  25, -25
	dc.w	 25,  25, -25
	dc.w	 25, -25, -25

	; y-axis faces
	dc.w	-25,  25, -25
	dc.w	-25,  25,  25
	dc.w	 25,  25, -25
                          
	dc.w	 25,  25, -25
	dc.w	-25,  25,  25
	dc.w	 25,  25,  25
                     
	dc.w	-25, -25, -25
	dc.w	 25, -25, -25
	dc.w	-25, -25,  25
                          
	dc.w	 25, -25, -25
	dc.w	 25, -25,  25
	dc.w	-25, -25,  25

	; x-axis faces
	dc.w	 25, -25, -25
	dc.w	 25,  25, -25
	dc.w	 25, -25,  25
                     
	dc.w	 25, -25,  25
	dc.w	 25,  25, -25
	dc.w	 25,  25,  25

	dc.w	-25, -25, -25
	dc.w	-25, -25,  25
	dc.w	-25,  25, -25
                     
	dc.w	-25, -25,  25
	dc.w	-25,  25,  25
	dc.w	-25,  25, -25
tri_scr_0:
	ds.w	(tri_scr_0-tri_obj_0)/2
tri_end: