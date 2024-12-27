; =============================================================================
; basic 2d game code
; * custom copperlist
; * double buffering
; *	tilemap rendering via blitter
; * simple hardware-sprites
; * todo ...
; * ...
; ... code by axg74 ...
; =============================================================================

; =============================================================================
; constants
; =============================================================================
SCREENWIDTH			= 640/8
SCREENHEIGHT		= 256
PLANECOUNT			= 4

TILESHEET_WIDTH		= 320
TILESHEET_HEIGHT	= 256
TILE_SIZE			= 16
TILEMAP_COLUMNS		= 20
TILEMAP_ROWS		= 13

; =============================================================================
; macros
; =============================================================================
waitblit:		macro
.\@				btst	#14,2(a5)
				bne.s	.\@
				endm

; =============================================================================
; entry point
; =============================================================================
start:			bsr		calc_tilepos_table

				bsr		init	

				;bsr		draw_tile_screen
				;bsr		swap_screens
				;bsr		draw_tile_screen


.loop:			cmp.b	#$ff,6(a5)
				bne.s	.loop

				bsr		blit_tiles_right_side
				bsr		map_scroll
			;	bsr		swap_screens
				bsr		set_screen_planes

				btst	#6,$bfe001
				bne.s	.loop

				bsr		quit
				rts

; =============================================================================
; init hardware
; =============================================================================
init:			lea		$dff000,a5
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
				
				move.w	#$83f0,$96(a5)
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
swap_screens:	move.l	screen_visible,d0
				move.l	screen_backbuffer,screen_visible
				move.l	d0,screen_backbuffer
				rts

; =============================================================================
; reinit amiga system
; =============================================================================
quit:			move.w	#$7fff,$96(a5)
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
; blit tiles on the right on the screen
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

				move.l	screen_visible,a2
				add.l	d2,a2
				add.l	#38,a2
				add.w	hardscroll_x_offset,a2
				movem.l	a1/a2,$50(a5)
				move.w	#PLANECOUNT*TILE_SIZE*64+1,$58(a5)
				waitblit

				move.l	screen_visible,a2
				add.l	d2,a2
				add.l	#38+40,a2
				add.w	hardscroll_x_offset,a2
				movem.l	a1/a2,$50(a5)
			;	move.w	#PLANECOUNT*TILE_SIZE*64+1,$58(a5)
				waitblit

				add.l	#SCREENWIDTH*TILE_SIZE*PLANECOUNT,d2
				add.l	#40,a3
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

map_scroll:		move.w	map_x,d0
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
				cmp.w	#319,map_x
				ble		.no
				move.w	#0,map_x
			.no:
				rts

; =============================================================================
; vertical blank interrupt handler
; =============================================================================
vb_irq_handler:	movem.l	d0-d7/a0-a6,-(a7)
				lea		$dff000,a5
				btst	#5,$1e(a5)
				bne.s	.no_vbi

				move.w	#%0000000000100000,$9c(a5)
.no_vbi:
				movem.l	(a7)+,d0-d7/a0-a6
				rte

; =============================================================================
; variables, data etc.
; =============================================================================	
map_x:					dc.w	0
map_y:					dc.w	0
map_width:				dc.w	20
map_height:				dc.w	13
hardscroll_x_offset:	dc.w	0
softscroll_x_value:		dc.w	$0000
screen_visible:			dc.l	0
screen_backbuffer:		dc.l	0

irqvec6_save:			dc.l	0			
dmacon_save:			dc.w	0
intena_save:			dc.w	0

tilemap_data:	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
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

gfxname:		dc.b	"graphics.library",0
				even

; #				offset for each tile in the tilesheet
tileoffset_tab:	dcb.l	20*16,0


spr0:			dc.w	$0120,$0000,$0122,$0000
spr1:			dc.w	$0124,$0000,$0126,$0000
spr2:			dc.w	$0128,$0000,$012a,$0000
spr3:			dc.w	$012c,$0000,$012e,$0000
spr4:			dc.w	$0130,$0000,$0132,$0000
spr5:			dc.w	$0134,$0000,$0136,$0000
spr6:			dc.w	$0138,$0000,$013a,$0000
spr7:			dc.w	$013c,$0000,$013e,$0000

				section data,data_c				
copperlist:		
				dc.w	$008e,$2981,$0090,$29c1
				dc.w	$0092,$0038,$0094,$00d0
				
bitplanes:		dc.w	$00e0,$0000,$00e2,$0000
				dc.w	$00e4,$0000,$00e6,$0000
				dc.w	$00e8,$0000,$00ea,$0000
				dc.w	$00ec,$0000,$00ee,$0000
				dc.w	$00f0,$0000,$00f2,$0000

				dc.w	$0100,$4200
bplcon1:		dc.w	$0102,$0000
				dc.w	$0104,$0000,$0106,$0000
				dc.w	$0108,280,$010a,280

colors:			dc.w	$0180,$0fff,$0182,$0000,$0184,$0000,$0186,$0000,$0188,$0000
				dc.w	$018a,$0000,$018c,$0000,$018e,$0000,$0190,$0000,$0192,$0000
				dc.w	$0194,$0000,$0196,$0000,$0198,$0000,$019a,$0000,$019c,$0000
				dc.w	$019e,$0000
				dc.w	$01a0,$0000,$01a2,$0000,$01a4,$0000,$01a6,$0000,$01a8,$00000
				dc.w	$01aa,$0000,$01ac,$0000,$01ae,$0000,$01b0,$0000,$01b2,$00000
				dc.w	$01b4,$0000,$01b6,$0000,$01b8,$0000,$01ba,$0000,$01bc,$00000
				dc.w	$01be,$00000
				dc.w	$ffff,$fffe
				
; #				CHIP-Data like graphics, sounds, music
tile_data:		incbin	"../data/gfx/tiles.rawblit"
test_screen:	incbin	"../data/gfx/test_screen.rawblit"
; #				preallocated screen memory
				
				section screen_ram,bss_c
screen1:		ds.b	SCREENWIDTH*SCREENHEIGHT*PLANECOUNT
screen2:		ds.b	SCREENWIDTH*SCREENHEIGHT*PLANECOUNT
