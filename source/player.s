; =============================================================================
; init player sprites
; =============================================================================
init_player:
	move.w	#80,player_x
	move.w	#96,player_y
	rts

; =============================================================================
; check for player movement via joystick (the simple way)
; =============================================================================
check_player_joystick:
	move.w	#0,$36(a5)
	move.w	player_speed,d0
	move.w	player_x,d1
	move.w	player_y,d2

	cmp.w	#$0003,$c(a5)
	bne.s	.not_right
	add.w	d0,d1
.not_right:
	cmp.w	#$0300,$c(a5)
	bne.s	.not_left
	sub.w	d0,d1
.not_left:
	cmp.w	#$0100,$c(a5)
	bne.s	.not_up
	sub.w	d0,d2
.not_up:
	cmp.w	#$0001,$c(a5)
	bne.s	.not_down
	add.w	d0,d2
.not_down:
	cmp.w	#$0200,$c(a5)
	bne.s	.not_left_up
	sub.w	d0,d1
	sub.w	d0,d2
.not_left_up:
	cmp.w	#$0103,$c(a5)
	bne.s	.not_right_up
	add.w	d0,d1
	sub.w	d0,d2
.not_right_up:
	cmp.w	#$0301,$c(a5)
	bne.s	.not_left_down
	sub.w	d0,d1
	add.w	d0,d2
.not_left_down:
	cmp.w	#$0002,$c(a5)
	bne.s	.not_right_down
	add.w	d0,d1
	add.w	d0,d2
.not_right_down:
	cmp.w	#1,d1
	bge.s	.clip_x1
	moveq	#1,d1
.clip_x1:
	cmp.w	#1,d2
	bge.s	.clip_y1
	moveq	#1,d2
.clip_y1:
	cmp.w	#320-32-36,d1
	ble.s	.clip_x2
	move.w	#320-32-36,d1
.clip_x2:
	cmp.w	#208-16,d2
	ble.s	.clip_y2
	move.w	#208-16,d2
.clip_y2:
	move.w	d1,player_x
	move.w	d2,player_y
	rts

; =============================================================================
; set player sprite on new position
; =============================================================================
set_player_sprite:
	lea		player_sprite_data_left,a0
	move.w	player_x,d0
	move.w	player_y,d1
	moveq	#16,d2
	bsr		set_sprite_position

	lea		player_sprite_data_right,a0
	move.w	player_x,d0
	add.w	#16,d0
	move.w	player_y,d1
	moveq	#16,d2
	bsr		set_sprite_position

	lea		spr0,a0
	move.l	#player_sprite_data_left,d0
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)

	lea		spr1,a0
	move.l	#player_sprite_data_right,d0
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)
	rts
