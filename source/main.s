; =============================================================================
; basic 2d game code
; * custom copperlist
; * double buffering
; *	tilemap rendering via blitter
; * simple hardware-sprites
; * todo ...
; * ...
; ... code by axg74 ...
;
; useful internet resources:
; https://codetapper.com/amiga/diary-of-a-game/menace/part-2-scrolling/
; =============================================================================
		jmp			start

SCREENWIDTH			=	640/8
SCREENHEIGHT		=	256
PLANECOUNT			= 	4
TILESHEET_WIDTH		=	320
TILESHEET_HEIGHT	=	256
TILE_SIZE			=	16
TILEMAP_COLUMNS		=	20
TILEMAP_ROWS		=	13
MAX_TILEMAP_WIDTH	=	320

waitblit:	macro
.\@
		btst	#14,2(a5)
		bne.s	.\@
		endm

; =============================================================================
; other sources
; =============================================================================

		include	"./player.s"

; =============================================================================
; game starts here
; =============================================================================
start:	
	bsr		calc_tilepos_table
	
	bsr		init	
	bsr		init_player

	bsr		draw_tile_screen
	bsr		swap_screens
	bsr		draw_tile_screen

.loop:			
	cmp.b	#$ff,6(a5)
	bne.s	.loop

	bsr		check_player_joystick
	bsr		set_player_sprite

	bsr		blit_tiles_right_side
	bsr		map_scroll
	bsr		swap_screens
	bsr		set_screen_planes

	btst	#6,$bfe001
	bne.s	.loop

	bsr		quit
	rts

; =============================================================================
; init hardware
; =============================================================================
init:	
	lea 	$dff000,a5
	move.w	#$8000,d1
	move.w	$2(a5),d0
	or.w	d1,d0
	move.w	d0,dmacon_save

	move.w	$1c(a5),d0
	or.w	d1,d0
	move.w	d0,intena_save

	move.l	$6c,irqvec6_save
	move.w	#$7fff,$96(a5)
	move.w	#$7fff,$9a(a5)
	move.w	#$0020,$9c(a5)

	move.l	#vb_irq_handler,$6c
	move.w	#%1100000000100000,$9a(a5)

	move.l	#screen1,screen_visible
	move.l	#screen2,screen_backbuffer
	bsr		set_screen_planes
				
	lea		colors,a0
	lea		tile_data+40*256*4,a1
	;lea		test_screen+80*256*4,a1
	moveq	#16-1,d7
.set_color_values:
	move.w	(a1)+,2(a0)
	addq.l	#4,a0
	dbf		d7,.set_color_values
				
	move.w	#%1000001111101111,$96(a5)
	move.l	#copperlist,$80(a5)
	move.w	#0,$88(a5)

	move.w	#0,map_x
	move.w	#0,map_y
	rts

; =============================================================================
; set bitplanes addresses
; =============================================================================
set_screen_planes:
	lea		bitplanes,a0
	move.l	screen_visible,d0
	add.w	hardscroll_x_offset,d0
	moveq	#PLANECOUNT-1,d7
.loop:
	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)
	swap	d0
	addq.l	#8,a0
	add.l	#SCREENWIDTH,d0
	dbf		d7,.loop
	rts

	; =============================================================================
; swap current pointer for the screen address
; =============================================================================
swap_screens:
	move.l	screen_visible,d0
	move.l	screen_backbuffer,screen_visible
	move.l	d0,screen_backbuffer
	rts

; =============================================================================
; reinit amiga system
; =============================================================================
quit:	
	move.w	#$7fff,$96(a5)
	move.w	#$7fff,$9a(a5)
				
	move.l	irqvec6_save,$6c
	move.w	dmacon_save,$96(a5)
	move.w	intena_save,$9a(a5)

	move.l	4,a6
	lea		gfxname,a1
	clr.l	d0
	jsr		-552(a6)
	move.l	d0,a1
	move.l	38(a1),$80(a5)
	move.w	#0,$88(a5)
	jsr		-414(a6)
	clr.l	d0
	rts

; =============================================================================
; draws a whole tilemap section to the screen
; =============================================================================	
draw_tile_screen:
	waitblit
	move.l	#$09f00000,$40(a5)
	move.l	#$ffffffff,$44(a5)
	move.l	#$0026004e,$64(a5)	

	lea		tilemap_data,a3

	moveq	#0,d1										; y-pos
	moveq	#TILEMAP_ROWS-1,d6
.y_loop:
	moveq	#0,d0										; x-pos
	moveq	#TILEMAP_COLUMNS-1,d7
.x_loop:
	moveq	#0,d3										; get tile-id
	move.w	(a3)+,d3
	lsl.w	#2,d3
	lea		tile_data,a1
	lea		tileoffset_tab,a4							; get the correct tile-offset for the
	add.l	(a4,d3),a1									; source

	move.l	screen_backbuffer,a2
	add.l	d0,a2
	add.l	d1,a2
	movem.l	a1/a2,$50(a5)
	move.w	#PLANECOUNT*TILE_SIZE*64+1,$58(a5)
	waitblit
	addq.l	#2,d0
	dbf		d7,.x_loop
	add.l	#SCREENWIDTH*TILE_SIZE*PLANECOUNT,d1
	dbf		d6,.y_loop
	rts
			
; =============================================================================
; blit tiles rows on both screens
; =============================================================================	
blit_tiles_right_side:
	waitblit
	move.l	#$09f00000,$40(a5)
	move.l	#$ffffffff,$44(a5)
	move.l	#$0026004e,$64(a5)	

	lea		tilemap_data,a3
	clr.l	d4
	move.w	map_x,d4
	lsr.w	#4,d4
	lsl.w	#1,d4
	add.l	d4,a3

	moveq	#0,d2										; y-offset
	moveq	#TILEMAP_ROWS-1,d7
.y_loop:
	moveq	#0,d3										; get tile-id
	move.w	(a3),d3
	lsl.w	#2,d3
	lea		tile_data,a1
	lea		tileoffset_tab,a4							; get the correct tile-offset for the
	add.l	(a4,d3),a1									; source

	move.l	screen_backbuffer,a2
	add.l	d2,a2
	add.w	hardscroll_x_offset,a2
	movem.l	a1/a2,$50(a5)
	move.w	#PLANECOUNT*TILE_SIZE*64+1,$58(a5)
	waitblit

	move.l	screen_visible,a2
	add.l	d2,a2
	add.w	hardscroll_x_offset,a2
	movem.l	a1/a2,$50(a5)
	move.w	#PLANECOUNT*TILE_SIZE*64+1,$58(a5)
	waitblit

	move.l	screen_backbuffer,a2
	add.l	d2,a2
	add.l	#40,a2
	add.w	hardscroll_x_offset,a2
	movem.l	a1/a2,$50(a5)
	move.w	#PLANECOUNT*TILE_SIZE*64+1,$58(a5)
	waitblit

	move.l	screen_visible,a2
	add.l	d2,a2
	add.l	#40,a2
	add.w	hardscroll_x_offset,a2
	movem.l	a1/a2,$50(a5)
	move.w	#PLANECOUNT*TILE_SIZE*64+1,$58(a5)
	waitblit

	add.l	#SCREENWIDTH*TILE_SIZE*PLANECOUNT,d2		; next row in bitplane
	add.l	#40,a3										; next row in tile-map-data
	dbf		d7,.y_loop
	rts

; =============================================================================
; calculate tile-posiiton offsets
; =============================================================================	
calc_tilepos_table:
	lea		tileoffset_tab,a0
	moveq	#0,d1
	moveq	#256/TILE_SIZE-1,d6
.y_loop:
	move.l	d1,d0
	moveq	#320/TILE_SIZE-1,d7
.x_loop:
	move.l	d0,(a0)+
	addq.l	#2,d0
	dbf		d7,.x_loop
	add.l	#TILE_SIZE*40*4,d1
	dbf		d6,.y_loop
	rts

; =============================================================================
; calculate soft-scroll-x and hard-scroll-x from the map-x-position
; =============================================================================	
map_scroll:	
	subq.w	#1,scroll_delay
	bpl.s	.no
	move.w	#0,scroll_delay

	move.w	map_x,d0			; calc softscroll-x value
	and.w	#15,d0
	move.w	#15,d2
	sub.w	d0,d2
	move.w	d2,d1
	lsl.w	#4,d1
	or.w	d2,d1
	move.w	d1,bplcon1+2

	clr.l	d0					; calc hardscroll-x value
	clr.l	d1					
	move.w	map_x,d0
	move.w	#320,d1
	divu	d1,d0
	swap	d0
	and.l	#$0000ffff,d0
	lsr.w	#4,d0
	lsl.w	#1,d0
	move.w	d0,hardscroll_x_offset

	addq.w	#1,map_x
	cmp.w	#MAX_TILEMAP_WIDTH-1,map_x
	ble		.no
	move.w	#0,map_x
.no:
	rts

; =============================================================================
; vertical blank interrupt handler
; =============================================================================
vb_irq_handler:
	movem.l	d0-d7/a0-a6,-(a7)
	lea		$dff000,a5
	btst	#5,$1e(a5)
	bne.s	.no_vbi

	move.w	#%0000000000100000,$9c(a5)
.no_vbi:
	movem.l	(a7)+,d0-d7/a0-a6
	rte

; =============================================================================
; set sprite position
; =============================================================================
; a0 = sprite-data
; d0 = x-pos.
; d1 = y-pos.
; d2 = sprite-height
set_sprite_position:
	add.w	#$91,d0
	add.w	#$29,d1
	clr.l	0(a0)					; clear sprite controll words
	move.b	d1,0(a0)				; vertical start position of the sprite
	btst	#0,d0
	beq.s	.no_h0
	bset	#0,3(a0)				; set h0
.no_h0:
	btst	#8,d1
	beq.s	.no_e8
	bset	#2,3(a0)				; set e8
.no_e8:
	lsr.w	#1,d0					; bits H8-H1
	move.b	d0,1(a0)				; first controll-word horizontal position
	add.w	d2,d1
	addq.w	#1,d1
	move.b	d1,2(a0)				; second controll-word vertical end-position
	btst	#8,d1
	beq.s	.no_l8
	bset	#1,3(a0)				; set l8
.no_l8:
	rts

; =============================================================================
; variables, data etc.
; =============================================================================	
map_x: 					dc.w	0
map_y: 					dc.w	0
map_width: 				dc.w	20
map_height:				dc.w	13
scroll_delay:			dc.w	0
hardscroll_x_offset: 	dc.w	0
softscroll_x_value:		dc.w	$0000
screen_visible: 		dc.l	0
screen_backbuffer: 		dc.l	0

player_x:				dc.w	0
player_y:				dc.w	0
player_speed:			dc.w	2

irqvec6_save:			dc.l	0			
dmacon_save: 			dc.w	0
intena_save: 			dc.w	0

tilemap_data:	
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,2,2,2,2,0,2,0,2,0,2,2,2,2,0,0,0,0,0,0
	dc.w	0,2,0,0,2,0,2,0,2,0,2,0,0,0,0,0,0,0,0,0
	dc.w	0,2,2,2,2,0,0,2,0,0,2,0,2,2,0,0,0,0,0,0
	dc.w	0,2,0,0,2,0,2,0,2,0,2,0,0,2,0,0,0,0,0,0
	dc.w	0,2,0,0,2,0,2,0,2,0,2,2,2,2,0,0,0,0,0,0
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3

gfxname:				dc.b	"graphics.library",0
						even

; #	offset for each tile in the tilesheet
tileoffset_tab:			dcb.l	20*16,0

			section data,data_c		
		
copperlist:	dc.w	$008e,$2991,$0090,$29b1
			dc.w	$0092,$0030,$0094,$00d0

spr0:		dc.w	$0120,$0000,$0122,$0000
spr1:		dc.w	$0124,$0000,$0126,$0000
spr2:		dc.w	$0128,$0000,$012a,$0000
spr3:		dc.w	$012c,$0000,$012e,$0000
spr4:		dc.w	$0130,$0000,$0132,$0000
spr5:		dc.w	$0134,$0000,$0136,$0000
spr6:		dc.w	$0138,$0000,$013a,$0000
spr7:		dc.w	$013c,$0000,$013e,$0000
				
bitplanes:	dc.w	$00e0,$0000,$00e2,$0000
			dc.w	$00e4,$0000,$00e6,$0000
			dc.w	$00e8,$0000,$00ea,$0000
			dc.w	$00ec,$0000,$00ee,$0000
			dc.w	$00f0,$0000,$00f2,$0000

			dc.w	$0100,$4200
bplcon1:	dc.w	$0102,$0000
			dc.w	$0104,%0000000000111111
			dc.w	$0106,$0000

; modulo calculation: ((80 * 3) + 40) - 2
			dc.w	$0108,278,$010a,278

; background colors
colors:		dc.w	$0180,$0fff,$0182,$0000,$0184,$0000,$0186,$0000,$0188,$0000
			dc.w	$018a,$0000,$018c,$0000,$018e,$0000,$0190,$0000,$0192,$0000
			dc.w	$0194,$0000,$0196,$0000,$0198,$0000,$019a,$0000,$019c,$0000
			dc.w	$019e,$0000

; sprite colors
			dc.w	$01a0,$0000,$01a2,$00f0,$01a4,$0f00,$01a6,$000f,$01a8,$00000
			dc.w	$01aa,$0000,$01ac,$0000,$01ae,$0000,$01b0,$0000,$01b2,$00000
			dc.w	$01b4,$0000,$01b6,$0000,$01b8,$0000,$01ba,$0000,$01bc,$00000
			dc.w	$01be,$00000

; screen start
			dc.w	$390f,$fffe

; screen end
			dc.w	$f90f,$fffe,$0100,$0200
			dc.w	$ffff,$fffe
				
; CHIP-Data like graphics, sounds, music

; normal player shot
shot1_sprite_data:
			dc.w	$0000,$0000
			dc.w	$00FE,$00C2
			dc.w	$07D3,$062D
			dc.w	$3289,$2D76
			dc.w	$C849,$B7B6
			dc.w	$3289,$2D76
			dc.w	$07D3,$062D
			dc.w	$00FE,$00C2
			dc.w	$0000,$0000

player_sprite_data_left:
			dc.w	$0000,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$ffff,$0000
			dc.w	$0000,$0000

player_sprite_data_right:
			dc.w	$0000,$0000
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$ffff
			dc.w	$0000,$0000

tile_data:	incbin	"../data/gfx/tiles.rawblit"
test_screen:incbin	"../data/gfx/test_screen.rawblit"

; preallocated screen memory
			section screen_ram,bss_c

screen1: ds.b	SCREENWIDTH*SCREENHEIGHT*PLANECOUNT
screen2: ds.b	SCREENWIDTH*SCREENHEIGHT*PLANECOUNT
