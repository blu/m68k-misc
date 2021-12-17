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

fract	equ 15

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_user

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode
	movea.l	#ea_stack,a1
	move.l	a1,usp
	andi.w	#$dfff,sr

frame:
	; compute scr coords for obj-space tris
	lea	tri_obj_0,a0
	lea	tri_scr_0,a1
	movea.l	a1,a2
	move.w	angle,d4
	bftst	d4{26:6} ; reversed indexation!
	bne	non_extrema

	; sin/cos extrema case -- only n*1/2*pi rotations
	and.w	#$ff,d4
	lsr.w	#6,d4
	lea.l	sincosLUT,a3
	move.w	0(a3,d4.w*8),d0 ; sin AND mask
	move.w	2(a3,d4.w*8),d1 ; sin XOR mask
	move.w	4(a3,d4.w*8),d2 ; cos AND mask
	move.w	6(a3,d4.w*8),d3 ; cos XOR mask
vert_extrema:
	move.w	(a0)+,d4 ; v_in.x
	move.w	(a0)+,d5 ; v_in.y
	move.w	d4,d6
	move.w	d5,d7

	; transform vertex x-coord: cos * x - sin * y
	and.w	d2,d4
	eor.w	d3,d4
	sub.w	d3,d4

	and.w	d0,d5
	eor.w	d1,d5
	sub.w	d1,d5

	sub.w	d5,d4
	addi.w	#tx1_w/2,d4
	move.w	d4,(a1)+ ; v_out.x

	; transform vertex y-coord: sin * x + cos * y
	and.w	d0,d6
	eor.w	d1,d6
	sub.w	d1,d6

	and.w	d2,d7
	eor.w	d3,d7
	sub.w	d3,d7

	add.w	d7,d6
	addi.w	#tx1_h/2,d6
	move.w	d6,(a1)+ ; v_out.y

	cmpa.l	a2,a0
	bcs	vert_extrema
	bra	xform_done

non_extrema:
	move.w	d4,d0
	jsr	lut_cos
	move.w	d0,d1
	move.w	d4,d0
	jsr	lut_sin
	moveq	#fract,d6 ; 68000 shift cannot do imm > 8
	moveq	#0,d7     ; 68000 addx cannot do imm
vert:
	move.w	(a0)+,d2 ; v_in.x
	move.w	(a0)+,d3 ; v_in.y

	; transform vertex x-coord: cos * x - sin * y
	move.w	d2,d4
	muls.w	d1,d4
	move.w	d3,d5
	muls.w	d0,d5

	sub.l	d5,d4
	; fx16.15 -> int16
	asr.l	d6,d4
	addx.w	d7,d4

	addi.w	#tx1_w/2,d4
	move.w	d4,(a1)+ ; v_out.x

	; transform vertex y-coord: sin * x + cos * y
	move.w	d2,d4
	muls.w	d0,d4
	move.w	d3,d5
	muls.w	d1,d5

	add.l	d5,d4
	; fx16.15 -> int16
	asr.l	d6,d4
	addx.w	d7,d4

	addi.w	#tx1_h/2,d4
	move.w	d4,(a1)+ ; v_out.y

	cmpa.l	a2,a0
	bcs	vert

xform_done:
	; compute bases for scr-space tris
	lea	tri_scr_0,a0
	lea	pb_0,a1
	lea	tri_end,a2
base:
	jsr	init_pb
	cmpa.l	a2,a0
	bcs	base

	; scan-convert the scr-space tris
	movea.l	#ea_texa1,a2
	movea.l	#ea_texa1+tx1_h*tx1_w,a3
	moveq	#0,d4 ; scr_x
	moveq	#0,d5 ; scr_y
	move.w	frame_i,d6
pixel:
	lea	pb_0,a0
	lea	pb_0+(tri_end-tri_scr_0)/tri_size*pb_size,a1
tri:
	move.w	d4,d0
	move.w	d5,d1
	jsr	get_coord

	; if {s|t} < 0 || (s+t) > area then pixel is outside
	cmpi.l	#0,d0
	blt	skip
	cmpi.l	#0,d1
	blt	skip
	add.l	d1,d0
	cmp.l	pb_area(a0),d0
	bgt	skip
	; tri pixel -- plot and exit tri loop
	move.b	d6,(a2)
	bra	tri_done
skip:
	adda.l	#pb_size,a0
	cmpa.l	a1,a0
	bne	tri
tri_done:
	addi.w	#1,d4
	cmpi.w	#tx1_w,d4
	blt	param
	moveq	#0,d4
	addi.w	#1,d5
param:
	adda.l	#1,a2
	cmpa.l	a3,a2
	bne	pixel

	addi.w	#4,angle
	move.w	frame_i,d0
	addi.w	#1,d0
	move.w	d0,frame_i
	movea.l	#ea_text1+tx1_w-4,a0
	jsr	print_u16
	bra	frame

	; some day
	moveq	#0,d0 ; syscall_exit
	trap	#15

; produce ascii from word
; d0.w: word to print
; a0: output address
; clobbers: d1, a1
print_u16:
	lea	4(a0),a1
nibble:
	rol.w	#4,d0
	move.b	d0,d1
	andi.b	#$f,d1
	addi.b	#'0',d1
	cmpi.b	#'0'+10,d1
	bcs	digit_ready
	addi.b	#'a'-'9'-1,d1
digit_ready:
	move.b	d1,(a0)+
	cmpa.l	a1,a0
	bcs	nibble
	rts

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

; compute parallelogram basis from a tri:
;   e01 = p1 - p0
;   e02 = p2 - p0
;   area = e01.x * e02.y - e02.x * e01.y
; a0: tri ptr
; a1: basis ptr
; returns: a0: tri_ptr + 1
;          a1: basis_ptr + 1
; clobbers: d0-d5
init_pb:
	move.w	(a0)+,d0 ; tri_p0.x
	move.w	(a0)+,d1 ; tri_p0.y

	move.w	(a0)+,d2 ; tri_p1.x
	move.w	(a0)+,d3 ; tri_p1.y

	move.w	(a0)+,d4 ; tri_p2.x
	move.w	(a0)+,d5 ; tri_p2.y

	sub.w	d0,d2 ; e01.x = p1.x - p0.x
	sub.w	d1,d3 ; e01.y = p1.y - p0.y

	sub.w	d0,d4 ; e02.x = p2.x - p0.x
	sub.w	d1,d5 ; e02.y = p2.y - p0.y

	move.w	d0,(a1)+ ; pb_p0.x
	move.w	d1,(a1)+ ; pb_p0.y

	move.w	d2,(a1)+ ; pb_e01.x
	move.w	d3,(a1)+ ; pb_e01.y

	move.w	d4,(a1)+ ; pb_e02.x
	move.w	d5,(a1)+ ; pb_e02.y

	; area = e01.x * e02.y - e02.x * e01.y
	muls.w	d5,d2
	muls.w	d4,d3
	sub.l	d3,d2

	move.l	d2,(a1)+ ; pb_area
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

; get sine of non-1/2*pi-multiple angle
; d0.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns: d0.w: sine as fx0.15 (d0[15] replicates sign)
	mc68020
lut_sin:
	and.w	#$ff,d0
	cmpi.b	#$80,d0
	bcs	positive
	subi.b	#$80,d0 ; rotate back to positive
	cmpi.b	#$40,d0
	bcs	symmetry_negative
	subi.b	#$80,d0
	neg.b	d0
symmetry_negative:
	move.w	sinLUT(d0.w*2),d0
	neg.w	d0
	rts
positive:
	cmpi.b	#$40,d0
	bcs	symmetry_positive
	subi.b	#$80,d0
	neg.b	d0
symmetry_positive:
	move.w	sinLUT(d0.w*2),d0
	rts

; get cosine of non-1/2*pi-multiple angle
; d0.w: angle ticks -- [0, 2pi) -> [0, 256)
; returns; d0.w: cosine as fx0.15 (d0[15] replicates sign)
	mc68000
lut_cos:
	addi.w	#$40,d0
	bra	lut_sin

angle:
	dc.w	0
frame_i:
	dc.w	0

	align 4
sinLUT: ; 15 fractional bits; for signed arithmetics
	dc.w $0000, $0324, $0648, $096B, $0C8C, $0FAB, $12C8, $15E2
	dc.w $18F9, $1C0C, $1F1A, $2224, $2528, $2827, $2B1F, $2E11
	dc.w $30FC, $33DF, $36BA, $398D, $3C57, $3F17, $41CE, $447B
	dc.w $471D, $49B4, $4C40, $4EC0, $5134, $539B, $55F6, $5843
	dc.w $5A82, $5CB4, $5ED7, $60EC, $62F2, $64E9, $66D0, $68A7
	dc.w $6A6E, $6C24, $6DCA, $6F5F, $70E3, $7255, $73B6, $7505
	dc.w $7642, $776C, $7885, $798A, $7A7D, $7B5D, $7C2A, $7CE4
	dc.w $7D8A, $7E1E, $7E9D, $7F0A, $7F62, $7FA7, $7FD9, $7FF6
sincosLUT: ; 16-bit masks for sincos extrema; order: AND, XOR for sine and cosine, resp
	dc.w  0,  0, -1,  0 ;   0 * pi
	dc.w -1,  0,  0,  0 ; 1/2 * pi
	dc.w  0,  0, -1, -1 ;   1 * pi
	dc.w -1, -1,  0,  0 ; 3/2 * pi
tri_obj_0:
	dc.w	  0, -29
	dc.w	 25,  14
	dc.w	-25,  14
tri_scr_0:
	ds.w	(tri_scr_0-tri_obj_0)/2
tri_end:
	align 4
pb_0:
	ds.w	(tri_end-tri_scr_0)/tri_size*pb_size/2
