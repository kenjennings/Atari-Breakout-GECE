;===============================================================================
; Breakout Arcade -- 1976
; Conceptualized by Nolan Bushnell and Steve Bristow.
; Built by Steve Wozniak.
; https://en.wikipedia.org/wiki/Breakout_(video_game)
;===============================================================================
; C64 Breakout clone -- 2016
; Written by Darren Du Vall aka Sausage-Toes
; source at: 
; Github: https://github.com/Sausage-Toes/C64_Breakout
;===============================================================================
; C64 Breakout clone ported to Atari 8-bit -- 2017
; Atari-fied by Ken Jennings
; Build for Atari using eclipse/wudsn/atasm on linux
; Source at:
; Github: https://github.com/kenjennings/C64-Breakout-for-Atari
; Google Drive: https://drive.google.com/drive/folders/0B2m-YU97EHFESGVkTXp3WUdKUGM
;===============================================================================
; Breakout: Gratuitous Eye Candy Edition -- 2017
; Written by Ken Jennings
; Build for Atari using eclipse/wudsn/atasm on linux
; Source at:
; Github: https://github.com/kenjennings/Atari-Breakout-GECE
; Google Drive: https://drive.google.com/drive/folders/
;===============================================================================

;===============================================================================
; History V 1.0
;===============================================================================
; display.asm contains all the data and supporting information 
; used for graphics display.
; See dli.asm for the code in the display list interrupts.
; See vbi.asm for the code managing animation, timers, etc.
; See screen.asm for the code managing the display in general.
;===============================================================================


;===============================================================================
; VARIOUS CONSTANTS AND LIMITS
;===============================================================================

; Let's define some useful offsets and sizes for the bricks. 
; Could become useful somewhere else.
;
BRICK_LEFT_OFFSET =   3  ; offset from normal playfield left edge to left edge of brick 
BRICK_RIGHT_OFFSET =  12 ; offset from normal playfield left edge to the right edge of first brick
BRICK_PIXEL_WIDTH =   10 ; Actual drawn pixels in brick.
BRICK_WIDTH =         11 ; including the trailing blank space separating bricks 

BRICK_TOP_OFFSET =     78  ; First scan line of top line of bricks. just a guess right now
BRICK_TOP_END_OFFSET = 82  ; Last scan line of the top line of bricks.
BRICK_BOTTOM_OFFSET =  133 ; Last scan line of bottom line of bricks.
BRICK_LINE_HEIGHT =   5    ; Actual drawn graphics scanlines.
BRICK_HEIGHT =        7    ; including the following blank lines (used when multiplying for position) 


; Playfield MIN/MAX travel areas relative to the ball.
;
MIN_PIXEL_X = PLAYFIELD_LEFT_EDGE_NORMAL+BRICK_LEFT_OFFSET
MAX_PIXEL_X = MIN_PIXEL_X+152 ; Actual last color clock of last brick.
MIN_BALL_X =  MIN_PIXEL_X ; because PM/left edge is same
MAX_BALL_X =  MAX_PIXEL_X-1 ; because ball is 2 color clocks wide

MIN_PIXEL_Y = 53 ; Top edge of the playfield.  just a guess right now.
MAX_PIXEL_Y = 230 ; bottom edge after paddle.  lose ball here.

; Ball travel when bouncing from walls and bricks will simply negate 
; the current horizontal or vertical direction.
; Ball travel when bouncing off the paddle will require lookup tables
; to manage angle (and speed changes).


; Playfield MIN/MAX travel areas relative to the Paddle.
;
; Paddle travel is only horizontal. But the conversion from paddle 
; value (potentiometer) to paddle Player on screen will have different
; tables based on wide paddle and narrow paddle sizes.
; The paddle also is allowed to travel beyond the left and right sides
; of the playfield far enough that only an edge of the paddle is 
; visible for collision on the playfield.
; The size of the paddle varied the coordinates for this.
;
; Paddle limits:
; O = Offscreen/not playfield
; X = ignored playfield 
; P = Playfield 
; T = Paddle Pixels
;
; (Normal  Left)     (Normal Right)
; OOOxxxPP           PPxxxxOOO 
; TTTTTTTT           TTTTTTTT
; MIN = Playfield left edge normal - 3
; MAX = Playfield right edge - 5
;
; (Small  Left)     (Small Right)
; OOOxxxPP           PPxxxxOOO 
;    TTTTT           TTTTT
; MIN = Playfield left edge normal
; MAX = Playfield right edge - 5
;
PADDLE_NORMAL_MIN_X = PLAYFIELD_LEFT_EDGE_NORMAL-3
PADDLE_NORMAL_MAX_X = PLAYFIELD_RIGHT_EDGE_NORMAL-5

PADDLE_SMALL_MIN_X = PLAYFIELD_LEFT_EDGE_NORMAL
PADDLE_SMALL_MAX_X = PLAYFIELD_RIGHT_EDGE_NORMAL-5

; FYI:
; PLAYFIELD_LEFT_EDGE_NORMAL  = $30 ; First/left-most color clock horizontal position
; PLAYFIELD_RIGHT_EDGE_NORMAL = $CF ; Last/right-most color clock horizontal position




;===============================================================================
; PLAYER/MISSILE BITMAP MEMORY
;===============================================================================
	*=$8000
; Using 2K boundary for single-line 
; resolution Player/Missiles
PLAYER_MISSILE_BASE = *
PMADR_MISSILE = PLAYER_MISSILE_BASE+$300
PMADR_BASE0 = PLAYER_MISSILE_BASE+$400
PMADR_BASE1 = PLAYER_MISSILE_BASE+$500
PMADR_BASE2 = PLAYER_MISSILE_BASE+$600
PMADR_BASE3 = PLAYER_MISSILE_BASE+$700

; Align to the boundary after Player/missile bitmaps
; ( *= $8800 )
	*=[*&$F800]+$0800

; Custom character set for Credit text window
CHARACTER_SET_00
	.incbin "mode3.cset"
; Mode 3 Custom character set.
; Alphas, numbers, basic punctuation.
; - ( ) . , : ; and /
; Also, infinity and Cross.
; Also artifact "FIRE"

; Character set is 1K of data, so alignment does 
; not need to be forced here.
; ( *= $8C00 )

; Custom character set for Title and Score
CHARACTER_SET_01
	.incbin "breakout.cset"
; Mode 6 custom character set
; 2x by 8 line chars for the 
; mode 6 title text:  B R E A K O U T
; and for 0 - 9
; and for ball counter

; Character set is 1/2K of data, so
; alignment does not need to be forced here.
; ( *= $8E00 )


;===============================================================================
; SCREEN MEMORY -- Directly displayed memory
;===============================================================================

; ( *= $8C00 to $8DFF )
; Real Playfield Memory:  2 pages.
; Aligning inside page boundaries means
; scrolling will only need to update the 
; LMS low byte for every line
;
BRICK_LINE0
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0000
BRICK_LINE1
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0040
BRICK_LINE2
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0080
BRICK_LINE3
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$00C0
BRICK_LINE4
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0100
BRICK_LINE5
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0140
BRICK_LINE6
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0180
BRICK_LINE7
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$01C0

; ( *= $8E00 to $8E7F )
; Memory for scrolling title
;
TITLE_LINE0
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0200
TITLE_LINE1
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0240

; ( *= $8E80 to $8EFF )
; Memory for scrolling Score 
;
SCORE_LINE0
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$0280
SCORE_LINE1
	.ds $0040 ; 64 bytes for left/right scroll. Relative +$02C0

; ( *= $8F00 to $8F3F )
; Master copies (source copied to working screen)
;
EMPTY_LINE ; 64 bytes of 0.
	.dc $0040 $00 ; 64 bytes of 0.              Relative +$0300


; ( *= $8F40 to $8F53 ) 20 bytes
; Horizontal thumper lines is same width as bricks, but it 
; has no gaps.
;
THUMPER_LINE
	.byte ~00011111, ~11111111, ~11111111, ~11111111, ~11111111 
	.byte ~11111111, ~11111111, ~11111111, ~11111111, ~11111111 
	.byte ~11111111, ~11111111, ~11111111, ~11111111, ~11111111 
	.byte ~11111111, ~11111111, ~11111111, ~11111111, ~11110000 




;===============================================================================
; NOT SCREEN MEMORY (parts copied to screen RAM)
;===============================================================================

; ( *= $8F54 to $8F67 ) 20 bytes
; 14 bricks, 11 pixels each, 154 pixels total. 
; Centered in 160 pixels.
; Bricks start at pixel 3 (counting from 0.
; Its easier to figure this out drawing it in binary...
;
BRICK_LINE_MASTER
	.byte ~00011111, ~11111011, ~11111111, ~01111111, ~11101111 ; 0, 1, 2, 3
	.byte ~11111101, ~11111111, ~10111111, ~11110111, ~11111110 ; 3, 4, 5, 6
	.byte ~11111111, ~11011111, ~11111011, ~11111111, ~01111111 ; 7, 8, 9, 10
	.byte ~11101111, ~11111101, ~11111111, ~10111111, ~11110000 ; 10, 11, 12, 13

; I want the graphics masters aligned to the start of a page.
; to insure cycling between each line does not require 
; updating a high byte for address.
	*=[*&$FF00]+$0100
	
; ( *= $9000 )  ( 160 bytes == 20 * 8) 
; Logo Picture imitating bricks.  
; Conveniently, 4 pixels/nybble per brick.
; Originally the graphic was 38 Characters wide,
; now as nybble pairs it is 19 characters wide. 
; In order to center this in the Playfield, each
; line is shifted one nybble, to center the data
; in 20 bytes.
;
; ***  ***  **** **   *  * **** *  *I***
; *  * *  * *    * *  *  * *  * *  *  * 
; *  * *  * *    *  * * *  *  * *  *  * 
; ***  ***  ***  **** ***  *  * *  *  * 
; *  * *  * *    *  * *  * *  * *  *  * 
; ** * ** * **   ** * ** * ** * ** *  **
; ** * ** * **   ** * ** * ** * ** *  **
; ***  ** * **** ** * ** * **** ****  **
;
LOGO_LINE0
	.byte $0F,$FF,$00,$FF,$F0,$0F,$FF,$F0,$FF,$00,$0F,$00,$F0,$FF,$FF,$0F,$00,$F3,$FF,$F0
LOGO_LINE1
	.byte $0F,$00,$F0,$F0,$0F,$0F,$00,$00,$F0,$F0,$0F,$00,$F0,$F0,$0F,$0F,$00,$F0,$0F,$00
LOGO_LINE2
	.byte $0F,$00,$F0,$F0,$0F,$0F,$00,$00,$F0,$0F,$0F,$0F,$00,$F0,$0F,$0F,$00,$F0,$0F,$00
LOGO_LINE3
	.byte $0F,$FF,$00,$FF,$F0,$0F,$FF,$00,$FF,$FF,$0F,$FF,$00,$F0,$0F,$0F,$00,$F0,$0F,$00
LOGO_LINE4
	.byte $0F,$00,$F0,$F0,$0F,$0F,$00,$00,$F0,$0F,$0F,$00,$F0,$F0,$0F,$0F,$00,$F0,$0F,$00
LOGO_LINE5
	.byte $0F,$F0,$F0,$FF,$0F,$0F,$F0,$00,$FF,$0F,$0F,$F0,$F0,$FF,$0F,$0F,$F0,$F0,$0F,$F0
LOGO_LINE6
	.byte $0F,$F0,$F0,$FF,$0F,$0F,$F0,$00,$FF,$0F,$0F,$F0,$F0,$FF,$0F,$0F,$F0,$F0,$0F,$F0
LOGO_LINE7
	.byte $0F,$FF,$00,$FF,$0F,$0F,$FF,$F0,$FF,$0F,$0F,$F0,$F0,$FF,$FF,$0F,$FF,$F0,$0F,$F0


; I want the graphics masters aligned to the start of a page.
; to insure cycling between each line does not require 
; updating a high byte for address.
	*=[*&$FF00]+$0100

; ( *= $9100 )  ( 160 bytes == 16 * 8)

; Game Over Picture imitating bricks.  3 pixels per brick,
; because it would not fit with 4 pixels per block.  At 4 pixels
; per brick the text would be 42 blocks which is 168 pixels and 
; the limit is 160 pixels in this mode.  
;
; This is redrawn and reencoded. Converting the picture 
; blocks to 000 or 111 bits worked well, so the representation 
; here is bit format. This is now 3 pixels * 42 block
; which is 126 pixels. Two additional 0 bits added to 
; center this in 128 pixels. Graphics length is 16 bytes.
; two 0 bytes added to the beginning and end of each line
; to center this in 20 bytes.
; 
; **** **   *   * ****   **** *  * **** *** 
; *    * *  ** ** *      *  * *  * *    *  *
; *    *  * * * * *      *  * *  * *    *  *
; * ** **** *   * ***    *  * *  * ***  *** 
; *  * *  * *   * *      *  * *  * *    *  *
; ** * ** * **  * **     ** * ** * **   ** *
; ** * ** * **  * **     ** *  * * **   ** *
; ***  ** * **  * ****   ****   ** **** ** *
;

GAMEOVER_LINE0
	.byte $00,$00,~01111111,~11111000,~11111100,~00000001,~11000000,~00011100,~01111111,~11111000,~00000011,~11111111,~11000111,~00000011,~10001111,~11111111,~00011111,~11110000,$00,$00
GAMEOVER_LINE1
	.byte $00,$00,~01110000,~00000000,~11100011,~10000001,~11111000,~11111100,~01110000,~00000000,~00000011,~10000001,~11000111,~00000011,~10001110,~00000000,~00011100,~00001110,$00,$00
GAMEOVER_LINE2
	.byte $00,$00,~01110000,~00000000,~11100000,~01110001,~11000111,~00011100,~01110000,~00000000,~00000011,~10000001,~11000111,~00000011,~10001110,~00000000,~00011100,~00001110,$00,$00
GAMEOVER_LINE3
	.byte $00,$00,~01110001,~11111000,~11111111,~11110001,~11000000,~00011100,~01111111,~11000000,~00000011,~10000001,~11000111,~00000011,~10001111,~11111000,~00011111,~11110000,$00,$00
GAMEOVER_LINE4
	.byte $00,$00,~01110000,~00111000,~11100000,~01110001,~11000000,~00011100,~01110000,~00000000,~00000011,~10000001,~11000111,~00000011,~10001110,~00000000,~00011100,~00001110,$00,$00
GAMEOVER_LINE5
	.byte $00,$00,~01111110,~00111000,~11111100,~01110001,~11111000,~00011100,~01111110,~00000000,~00000011,~11110001,~11000111,~11100011,~10001111,~11000000,~00011111,~10001110,$00,$00
GAMEOVER_LINE6
	.byte $00,$00,~01111110,~00111000,~11111100,~01110001,~11111000,~00011100,~01111110,~00000000,~00000011,~11110001,~11000000,~11100011,~10001111,~11000000,~00011111,~10001110,$00,$00
GAMEOVER_LINE7
	.byte $00,$00,~01111111,~11000000,~11111100,~01110001,~11111000,~00011100,~01111111,~11111000,~00000011,~11111111,~11000000,~00011111,~10001111,~11111111,~00011111,~10001110,$00,$00


; I want the Display List Subroutines to start aligned 
; to a page for the same reason -- This gives them all 
; the same address high byte, so only the low byte
; of the address needs to be changed on JMP instructions
; to target a different subroutine.
	*=[*&$FF00]+$0100
	
; ( *= $9200 to ??????????????$91AC )  (3 * 15 == 45 bytes) 

; Title Frames for coarse scrolling
;
TITLE_FRAME0
; Scan line 9-16,    screen lines 2-9,      Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 17-24,   screen lines 10-17,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 25-32,   screen lines 18-25,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word TITLE_LINE0+20 ; Text is at +22.  HSCROLL=4 to center text
; Scan line 33-40,   screen lines 26-33,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word TITLE_LINE1+20
; Scan line 41,      screen lines 34,       8 (1) blank lines, No scrolling -- sacrifice line
	.byte DL_BLANK_8|DL_DLI ; DLI for Horizontal Thumper Bumper
; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_TITLE_RTS
	
TITLE_FRAME1
; Scan line 9-16,    screen lines 2-9,      Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 17-24,   screen lines 10-17,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word TITLE_LINE0+20
; Scan line 25-32,   screen lines 18-25,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word TITLE_LINE1+20
; Scan line 33-40,   screen lines 26-33,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 41,      screen lines 34,       8 (1) blank lines, No scrolling -- sacrifice line
	.byte DL_BLANK_8|DL_DLI ; DLI for Horizontal Thumper Bumper
; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_TITLE_RTS

TITLE_FRAME2
; Scan line 9-16,    screen lines 2-9,      Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word TITLE_LINE0+20
; Scan line 17-24,   screen lines 10-17,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word TITLE_LINE1+20
; Scan line 25-32,   screen lines 18-25,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 33-40,   screen lines 26-33,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 41,      screen lines 34,       8 (1) blank lines, No scrolling -- sacrifice line
	.byte DL_BLANK_8|DL_DLI ; DLI for Horizontal Thumper Bumper
; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_TITLE_RTS

TITLE_FRAME3
; Scan line 9-16,    screen lines 2-9,      Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word TITLE_LINE1+20
; Scan line 17-24,   screen lines 10-17,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 25-32,   screen lines 18-25,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 33-40,   screen lines 26-33,    Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word EMPTY_LINE
; Scan line 41,      screen lines 34,       8 (1) blank lines, No scrolling -- sacrifice line
	.byte DL_BLANK_8|DL_DLI ; DLI for Horizontal Thumper Bumper
; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_TITLE_RTS

TITLE_FRAME_EMPTY
; Scan line 9-16,    screen lines 2-9,      Eight blank lines
	.byte DL_BLANK_8
; Scan line 17-24,   screen lines 10-17,    Eight blank lines
	.byte DL_BLANK_8
; Scan line 25-32,   screen lines 18-25,    Eight blank lines
	.byte DL_BLANK_8
; Scan line 33-40,   screen lines 26-33,    Eight blank lines
	.byte DL_BLANK_8
; Scan line 41,      screen lines 34,       1 blank lines, (mimic the scrolling sacrifice)
	.byte DL_BLANK_1|DL_DLI ; DLI for Horizontal Thumper Bumper
; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_TITLE_RTS



; ( *= $92xx to ????????$92xx )  ( 43 bytes ) 
; Bumper Frames for animating horizontal bumper at top of screen
;
; Scan lines 42-52,  screen line 35-45,     11 various blank and graphics lines in routine

; idle state waiting for impact.  Line is visible when ball gets near.
THUMPER_FRAME_WAIT 
	.byte DL_BLANK_8      ;    8 lines
	.byte DL_BLANK_2      ; +  2 lines
	.byte DL_MAP_C|DL_LMS ; +  1 lines
	.word THUMPER_LINE
	;                    ==== 11 lines
	; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_THUMPER_RTS

THUMPER_FRAME0
	.byte DL_BLANK_8 ;    8 lines
	.byte DL_BLANK_3 ; +  3 lines 
	;               ==== 11 lines
	; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_THUMPER_RTS

THUMPER_FRAME1
	.byte DL_BLANK_7      ;    7 lines
	.byte DL_MAP_9|DL_LMS ; +  4 lines
	.word THUMPER_LINE
	;                    ==== 11 lines
	; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_THUMPER_RTS

THUMPER_FRAME2
	.byte DL_BLANK_6      ;    6 lines
	.byte DL_MAP_B|DL_LMS ; +  2 lines
	.word THUMPER_LINE
	.byte DL_BLANK_3      ;    3 lines
	;                    ==== 11 lines
	; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_THUMPER_RTS

THUMPER_FRAME3
	.byte DL_BLANK_5      ;    5 lines
	.byte DL_MAP_C|DL_LMS ; +  1 lines
	.word THUMPER_LINE
	.byte DL_BLANK_5      ;    5 lines
	;                    ==== 11 lines
	; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_THUMPER_RTS

THUMPER_FRAME4
	.byte DL_BLANK_2      ;    2 lines
	.byte DL_MAP_C|DL_LMS ; +  1 lines
	.word THUMPER_LINE
	.byte DL_BLANK_8      ;    8 lines
	;                    ==== 11 lines
	; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_THUMPER_RTS

THUMPER_FRAME5
	.byte DL_MAP_C|DL_LMS ; +  1 lines
	.word THUMPER_LINE
	.byte DL_BLANK_5      ;    5 lines
	.byte DL_BLANK_5      ;    5 lines
	;                    ==== 11 lines
	; Return to main display list
	.byte DL_JUMP
	.word DISPLAY_LIST_THUMPER_RTS


	

; A VBI sets initial values:
; HPOS and SIZE for all Players and missiles.
; HSCROL and VSCROL.
; By default CHBAS and inital COLPF/COLPM are already handled.

;===============================================================================
; DISPLAY DESIGN 
;===============================================================================

;-------------------------------------------
; TITLE SECTION: NARROW
; Player 0 == Flying text.
; Mode 6 color text for title.
; Color 0 == Text
; Color 1 == Text
; Color 2 == Text
; Color 3 == Text
;-------------------------------------------
; COLPM0, COLPF0, COLPF1, COLPF2, COLPF3
; HPOSP0
; SIZEP0
; CHBASE
; VSCROLL, HSCROLL (for centering)
;-------------------------------------------
	; Scan line 8,       screen line 1,         One blank scan line

; Jump to Title Scroll frame...

	; Scan lines 9-41,   screen lines 2-34,     4 lines of Mode 6 text for vertical scrolling title 

; Jump back to Main list.

;-------------------------------------------
; THUMPER BUMPER SECTION: NORMAL
; color 1 = horizontal/top bumper.
; Player 3 = Left bumper 
; Missile (5th Player) = Right Bumper
;-------------------------------------------
; COLPF0, COLPM0, COLPF3
; HPOSP3, HPOSM0
; SIZEP3, SIZEM0
;-------------------------------------------

	; Scan line 42,      screen line 35,         One blank scan lines

; Jump to Horizontal Thumper bumper

	; Scan lines 43-53,  screen line 36-46,     11 various blank and graphics lines in routine

; Jump back to Main list.

;-------------------------------------------
; PLAYFIELD SECTION: NORMAL
; color 1 = bricks
; Player 0 = Ball 
; Player 1 = boom-o-matic animation 1
; Player 2 = boom-o-matic animation 1
;    and already set earlier:
; Player 3 = Left bumper 
; Missile (5th Player) = Right Bumper
;-------------------------------------------
; COLPF0, COLPM0, COLPM1, COLPM2
; HPOSP0, HPOSP1, HPOSP2
; SIZEP0, SIZEP1, SIZEP2
; VSCROLL
;-------------------------------------------

; Blanks above bricks.

	; Scan line 54-77,   screen line 47-70,     24 blank lines

; Bricks...
	; Scan line 78-82,   screen line 71-75,     5 Mode C lines, repeated
	; Scan line 83-84    screen line 76-77,     Two blank scan lines, No scrolling -- sacrifice line
	; ...
	; Brick line 8
	; Scan line 127-131, screen line 120-124,   5 Mode C lines, repeated
	; Scan line 132-133, screen line 125-126,   Two blank scan lines, No scrolling -- sacrifice line

; After Bricks.
	; Scan line 134-141, screen line 127-134,   Eight blank scan lines

;-------------------------------------------
; CREDITS SECTION: NARROW
; Color 2 = text
; Color 3 = text background
;    and already set earlier:
; Player 0 = Ball 
; Player 3 = Left bumper 
; Missile (5th Player) = Right Bumper
;-------------------------------------------
; COLPF1, COLPF2
; CHBASE
; VSCROLL, HSCROLL
;-------------------------------------------

; Credits
	; Scan line 142-151, screen line 135-144,   10 Lines Mode 3
	; Scan line 152-161, screen line 145-154,   10 Lines Mode 3
	; Scan line 162-171, screen line 155-164,   10 Lines Mode 3
	; Scan line 172-181, screen line 165-174,   10 Lines Mode 3
	; Scan line 182-191, screen line 175-184,   10 Lines Mode 3
	; Scan line 192-201, screen line 185-194,   10 Lines Mode 3
	; Scan line 202-202, screen line 195-195,   10 (1) Lines Mode 3 ; scrolling sacrifice
	
	; Scan line 203-204, screen line 196-197,   Two blank scan lines

;-------------------------------------------
; PADDLE SECTION: NARROW
; Player 1 = Paddle
; Player 2 = Paddle
; Player 3 = Paddle
;    and already set earlier:
; Player 0 = Ball 
;-------------------------------------------
; COLPM1, COLPM2, COLPM3
;-------------------------------------------

; Paddle
	; Scan line 205-212, screen line 198-205,   Eight blank scan lines (top 4 are paddle)	

;-------------------------------------------
; TITLE SECTION: NORMAL
; Player 0 == Talking ball text.
; Player 1 == Talking ball text.
; Player 2 == Talking ball text.
; Player 3 == Talking Ball Text.
; Player 5 == Talking Ball text.
; Mode 6 color text for ball list and score.
; Color 1  == Talking Balls. 
; Color 2  == score
; Color 3  == score
;-------------------------------------------
; COLPM0, COLPF0, COLPF1, COLPF2, COLPF3
; HPOSP0, HPOSP1, HPOSP2, HPOSP3, 
; HPOSM0, HPOSM1, HPOSM2, HPOSM3 
; SIZEP0, SIZEP1, SIZEP2, SIZEP3, SIZEM
; CHBASE
; HSCROLL
;-------------------------------------------
; Ball counter and score
	; Scan line 213-220, screen line 206-213,   Mode 6 text, scrolling
	; Scan line 221-228, screen line 214-221,   Mode 6 text, scrolling

	; Scan line 229-229, screen line 222-222,   One blank scan line
	
; Jump Vertical Blank.



;===============================================================================
; Forcing the Display list to a 1K boundary 
; is mild overkill.  Display Lists even as funky
; as this one are fairly short. 
; Alignment to the next Page is sufficient insurance 
; preventing the display list from crossing over 
; the next 1K boundary.

	*=[*&$FF00]+$0100

	; ( *= $9300 to  ) 

DISPLAY_LIST 
 
	; Scan line 8,       screen line 1,         One blank scan line
	.byte DL_BLANK_1|DL_DLI 
	; VBI: Set Narrow screen, HSCROLL=4 (to center text), VSCROLL, 
	;      HPOS0 and SIZE0 for title.  PRIOR=All P/M on top.
	; DLI1: hkernel for COLPF and COLPM color bars in the text.

	.byte DL_JUMP		    ; JMP to Title scrolling display list "routine"
DISPLAY_LIST_TITLE_VECTOR   ; Low byte of coarse scroll frame
	.word TITLE_FRAME_EMPTY ; 

	; DLI2: Occurred as the last line of the Title SCroll section.
	; Set Normal Screen, VSCROLL=0, COLPF0 for horizontal bumper.
	; Set PRIOR for Fifth Player.
	; Set HPOSM0/HPOSM1, COLPF3 SIZEM for left and right Thumper-bumpers.
	; set HITCLR for Playfield.
	; Set HPOSP0/P1/P2, COLPM0/PM1/PM2, SIZEP0/P1/P2 for top row Boom objects.
	
DISPLAY_LIST_TITLE_RTS ; return destination for title scrolling "routine"
	; Scan line 42,      screen line 35,         One blank scan lines
	.byte DL_BLANK_1 ; I am uncomfortable with a JMP going to a JMP.
	; Also, the blank line provides time for clean DLI.
		
	; Scan lines 43-53,  screen line 36-46,     11 various blank and graphics lines in routine
	.byte DL_JUMP	        ; Jump to horizontal thumper animation frame
DISPLAY_LIST_THUMPER_VECTOR ; remember this -- update low byte to change frames
	.word THUMPER_FRAME0
	
	; Note DLI started before thumper-bumper Display Lists for 
	; P/M HPOS, COLPM, SIZE and HITCLR
	; Also, this DLI ends by setting HPOS and COLPM for the BOOM 
	; objects in the top row of bricks. 

DISPLAY_LIST_THUMPER_RTS ; destination for animation routine return.
	; Top of Playfield is empty above the bricks. 
	; Scan line 54-77,   screen line 47-70,     24 blank lines
	.byte DL_BLANK_8
	.byte DL_BLANK_8
	.byte DL_BLANK_8|DL_DLI
	; DLI3: Hkernel 8 times....
	;      Set HSCROLL for line, VSCROLL = 5, then Set COLPF0 for 5 lines.
	;      Reset VScroll to 1 (allowing 2 blank lines.)
	;      Set P/M Boom objects, HPOS, COLPM, SIZE
	;      Repeat HKernel.

	; Define 8 rows of Bricks.  
	; Each is 5 lines of mode C graphics, plus 2 blank line.
	; The 5 rows of graphics are defined by using the VSCROL
	; exploit to expand one line of mode C into five lines.

	; Block line 1
	; Scan line 78-82,   screen line 71-75,     5 Mode C lines, repeated
	; Scan line 83-84    screen line 76-77,     Two blank scan lines, No scrolling -- sacrifice line
	; ...
	; Block line 8
	; Scan line 127-131, screen line 120-124,   5 Mode C lines, repeated
	; Scan line 132-133, screen line 125-126,   Two blank scan lines, No scrolling -- sacrifice line
BRICK_BASE
	; BRICK_BASE+1, +5, +9, +13, +17, +21, +25, +29 is low byte of row.
	; Only this byte should be needed for scrolling each row.
	entry .= 0
	.rept 8 ; repeat for 8 lines of bricks (56 scan lines) 
	; scan line +0 to +4  -- 5 scan lines of mode C copied/extended
	.byte DL_MAP_C|DL_LMS|DL_VSCROLL|DL_HSCROLL
	.word BRICK_LINE0+[entry*$40] ; not immediately offset into middle of graphics line
	; one blank scan line
	.byte DL_BLANK_2
	entry .= entry+1 ; next entry in table.
	.endr
	; HKernel ends:
	; set Narrow screen, COLPF2, VSCROLL, COLPF1 for scrolling credit/prompt window.
	; Collect HITCLR values for analysis of bricks .  Reset HITCLR.
	
	; a scrolling window for messages and credits.  
	; This is 8 blank lines +  8 * 10 scan lines plus 7 blank lines.
	; These are ANTIC Mode 3 lines so each is 10 scan lines tall.

	; Scan line 134-141, screen line 127-134,   Eight blank scan lines
	.byte DL_BLANK_8|DL_DLI   
	; DLI4: Set Narrow Width, VSCROLL for window. Fade text in.  

	; Scan line 142-151, screen line 135-144,   10 Lines Mode 3
	.byte DL_TEXT_3|DL_LMS|DL_VSCROLL
DISPLAY_LIST_TEXT_SCROLL_0
	.word CENTER_SCROLL_00

	; Scan line 152-161, screen line 145-154,   10 Lines Mode 3
	.byte DL_TEXT_3|DL_LMS|DL_VSCROLL
DISPLAY_LIST_TEXT_SCROLL_1
	.word CENTER_SCROLL_00

	; Scan line 162-171, screen line 155-164,   10 Lines Mode 3
	.byte DL_TEXT_3|DL_LMS|DL_VSCROLL
DISPLAY_LIST_TEXT_SCROLL_2
	.word CENTER_SCROLL_00

	; Scan line 172-181, screen line 165-174,   10 Lines Mode 3
	.byte DL_TEXT_3|DL_LMS|DL_VSCROLL
DISPLAY_LIST_TEXT_SCROLL_3
	.word CENTER_SCROLL_00

	; Scan line 182-191, screen line 175-184,   10 Lines Mode 3
	.byte DL_TEXT_3|DL_LMS|DL_DLI|DL_VSCROLL
	; DLI5: text fade out last 8 lines	
DISPLAY_LIST_TEXT_SCROLL_5
	.word CENTER_SCROLL_00

	; Scan line 192-201, screen line 185-194,   10 Lines Mode 3
	.byte DL_TEXT_3|DL_LMS|DL_VSCROLL
DISPLAY_LIST_TEXT_SCROLL_6
	.word CENTER_SCROLL_00

	; Scan line 202-202, screen line 195-195,   10 (1) Lines Mode 3 ; scrolling sacrifice
	.byte DL_TEXT_3|DL_LMS
DISPLAY_LIST_TEXT_SCROLL_7
	.word CENTER_SCROLL_00
	
	; Scan line 203-204, screen line 196-197,   Two blank scan lines 	
	.byte DL_BLANK_8|DL_DLI; 
	
	; DLI6:
	; Sets Paddle specs. PMWIDTH, HPOS, HKernel changes colors for paddle.
	; Then set HSCROLL for Scores.  

	; Scan line 205-212, screen line 198-205,   Eight blank scan lines (top 4 are paddle)	
	.byte DL_BLANK_8|DL_DLI; 
	
	; The paddle occurs here. (205-208)
	; Small gap (209-212) afterwards is area for ball to "fall" into for miss.
	
	; DLI7:
	; Set Normal Width, HSCROLL for Scores, colors for ball counters.
	
	; Next is the score lines. Like to use 12 scan lines for the text.
	; Mode 6 seems like fun, again. Center the 12 lines of custom 
	; character set in the middle of these 16.
	; Scan line 213-220, screen line 206-213,   Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_HSCROLL
	.word SCORE_LINE0
	; Scan line 221-228, screen line 214-221,   Mode 6 text, scrolling
	.byte DL_TEXT_6|DL_LMS|DL_HSCROLL
	.word SCORE_LINE1

	; Scan line 229-229, screen line 222-222,   One blank scan line
	; Blank line.  Make sure DLI ends before VBI starts
	.byte DL_BLANK_1
	
	; Finito.
	.byte DL_JUMP_VB
	.word DISPLAY_LIST


;===============================================================================
; Forcing alignment to the next Page for the vertically 
; scrolled credits and prompt text. Since all the lines 
; are 32-bytes for the narrow screen width if it gets
; near a 4K boundary it will be properly aligned.

	*=[*&$FF00]+$0100

; ( *= $9400 to  ) 

; Center scrolling window text.  Each line 32 bytes.  
; Mode 3 lines.  Custom character set.
; Alphas, numbers, basic punctuation.
; - ( . , : / ;
; Also, infinity and Cross.
; Also artifact "FIRE"
; Also custom 2x by 8 chars for the 
; mode 6 title text:  B R E A K O U T

; Common lines for center scroll
CENTER_SCROLL_00	.sbyte "                                " 	
CENTER_SCROLL_01	.sbyte "          - - + - -             " 

; SubTitle on Logo Screen.
SUBTITLE_01	.sbyte "        B R E A K O U T         " ; 
SUBTITLE_02	.sbyte "           Gratuitous           " 
SUBTITLE_03	.sbyte "           Eye-Candy            "
SUBTITLE_04	.sbyte "            Edition             " ; 

; Prompts for the center scrolling window.
PROMPT_LINES
	;                                         ; repeat common 00 for lines to empty the scroll window
PROMPT_01	.sbyte "  Press   F I R E   to continue " ; 1
	;                                         ; repeat common 00 for lines to empty the scroll window

; Credits for center scrolling window.  
CREDIT_LINES
	;                                         ; repeat common 00 for lines to empty the scroll window
CREDIT_01	.sbyte "Breakout Arcade                 " ; 1
CREDIT_02	.sbyte "-- ( 1976 )                     " ; 2
	;                                         ; repeat common 00
CREDIT_03	.sbyte "Conceptualized by Nolan Bushnell" ; 3
CREDIT_04	.sbyte "and Steve Bristow.              " ; 4
CREDIT_05	.sbyte "Built by Steve Wozniak.         " ; 5
CREDIT_06	.sbyte "https://en.wikipedia.org/...    " ; 6
CREDIT_07	.sbyte "...wiki/Breakout_(video_game)   " ; 7
	;                                         ; repeat common 00
	;            - - + - -                    ; repeat common 01
	;                                         ; repeat common 00
CREDIT_08	.sbyte "C64 Breakout clone              " ; 8 C64 Breakout clone
CREDIT_09	.sbyte "-- ( 2016 )                     " ; 9
	;                                         ; repeat common 00
CREDIT_10	.sbyte "Written by Darren Du Vall       " ; 10
CREDIT_11	.sbyte "aka Sausage-Toes                " ; 11
CREDIT_12	.sbyte "Source at:                      " ; 12 source at
CREDIT_13	.sbyte "Github: https://github.com/     " ; 13 github
CREDIT_14	.sbyte "Sausage-Toes/C64_Breakout       " ; 14
	;                                         ; repeat common 00
	;            - - + - -                    ; repeat common 01
	;                                         ; repeat common 00
	;       .sbyte "C64 Breakout clone              " ; repeat 8 C64 Breakout clone
CREDIT_15	.sbyte "ported to Atari 8-bit           " ; 15
CREDIT_16	.sbyte -- ( 2017 )                      " ; 16 -- 2017
	;                                         ; repeat common 00
CREDIT_17	.sbyte "Atari-fied by Ken Jennings      " ; 17
CREDIT_18	.sbyte "Built for Atari using eclipse,  " ; 18 built 1
CREDIT_19	.sbyte "wudsn, and atasm on linux.      " ; 19 built 2
	;       .sbyte "Source at:                      " ; repeat 12 source at
	;       .sbyte "Github: https://github.com/     " ; repeat 13 github
CREDIT_20	.sbyte "kenjennings/C64-Breakout-...    " ; 20
CREDIT_21	.sbyte "...for-Atari                    " ; 21 for atari
CREDIT_22	.sbyte "Google Drive:                   " ; 22 google drive 1
CREDIT_23	.sbyte "https://drive.google.com/...    " ; 23 google drive 2
CREDIT_24	.sbyte "...drive/folders/...            " ; 24 google drive 3
CREDIT_25	.sbyte "...0B2m-YU97EHFESGVkTXp3WUdKUGM " ; 25
	;                                         ; repeat common 00
	;            - - + - -                    ; repeat common 01
	;                                         ; repeat common 00
CREDIT_26	.sbyte "Breakout:                       " ; 26
CREDIT_27	.sbyte "Gratuitous Eye Candy Edition    " ; 27
	;       .sbyte "-- ( 2017 )                     " ; repeat 16 -- 2017
	;                                         ; repeat common 00
CREDIT_28	.sbyte "Written by Ken Jennings         " ; 28
	;       .sbyte "Built for Atari using eclipse,  " ; repeat 18 built 1
	;       .sbyte "wudsn, and atasm on linux.      " ; repeat 19 built 1
	;       .sbyte "Source at:                      " ; repeat 12 source at
	;       .sbyte "Github: https://github.com/     " ; repeat 13 github
CREDIT_29	.sbyte "kenjennings/Breakout-GECE-...   " ; 29
	;       .sbyte "...for-Atari                    " ; repeat 21 for Atari
	;       .sbyte "Google Drive:                   " ; repeat 22 google drive 1
	;       .sbyte "https://drive.google.com/...    " ; repeat 23 google drive 2
	;       .sbyte "...drive/folders/...            " ; repeat 24 google drive 3
CREDIT_30	.sbyte "...                             " ; 30
	;                                         ; repeat common 00
	;            - - + - -                    ; repeat common 01
	;                                         ; repeat common 00
CREDIT_31	.sbyte "Ken Jennings                    " ; 31
CREDIT_32	.sbyte "-- ( 1966 )                     " ; 32
	;                                         ; repeat common 00
CREDIT_33	.sbyte "Produced by Mr and Mrs Jennings " ; 33
	;                                         ; repeat common 00
CREDIT_34	.sbyte "               ;-)              " ; 34	
	;                                         ; repeat common 00
CREDIT_35	.sbyte "in an amazing and wonderful     " ; 35
CREDIT_36	.sbyte "universe made by an infinite God" ; 36
CREDIT_37	.sbyte "-- ( infinity )                       " ; 37
	;                                         ; repeat common 00
CREDIT_38	.sbyte "   The Son is the radiance of   " ; 38
CREDIT_39	.sbyte "    GOD's glory and the exact   " ; 39
CREDIT_40	.sbyte "  representation of his being,  " ; 40 
CREDIT_41	.sbyte "  sustaining all things by his  " ; 41
CREDIT_42	.sbyte "  powerful word. After he had   " ; 42
CREDIT_43	.sbyte " provided purification for sins," ; 43
CREDIT_44	.sbyte "  he sat down at the right hand " ; 44
CREDIT_45	.sbyte "    of the Majesty in heaven.   " ; 45
CREDIT_46	.sbyte "-- Hebrews 1:3                  " ; 46
	;                                         ; repeat common 00
	;            - - + - -                    ; repeat common 01
	; Repeat 00 to scroll credits off....5, 6, 7 lines?



; Game Modes.  
; Different sections of the screen are operating at different times.
; 0 = Main title screen.
;     SCrolling title text is OFF.
;     Thumper Bumpers are OFF.  (But they would be off by default over time).
;     BALL is OFF
;     Paddle is off.
; 

;===============================================================================
; ALL THE MOVING PARTS
;===============================================================================
; Tables of things previously declared.
; Tables that don't need alignment.
; Other variables for controlling action/animation and interaction 
; between the display, the VBI, and MAIN.

; Display List Interrupts, Internal Shadow data, and other information.
; Most of this is managed and indexed by the Vertical Blank Interrupt.
; The Display List and Display List Interrupt simply show it as presented.

; Title: Animated text fly-in, the color gradient cycling and scrolling  
; text at top of screen operates during game play, and the pause screen.
; This is Off for Game Over, and Title screens
;
; Two second delay (120) frames for no activity.
; Text flies in from the right 2 color clocks per frame.
; Four second delay (240) frames for viewing.
; Vscroll up 1 scanline until all lines gone.
; 
TITLE_STOP_GO .byte 0 ; set by mainline to indicate title is working or not.
; 0 = stop.
; 1 = go.  (after main routine has initialized restart).

TITLE_PLAYING .byte 0 ; flag indicates title animation stage in progress. 
; 0 == not running -- title lines in 0/empty state. 
; 1 == clear. no movement. (Running a couple second of delay.)
; 2 == Text fly-in is in progress. 
; 3 == pause for public admiration. 
; 4 == Text  VSCROLL to top of screen in progress.  return to 0 state.

TITLE_TIMER .byte 0 ; set by Title handler for pauses.


TITLE_HPOSP0 
	.byte 0 ; Current P/M position of fly-in letter. or 0 if no letter.

TITLE_SIZEP0 
	.byte PM_SIZE_NORMAL ; current size of Player 0

TITLE_GPRIOR 
	.byte 1 ; Current P/M Priority in title. 

TITLE_VSCROLL .byte 0 ; current fine scroll position. (0 to 7)
TITLE_CSCROLL .byte 0 ; current coarse scroll position. (0 to 4)


; Display List -- Title Scrolling coarse scroll conditions.
;
TITLE_FRAME_TABLE
	.byte <TITLE_FRAME_EMPTY
	.byte <TITLE_FRAME0
	.byte <TITLE_FRAME1
	.byte <TITLE_FRAME2
	.byte <TITLE_FRAME3


TITLE_CURRENT_FLYIN 
	.byte 0 ; current index (0 to 7) into tables for visible stuff in table below.

TITLE_PM_IMAGE_LIST ; beginning offset into character set to copy image data to Player
	.byte $08,$18,$28,$38,$48,$58,$68,$78

TITLE_PM_TARGET_LIST ; Player target HPOS
	entry .= 0
	.rept 8 ; repeat for 8 characters
	.byte >[PLAYFIELD_LEFT_EDGE_NARROW+4+entry]
	entry .= entry+16 ; next entry in table.
	.endr
	
TITLE_CHAR_LIST ; Screen byte of first (top) half of each character 
	.byte $01,$43,$85,$C7,$09,$4B,$8D,$CF ; B R E A K O U T custom chars in different COLPF values

TITLE_PM_CHAR_POS ; Title Line offset for each character
	.byte 22,24,26,28,30,32,34,36 

; The following tables vertically scroll the title up 
; off the screen.  It has step by step values for 
; VSCROLL, coarse scroll (in display list), WSYNC offset,
; Wsync color, flag to double-increment the color counter.
; While the VSCROLL is always 0,1,2,3,4,5,6,7, it is easier
; to just read from table and store rather than checking 
; for 8, then resetting, and coarse scrolling.
; 32 steps for each.
TITLE_VSCROLL_TABLE
	.byte 0,1,2,3,4,5,6,7,0,1,2,3,4,5,6,7,0,1,2,3,4,5,6,7,0,1,2,3,4,5,6,7

TITLE_CSCROLL_TABLE ; index into TITLE_FRAME_TABLE
	.byte 1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4

TITLE_WSYNC_OFFSET_TABLE ; DLI: Skip lines before starting color bar. 
	.byte 20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0,0,0,0,0,0,0,0,0,0,0,0

TITLE_WSYNC_COLOR_TABLE ; DLI: How many lines to read from color tables.
	.byte 12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,11,10,9,8,7,6,5,4,3,2,1

TITLE_COLOR_COUNTER_PLUS ; Flag to double-increment COLOR_COUNTER when losing lines.
	.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

TITLE_SCROLL_COUNTER ; index into the tables above. 0 to 32
	.byte 0

	
; DLI parts.
TITLE_WSYNC_OFFSET  .byte 20 ; Number of lines to drop through before color draw

TITLE_WSYNC_COLOR   .byte 12 ; Number of lines to do color draw
TITLE_WSYNC_COLOR_TEMP
TITLE_COLOR_COUNTER .byte 0  ; Index into color table

TITLE_DLI_PMCOLOR   .byte 0

TITLE_DLI_PMCOLOR_TABLE ; which text color to use for P/M. referenced by TITLE_CURRENT_FLYIN.
	.byte 0,1,2,3,0,1,2,3

; Which COLPF table should the flying title 
; character as COLPM0 use for color?
; The VBI will assign this to a Page 0 
; location, so the DLI can use indirect 
; address to set the color for the Player.	
TITLE_DLI_COLPM_TABLE_LO
	.byte <TITLE_COLPF0
	.byte <TITLE_COLPF1
	.byte <TITLE_COLPF2
	.byte <TITLE_COLPF3
	
TITLE_DLI_COLPM_TABLE_HI
	.byte >TITLE_COLPF0
	.byte >TITLE_COLPF1
	.byte >TITLE_COLPF2
	.byte >TITLE_COLPF3

; Page 0 location is a pointer to one 
; of the COLPF tables.
ZTITLE_COLPM0=ZEROPAGE_POINTER_9 


TITLE_COLPF0 ; "Red"
	.byte COLOR_PINK+$00 ; 0 ; First 12 positions are start
	.byte COLOR_PINK+$02 ; 1
	.byte COLOR_PINK+$04 ; 2
	.byte COLOR_PINK+$06 ; 3
	.byte COLOR_PINK+$08 ; 4
	.byte COLOR_PINK+$0a ; 5
	.byte COLOR_PINK+$0c ; 6
	.byte COLOR_PINK+$0e ; 7
	.byte COLOR_PINK+$0c ; 8
	.byte COLOR_PINK+$0a ; 9 
	.byte COLOR_PINK+$08 ; 10
	.byte COLOR_PINK+$06 ; 11
	.byte COLOR_PINK+$04 ;(12)
	.byte COLOR_PINK+$02 ;(13)
	.byte COLOR_PINK+$00 ;(14)
	.byte COLOR_PINK+$00 ;(15)
	.byte COLOR_PINK+$02 ;(16)
	.byte COLOR_PINK+$02 ;(17)
	.byte COLOR_PINK+$04 ;(18)
	.byte COLOR_PINK+$04 ;(19)
	.byte COLOR_PINK+$06 ;(20)
	.byte COLOR_PINK+$06 ;(21)
	.byte COLOR_PINK+$08 ;(22)
	.byte COLOR_PINK+$08 ;(23)
	.byte COLOR_PINK+$0a ;(24) 
	.byte COLOR_PINK+$0a ;(25) 
	.byte COLOR_PINK+$0c ;(26) 
	.byte COLOR_PINK+$0c ;(27) 
	.byte COLOR_PINK+$0e ;(28) 
	.byte COLOR_PINK+$0e ;(29) 
	.byte COLOR_PINK+$0c ;(30) 
	.byte COLOR_PINK+$0c ;(31) 
	.byte COLOR_PINK+$0a ;(32) 
	.byte COLOR_PINK+$0a ;(33) 
	.byte COLOR_PINK+$08 ;(34) 
	.byte COLOR_PINK+$08 ;(35) 
	.byte COLOR_PINK+$06 ;(36) 
	.byte COLOR_PINK+$06 ;(37)
	.byte COLOR_PINK+$04 ;(38) 
	.byte COLOR_PINK+$04 ;(39) 
	.byte COLOR_PINK+$02 ;(40)
	.byte COLOR_PINK+$02 ;(41) 
	.byte COLOR_PINK+$00 ;(42) -- end on this index.
	.byte COLOR_PINK+$00 ; 0
	.byte COLOR_PINK+$02 ; 1
	.byte COLOR_PINK+$04 ; 2
	.byte COLOR_PINK+$06 ; 3
	.byte COLOR_PINK+$08 ; 4
	.byte COLOR_PINK+$0a ; 5
	.byte COLOR_PINK+$0c ; 6
	.byte COLOR_PINK+$0e ; 7
	.byte COLOR_PINK+$0c ; 8
	.byte COLOR_PINK+$0a ; 9 
	.byte COLOR_PINK+$08 ; 10

	

TITLE_COLPF1 ; "Orange"
	entry .= $04
	.rept 6 ; repeating for 12 bytes 4, 6, 8, a, c, e
	.byte [COLOR_RED_ORANGE+entry]
	.byte [COLOR_RED_ORANGE+entry]
	entry .= entry+2 ; next entry in table.
	.endr
	.rept 7 ; repeating for 14 bytes c, a, 8, 6, 4, 2, 0
	entry .= entry-2 ; next entry in table.
	.byte [COLOR_RED_ORANGE+entry]
	.byte [COLOR_RED_ORANGE+entry]
	.endr
	.rept 7 ; repeating for 7 bytes 2, 4, 6, 8, a, c, e
	entry .= entry+2 ; next entry in table.
	.byte [COLOR_RED_ORANGE+entry]
	.endr
	.rept 6 ; repeating for 6 bytes c, a, 8, 6, 4, 2
	entry .= entry-2 ; next entry in table.
	.byte [COLOR_RED_ORANGE+entry]
	.endr
	entry .= $00
	.rept 7 ; repeating for 14 bytes 0, 2, 4, 6, 8, a, c
	.byte [COLOR_RED_ORANGE+entry]
	.byte [COLOR_RED_ORANGE+entry]
	entry .= entry+2 ; next entry in table.
	.endr
	.byte COLOR_RED_ORANGE+$0e
; 12 + 14 + 7 + 6 + 14 + 1 == 54 == 43 color lines + 11 dups
	
	
;	.byte COLOR_RED_ORANGE+$04 ; 10
;	.byte COLOR_RED_ORANGE+$04 ; 11
;	.byte COLOR_RED_ORANGE+$06 ;(12)
;	.byte COLOR_RED_ORANGE+$06 ;(13)
;	.byte COLOR_RED_ORANGE+$08 ;(14)
;	.byte COLOR_RED_ORANGE+$08 ;(15)
;	.byte COLOR_RED_ORANGE+$0a ;(16)
;	.byte COLOR_RED_ORANGE+$0a ;(17)
;	.byte COLOR_RED_ORANGE+$0c ;(18)
;	.byte COLOR_RED_ORANGE+$0c ;(19)
;	.byte COLOR_RED_ORANGE+$0e ;(20)
;	.byte COLOR_RED_ORANGE+$0e ;(21)--
	
;	.byte COLOR_RED_ORANGE+$0c ;(22)
;	.byte COLOR_RED_ORANGE+$0c ;(23)
;	.byte COLOR_RED_ORANGE+$0a ;(24) 
;	.byte COLOR_RED_ORANGE+$0a ;(25) 
;	.byte COLOR_RED_ORANGE+$08 ;(26) 
;	.byte COLOR_RED_ORANGE+$08 ;(27) 
;	.byte COLOR_RED_ORANGE+$06 ;(28) 
;	.byte COLOR_RED_ORANGE+$06 ;(29) 
;	.byte COLOR_RED_ORANGE+$04 ;(30) 
;	.byte COLOR_RED_ORANGE+$04 ;(31) 
;	.byte COLOR_RED_ORANGE+$02 ;(32) 
;	.byte COLOR_RED_ORANGE+$02 ;(33) 
;	.byte COLOR_RED_ORANGE+$00 ;(34) 
;	.byte COLOR_RED_ORANGE+$00 ;(35)
	
;	.byte COLOR_RED_ORANGE+$02 ;(36) 
;	.byte COLOR_RED_ORANGE+$04 ;(37)
;	.byte COLOR_RED_ORANGE+$06 ;(38) 
;	.byte COLOR_RED_ORANGE+$08 ;(39) 
;	.byte COLOR_RED_ORANGE+$0a ;(40)
;	.byte COLOR_RED_ORANGE+$0c ;(41) 
;	.byte COLOR_RED_ORANGE+$0e ;(42)
	
;	.byte COLOR_RED_ORANGE+$0c ; 0
;	.byte COLOR_RED_ORANGE+$0a ; 1
;	.byte COLOR_RED_ORANGE+$08 ; 2
;	.byte COLOR_RED_ORANGE+$06 ; 3
;	.byte COLOR_RED_ORANGE+$04 ; 4
;	.byte COLOR_RED_ORANGE+$02 ; 5
	
;	.byte COLOR_RED_ORANGE+$00 ; 6
;	.byte COLOR_RED_ORANGE+$00 ; 7
;	.byte COLOR_RED_ORANGE+$02 ; 8
;	.byte COLOR_RED_ORANGE+$02 ; 9 -- end on this index.
;	.byte COLOR_RED_ORANGE+$04 ; 10  
;	.byte COLOR_RED_ORANGE+$04 ; 0 ; First 12 positions are start
;	.byte COLOR_RED_ORANGE+$06 ; 1
;	.byte COLOR_RED_ORANGE+$06 ; 2
;	.byte COLOR_RED_ORANGE+$08 ; 3
;	.byte COLOR_RED_ORANGE+$08 ; 4
;	.byte COLOR_RED_ORANGE+$0a ; 5
;	.byte COLOR_RED_ORANGE+$0a ; 6
;	.byte COLOR_RED_ORANGE+$0c ; 7
;	.byte COLOR_RED_ORANGE+$0c ; 8

;	.byte COLOR_RED_ORANGE+$0e ; 9 

; Fit of extreme laziness.   
; Just Copy/Paste sections from the top to the bottom. 
TITLE_COLPF2 ; "Green"
	.byte COLOR_GREEN+$08 ;(18)
	.byte COLOR_GREEN+$06 ;(19)
	.byte COLOR_GREEN+$04 ;(20)
	.byte COLOR_GREEN+$02 ;(21)
	.byte COLOR_GREEN+$00 ;(22)
	.byte COLOR_GREEN+$00 ;(23)
	.byte COLOR_GREEN+$02 ;(24) 
	.byte COLOR_GREEN+$02 ;(25) 
	.byte COLOR_GREEN+$04 ;(26) 
	.byte COLOR_GREEN+$04 ;(27) 
	.byte COLOR_GREEN+$06 ;(28) 
	.byte COLOR_GREEN+$06 ;(29) 
	.byte COLOR_GREEN+$08 ;(30) 
	.byte COLOR_GREEN+$08 ;(31) 
	.byte COLOR_GREEN+$0a ;(32) 
	.byte COLOR_GREEN+$0a ;(33) 
	.byte COLOR_GREEN+$0c ;(34) 
	.byte COLOR_GREEN+$0c ;(35) 
	.byte COLOR_GREEN+$0e ;(36) 
	.byte COLOR_GREEN+$0e ;(37)
	.byte COLOR_GREEN+$0c ;(38) 
	.byte COLOR_GREEN+$0c ;(39) 
	.byte COLOR_GREEN+$0a ;(40)
	.byte COLOR_GREEN+$0a ;(41) 
	.byte COLOR_GREEN+$08 ;(42) 
	.byte COLOR_GREEN+$08 ; 0
	.byte COLOR_GREEN+$06 ; 1
	.byte COLOR_GREEN+$06 ; 2
	.byte COLOR_GREEN+$04 ; 3
	.byte COLOR_GREEN+$04 ; 4
	.byte COLOR_GREEN+$02 ; 5
	.byte COLOR_GREEN+$02 ; 6
	.byte COLOR_GREEN+$00 ; 7
	.byte COLOR_GREEN+$00 ; 8
	.byte COLOR_GREEN+$02 ; 9 
	.byte COLOR_GREEN+$04 ; 10
	.byte COLOR_GREEN+$06 ; 0 ; First 12 positions are start
	.byte COLOR_GREEN+$08 ; 1
	.byte COLOR_GREEN+$0a ; 2
	.byte COLOR_GREEN+$0c ; 3
	.byte COLOR_GREEN+$0e ; 4
	.byte COLOR_GREEN+$0c ; 5
	.byte COLOR_GREEN+$0a ; 6 -- end on this index.
	.byte COLOR_GREEN+$08 ; 7
	.byte COLOR_GREEN+$06 ; 8
	.byte COLOR_GREEN+$04 ; 9 
	.byte COLOR_GREEN+$02 ; 10
	.byte COLOR_GREEN+$00 ; 11
	.byte COLOR_GREEN+$00 ;(12)
	.byte COLOR_GREEN+$02 ;(13)
	.byte COLOR_GREEN+$02 ;(14)
	.byte COLOR_GREEN+$04 ;(15)
	.byte COLOR_GREEN+$04 ;(16)
	.byte COLOR_GREEN+$06 ;(17)

	
TITLE_COLPF3 ; "Yellow"
	.byte COLOR_LITE_ORANGE+$0c ;(30) 
	.byte COLOR_LITE_ORANGE+$0c ;(31) 
	.byte COLOR_LITE_ORANGE+$0a ;(32) 
	.byte COLOR_LITE_ORANGE+$0a ;(33) 
	.byte COLOR_LITE_ORANGE+$08 ;(34) 
	.byte COLOR_LITE_ORANGE+$08 ;(35) 
	.byte COLOR_LITE_ORANGE+$06 ;(36) 
	.byte COLOR_LITE_ORANGE+$06 ;(37)
	.byte COLOR_LITE_ORANGE+$04 ;(38) 
	.byte COLOR_LITE_ORANGE+$04 ;(39) 
	.byte COLOR_LITE_ORANGE+$02 ;(40)
	.byte COLOR_LITE_ORANGE+$02 ;(41) 
	.byte COLOR_LITE_ORANGE+$00 ;(42) 
	.byte COLOR_LITE_ORANGE+$00 ; 0
	.byte COLOR_LITE_ORANGE+$02 ; 1
	.byte COLOR_LITE_ORANGE+$04 ; 2
	.byte COLOR_LITE_ORANGE+$06 ; 3
	.byte COLOR_LITE_ORANGE+$08 ; 4
	.byte COLOR_LITE_ORANGE+$0a ; 5
	.byte COLOR_LITE_ORANGE+$0c ; 6
	.byte COLOR_LITE_ORANGE+$0e ; 7
	.byte COLOR_LITE_ORANGE+$0c ; 8
	.byte COLOR_LITE_ORANGE+$0a ; 9 
	.byte COLOR_LITE_ORANGE+$08 ; 10
	.byte COLOR_LITE_ORANGE+$06 ; 0 ; First 12 positions are start
	.byte COLOR_LITE_ORANGE+$04 ; 1
	.byte COLOR_LITE_ORANGE+$02 ; 2
	.byte COLOR_LITE_ORANGE+$00 ; 3
	.byte COLOR_LITE_ORANGE+$00 ; 4
	.byte COLOR_LITE_ORANGE+$02 ; 5
	.byte COLOR_LITE_ORANGE+$02 ; 6
	.byte COLOR_LITE_ORANGE+$04 ; 7
	.byte COLOR_LITE_ORANGE+$04 ; 8
	.byte COLOR_LITE_ORANGE+$06 ; 9 
	.byte COLOR_LITE_ORANGE+$06 ; 10
	.byte COLOR_LITE_ORANGE+$08 ; 11
	.byte COLOR_LITE_ORANGE+$08 ;(12)
	.byte COLOR_LITE_ORANGE+$0a ;(13)
	.byte COLOR_LITE_ORANGE+$0a ;(14)
	.byte COLOR_LITE_ORANGE+$0c ;(15)
	.byte COLOR_LITE_ORANGE+$0c ;(16)
	.byte COLOR_LITE_ORANGE+$0e ;(17)
	.byte COLOR_LITE_ORANGE+$0e ;(18) -- end on this index.
	.byte COLOR_LITE_ORANGE+$0c ;(19)
	.byte COLOR_LITE_ORANGE+$0c ;(20)
	.byte COLOR_LITE_ORANGE+$0a ;(21)
	.byte COLOR_LITE_ORANGE+$0a ;(22)
	.byte COLOR_LITE_ORANGE+$08 ;(23)
	.byte COLOR_LITE_ORANGE+$08 ;(24) 
	.byte COLOR_LITE_ORANGE+$06 ;(25) 
	.byte COLOR_LITE_ORANGE+$06 ;(26) 
	.byte COLOR_LITE_ORANGE+$04 ;(27) 
	.byte COLOR_LITE_ORANGE+$04 ;(28) 
	.byte COLOR_LITE_ORANGE+$02 ;(29) 




TITLE_TEXT0
	.sbyte "  B R E A K O U T   "
TITLE_TEXT1
	.sbyte "  B R E A K O U T   "

;===============================================================================
; THUMPER-BUMPER Proximity Force Field: 
;===============================================================================
; As the ball nears the top, left and right borders
; a force field begin charging.  When the ball reaches the 
; force field line the ball rebounds in conjunction 
; with a reactive bounce animation of the force field.
;
; Only values 9 to 0 are meaningful. 
; Value 0 triggers thumper anim.
; Proximity values >0 will not be respected
; when a thumper animation is in progress.
; Only value 0 will trigger the start of a 
; new thumper animation cycle.
;
; MAIN code sets the new proximity.  
; Proximity is Ball position - border postition 
;
; VBI reacts to new proximity.
; if animation is in progress then
;     update animation.
;     if proximity = 0 then (re)start animation.
; Else
;     if proximity >8 then no proxmity color.
;     if proximity 1 to 8 then set proximity color.
;	  if proximity = 0 then start animation.
; End if

; Display List-- Horizontal Thumper sequence
; The list is the low byte of the address of different
; versions of the bumper shape.  The VBI will overwite 
; the low byte of a JMP instruction in the Display
; List to point to the next frame in the animation.
;
THUMPER_HORIZ_ANIM_TABLE
	.byte <THUMPER_FRAME_WAIT
	.byte <THUMPER_FRAME0
	.byte <THUMPER_FRAME1
	.byte <THUMPER_FRAME0
	.byte <THUMPER_FRAME2
	.byte <THUMPER_FRAME0
	.byte <THUMPER_FRAME3
	.byte <THUMPER_FRAME0
	.byte <THUMPER_FRAME4
	.byte <THUMPER_FRAME0
	.byte <THUMPER_FRAME5
	.byte <THUMPER_FRAME0

; Missile -- LEFT Vertical Thumper sequence
; List establishes HPOS and SIZE
; entry 0 is waiting state.
;
THUMPER_LEFT_ANIM_TABLE
	.byte MIN_PIXEL_X-1,  ~00000000 ; Waiting for Proximity 
	.byte MIN_PIXEL_X-4,  ~00000011 ; MASK: MASK_MISSILE0_BITS
	.byte MIN_PIXEL_X-5,  ~00000001
	.byte MIN_PIXEL_X-6,  ~00000000
	.byte MIN_PIXEL_X-8,  ~00000000
	.byte MIN_PIXEL_X-11, ~00000000

; Missile -- RIGHT Vertical Thumper sequence
; List establishes HPOS and SIZE
; entry 0 is waiting state
;
THUMPER_RIGHT_ANIM_TABLE
	.byte MIN_PIXEL_X+1,  ~00000000 ; Waiting for Proximity 
	.byte MIN_PIXEL_X+1,  ~00001100 ; MASK: MASK_MISSILE1_BITS
	.byte MIN_PIXEL_X+4,  ~00000100
	.byte MIN_PIXEL_X+6,  ~00000000
	.byte MIN_PIXEL_X+8,  ~00000000
	.byte MIN_PIXEL_X+11, ~00000000
;
; THUMPER-BUMPER Proximity set by MAIN code:
; 
THUMPER_PROXIMITY
THUMPER_PROXIMITY_TOP   .byte $09 
THUMPER_PROXIMITY_LEFT  .byte $09 
THUMPER_PROXIMITY_RIGHT .byte $09 
;
; VBI maintains animation frame progress
;
THUMPER_FRAME
THUMPER_FRAME_TOP   .byte 0 ; 0 is no animation.
THUMPER_FRAME_LEFT  .byte 0 ; 0 is no animation.
THUMPER_FRAME_RIGHT .byte 0 ; 0 is no animation.
;
; VBI maintains animation frames
;
THUMPER_FRAME_LIMIT
THUMPER_FRAME_LIMIT_TOP   .byte 12 ; at 12 return to 0
THUMPER_FRAME_LIMIT_LEFT  .byte 6  ; at 6 return to 0
THUMPER_FRAME_LIMIT_RIGHT .byte 6  ; at 6 return to 0
;
; VBI sets colors, and DLI2 sets them on screen.
;
THUMPER_COLOR
THUMPER_COLOR_TOP   .byte 0
THUMPER_COLOR_LEFT  .byte 0
THUMPER_COLOR_RIGHT .byte 0

; VBI sets the color of the thumper based on 
; the distance of the ball determined by the MAIN
; routine where distance == 
; for X is ABS((BallX - BorderX)) / 2
; for Y is ABS((BallX - BorderX)) / 4  
; (These colors are set when a thumper anim is NOT in progress).
; Therefore, adjusted distance 1 to 8 have a color.
; Distance 9 is black.  (maybe we'll make it very grey)
; Thumper animation (distance 0 ) is white.
; greater than 8 is color $00
THUMPER_PROXIMITY_COLOR
	.byte $0E,$7E,$7C,$7A,$78,$76,$74,$72,$70,$00


; ==============================================================
; BRICKS
; ==============================================================
; "Bricks" refers to the playfield bricks and 
; the graphics for the Title log and the Game
; Over screen.  "Bricks" may also be an empty
; line to remove/transition these objects between
; the different displays.
;
; The Bricks may be in a static state for maintaining 
; current contents, or in a transition state 
; moving another screen contents on to the display.
;
; The MAIN code preps the BRICK lines for movement,
; sets the direction of each, and then notifies the 
; VBI to make the updates.

;===============================================================================
; BRICKS/PLAYFIELD -- HORIZONTAL SCROLL
;===============================================================================
; The playfield area is used for the game bricks while playing 
; and the large blocks for the TITLE LOGO and the GAME OVER.
;
; Lets talk about horizontal fine scrolling on the Atari...
;
; Earlier, the BRICK_LINEs were defined as 64-bytes each. 
; Part of the reason for this is to make the address math easy
; for the rows.   The other part has to do with how horizontal
; scrolling works.
;
; The graphics mode for the BRICKS is 20 bytes for normal screen 
; width (at 8 color clocks per byte). The game needs three screens 
; next to each other to accommodate the transitions.  (Well, it 
; could actually be done as 2 screens next to each other by someone 
; more clever. It is easier for my feeble mind to manage it if the 
; apparent transition motion between three screens really is 
; three screens.)
;
; The screen arrangement per line:
; 20 bytes|20 bytes|20 bytes == 60 bytes.
;
; To make the screens look like the end of one screen isn't 
; directly attached to the start of the next, I insert
; one empty byte between each:
; 20 bytes|1 byte|20 bytes|1 byte|20 bytes == 62 bytes.
;
; So, the program can just use the first 62 bytes of each row, and
; ignore the last two, right? Not so. The program must offset its 
; base reference for the three screens due to the way the Atari 
; does horizontal scrolling. 
;
; When horizontal scrolling is enabled ANTIC reads more data beginning
; at the current memory scan address than it needs to display the
; visible graphics line -- it reads enough additional data to 
; maintain a buffer of 16 color clocks at the beginning of the 
; display line.
;
; Examples below assume a graphics mode that displays 8 color clocks 
; (pixels) per byte (the mode used for the game playfield.):
;
; Normal memory read and display:
; (Simple and obvious -- 20 bytes read. 20 bytes displayed) 
; P is displayed pixels from a byte
; MS (memory scan pointer points to byte 0)
;  v
; |byte 0  |byte 1  |byte 2  |byte 3 ...|byte 18 |byte 19 |
; |PPPPPPPP|PPPPPPPP|PPPPPPPP|PPP... ...|PPPPPPPP|PPPPPPPP|
; 
; Memory read and display for Horizontal scrolling:
; (Not so obvious -- more than 20 bytes read. 20 bytes displayed.)
; P is displayed pixels from a byte
; B is buffered pixels
; MS (memory scan pointer points to byte 0)
;  v
; |byte 0  |byte 1  |byte 2  |byte 3  |byte 4 ...|byte 19 |byte 20 |byte 21 |
; |BBBBBBBB|BBBBBBBB|PPPPPPPP|PPPPPPPP|PPP... ...|PPPPPPPP|PPPPPPPP|PPPPPPPP|
;   FEDCBA9|87654321|0 = HSCROL positions
;                    ^ HSCROL = 0
;
; Horizontal scrolling works by using the HSCROL register to specify
; how many of the 16 buffered color clocks at the start of the line 
; should be output for display.  The example above shows none of the 
; buffered pixels output, so the HSCROL value is 0. Note that in this 
; case of HSCROL value 0 the buffer causes the actual display output to 
; begin two bytes later in memory than specified by ANTIC's memory scan 
; pointer.  

; The HSCROL value may range from 0 buffered color clocks output to 
; display up to 15 buffered color clocks output.  The example below 
; shows HSCROL set to 3.
;
; Memory read and display for Horizontal scrolling when HSCROL = 3
; (Not so obvious -- more than 20 bytes read. 20 bytes displayed.)
; P is displayed pixels from a byte
; B is buffered pixels
; D is buffered pixels added to display.
; N is previously displayable pixels removed from display due to HSCROL shifting the pixels.
; MS (memory scan pointer points to byte 0)
;  v
; |byte 0  |byte 1  |byte 2  |byte 3  |byte 4 ...|byte 19 |byte 20 |byte 21 |
; |BBBBBBBB|BBBBBDDD|PPPPPPPP|PPPPPPPP|PPP... ...|PPPPPPPP|PPPPPPPP|PPPPPNNN|
;   FEDCBA9|87654321|0 = HSCROL positions
;                ^ HSCROL = 3
;
; The number of color clocks output for display is still consistent with the 
; normal output for the mode of graphics.   The contents of the line 
; shifts to the right "losing" 3 color clocks at the right side of the screen
; while HSCROL adds 3 color clocks to the left side of the display.
;
; Note that while ANTIC buffers 16 color clocks of data, the HSCROL value can 
; only range up to 15.  This means the first buffered color clock is not
; displayable...
;
; Memory read and display for Horizontal scrolling when HSCROL = 15 ($F)
; (Not so obvious -- more than 20 bytes read. 20 bytes displayed.)
; P is displayed pixels from a byte
; B is buffered pixels
; D is buffered pixels added to display.
; N is previously displayable pixels removed from display due to HSCROL shifting the pixels.
; MS (memory scan pointer points to byte 0)
;  v
; |byte 0  |byte 1  |byte 2  |byte 3  |byte 4 ...|byte 19 |byte 20 |byte 21 |
; |BDDDDDDD|DDDDDDDD|PPPPPPPP|PPPPPPPP|PPP... ...|PPPPPPPP|PNNNNNNN|NNNNNNNN|
; | FEDCBA9|87654321|0 = HSCROL positions
; | ^ HSCROL = 15 ($F)
;  
; Displaying that final color clock requires (at least) one more byte prior 
; to this byte allowing HSCROL to output the contents of this byte.
; In other words, begin displaying from a previous memory location 
; (the original byte 0 address - 2 bytes) and then set fine scroll HSCROL 
; value to 0.
;
; An interesting part of Atari horizontal scrolling is that the 16 color 
; clocks buffered can exceed the distance of one byte's worth of color clocks.
; Therefore the increment (or decrement) for coarse scrolling is greater than 
; 1 byte. Some ANTIC modes have two bytes per 16 color clocks, some have 
; 4 bytes.  This has the interesting effect that the same display can be output 
; by different variations of memory scan starting address and HSCROL.
; For example, the display output is identical for the two settings below:
; 
; P is displayed pixels from a byte
; B is buffered pixels
; D is buffered pixels added to display.
; N is pixels not displayed on right.
; Z is pixels not read/not buffered/not displayed from the left 
; MS (memory scan pointer points to byte 0)
;  v
; |byte 0  |byte 1  |byte 2  |byte 3  |byte 4 ...|byte 19 |byte 20 |byte 21 |byte 22 |
; |BBBBBBBB|BBBBBBBB|PPPPPPPP|PPPPPPPP|PPP... ...|PPPPPPPP|PPPPPPPP|PPPPPPPP|NNNNNNNN|
; | FEDCBA9|87654321|0 = HSCROL positions
; |                  ^ HSCROL = 0
;
; MS (memory scan pointer points to byte 1)
;           v
; |byte 0  |byte 1  |byte 2  |byte 3  |byte 4 ...|byte 19 |byte 20 |byte 21 |byte 22 |
; |ZZZZZZZZ|BBBBBBBB|DDDDDDDD|PPPPPPPP|PPP... ...|PPPPPPPP|PPPPPPPP|PPPPPPPP|NNNNNNNN|
; |        | FEDCBA9|87654321|0 = HSCROL positions
; |                  ^ HSCROL = 8
;
; So, the consequence of this discussion and horizontal scrolling's treatment of the 
; first byte of the buffer means that the program can't consider the first byte 
; completely displayable and will ignore it as part of the intended display output.  
; However, the program must still accommodate that byte in order to scroll to the 
; byte that follows. 
;
; Therefore, the memory map for the display lines looks like this: 
; ignore byte 0|20 bytes|1 byte|20 bytes|1 byte|20 bytes == 63 bytes.
;
; Thus the origination position for each of the three screens relative to the 
; base address of each line:
; Left Screen: Memory Scan +0,  HSCROL = 8
; Center Screen: Memory Scan +20, HSCROL = 0 (or Memory Scan +21, HSCROL = 8)
; Right Screen: Memory Scan +41, HSCROL = 0 (or Memory Scan +42, HSCROL = 8)
;
; Reference lookup for Display List LMS offset for screen postition:
; 0 = left
; 1 = center
; 2 = right
;
BRICK_SCREEN_LMS  .byte 0,20,41
;
; and HSCROL value to align the correct bytes...
;
BRICK_SCREEN_HSCROL .byte 8,0,0
;
; Move immediately to target positions if value is 1.
; Copy the BRICK_BRICK_SCREEN_TARGET_LMS_LMS and 
; BRICK_SCREEN_TARGET_HSCROL to all current positions.
;
BRICK_SCREEN_IMMEDIATE_POSITION .byte 0
;
; Offsets of Display List LMS pointers (low byte) of each row position.
; BRICK_BASE+1, +5, +9, +13, +17, +21, +25, +29 is low byte of row.
;
BRICK_CURRENT_LMS_OFFSETS ; DISPLAY LIST: offset from BRICK_BASE to low byte of each LMS address
	.byte 1,5,9,13,17,21,25,29
;
; DLI: HSCROL/fine scrolling position.
;
BRICK_CURRENT_HSCROL .byte 0,0,0,0,0,0,0,0
;
; MAIN code sets the following sets of configuration
; per each line of the playfield.  VBI takes these
; instructions and moves display during each frame.
;
; Target LMS offset/coarse scroll to move the display. 
; One target per display line... line 0 to line 7.
;
BRICK_SCREEN_TARGET_LMS .byte 20,20,20,20,20,20,20,20
;
; Target HSCROL/fine scrolling destination for moving display.
;
BRICK_SCREEN_TARGET_HSCROL .byte 0,0,0,0,0,0,0,0
;
; Increment or decrement the movement direction? 
; -1= view Left/graphics right, +1=view Right/graphics left
;
BRICK_SCREEN_DIRECTION .byte 1,-1,1,-1,1,-1,1,-1
;
; Brick Screen speed to move (HSCROLs +/- per frame)
;
BRICK_SCREEN_HSCROL_MOVE .byte 1,1,2,2,3,3,4,4
;
; Frame count to delay start of transition.
;
BRICK_SCREEN_MOVE_DELAY .byte 7,6,5,4,3,2,1,0
;
; MAIN flag to VBI requesting start of screen transition.
;
BRICK_SCREEN_START_SCROLL .byte 0
;
; VBI Feedback to MAIN that it is busy moving
;
BRICK_SCREEN_IN_MOTION .byte 0
;
;
;
BRICK_LINE_TABLE_LO
	entry .= 0
	.rept 8 ; repeat for 8 lines
	.byte <[BRICK_LINE0+[entry*64]]
	entry .= entry+1 ; next entry in table.
	.endr
	
BRICK_LINE_TABLE_HI
	entry .= 0
	.rept 8 ; repeat for 8 lines
	.byte >[BRICK_LINE0+[entry*64]]
	entry .= entry+1 ; next entry in table.
	.endr

;
; Mask to erase an individual brick, numbered 0 to 13.
; Starting byte offset for visible screen memory, then the AND mask 
; for 3 bytes because some bricks cross three bytes.
;
BRICK_MASK_TABLE
	.byte $00, ~00000000, ~00000011, ~11111111
	.byte $01, ~11111000, ~00000000, ~01111111
	.byte $03, ~00000000, ~00001111, ~11111111
	.byte $04, ~11100000, ~00000001, ~11111111

	.byte $05, ~11111100, ~00000000, ~00111111
	.byte $07, ~10000000, ~00000111, ~11111111
	.byte $08, ~11110000, ~00000000, ~11111111
	.byte $0a, ~00000000, ~00011111, ~11111111

	.byte $0b, ~11000000, ~00000011, ~11111111
	.byte $0c, ~11111000, ~00000000, ~01111111
	.byte $0e, ~00000000, ~00001111, ~11111111
	.byte $0f, ~11100000, ~00000001, ~11111111

	.byte $10, ~11111100, ~00000000, ~00111111
	.byte $12, ~10000000, ~00000000, ~00000000  ; This would also clear byte 21


;
; Table for P/M Xpos of each brick left edge
;
BRICK_XPOS_LEFT_TABLE
	entry .= 0
	.rept 14 ; repeat for 14 bricks in a line
	.byte PLAYFIELD_LEFT_EDGE_NORMAL+BRICK_LEFT_OFFSET+[entry*BRICK_WIDTH]]
	entry .= entry+1 ; next entry in table.
	.endr
;
; Table for P/M Xpos of each brick right edge
;
BRICK_XPOS_RIGHT_TABLE
	entry .= 0
	.rept 14 ; repeat for 14 bricks in a line
	.byte PLAYFIELD_LEFT_EDGE_NORMAL+BRICK_RIGHT_OFFSET+[entry*BRICK_WIDTH]]
	entry .= entry+1 ; next entry in table.
	.endr


; The "PLAYFIELD edge offset" for Y direction defined in the  
; custom chip include files is not used here, because the vertical 
; display is entirely managed by a custom display list instead of 
; the default Operating System graphics modes.
;
; Table for P/M Ypos of each brick top edge
;
BRICK_YPOS_TOP_TABLE
	entry .= 0
	.rept 8 ; repeat for 8 lines of bricks 
	.byte BRICK_TOP_OFFSET+[entry*BRICK_HEIGHT]]
	entry .= entry+1 ; next entry in table.
	.endr
;
; Table for P/M Ypos of each brick bottom edge
;
BRICK_YPOS_BOTTOM_TABLE
	entry .= 0
	.rept 8 ; repeat for 8 lines of bricks 
	.byte BRICK_BOTTOM_OFFSET+[entry*BRICK_HEIGHT]]
	entry .= entry+1 ; next entry in table.
	.endr


; BRICK_BASE+1, +5, +9, +13, +17, +21, +25, +29 is low byte of row.

BRICK_LINE_MASTER
	.byte ~00011111, ~11111011, ~11111111, ~01111111, ~11101111 ; 0, 1, 2, 3
	.byte ~11111101, ~11111111, ~10111111, ~11110111, ~11111110 ; 3, 4, 5, 6
	.byte ~11111111, ~11011111, ~11111011, ~11111111, ~01111111 ; 7, 8, 9, 10
	.byte ~11101111, ~11111101, ~11111111, ~10111111, ~11110000 ; 10, 11, 12, 13

; Convert X coordinate to brick, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14.
; The Table does NOT contain entries for the entire playfield width.  It contains
; only the entries of the valid playfield from left bumper to right bumper.
; Three color clocks on the left and four on the right are not included in the 
; playfield.  
; (or from Normal Border Left Offset +3  to Normal Border Right Offset -4).
;
; The 11-ness of the brick width is what makes calculations a bear.  And this would
; have to be repeated for every pixel test for multiple position tests per each frame. 
; A lookup table reduces this computation to an indexed read.  
;
; Still this table is a highly wasteful 153 byte travesty. 

BALL_XPOS_TO_BRICK_TABLE
	.byte 1,1,1,1,1,1,1,1,1,1,0
	.byte 2,2,2,2,2,2,2,2,2,2,0
	.byte 3,3,3,3,3,3,3,3,3,3,0
	.byte 4,4,4,4,4,4,4,4,4,4,0
	.byte 5,5,5,5,5,5,5,5,5,5,0
	.byte 6,6,6,6,6,6,6,6,6,6,0
	.byte 7,7,7,7,7,7,7,7,7,7,0
	.byte 8,8,8,8,8,8,8,8,8,8,0
	.byte 9,9,9,9,9,9,9,9,9,9,0
	.byte 10,10,10,10,10,10,10,10,10,10,0
	.byte 11,11,11,11,11,11,11,11,11,11,0
	.byte 12,12,12,12,12,12,12,12,12,12,0
	.byte 13,13,13,13,13,13,13,13,13,13,0
	.byte 14,14,14,14,14,14,14,14,14,14

; Brick rows are 5 lines + 2 blanks between.  Another bad computation like
; the X Position deal.  When the Ball Y position to test is between the 
; first scan line and last scan line of the brick rows this lookup table
; identifies the row 1, 2, 3, 4, 5, 6, 7, 8.

BALL_YPOS_TO_BRICK_TABLE
	.byte 1,1,1,1,1,0,0
	.byte 2,2,2,2,2,0,0
	.byte 3,3,3,3,3,0,0
	.byte 4,4,4,4,4,0,0
	.byte 5,5,5,5,5,0,0
	.byte 6,6,6,6,6,0,0
	.byte 7,7,7,7,7,0,0
	.byte 8,8,8,8,8


;===============================================================================
; BOOM-O-MATIC.
;===============================================================================
; Players 1 and 2 implement a Boom animation for bricks knocked out.
; The animation overlays the destroyed brick with a player two scan lines 
; and two color clocks larger than the brick.  This is centered on the brick
; providing a first frame impression that the brick expands. On subsequent 
; frames the image shrinks and color fades. 
;
; A DLI cuts these two players HPOS for each line of bricks, so there are 
; two separate Boom-o-matics possible for each line.   Realistically, 
; given the ball motion and collision policy it is impossible to request 
; two Boom cycles begin on the same frame for the same row, and would be 
; unlikely to have multiple animations running on every line. (But, just
; in case the code plans for the worst.)
;
; When MAIN code detects collision it will generate a request for a Boom-O-Matic
; animation that VBI will service.  VBI will determine if the request is for
; Boom 1 or Boom 2 .  If both animation cycles are in progress the one with the
; most progress will reset itself for the new animation.
;
; Side note -- maybe a future iteration will utilize the boom-o-matic blocks 
; during Title or Game Over sequences.

ENABLE_BOOM .byte 0

BOOM_1_REQUEST .byte 0,0,0,0,0,0,0,0 ; MAIN provides flag to add this brick. 0 = no brick. 1 = new brick.
BOOM_2_REQUEST .byte 0,0,0,0,0,0,0,0 ; MAIN provides flag to add this brick.

BOOM_1_REQUEST_BRICK .byte 0,0,0,0,0,0,0,0 ; MAIN provides brick number in this row. 0 - 13
BOOM_2_REQUEST_BRICK .byte 0,0,0,0,0,0,0,0 ; MAIN provides brick number in this row. 0 - 13

BOOM_1_CYCLE .byte 0,0,0,0,0,0,0,0 ; VBI needs one for each row (0 = no animation)
BOOM_2_CYCLE .byte 0,0,0,0,0,0,0,0 ; VBI needs one for each row

BOOM_1_BRICK .byte 0,0,0,0,0,0,0,0 ; VBI uses Brick number on the row doing the Boom Cycle.
BOOM_2_BRICK .byte 0,0,0,0,0,0,0,0 ; VBI uses Brick number on the row doing the Boom Cycle.

BOOM_1_HPOS .byte 0,0,0,0,0,0,0,0 ; DLI needs HPOS1 for row
BOOM_2_HPOS .byte 0,0,0,0,0,0,0,0 ; DLI needs HPOS2 for row

BOOM_1_SIZE .byte 0,0,0,0,0,0,0,0 ; DLI needs P/M SIZE1 for row
BOOM_2_SIZE .byte 0,0,0,0,0,0,0,0 ; DLI needs P/M SIZE2 for row

BOOM_1_COLPM .byte 0,0,0,0,0,0,0,0 ; DLI needs P/M COLPM1 for row
BOOM_2_COLPM .byte 0,0,0,0,0,0,0,0 ; DLI needs P/M COLPM2 for row

BOOM_CYCLE_COLOR ; by row by cycle frame -- 9 frames per boom animation
	.byte $0E,COLOR_PINK|$0E,       COLOR_PINK|$0C,       COLOR_PINK|$0A,       COLOR_PINK|$08,COLOR_PINK|$06,COLOR_PINK|$04,$02,$00
	.byte $0E,COLOR_PINK|$0E,       COLOR_PINK|$0C,       COLOR_PINK|$0A,       COLOR_PINK|$08,COLOR_PINK|$06,COLOR_PINK|$04,$02,$00
	.byte $0E,COLOR_RED_ORANGE|$0E, COLOR_RED_ORANGE|$0C, COLOR_RED_ORANGE|$0A, COLOR_RED_ORANGE|$08,COLOR_RED_ORANGE|$06,COLOR_RED_ORANGE|$04,$02,$00
	.byte $0E,COLOR_RED_ORANGE|$0E, COLOR_RED_ORANGE|$0C, COLOR_RED_ORANGE|$0A, COLOR_RED_ORANGE|$08,COLOR_RED_ORANGE|$06,COLOR_RED_ORANGE|$04,$02,$00
	.byte $0E,COLOR_GREEN|$0E,      COLOR_GREEN|$0C,      COLOR_GREEN|$0A,      COLOR_GREEN|$08,COLOR_GREEN|$06,COLOR_GREEN|$04,$02,$00
	.byte $0E,COLOR_GREEN|$0E,      COLOR_GREEN|$0C,      COLOR_GREEN|$0A,      COLOR_GREEN|$08,COLOR_GREEN|$06,COLOR_GREEN|$04,$02,$00
	.byte $0E,COLOR_LITE_ORANGE|$0E,COLOR_LITE_ORANGE|$0C,COLOR_LITE_ORANGE|$0A,COLOR_LITE_ORANGE|$08,COLOR_LITE_ORANGE|$06,COLOR_LITE_ORANGE|$04,$02,$00
	.byte $0E,COLOR_LITE_ORANGE|$0E,COLOR_LITE_ORANGE|$0C,COLOR_LITE_ORANGE|$0A,COLOR_LITE_ORANGE|$08,COLOR_LITE_ORANGE|$06,COLOR_LITE_ORANGE|$04,$02,$00

BOOM_CYCLE_OFFSET ; Base offset (row * 9) to the color entries and P/M images for the cycle.
	.byte $00,9,18,27,36,45,54,63,72
	
BOOM_CYCLE_HPOS ; by cycle frame -- relative to Brick from BRICK_XPOS_LEFT_TABLE
	.byte $ff,$ff,$00,$00,$01,$02,$03,$04,$04

BOOM_CYCLE_SIZE ; by cycle frame
	.byte PM_SIZE_DOUBLE ; 6 bits * 2 color clocks == 12 color clocks. ; 1
	.byte PM_SIZE_DOUBLE ; 6 bits * 2 color clocks == 12 color clocks. ; 2
	.byte PM_SIZE_DOUBLE ; 5 bits * 2 color clocks == 10 color clocks. ; 3
	.byte PM_SIZE_DOUBLE ; 5 bits * 2 color clocks == 10 color clocks. ; 4
	.byte PM_SIZE_NORMAL ; 8 bits * 1 color clocks == 8 color clocks.  ; 5
	.byte PM_SIZE_NORMAL ; 6 bits * 1 color clocks == 6 color clocks.  ; 6
	.byte PM_SIZE_NORMAL ; 4 bits * 1 color clocks == 4 color clocks.  ; 7
	.byte PM_SIZE_NORMAL ; 2 bits * 1 color clocks == 2 color clocks.  ; 8
	.byte PM_SIZE_NORMAL ; 2 bits * 1 color clocks == 2 color clocks.  ; 9
	
BOOM_ANIMATION_FRAMES ; 7 bytes of Player image data per each cycle frame -- 8th and 9th byte 0 padded, since we have a offset table for * 9 
	.byte $FC,$FC,$FC,$FC,$FC,$FC,$FC,$00,$00 ; 7 scan lines, 6 bits * 2 color clocks == 12 color clocks. ; 1
	.byte $FC,$FC,$FC,$FC,$FC,$FC,$FC,$00,$00 ; 7 scan lines, 6 bits * 2 color clocks == 12 color clocks. ; 2
	.byte $00,$F8,$F8,$F8,$F8,$F8,$00,$00,$00 ; 5 scan lines, 5 bits * 2 color clocks == 10 color clocks. ; 3
	.byte $00,$F8,$F8,$F8,$F8,$F8,$00,$00,$00 ; 5 scan lines, 5 bits * 2 color clocks == 10 color clocks. ; 4
	.byte $00,$00,$FF,$FF,$FF,$00,$00,$00,$00 ; 3 scan lines, 8 bits * 1 color clocks == 8 color clocks.  ; 5
	.byte $00,$00,$FC,$FC,$FC,$00,$00,$00,$00 ; 3 scan lines, 6 bits * 1 color clocks == 6 color clocks.  ; 6
	.byte $00,$00,$00,$F0,$00,$00,$00,$00,$00 ; 1 scan line, 4 bits * 1 color clocks == 4 color clocks.   ; 7
	.byte $00,$00,$00,$C0,$00,$00,$00,$00,$00 ; 1 scan line, 2 bits * 1 color clocks == 2 color clocks.   ; 8
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00 ; 0 scan line, 0 bits * 0 color clocks == 0 color clocks.   ; 9

; ==============================================================
; BALL:
; ==============================================================
; Very simple.  
; MAIN code analyzes CURRENT position of the ball to set the NEW postion.
; VBI code updates the Player image and sets NEW as CURRENT.
; Everything else -- collisions and reactions are established by the MAIN code.

ENABLE_BALL .byte 0 ; set by MAIN to turn on and off the ball.

BALL_CURRENT_X .byte 0
BALL_CURRENT_Y .byte 0

BALL_HPOS .byte 0 ; this lets VBI tell DLI to remove from screen without zeroing CURRENT

BALL_NEW_X .byte 0 ; DLI sets HPOSP0
BALL_NEW_Y .byte 0 ; VBI moves image


;===============================================================================
; BALL SPEED CONTROL
;===============================================================================
; The ball speeds up to apply progressive difficulty.
;
; This is unlike the collision detection for a moving player 
; vs the coordinates of characters on screen.   The ball is a 
; fairly small square that is being evaluated against graphics pixels.
;
; Moving the ball greater distances for speed introduced side effects 
; in the collision actions.  Allowing the ball to make multiple pixel 
; steps in one evaluation of movement causes flaws. Clipping the motion 
; to the position of a collision makes the ball appear to move slower,
; or to curve slightly at the moment of collision.
;
; Keeping the ball behavior consistent for the speed, and properly 
; identifying collisions means moving the ball only one pixel at a 
; time in any given direction, evaluating and reacting to the possible 
; collision, and doing so repeatedly multiple times per frame to 
; sustain the motion speedup.
;
; This means there must be a step by step program for directing the
; pixel by pixel (scan line by scan line, color clock by color clock)
; motion.  The maximum distance to travel in a frame is 3 units in 
; either direction, so each speed program has three steps. The array
; is padded to 4 entries to make multiplyuing out the steps convenient.
; 
; Speed control directs moving from program to program.  The last step 
; of the program indicates a jump to a prior step, so the last three 
; speed types are repeated.

BALL_SPEED_SEQUENCE .byte 0,1,2,3,4,5,3 ; Note that the last step causes a loop of 3, 4, 5

; (inc this value, then get new current value from Speed sequence table. ) 
BALL_SPEED_CURRENT_SEQUENCE .byte 0 ; which step in the sequence above is current. 

BALL_SPEED_CURRENT_STEP .byte 0 ; 0 to 2

BALL_BOUNCE_COUNT .byte 6 ; decrement at each paddle hit. When it reaches 0 it resets 
; to 6 and the next speed sequence begins..

BALL_X_STEPS 
	.byte 1,0,0,0 ; 0 +1
	.byte 1,1,0,0 ; 1 +2
	.byte 1,1,0,0 ; 2 +2 
	.byte 1,1,1,0 ; 3 +3
	.byte 1,1,0,0 ; 4 +2
	.byte 1,1,1,0 ; 5 +3

BALL_Y_STEPS
	.byte 1,0,0,0 ; 0 +1
	.byte 1,0,0,0 ; 1 +1
	.byte 1,1,0,0 ; 2 +2
	.byte 1,1,0,0 ; 3 +2
	.byte 1,1,1,0 ; 4 +3
	.byte 1,1,1,0 ; 5 +3
	

; 

;
; Pointers to data to draw the Title screen logo
;
LOGO_LINE_TABLE_LO
	entry .= 0
	.rept 8 ; repeat for 8 rows
	.byte <[LOGO_LINE0+[entry*19]]
	entry .= entry+1 ; next entry in table.
	.endr
	
LOGO_LINE_TABLE_HI
	entry .= 0
	.rept 8 ; repeat for 8 rows
	.byte >[LOGO_LINE0+[entry*19]]
	entry .= entry+1 ; next entry in table.
	.endr
;
; Pointers to data to draw the Game Over screen
;
GAMEOVER_LINE_TABLE_LO
	entry .= 0
	.rept 8 ; repeat for 8 rows
	.byte <[GAMEOVER_LINE0+[entry*16]]
	entry .= entry+1 ; next entry in table.
	.endr

GAMEOVER_LINE_TABLE_HI
	entry .= 0
	.rept 8 ; repeat for 8 rows
	.byte >[GAMEOVER_LINE0+[entry*16]]
	entry .= entry+1 ; next entry in table.
	.endr



;===============================================================================
; CREDIT AND PROMPT Scrolling tables.

; State Controls

ENABLE_CREDIT_SCROLL .byte 0 ; MAIN: Flag to stop/start scrolling/visible text
SCROLL_DO_FADE .byte 0       ; MAIN: 0 = no fade.  1= fade up.  2 = fade down.
SCROLL_TICK_DELAY .byte 0    ; MAIN: number of frames to delay per scroll step.
SCROLL_BASE .word 0          ; MAIN: Base table to start scrolling
SCROLL_MAX_LINES .byte 0     ; MAIN: number of lines in scroll before restart.

SCROLL_CURRENT_TICK .byte 0    ; VBI: Current tick for delay, decrementing to 0.
SCROLL_IN_FADE .byte 0         ; VBI: fade is in progress? 0 = no. 1 = up. 2 = down
SCROLL_CURRENT_FADE .byte 0    ; VBI/DLI: VBI set for DLI - Current Fade Start position
SCROLL_CURRENT_LINE .byte 0    ; VBI: increment for start line of window.
SCROLL_CURRENT_VSCROLL .byte 0 ; VBI/DLI: VBI sets for DLI -- Current Fine Vertical Scroll vertical position. 

; Scroll text has shading on first and last lines.
; 6 values used at a time.
; Incrementing CURRENT_FADE changes text from black/off to shaded up to white.
; CURRENT_FADE should range from 0 to 6.
; 0 is off.  6 is fully lit.
; The DLI on the first line begins at SCROLL_CURRENT_FADE and reads 6 consecutive values for text brightness.
SCROLL_FADE_START_LINE_TABLE .byte $0,$0,$0,$0,$0,$0,$2,$4,$6,$8,$a,$c
; The DLI in the last line reads from SCROLL_CURRENT_FADE decrementing to 0 for text brightness.
SCROLL_FADE_END_LINE_TABLE   .byte $0,$2,$4,$6,$8,$a,$c
  
; Credits
CREDIT_SCROLL_TABLE ; Addresses of text lines for scroll
	.word CENTER_SCROLL_00 ; 1 Ten lines for empty screen.
	.word CENTER_SCROLL_00 ; 2
	.word CENTER_SCROLL_00 ; 3
	.word CENTER_SCROLL_00 ; 4
	.word CENTER_SCROLL_00 ; 5
	.word CENTER_SCROLL_00 ; 6
	.word CENTER_SCROLL_00 ; 7
	.word CENTER_SCROLL_00 ; 8
	.word CENTER_SCROLL_00 ; 9 
	.word CENTER_SCROLL_00 ; 10
	.word CREDIT_01 ; 11
	.word CREDIT_02 ; 12
	
	.word CENTER_SCROLL_00 ; 13

	.word CREDIT_03 ; 14
	.word CREDIT_04 ; 15
	.word CREDIT_05 ; 16
	.word CREDIT_06 ; 17
	.word CREDIT_07 ; 18

	.word CENTER_SCROLL_00 ; 19
	.word CENTER_SCROLL_01 ; 20  - - + - - 
	.word CENTER_SCROLL_00 ; 21

	.word CREDIT_08 ; 22
	.word CREDIT_09 ; 23

	.word CENTER_SCROLL_00 ; 24

	.word CREDIT_10 ; 25
	.word CREDIT_11 ; 26
	.word CREDIT_12 ; 27
	.word CREDIT_13 ; 28
	.word CREDIT_14 ; 29

	.word CENTER_SCROLL_00 ; 30
	.word CENTER_SCROLL_01 ; 31  - - + - - 
	.word CENTER_SCROLL_00 ; 32

	.word CREDIT_08 ; 33
	.word CREDIT_15 ; 34
	.word CREDIT_16	; 35

	.word CENTER_SCROLL_00 ; 36
	
	.word CREDIT_17 ; 37
	.word CREDIT_18 ; 38
	.word CREDIT_19 ; 39
	.word CREDIT_12 ; 40
	.word CREDIT_13 ; 41
	.word CREDIT_20 ; 42
	.word CREDIT_21 ; 43
	.word CREDIT_22 ; 44
	.word CREDIT_23 ; 45
	.word CREDIT_24 ; 46
	.word CREDIT_25 ; 47

	.word CENTER_SCROLL_00 ; 48
	.word CENTER_SCROLL_01 ; 49 - - + - - 
	.word CENTER_SCROLL_00 ; 50	

	.word CREDIT_26	; 51
	.word CREDIT_27 ; 52
	.word CREDIT_16 ; 53

	.word CENTER_SCROLL_00 ; 54
	
	.word CREDIT_28 ; 55
	.word CREDIT_18 ; 56
	.word CREDIT_19 ; 57 
	.word CREDIT_12 ; 58
	.word CREDIT_13 ; 59
	.word CREDIT_29 ; 60
	.word CREDIT_21 ; 61
	.word CREDIT_22 ; 62
	.word CREDIT_23 ; 63
	.word CREDIT_24 ; 64
	.word CREDIT_30 ; 65

	.word CENTER_SCROLL_00 ; 66
	.word CENTER_SCROLL_01 ; 67  - - + - - 
	.word CENTER_SCROLL_00 ; 68	

	.word CREDIT_31 ; 69
	.word CREDIT_32 ; 70

	.word CENTER_SCROLL_00 ; 71

	.word CREDIT_33 ; 72

	.word CENTER_SCROLL_00 ; 73

	.word CREDIT_34 ; 74

	.word CENTER_SCROLL_00 ; 75

	.word CREDIT_35 ; 76
	.word CREDIT_36 ; 77
	.word CREDIT_37 ; 78

	.word CENTER_SCROLL_00 ; 79

	.word CREDIT_38 ; 80
	.word CREDIT_39 ; 81
	.word CREDIT_40 ; 82
	.word CREDIT_41 ; 83
	.word CREDIT_42 ; 84
	.word CREDIT_43 ; 85
	.word CREDIT_44 ; 86
	.word CREDIT_45 ; 87
	.word CREDIT_46 ; 88

	.word CENTER_SCROLL_00 ; 89
	.word CENTER_SCROLL_01 ; 90  - - + - - 
	
	.word CENTER_SCROLL_00 ; 91  Ten lines for empty screen.
	.word CENTER_SCROLL_00 ; 92
	.word CENTER_SCROLL_00 ; 93
	.word CENTER_SCROLL_00 ; 94
	.word CENTER_SCROLL_00 ; 95
	.word CENTER_SCROLL_00 ; 96
	.word CENTER_SCROLL_00 ; 97
	.word CENTER_SCROLL_00 ; 98
	.word CENTER_SCROLL_00 ; 99

CREDIT_SCROLL_TABLE_SIZE=98  ; Address/words up to here, then loop around 
	

CONTINUE_SCROLL_TABLE ; Addresses of text lines for scroll
	.word CENTER_SCROLL_00  ; Ten lines for empty screen.
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word PROMPT_01
	.word CENTER_SCROLL_00  ; Ten lines for empty screen.
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 

CONTINUE_SCROLL_TABLE_SIZE=12  ; Address/words up to here, then loop around 	


SUBTITLE_SCROLL_TABLE ; Addresses of text lines for scroll
	.word CENTER_SCROLL_00  ; Ten lines for empty screen.
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word SUBTITLE_01
	.word CENTER_SCROLL_00  
	.word CENTER_SCROLL_00 
	.word SUBTITLE_02
	.word CENTER_SCROLL_00 
	.word SUBTITLE_03
	.word CENTER_SCROLL_00 
	.word SUBTITLE_04	
	.word CENTER_SCROLL_00  ; Ten lines for empty screen.
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 
	.word CENTER_SCROLL_00 

SUBTITLE_SCROLL_TABLE_SIZE=19  ; Address/words up to here, then loop around 	


;===============================================================================
; PADDLE CONTROL

; Positioning is very simple. Lookup potentiometer value in
; the table.  Set Player HPOS accordingly.

PADDLE_SIZE .byte 0 ; Paddle Size  0 = Normal.  1 = Small.

; Convert Potentiometer value to Paddle screen position.

PADDLE_NORMAL_POSITION_TABLE ; 228 bytes of HPOS coordinates corresponding to paddle values
    .byte $CA,$CA,$CA,$C9,$C9,$C8,$C7,$C6,$C6,$C5,$C4,$C4,$C3,$C2,$C2,$C1,$C0,$BF,$BF,$BE,$BD,$BD,$BC,$BB,$BB,$BA,$B9,$B8,$B8,$B7,$B6,$B6
    .byte $B5,$B4,$B4,$B3,$B2,$B1,$B1,$B0,$AF,$AF,$AE,$AD,$AD,$AC,$AB,$AA,$AA,$A9,$A8,$A8,$A7,$A6,$A5,$A5,$A4,$A3,$A3,$A2,$A1,$A1,$A0,$9F
    .byte $9E,$9E,$9D,$9C,$9C,$9B,$9A,$9A,$99,$98,$97,$97,$96,$95,$95,$94,$93,$93,$92,$91,$90,$90,$8F,$8E,$8E,$8D,$8C,$8C,$8B,$8A,$89,$89
    .byte $88,$87,$87,$86,$85,$84,$84,$83,$82,$82,$81,$80,$80,$7F,$7E,$7D,$7D,$7C,$7B,$7B,$7A,$79,$79,$78,$77,$76,$76,$75,$74,$74,$73,$72
    .byte $72,$71,$70,$6F,$6F,$6E,$6D,$6D,$6C,$6B,$6A,$6A,$69,$68,$68,$67,$66,$66,$65,$64,$63,$63,$62,$61,$61,$60,$5F,$5F,$5E,$5D,$5C,$5C
    .byte $5B,$5A,$5A,$59,$58,$58,$57,$56,$55,$55,$54,$53,$53,$52,$51,$51,$50,$4F,$4E,$4E,$4D,$4C,$4C,$4B,$4A,$49,$49,$48,$47,$47,$46,$45
    .byte $45,$44,$43,$42,$42,$41,$40,$40,$3F,$3E,$3E,$3D,$3C,$3B,$3B,$3A,$39,$39,$38,$37,$37,$36,$35,$34,$34,$33,$32,$32,$31,$30,$30,$2F
    .byte $2E,$2D,$2D,$2D

PADDLE_SMALL_POSITION_TABLE ; 228 bytes of HPOS coordinates corresponding to paddle values
    .byte $CA,$CA,$CA,$C9,$C9,$C8,$C7,$C7,$C6,$C5,$C4,$C4,$C3,$C2,$C2,$C1,$C0,$C0,$BF,$BE,$BE,$BD,$BC,$BC,$BB,$BA,$B9,$B9,$B8,$B7,$B7,$B6
    .byte $B5,$B5,$B4,$B3,$B3,$B2,$B1,$B1,$B0,$AF,$AE,$AE,$AD,$AC,$AC,$AB,$AA,$AA,$A9,$A8,$A8,$A7,$A6,$A5,$A5,$A4,$A3,$A3,$A2,$A1,$A1,$A0
    .byte $9F,$9F,$9E,$9D,$9D,$9C,$9B,$9A,$9A,$99,$98,$98,$97,$96,$96,$95,$94,$94,$93,$92,$92,$91,$90,$8F,$8F,$8E,$8D,$8D,$8C,$8B,$8B,$8A
    .byte $89,$89,$88,$87,$86,$86,$85,$84,$84,$83,$82,$82,$81,$80,$80,$7F,$7E,$7E,$7D,$7C,$7B,$7B,$7A,$79,$79,$78,$77,$77,$76,$75,$75,$74
    .byte $73,$73,$72,$71,$70,$70,$6F,$6E,$6E,$6D,$6C,$6C,$6B,$6A,$6A,$69,$68,$67,$67,$66,$65,$65,$64,$63,$63,$62,$61,$61,$60,$5F,$5F,$5E
    .byte $5D,$5C,$5C,$5B,$5A,$5A,$59,$58,$58,$57,$56,$56,$55,$54,$54,$53,$52,$51,$51,$50,$4F,$4F,$4E,$4D,$4D,$4C,$4B,$4B,$4A,$49,$48,$48
    .byte $47,$46,$46,$45,$44,$44,$43,$42,$42,$41,$40,$40,$3F,$3E,$3D,$3D,$3C,$3B,$3B,$3A,$39,$39,$38,$37,$37,$36,$35,$35,$34,$33,$32,$32
    .byte $31,$30,$30,$30

; CURRENT STATE:
; Paddle is made of several Player objects providing 
; additional horizontal color.  A DLI makes vertical 
; shading in the main colors.

; FUTURE ENHANCEMENT:
; The paddle reacts to ball proximity and strikes similar 
; to the way the bumpers work.  MAIN sets the value.
; distance == (PADDLE_Y - BALL_Y) / 4 only when Ball Y 
; is less than/equal to Paddle Y. AND X is within a
; 1 pixel limit of the paddle size.

PADDLE_PROXIMITY .byte $09 
;
; VBI maintains animation frames
;
PADDLE_FRAME_LIMIT .byte 12 ; at 12 return to 0
;
; VBI sets colors, and DLI sets them on screen.
;
PADDLE_COLOR .byte 0

; VBI sets the color of the paddle based on 
; the distance of the ball determined by the MAIN
; routine where distance == 
; for Y is ABS((PADDLE_Y - BALL_Y)) / 4  
; greater than 8 is color $00
PADDLE_PROXIMITY_COLOR
	.byte $0E,$7E,$7C,$7A,$78,$76,$74,$72,$70,$00

