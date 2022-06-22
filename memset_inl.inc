; memset a buffer to a given value; 1B inner loop
; a0: target
; d0.b: value
; d1.w: length; 0 is undefined
; returns: a0: last_written_address + 1
	macro memset1_inl
.loop\@
	move.b	d0,(a0)+
	subi.w	#1,d1
	bne	.loop\@
	endm

; memset a buffer to a given value; 2B inner loop; only aligned writes
; a0: target
; d0.w: value splatted to word
; d1.w: length; 0 is undefined
; returns: a0: last_written_address + 1
; clobbers: d2
	macro memset2_inl
	move.l	a0,d2

	btst	#0,d2
	beq	.head0\@
	move.b	d0,(a0)+
	subi.w	#1,d1
.head0\@:
	cmp.w	#2,d1
	bcs	.tail0\@

	move.w	d1,d2
	lsr.w	#1,d2
.loop\@:
	move.w	d0,(a0)+
	subi.w	#1,d2
	bne	.loop\@
.tail0\@:
	btst	#0,d1
	beq	.done\@
	move.b	d0,(a0)+
.done\@:
	endm

; memset a buffer to a given value; 4B inner loop; only aligned writes
; a0: target
; d0.l: value splatted to long word
; d1.w: length; 0 is undefined
; returns: a0: last_written_address + 1
; clobbers: d2
	macro memset4_inl
	move.l	a0,d2

	btst	#0,d2
	beq	.head0\@
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.w	#1,d1
.head0\@:
	cmp.w	#2,d1
	bcs	.tail0\@

	btst	#1,d2
	beq	.head1\@
	move.w	d0,(a0)+
;	addi.l	#2,d2 ; for higher alignmen versions
	subi.w	#2,d1
.head1\@:
	cmp.w	#4,d1
	bcs	.tail1\@

	move.w	d1,d2
	lsr.w	#2,d2
.loop\@:
	move.l	d0,(a0)+
	subi.w	#1,d2
	bne	.loop\@
.tail1\@:
	btst	#1,d1
	beq	.tail0\@
	move.w	d0,(a0)+
.tail0\@:
	btst	#0,d1
	beq	.done\@
	move.b	d0,(a0)+
.done\@:
	endm

; memset a buffer to a given value; 8B inner loop; only aligned writes
; a0: target
; d0.l: value splatted to long word
; d1.w: length; 0 is undefined
; returns: a0: last_written_address + 1
; clobbers: d2
	macro memset8_inl
	move.l	a0,d2

	btst	#0,d2
	beq	.head0\@
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.w	#1,d1
.head0\@:
	cmp.w	#2,d1
	bcs	.tail0\@

	btst	#1,d2
	beq	.head1\@
	move.w	d0,(a0)+
	addi.l	#2,d2
	subi.w	#2,d1
.head1\@:
	cmp.w	#4,d1
	bcs	.tail1\@

	btst	#2,d2
	beq	.head2\@
	move.l	d0,(a0)+
;	addi.l	#4,d2 ; for higher alignmen versions
	subi.w	#4,d1
.head2\@:
	cmp.w	#8,d1
	bcs	.tail2\@

	move.w	d1,d2
	lsr.w	#3,d2
.loop\@:
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	subi.w	#1,d2
	bne	.loop\@
.tail2\@:
	btst	#2,d1
	beq	.tail1\@
	move.l	d0,(a0)+
.tail1\@:
	btst	#1,d1
	beq	.tail0\@
	move.w	d0,(a0)+
.tail0\@:
	btst	#0,d1
	beq	.done\@
	move.b	d0,(a0)+
.done\@:
	endm

; memset a buffer to a given value; 16B inner loop; only aligned writes
; a0: target
; d0.l: value splatted to long word
; d1.w: length; 0 is undefined
; returns: a0: last_written_address + 1
; clobbers: d2
	macro memset16_inl
	move.l	a0,d2

	btst	#0,d2
	beq	.head0\@
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.w	#1,d1
.head0\@:
	cmp.w	#2,d1
	bcs	.tail0\@

	btst	#1,d2
	beq	.head1\@
	move.w	d0,(a0)+
	addi.l	#2,d2
	subi.w	#2,d1
.head1\@:
	cmp.w	#4,d1
	bcs	.tail1\@

	btst	#2,d2
	beq	.head2\@
	move.l	d0,(a0)+
	addi.l	#4,d2
	subi.w	#4,d1
.head2\@:
	cmp.w	#8,d1
	bcs	.tail2\@

	btst	#3,d2
	beq	.head3\@
	move.l	d0,(a0)+
	move.l	d0,(a0)+
;	addi.l	#8,d2 ; for higher alignmen versions
	subi.w	#8,d1
.head3\@:
	cmp.w	#16,d1
	bcs	.tail3\@

	move.w	d1,d2
	lsr.w	#4,d2
.loop\@:
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	subi.w	#1,d2
	bne	.loop\@
.tail3\@:
	btst	#3,d1
	beq	.tail2\@
	move.l	d0,(a0)+
	move.l	d0,(a0)+
.tail2\@:
	btst	#2,d1
	beq	.tail1\@
	move.l	d0,(a0)+
.tail1\@:
	btst	#1,d1
	beq	.tail0\@
	move.w	d0,(a0)+
.tail0\@:
	btst	#0,d1
	beq	.done\@
	move.b	d0,(a0)+
.done\@:
	endm
