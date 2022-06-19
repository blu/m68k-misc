; control symbols:
; fb_w (numerical): fb width
; fb_h (numerical): fb height
; color (numerical, optional): color literal if macro; byte label otherwise
; do_clip (define): enforce clipping in primitives

; draw a line in a statically-sized fb; last pixel omitted
; d0.w: x0
; d1.w: y0
; d2.w: x1
; d3.w: y1
; a0: fb ptr
; clobbers: d4-d7, a1
line:
	; compute x0,y0 addr in fb
	move.w	d1,d4
	muls.w	#fb_w,d4
	adda.l	d4,a0
	adda.w	d0,a0

	moveq	#1,d6
	move.w	d2,d4
	sub.w	d0,d4 ; dx
	bge	dx_done$
	neg.w	d4
	neg.w	d6
dx_done$:
	moveq	#1,d7
	movea.w	#fb_w,a1
	move.w	d3,d5
	sub.w	d1,d5 ; dy
	bge	dy_done$
	neg.w	d5
	neg.w	d7
	movea.w	#-fb_w,a1
dy_done$:
	cmp.w	d4,d5
	bge	high_slope$

	; low slope: iterate along x
	add.w	d5,d5 ; 2 dy
	move.w	d5,d3
	sub.w	d4,d3 ; 2 dy - dx
	add.w	d4,d4 ; 2 dx
loop_x$:
	#ifdef do_clip
	cmp.w	#fb_w,d0
	bcc	advance_x$
	cmp.w	#fb_h,d1
	bcc	advance_x$
	#endif
	#ifdef color
	move.b	#color,(a0)
	#else
	move.b	color,(a0)
	#endif
advance_x$:
	adda.w	d6,a0
	add.w	d6,d0
	tst.w	d3
	ble	x_done$
	adda.l	a1,a0
	sub.w	d4,d3
	add.w	d7,d1
x_done$:
	add.w	d5,d3
	cmp.w	d0,d2
	bne	loop_x$
	rts
high_slope$: ; iterate along y
	add.w	d4,d4 ; 2 dx
	move.w	d4,d2
	sub.w	d5,d2 ; 2 dx - dy
	add.w	d5,d5 ; 2 dy
	bne	loop_y$
	rts
loop_y$:
	#ifdef do_clip
	cmp.w	#fb_w,d0
	bcc	advance_y$
	cmp.w	#fb_h,d1
	bcc	advance_y$
	#endif
	#ifdef color
	move.b	#color,(a0)
	#else
	move.b	color,(a0)
	#endif
advance_y$:
	adda.l	a1,a0
	add.w	d7,d1
	tst.w	d2
	ble	y_done$
	adda.w	d6,a0
	sub.w	d5,d2
	add.w	d6,d0
y_done$:
	add.w	d4,d2
	cmp.w	d1,d3
	bne	loop_y$
	rts
