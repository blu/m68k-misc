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
; do_persp (define): enforce perspective projection
; do_morfe (define): enforce morfe compatibility

	#if alt_plat == 0
	#include "plat_a2560u.inc"
	#else
	#include "plat_a2560k.inc"
	#endif

tx0_w	.equ 100
tx0_h	.equ 75

tx1_w	.equ 80
tx1_h	.equ 60

fb_w	.equ tx0_w
fb_h	.equ tx0_h

spins	.equ 0x8000

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code

	#ifdef do_morfe
	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#0x080000,a0
	move.l	a0,usp
	andi.w	#0xdfff,sr

	#else
	; FoenixMCP PGX header
	.byte	"PGX", 0x02
	.long	start$
start$:
	#endif
	; disable all vicky engines but text
	; set channel A to 800x600, text 100x75
	movea.l	#ea_vicky,a0
	move.l	hw_vicky_master(a0),d0
	move.l	hw_vicky_border(a0),d1
	move.l	hw_vicky_cursor(a0),d2
	and.w	#reset_master_mode,d0
	or.w	#set_master_text|set_master_mode_800x600,d0
	move.l	d0,hw_vicky_master(a0)
	and.b	#reset_border_enable,d1
	move.l	d1,hw_vicky_border(a0)
	and.b	#reset_cursor_enable,d2
	move.l	d2,hw_vicky_cursor(a0)

	; pre-bake non-per-frame transforms to obj-space
	lea	sinLUT14,a6

	moveq	#14,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7  ; 68000 addx cannot do imm

	move.w	#-0x20,d4
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
bvert$:
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
	bcs	bvert$

	; clear channel A -- symbols
	lea.l	pattern,a0
	jsr	clear_text0
frame$:
	#ifdef do_clear
	; clear channel A -- colors
	lea.l	pattern+4*4,a0
	jsr	clear_texa0
	#endif

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

	#ifdef do_persp
	#if target_cpu >= 2
	; apply perspective for cam looking along -Z
	subi.l	#128<<14,d2
	neg.l	d2

	asl.l	#7,d0
	asl.l	#7,d1
	divs.l	d2,d0
	divs.l	d2,d1

	#else
	; fx16.14 -> int16
	asr.l	d6,d0
	addx.w	d7,d0
	asr.l	d6,d1
	addx.w	d7,d1
	asr.l	d6,d2
	addx.w	d7,d2

	; apply perspective for cam looking along -Z
	subi.w	#128,d2
	neg.w	d2

	asl.w	#7,d0
	asl.w	#7,d1
	ext.l	d0
	ext.l	d1
	divs.w	d2,d0
	divs.w	d2,d1

	#endif
	#else
	; fx16.14 -> int16
	asr.l	d6,d0
	addx.w	d7,d0
	asr.l	d6,d1
	addx.w	d7,d1
	asr.l	d6,d2
	addx.w	d7,d2

	#endif
	; translate origin to center of fb
	addi.w	#tx0_w/2,d0
	addi.w	#tx0_h/2,d1

	move.w	d0,(a5)+ ; v_out.x
	move.w	d1,(a5)+ ; v_out.y
	move.w	d2,(a5)+ ; v_out.z

	cmpa.l	a6,a4
	bcs	vert$

	; scan-convert the scr-space tri edges
	movea.l	a5,a3
	movea.l	#ea_texa0,a5
	move.b	#0x40,color
tri$:
	addi.b	#1,color

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

	addi.w	#1,angle
	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text0+tx0_w*tx0_h-4,a0
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
r3_size	.equ	6

; struct tri
tri_p0	.equ	0  ; word x3 ; r3
tri_p1	.equ	6  ; word x3 ; r3
tri_p2	.equ	12 ; word x3 ; r3
tri_size .equ	18

mat_size .equ r3_size*3

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

	#if target_cpu >= 2
	move.w	0(a6,d0.w*2),d0

	#else
	add.w	d0,d0
	move.w	0(a6,d0.w),d0

	#endif
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

	#if target_cpu >= 2
	move.w	0(a6,d0.w*2),d0

	#else
	add.w	d0,d0
	move.w	0(a6,d0.w),d0

	#endif
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

	.align 4
pattern: ; fb clear pattern
	.space	4*4, 0x20
	.space	4*4, 0x70
angle:	; current angle
	.word	0
roto:	; rotation matrix
	.space	mat_size
	.space	mat_size
frame_i: ; frame index
	.word	0
color:	; primitive color
	.space	1

	.align 16
sinLUT14:
	#include "sinLUT14_64.inc"
tri_obj_0:
	; z-axis faces
	.word	-23, -23,  25
	.word	 22, -23,  25
	.word	-23,  22,  25

	.word	-22,  23,  25
	.word	 23, -22,  25
	.word	 23,  23,  25

	.word	-23, -23, -25
	.word	-23,  22, -25
	.word	 22, -23, -25

	.word	-22,  23, -25
	.word	 23,  23, -25
	.word	 23, -22, -25

	; y-axis faces
	.word	-23,  25, -23
	.word	-23,  25,  22
	.word	 22,  25, -23
                          
	.word	 23,  25, -22
	.word	-22,  25,  23
	.word	 23,  25,  23
                     
	.word	-23, -25, -23
	.word	 22, -25, -23
	.word	-23, -25,  22
                          
	.word	 23, -25, -22
	.word	 23, -25,  23
	.word	-22, -25,  23

	; x-axis faces
	.word	 25, -23, -23
	.word	 25,  22, -23
	.word	 25, -23,  22
                     
	.word	 25, -22,  23
	.word	 25,  23, -22
	.word	 25,  23,  23

	.word	-25, -23, -23
	.word	-25, -23,  22
	.word	-25,  22, -23
                     
	.word	-25, -22,  23
	.word	-25,  23,  23
	.word	-25,  23, -22
tri_scr_0:
	.space	tri_scr_0-tri_obj_0
