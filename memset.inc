	inline
; memset a buffer to a given value; 1B inner loop
; a0: target
; d0.b: content
; d1.l: length; 0 is undefined
; returns: a0: last_written_address + 1
memset1:
	move.b	d0,(a0)+
	subi.l	#1,d1
	bne	memset1
	rts

	einline

	inline
; memset a buffer to a given value; 2B inner loop; only aligned writes
; a0: target
; d0.l: content; value splatted to long word
; d1.l: length; 0 is undefined
; returns: a0: last_written_address + 1
; clobbers: d2
memset2:
	move.l	a0,d2

	btst	#0,d2
	beq	.head0
	move.b	d0,(a0)+
	subi.l	#1,d1
.head0:
	cmp.l	#2,d1
	bcs	.tail0

	move.l	d1,d2
	lsr.l	#1,d2
.loop:
	move.w	d0,(a0)+
	subi.l	#1,d2
	bne	.loop
.tail0:
	btst	#0,d1
	beq	.done
	move.b	d0,(a0)+
.done:
	rts

	einline

	inline
; memset a buffer to a given value; 4B inner loop; only aligned writes
; a0: target
; d0.l: content; value splatted to long word
; d1.l: length; 0 is undefined
; returns: a0: last_written_address + 1
; clobbers: d2
memset4:
	move.l	a0,d2

	btst	#0,d2
	beq	.head0
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.l	#1,d1
.head0:
	cmp.l	#2,d1
	bcs	.tail0

	btst	#1,d2
	beq	.head1
	move.w	d0,(a0)+
;	addi.l	#2,d2 ; for higher alignmen versions
	subi.l	#2,d1
.head1:
	cmp.l	#4,d1
	bcs	.tail1

	move.l	d1,d2
	lsr.l	#2,d2
.loop:
	move.l	d0,(a0)+
	subi.l	#1,d2
	bne	.loop
.tail1:
	btst	#1,d1
	beq	.tail0
	move.w	d0,(a0)+
.tail0:
	btst	#0,d1
	beq	.done
	move.b	d0,(a0)+
.done:
	rts

	einline

	inline
; memset a buffer to a given value; 8B inner loop; only aligned writes
; a0: target
; d0.l: content; value splatted to long word
; d1.l: length; 0 is undefined
; returns: a0: last_written_address + 1
; clobbers: d2
memset8:
	move.l	a0,d2

	btst	#0,d2
	beq	.head0
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.l	#1,d1
.head0:
	cmp.l	#2,d1
	bcs	.tail0

	btst	#1,d2
	beq	.head1
	move.w	d0,(a0)+
	addi.l	#2,d2
	subi.l	#2,d1
.head1:
	cmp.l	#4,d1
	bcs	.tail1

	btst	#2,d2
	beq	.head2
	move.l	d0,(a0)+
;	addi.l	#4,d2 ; for higher alignmen versions
	subi.l	#4,d1
.head2:
	cmp.l	#8,d1
	bcs	.tail2

	move.l	d1,d2
	lsr.l	#3,d2
.loop:
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	subi.l	#1,d2
	bne	.loop
.tail2:
	btst	#2,d1
	beq	.tail1
	move.l	d0,(a0)+
.tail1:
	btst	#1,d1
	beq	.tail0
	move.w	d0,(a0)+
.tail0:
	btst	#0,d1
	beq	.done
	move.b	d0,(a0)+
.done:
	rts

	einline

	inline
; memset a buffer to a given value; 16B inner loop; only aligned writes
; a0: target
; d0.l: content; value splatted to long word
; d1.l: length; 0 is undefined
; returns: a0: last_written_address + 1
; clobbers: d2
memset16:
	move.l	a0,d2

	btst	#0,d2
	beq	.head0
	move.b	d0,(a0)+
	addi.l	#1,d2
	subi.l	#1,d1
.head0:
	cmp.l	#2,d1
	bcs	.tail0

	btst	#1,d2
	beq	.head1
	move.w	d0,(a0)+
	addi.l	#2,d2
	subi.l	#2,d1
.head1:
	cmp.l	#4,d1
	bcs	.tail1

	btst	#2,d2
	beq	.head2
	move.l	d0,(a0)+
	addi.l	#4,d2
	subi.l	#4,d1
.head2:
	cmp.l	#8,d1
	bcs	.tail2

	btst	#3,d2
	beq	.head3
	move.l	d0,(a0)+
	move.l	d0,(a0)+
;	addi.l	#8,d2 ; for higher alignmen versions
	subi.l	#8,d1
.head3:
	cmp.l	#16,d1
	bcs	.tail3

	move.l	d1,d2
	lsr.l	#4,d2
.loop:
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	subi.l	#1,d2
	bne	.loop
.tail3:
	btst	#3,d1
	beq	.tail2
	move.l	d0,(a0)+
	move.l	d0,(a0)+
.tail2:
	btst	#2,d1
	beq	.tail1
	move.l	d0,(a0)+
.tail1:
	btst	#1,d1
	beq	.tail0
	move.w	d0,(a0)+
.tail0:
	btst	#0,d1
	beq	.done
	move.b	d0,(a0)+
.done:
	rts

	einline
