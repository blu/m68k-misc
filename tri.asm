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

	; don't use align lest intelHex output breaks; use pad_code instead
	macro	pad_code ; <num_words>
	dcb.w	\1,$4afc ; illegal instruction; traps
	endm

	; we want absolute addresses -- with moto/vasm that means
	; just use org; don't use sections as they cause resetting
	; of the current offset for generation of relocatable code
	org	ea_user

	; we get injected right into supervisor mode, interrupt-style
	; demote ourselves to user mode

	movea.l	#ea_stack,a1
	move.l	a1,usp
	andi.w	#$dfff,sr

	; plot graph paper on channel B -- glyphs
;	lea.l	pattern,a0
;	jsr	clear_text1

	; plot graph paper on channel B -- colors
;	lea.l	pattern+4*4,a0
;	jsr	clear_texa1

	; compute bases for a few on-screeen tris
	lea	tri_0,a0
	lea	pb_0,a1
	lea	tri_end,a2
cpb:
	jsr	init_pb
	adda.l	#tri_size,a0
	adda.l	#pb_size,a1
	cmpa.l	a2,a0
	bcs	cpb

	movea.l	#ea_texa1,a2
	movea.l	#ea_texa1+tx1_h*tx1_w,a3
	moveq	#0,d5 ; curr_x
	moveq	#0,d6 ; curr_y
pixel:
	lea	pb_0,a0
	lea	pb_0+(tri_end-tri_0)/tri_size*pb_size,a1
	moveq	#$47,d7
tri:
	move.w	d5,d0
	move.w	d6,d1
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
	move.b	d7,(a2)
	bra	tri_done
skip:
	addi.b	#1,d7
	adda.l	#pb_size,a0
	cmpa.l	a1,a0
	bne	tri
tri_done:
	addi.w	#1,d5
	cmpi.w	#tx1_w,d5
	blt	param
	moveq	#0,d5
	addi.w	#1,d6
param:
	adda.l	#1,a2
	cmpa.l	a3,a2
	bne	pixel

	moveq	#0,d0 ; syscall_exit
	trap	#15

; clear text channel B
; a0: pattern ptr
; clobbers d0-d7
clear_text1:
	movem.l	(a0),d0-d3
	movea.l	#ea_text1,a0
Lloop:
	movem.l	d0-d3,(a0)
	adda.l	#$4*4,a0 ; emits lea (an,16),an
	cmpa.l	#ea_text1+tx1_w*tx1_h,a0
	blt	Lloop
	rts

; clear attr channel B
; a0: pattern ptr
; clobbers d0-d7
clear_texa1:
	movem.l (a0),d0-d3
	movea.l	#ea_texa1,a0
LLloop:
	movem.l	d0-d3,(a0)
	adda.l	#$4*4,a0 ; emits lea (an,16),an
	cmpa.l	#ea_texa1+tx1_w*tx1_h,a0
	blt	LLloop
	rts

; struct r2
	clrso
r2_x	so.w 1
r2_y	so.w 1

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
; clobbers: d0-d5
init_pb:
	move.w	tri_p0+r2_x(a0),d0
	move.w	tri_p0+r2_y(a0),d1

	move.w	tri_p1+r2_x(a0),d2
	move.w	tri_p1+r2_y(a0),d3

	move.w	tri_p2+r2_x(a0),d4
	move.w	tri_p2+r2_y(a0),d5

	sub.w	d0,d2 ; e01.x = p1.x - p0.x
	sub.w	d1,d3 ; e01.y = p1.y - p0.y

	sub.w	d0,d4 ; e02.x = p2.x - p0.x
	sub.w	d1,d5 ; e02.y = p2.y - p0.y

	move.w	d0,pb_p0+r2_x(a1)
	move.w	d1,pb_p0+r2_y(a1)

	move.w	d2,pb_e01+r2_x(a1)
	move.w	d3,pb_e01+r2_y(a1)

	move.w	d4,pb_e02+r2_x(a1)
	move.w	d5,pb_e02+r2_y(a1)

	; area = e01.x * e02.y - e02.x * e01.y
	muls.w	d5,d2
	muls.w	d4,d3
	sub.l	d3,d2

	move.l	d2,pb_area(a1)
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

	align 2
pattern:
	dc.l	'0123', '4567', '89ab', 'cdef'
	dc.l	$44444444, $44444444, $44444444, $44444444
tri_0:
	dc.w	79,  0
	dc.w	49, 31
	dc.w	 0, 33

	dc.w	79,  0
	dc.w	63, 59
	dc.w	49, 31

	dc.w	63, 59
	dc.w	 0, 33
	dc.w	49, 31
tri_end:
	align 4
pb_0:
	ds.w	(tri_end-tri_0)/tri_size*pb_size/2
