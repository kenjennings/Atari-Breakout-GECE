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
; Github: https://github.com/kenjennings/Breakout-GECE-for-Atari
; Google Drive: https://drive.google.com/drive/folders/
;===============================================================================

;===============================================================================
;   ATARI SYSTEM INCLUDES
;===============================================================================
; Various Include files that provide equates defining 
; registers and the values used for the registers:
;
	.include "ANTIC.asm" 
	.include "GTIA.asm"
	.include "POKEY.asm"
	.include "PIA.asm"
	.include "OS.asm"
	.include "DOS.asm" ; This provides the LOMEM, start, and run addresses.

	.include "macros.asm"


;===============================================================================
;   VARIOUS CONSTANTS AND LIMITS
;===============================================================================
; Let's define some useful offsets and sizes. 
; Could become useful somewhere else.
;
BRICK_LEFT_OFFSET =   3  ; offset from normal PLAYFIELD LEFT edge to left edge of brick 
BRICK_RIGHT_OFFSET =  12 ; offset from normal PLAYFIELD LEFT edge to the right edge of first brick

BRICK_PIXEL_WIDTH =   10 ; Actual drawn pixels in brick.
BRICK_WIDTH =         11 ; including the trailing blank space separating bricks 

BRICK_TOP_OFFSET =     78  ; First scan line of top line of bricks.
BRICK_TOP_END_OFFSET = 82  ; Last scan line of the top line of bricks.
BRICK_BOTTOM_OFFSET =  131 ; Last scan line of bottom line of bricks.

BRICK_LINE_HEIGHT =    5   ; Actual drawn graphics scanlines.
BRICK_HEIGHT =         7   ; including the following blank lines (used when multiplying for position) 
;
; Playfield MIN/MAX travel areas relative to the ball.
;
MIN_PIXEL_X = PLAYFIELD_LEFT_EDGE_NORMAL+BRICK_LEFT_OFFSET ; 48 + 3 = 51
MAX_PIXEL_X = MIN_PIXEL_X+152 ; Actual last color clock of last brick. 51 + 152 = 203

PIXELS_COLS = MAX_PIXEL_X-MIN_PIXEL_X+1 ; number of real pixels on line (153)

MIN_BALL_X =  MIN_PIXEL_X ; because PM/left edge is same
MAX_BALL_X =  MAX_PIXEL_X-1 ; because ball is 2 color clocks wide

MIN_PIXEL_Y = 53 ; Top edge of the playfield.  just a guess right now.
MAX_PIXEL_Y = 230 ; bottom edge after paddle.  lose ball here.

; Ball travel when bouncing from walls and bricks will simply negate 
; the current horizontal or vertical direction.
; Ball travel when bouncing off the paddle will require lookup tables
; to manage angle (and speed changes).
;
; Playfield MIN/MAX travel areas relative to the Paddle.
;
; Paddle travel is only horizontal. But the conversion from paddle 
; value (potentiometer) to paddle Player on screen will have different
; tables based on wide paddle and narrow paddle sizes.
; The paddle also is allowed to travel beyond the left and right sides
; of the playfield far enough that only an edge of the paddle is 
; visible for collision on the playfield.
; The size of the paddle varies the coordinates for this.
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

;  Offset to make binary 0 to 9 into text  
; 48 for PETSCII/ATASCII,  16 for Atari internal
NUM_BIN_TO_TEXT = 16  

; Adjusted playfield width for exaluating paddle position.
; This is needed several times, so is computed once here:
; Screen max X limit is 
; PLAYFIELD_RIGHT_EDGE_NORMAL/$CF -  PLAYFIELD_LEFT_EDGE_NORMAL/$30 == $9F
; Then, this needs to subtract 11 (12-1) for the size of the paddle, == $93.
PADDLE_MAX = (PLAYFIELD_RIGHT_EDGE_NORMAL-PLAYFIELD_LEFT_EDGE_NORMAL-11)


;===============================================================================
;    ZERO PAGE VARIABLES
;===============================================================================
; These will be used when needed to pass extra parameters to 
; routines when you can't use A, X, Y registers for other reasons.
; Essentially, think of these as extra data registers.
;
; Also used as permanent variables with lower latency than regular memory.

; The Atari OS has defined purpose for the first half of Page Zero 
; locations.  Since no Floating Point will be used here we'll 
; borrow the FP registers in Page Zero.

PARAM_00 = $D4 ; ZMR_ROBOTO  -- Is Mr Roboto playing the automatic demo mode? init 1/yes
PARAM_01 = $D6 ; ZDIR_X      -- +1 Right, -1 Left.  Indicates direction of travel.
PARAM_02 = $D7 ; ZDIR_Y      -- +1 Down, -1 Up.  Indicates direction of travel.
PARAM_03 = $D8 ; ZCOLLISION  -- Is Brick present at tested location? 0 = no, 1 = yes
PARAM_04 = $D9 ; ZBRICK_LINE -- coord_Y reduced to line 1-8
PARAM_05 = $DA ; ZBRICK_COL  -- coord_X reduced to brick number 1-14
PARAM_06 = $DB ; ZCOORD_Y    -- coord_Y for collision check
PARAM_07 = $DC ; ZCOORD_X    -- coord_X for collision check  
PARAM_08 = $DD ;   
;
; And more Zero Page fun.  This is assembly, dude.  No BASIC in sight anywhere.
; No BASIC means we can get craaaazy with the second half of Page Zero.
;
; In fact, there's no need to have the regular game variables out in high memory.  
; For starters, all the Byte-sized values are hereby moved to Page 0.
;
PARAM_09 = $80 ; TITLE_STOP_GO - set by mainline to indicate title is working or not.

PARAM_10 = $81 ; TITLE_PLAYING - flag indicates title animation stage in progress. 
PARAM_11 = $82 ; TITLE_TIMER - set by Title handler for pauses.
PARAM_12 = $83 ; TITLE_HPOSP0 - Current P/M position of fly-in letter. or 0 if no letter.
PARAM_13 = $84 ; TITLE_SIZEP0 - current size of Player 0
PARAM_14 = $85 ; TITLE_GPRIOR - Current P/M Priority in title. 
PARAM_15 = $86 ; TITLE_VSCROLL - current fine scroll position. (0 to 7)
PARAM_16 = $87 ; TITLE_CSCROLL - current coarse scroll position. (0 to 4)
PARAM_17 = $88 ; TITLE_CURRENT_FLYIN - current index (0 to 7) into tables for visible stuff in table below.
PARAM_18 = $89 ; TITLE_SCROLL_COUNTER - index into the tables above. 0 to 32
PARAM_19 = $8a ; TITLE_WSYNC_OFFSET - Number of scan lines to drop through before color draw

PARAM_20 = $8b ; TITLE_WSYNC_COLOR - Number of scan lines to do color bars
PARAM_21 = $8c ; TITLE_COLOR_COUNTER - Index into color table
PARAM_22 = $8d ; TITLE_DLI_PMCOLOR - PM Index into TITLE_DLI_PMCOLOR_TABLE
PARAM_23 = $8e ; THUMPER_PROXIMITY/THUMPER_PROXIMITY_TOP
PARAM_24 = $8f ; THUMPER_PROXIMITY_LEFT
PARAM_25 = $90 ; THUMPER_PROXIMITY_RIGHT
PARAM_26 = $91 ; THUMPER_FRAME/THUMPER_FRAME_TOP
PARAM_27 = $92 ; THUMPER_FRAME_LEFT
PARAM_28 = $93 ; THUMPER_FRAME_RIGHT
PARAM_29 = $94 ; THUMPER_FRAME_LIMIT/THUMPER_FRAME_LIMIT_TOP

PARAM_30 = $95 ; THUMPER_FRAME_LIMIT_LEFT
PARAM_31 = $96 ; THUMPER_FRAME_LIMIT_RIGHT
PARAM_32 = $97 ; THUMPER_COLOR/THUMPER_COLOR_TOP
PARAM_33 = $98 ; THUMPER_COLOR_LEFT
PARAM_34 = $99 ; THUMPER_COLOR_RIGHT
PARAM_35 = $9a ; BRICK_SCREEN_START_SCROLL
PARAM_36 = $9b ; BRICK_SCREEN_IMMEDIATE_POSITION
PARAM_37 = $9c ; BRICK_SCREEN_IN_MOTION
PARAM_38 = $9d ; ENABLE_BOOM
PARAM_39 = $9e ; ENABLE_BALL

PARAM_40 = $9f ; BALL_CURRENT_X
PARAM_41 = $a0 ; BALL_CURRENT_Y
PARAM_42 = $a1 ; BALL_HPOS
PARAM_43 = $a2 ; BALL_NEW_X
PARAM_44 = $a3 ; BALL_NEW_Y
PARAM_45 = $a4 ; BALL_COLOR
PARAM_46 = $a5 ; BALL_SPEED_CURRENT_SEQUENCE
PARAM_47 = $a6 ; BALL_SPEED_CURRENT_STEP
PARAM_48 = $a7 ; BALL_BOUNCE_COUNT
PARAM_49 = $a8 ; ENABLE_CREDIT_SCROLL - MAIN: Flag to stop/start scrolling/visible text

PARAM_50 = $a9 ; SCROLL_DO_FADE - MAIN: 0 = no fade.  1= fade up.  2 = fade down.
PARAM_51 = $aa ; SCROLL_TICK_DELAY - MAIN: number of frames to delay per scroll step.
PARAM_52 = $ab ; SCROLL_BASE - MAIN: Base table to start scrolling
PARAM_53 = $ac ; SCROLL_MAX_LINES - MAIN: number of lines in scroll before restart.
PARAM_54 = $ad ; SCROLL_CURRENT_TICK - VBI: Current tick for delay, decrementing to 0.
PARAM_55 = $ae ; SCROLL_IN_FADE - VBI: fade is in progress? 0 = no. 1 = up. 2 = down
PARAM_56 = $af ; SCROLL_CURRENT_FADE - VBI/DLI: VBI set for DLI - Current Fade Start position
PARAM_57 = $b0 ; SCROLL_CURRENT_LINE - VBI: increment for start line of window.
PARAM_58 = $b1 ; SCROLL_CURRENT_VSCROLL -  VBI/DLI: VBI sets for DLI -- Current Fine Vertical Scroll vertical position. 
PARAM_59 = $b2 ; ENABLE_PADDLE

PARAM_60 = $b3 ;   PADDLE_SIZE
PARAM_61 = $b4 ;   PADDLE_HPOS
PARAM_62 = $b5 ;   PADDLE_STRIKE
PARAM_63 = $b6 ;   PADDLE_FRAME
PARAM_64 = $b7 ;   PADDLE_STRIKE_COLOR
PARAM_65 = $b8 ; ENABLE_BALL_COUNTER
PARAM_66 = $b9 ;   BALL_COUNTER
PARAM_67 = $ba ;   BALL_TITLE_HPOS - DLI: Add 8 for PM1 and then same for PM2
PARAM_68 = $bb ;   SINE_WAVE_DELAY
PARAM_69 = $bc ;   BALL_COUNTER_COLOR

PARAM_70 = $bd ; ENABLE_SCORE
PARAM_71 = $be ;   REAL_SCORE_DIGITS
PARAM_72 = $bf ;   DISPLAYED_SCORE_DELAY
PARAM_73 = $c0 ;   DISPLAYED_BALLS_SCORE_COLOR_INDEX
PARAM_74 = $c1 ; ENABLE_SOUND
PARAM_75 = $c2 ;   SOUND_CURRENT_VOICE
PARAM_76 = $c3 ; ZAUTO_NEXT
PARAM_77 = $c4 ; ZBRICK_COUNT  - init 112 (full screen of bricks)
PARAM_78 = $c5 ; ZBRICK_POINTS - init 0 - point value of brick to add to score.
PARAM_79 = $c6 ; ZBALL_COUNT   - init 5

PARAM_80 = $c7 ; 
PARAM_81 = $c8 ;    
PARAM_82 = $c9 ;    
PARAM_83 = $ca ;    
PARAM_84 = $cb ; 
PARAM_85 = $cc ;    
PARAM_86 = $cd ; 
PARAM_87 = $ce ; 
PARAM_88 = $cf ; 
PARAM_89 = $d0 ; 

ZEROPAGE_POINTER_1 = $DE ; 
ZEROPAGE_POINTER_2 = $E0 ; 
ZEROPAGE_POINTER_3 = $E2 ; 
ZEROPAGE_POINTER_4 = $E4 ; 
ZEROPAGE_POINTER_5 = $E6 ; 
ZEROPAGE_POINTER_6 = $E8 ; 
ZEROPAGE_POINTER_7 = $EA ; 
ZEROPAGE_POINTER_8 = $EC ; ZBRICK_BASE   -- Pointer to start of bricks on a line.
ZEROPAGE_POINTER_9 = $EE ; ZTITLE_COLPM0 -- VBI sets for DLI to use

;===============================================================================
;   LOAD START
;===============================================================================

;	*=LOMEM_DOS     ; $2000  ; After Atari DOS 2.0s
;	*=LOMEM_DOS_DUP ; $3308  ; Alternatively, after Atari DOS 2.0s and DUP

; This will not be a terribly big or complicated game.  Begin after DUP.

	*=$3400 

;===============================================================================


;===============================================================================
;   VARIABLES AND DATA
;===============================================================================

ZMR_ROBOTO =  PARAM_00 ; Is Mr Roboto playing the automatic demo mode? init 1/yes

ZDIR_X =      PARAM_01 ; +1 Right, -1 Left.  Indicates direction of travel.
 
ZDIR_Y =      PARAM_02 ; +1 Down, -1 Up.  Indicates direction of travel.

ZCOLLISION =  PARAM_03 ; Is Brick present at tested location? 0 = no, 1 = yes

ZBRICK_LINE = PARAM_04 ; Ycoord reduced to line 1-8

ZBRICK_COL =  PARAM_05 ; Xcoord reduced to brick number 1-14

ZCOORD_Y =    PARAM_06 ; Ycoord for collision check

ZCOORD_XP =   PARAM_07 ; Xcoord for collision check  


; flag when timer counted (29 sec). Used on the
; title and game over  and auto play screens. When auto_wait
; ticks it triggers automatic transition to the 
; next screen.
ZAUTO_NEXT =    PARAM_76 ; .byte 0

ZBRICK_COUNT =  PARAM_77 ; .byte 112 (full screen of bricks, 8 * 14)

ZBRICK_POINTS = PARAM_78 ; .byte $00

ZBALL_COUNT =   PARAM_79 ; .byte $05


ZBRICK_BASE =   ZEROPAGE_POINTER_8 = $EC ; Pointer to start of bricks on a line.

ZTITLE_COLPM0 = ZEROPAGE_POINTER_9 = $EE ; VBI sets for DLI to use




;===============================================================================
;	GAME INTERRUPT INCLUDES
;===============================================================================

	.include "vbi.asm"

	.include "dli.asm"


;===============================================================================
;   MAIN GAME CONTROL LOOP
;===============================================================================

;===============================================================================
; Program Start/Entry.  This address goes in the DOS Run Address.
;===============================================================================
PRG_START 


	jsr setup  ; setup graphics


FOREVER
	jmp FOREVER


	; ========== TITLE SCREEN ==========

do_title_screen
	jsr clear_sound  ; zero residual mr roboto after effects
	jsr display_title

	jsr reset_delay_timer
do_while_waiting_title
	jsr check_event
	; 0 means nothing unusual happened.
	; 1 means auto_next timer happened.  (Mr roboto can be enabled).
	; 2 means button was released.  (Mr roboto can be disabled).
	beq do_while_waiting_title ; 0 is no event

	cmp #2 ; button pressed?
	bne start_mr_roboto ; no button.  try the timer to start Mr Roboto.
	beq do_player_start ; Yes?  then continue by  running player.

start_mr_roboto	; timer ended? so Mr Roboto wakes up for work
	lda last_event
	cmp #1  ; by this point this should be true.
	bne do_player_start ; not the timer.  go go player.
	inc ZMR_ROBOTO  ; timer expired, so enable mr_roboto
	bne do_start_game
	
do_player_start ; make sure roboto is not playing.
	lda #0;
	sta ZMR_ROBOTO

	; ========== GAME INITIALIZATION ==========

do_start_game	
	jsr start_game ; initialize beginning of game.
	
	; ========== GAME EVENT CHECK -- PLAY MR ROBOTO OR NOT ==========

	jsr reset_delay_timer
do_while_gameplay
	jsr check_event
	; button and timer events matter if mr_roboto is playing
	beq do_play_game ;nothing special, continue game

	lda ZMR_ROBOTO ; button or timer expired and check if
	beq do_play_game ; mr roboto not running, so it doesn't matter

	lda last_event
	cmp #2 ; check for key press
	beq skip_attract ; We exit because of button.
	bne end_loop_roboto_attract ; Time expired. exit and turn on attract mode 

	; ========== GAME PLAY ==========

do_play_game	
	jsr game_cycle
	lda game_over_flag
	beq do_while_gameplay

	; ========== GAME OVER ==========

	jsr game_over
	
	jsr reset_delay_timer
do_while_waiting_game_over
	jsr check_event
	beq do_while_waiting_game_over
	
	cmp #2 ; if a key was pressed we are returning 
	beq skip_attract
	bne check_mr_roboto_employment
	
	; If Mr Roboto is not at work, skip turning on attract mode.
check_mr_roboto_employment	
	lda ZMR_ROBOTO
	beq skip_attract

	; if mr roboto is at work intentionally turn on the attract mode on...	
end_loop_roboto_attract
	lda #$fe  ; force attract mode on
	sta ATRACT

skip_attract
	jmp do_title_screen  ; do while more electricity

	rts ; never reaches here.


;===============================================================================
;   Basic setup. Stop sound. Create screen.
;===============================================================================
setup
; Make sure 6502 decimal mode is not set -- not  necessary, 
; but it makes me feel better to know this is not on.
	cld

	jsr clear_sound ; Turn off all audio.

	lda #COLOR_BLACK
	sta COLOR4 ; COLBAK background and border for multi-color text mode

; Before we can really get going, Atari needs to set up a custom 
; screen to imitate what is being used on the C64.

	jsr AtariStopScreen ; Kill screen DMA, kill interrupts, kill P/M graphics.

	jsr WaitFrame ; Wait for vertical blank updates from the shadow registers.

	jsr AtariStartScreen ; Startup custom display list, etc.

	rts 

; Setup_Sprites:
; C64 is using a paddle image that is 13 high-res pixels 
; wide in double width to make it 13 med-res pixels wide.
; It also uses double height, so the four lines of data
; work out to 8 scan lines.
;
; ;paddle 12x4 top left corner
; xxxxxxxxxxxxx (13 pixels) (repeated four times):
;        byte $ff,$f8
; (this would be 12 pixels if the data was $ff, $f0.)
 
; On Atari this is roughly the same as 12 color clocks. 
; Since a normal Player is 8 color clocks wide, we also
; need to double the width of the Atari Player to make 
; an image that covers 12 color clocks. 

setup_sprites
	;===== paddle =====
	; A double width Player will make a 6-bit wide image for 
	; Atari ($FC bitmap pattern) cover 12 color clocks.

	lda #PM_SIZE_DOUBLE ; actual value is 1 which is same as C64.
	sta SIZEP0 ; double width for Player 0

	; Note that the "double height" will be handled on the Atari by 
	; supplying more image data for the Player.

	lda #COLOR_LITE_BLUE+$08
	sta PCOLOR0 ; COLPM0 Player 0 color.
	lda #84 ; set x coord 
	sta HPOSP0 ; Player 0 Horizontal position

	; On Atari Y position and image are handled by copying  
	; the image data into the Player bitmap.

	jsr AtariSetPaddleImage ; Do image setup at Y position for Atari

	;===== ball =====
	lda #COLOR_GREY+$0F
	sta PCOLOR1 ; COLPM1 Player 1 color.

	jsr reset_ball ; handle initial ball placement

	rts


;===============================================================================
;   MAIN GAME CYCLE
;===============================================================================
game_cycle
	; The paddle control/movement is only 
	; called once, because the Atari version 
	; is using a real paddle.  
	; It was originally called twice to allow the 
	; keyboard/joystick controls to move the 
	; paddle faster than the ball.
	lda ZMR_ROBOTO ; auto play on?
	bne autobot;
	jsr move_paddle ; otherwise do player movement.
	clc
	bcc game_checks

autobot
	jsr auto_paddle
	jsr auto_paddle
	
game_checks  
	jsr move_ball
	jsr check_sprite_collision
	jsr check_sprite_background_collision

	rts

;===============================================================================
; ===== Atari ======
; Player specs...
; ===== HORIZONTAL ======
; Minimum X == $30.
; Maximum X == $CF.
; $CF - Player Width ($0C) + 1 == $C4
; $C4 - $30 == range 00 to $94
;
; Pot controller == range $00 to $E4
;
; Therefore...
; It is safe to clip paddle value to 
; fit the screen.
;===============================================================================


;===============================================================================
;   MOVE PADDLE
;===============================================================================
move_paddle
	lda PADDL0; ; Atari -- using real paddles (or the mouse in an emulator)

; FYI: Screen limit is 
; PLAYFIELD_RIGHT_EDGE_NORMAL/$CF -  PLAYFIELD_LEFT_EDGE_NORMAL/$30 == $9F
; Then, this needs to subtract 11 (12-1) for the size of the paddle, == $93.
; PADDLE_MAX = (PLAYFIELD_RIGHT_EDGE_NORMAL-PLAYFIELD_LEFT_EDGE_NORMAL-11)

	cmp #PADDLE_MAX ; is paddle value bigger than screen limit?
	bcc paddle_ok ; No, so adjust for Player/missile horizontal placement
	lda #PADDLE_MAX ; Yes, clip to the limit
paddle_ok
	sta PADDLE_PLAYER_X  ; Save it temporarily.
	clc ; subtract/invert X direction
	lda #PADDLE_MAX
	sbc PADDLE_PLAYER_X
	clc ; and then readjust to the left minimum coordinate
	adc #PLAYFIELD_LEFT_EDGE_NORMAL
	sta PADDLE_PLAYER_X
	sta HPOSP0 ; store in Player position hardware register

	rts


auto_paddle
	lda BALL_PLAYER_X ; Atari current Ball X position
	cmp PADDLE_PLAYER_X ; Atari current Paddle X position
	bcc move_paddle_left ;a less than x
	bcs move_paddle_right ;a greater or equal x

	rts


.local
move_paddle_left
	lda PADDLE_PLAYER_X ; Get current paddle x position
	cmp #PLAYFIELD_LEFT_EDGE_NORMAL ; Minimum/left limit
	beq ?hit_left_wall
	dec PADDLE_PLAYER_X ; minus moves left
	lda PADDLE_PLAYER_X ; get new value
	sta HPOSP0 ; store in Player position hardware register

?hit_left_wall
	
	rts


.local
move_paddle_right
	lda PADDLE_PLAYER_X ; Get current paddle x position
	cmp #(PLAYFIELD_RIGHT_EDGE_NORMAL-11) ; Maximum/right limit
	beq ?hit_right_wall
	inc PADDLE_PLAYER_X ; plus moves right
	lda PADDLE_PLAYER_X ; get new value
	sta HPOSP0 ; store in Player position hardware register

?hit_right_wall

	rts  


;===============================================================================
;   MOVE BALL
;===============================================================================
move_ball
	jsr move_ball_horz
	jsr move_ball_vert
	rts


move_ball_horz
	lda ZDIR_X
	beq move_ball_left
	jsr move_ball_right
	rts


move_ball_vert
	lda ZDIR_Y
	beq moveball_up
	jsr moveball_down
	rts


.local
move_ball_left
	dec BALL_PLAYER_X ; Move left
	lda BALL_PLAYER_X ; get value
	sta HPOSP1 ; Move player
	cmp #$30 ; Hit the border?
	beq ?hit_left_wall ; Yes, then rebound
	rts
	
?hit_left_wall
	lda #1
	sta ZDIR_X
	jsr sound_wall
	
	rts


.local
move_ball_right
	inc BALL_PLAYER_X ; Move right
	lda BALL_PLAYER_X ; get value
	sta HPOSP1 ; Move player
	cmp #$CC ; Hit the border? ($CF - 5 pixel width)
	beq ?hit_right_wall
	
	rts
	
?hit_right_wall
	lda #0
	sta ZDIR_X
	jsr sound_wall
	
	rts


moveball_up
	jsr AtariPMRippleUp ; dec position and redraw
	lda BALL_PLAYER_Y

	cmp #(PM_1LINE_NORMAL_TOP-4) ; Normal top of playfield
	beq hit_ceiling
	
	rts
	
hit_ceiling
	lda #1
	sta ZDIR_Y
	jsr sound_wall
	
	rts


moveball_down
	jsr AtariPMRippleDown ; inc position and redraw
	lda BALL_PLAYER_Y
	cmp #220
	beq hit_floor
	
	rts
	
hit_floor
	jsr sound_bing ; Buzzer for drop ball

	dec ZBALL_COUNT ;update ball count
	jsr display_ball_count
	lda ZBALL_COUNT
	bne continue_game

	inc game_over_flag ; tell game loop we're over.

continue_game
	jsr reset_ball

	rts


;===============================================================================
;   G A M E   O V E R
;===============================================================================
game_over
; On Atari just move 
; players off screen...
	jsr AtariMovePMOffScreen

	loadPointer ZEROPAGE_POINTER_1, GAME_OVER_TEXT                               
	lda #10                          
	sta PARAM1                      
	lda #13
	sta PARAM2                      
	jsr DisplayText
	
	jsr display_start_message

	rts


.local        
;===============================================================================
;   CHECK FOR BALL/PADDLE SPRITE COLLISION
;===============================================================================
check_sprite_collision
	lda P1PL ; Player 1 to player collision
	and #COLPMF0_BIT ; Player 1 to Player 0
	beq exit_check_sprite_collision

?is_collision
	sta HITCLR ; reset collision -- any write will do
	lda #0
	sta ZDIR_Y
	jsr sound_paddle

exit_check_sprite_collision
	rts


.local
;===============================================================================
;   CHECK FOR BALL/BACKGROUND COLLISION
;===============================================================================
check_sprite_background_collision
	lda P1PF ; Player 1 to Playfield collisions
	and #(COLPMF0_BIT|COLPMF1_BIT|COLPMF2_BIT|COLPMF3_BIT) ; all four colors
	beq ?no_collision

?is_collision
	jsr calc_ball_xchar
	jsr calc_ball_ychar
		
	ldx  ychar ; get base address for the current Y line
	lda SCREEN_LINE_OFFSET_TABLE_LO,x 
	sta ZEROPAGE_POINTER_1
	lda SCREEN_LINE_OFFSET_TABLE_HI,x 
	sta ZEROPAGE_POINTER_1 + 1

	ldy xchar ; Y is the offset in X chars
	lda (ZEROPAGE_POINTER_1),y ; read the character under the ball.

	jsr check_is_brick ; figure out if A is a brick?
	lda ZCOLLISION 
	beq ?no_collision ; if so, then no collision

	;calc x,y parms to erase brick
	lda xchar
	sec
	lsr     ;/2
	lsr     ;/4 
	asl     ;*2
	asl     ;*4
	sta PARAM1
	lda ychar
	sec
	sbc #3  ;brick rows start on 4th line
	lsr     ;/2 (bricks are 2 char high)
	asl     ;*2
	adc #3
	sta PARAM2
	jsr erase_brick

	sta HITCLR ; reset collision -- any write will do
	;flip vertical direction
	lda ZDIR_Y
	eor #~00000001 ; Atari atasm syntax 
	sta ZDIR_Y
	;move ball out of collision
	jsr move_ball_vert 
	jsr move_ball_vert
	jsr move_ball_vert
	jsr move_ball_vert
	jsr sound_bounce
	jsr calc_brick_points

	;update brick count
	ldx ZBRICK_COUNT
	dex
	stx ZBRICK_COUNT
	;check is last brick
	cpx #0
	bne ?no_collision
	jsr reset_playfield

?no_collision

	rts

		
;===============================================================================
;   CALCULATE POINTS SCORE
;       outputs point value to "ZBRICK_POINTS"
;       calls routines to update score total "add_score"
;       and display updated score "display_score"
;===============================================================================
calc_brick_points
	clc
	lda ychar  ; Y "character" position of ball
	cmp #9
	bcs point_yellow 
	cmp #7
	bcs point_green
	cmp #5
	bcs point_orange
	cmp #3
	bcs point_red
	rts
point_yellow
	lda #1
	jmp save_brick_points      
point_green
	lda #3
	jmp save_brick_points       
point_orange
	lda #5
	jmp save_brick_points     
point_red
	lda #7
	jmp save_brick_points      
save_brick_points
	sta ZBRICK_POINTS
	jsr add_score
	jsr display_score

	rts


;===============================================================================
;   RESET PLAYFIELD
;===============================================================================
reset_playfield
	jsr draw_playfield
	
	lda #112 ; (8 rows * 14 bricks)
	sta ZBRICK_COUNT
	
	jsr display_score
	
	jsr reset_ball
	
	lda #1
	sta ZDIR_Y
	
	jsr move_ball_vert

	rts


.local
;===============================================================================
;   RESET BALL 
;===============================================================================
reset_ball
	jsr AtariClearBallImage ; Erase ball image at last Y position
; Since the ball is "animated" (i.e. it moves in X and Y directions)
; the Atari version combines initializing the X and Y of 
; the ball image into a function...
	lda #90 ; Set X coordinate
	ldy #128  ; set y coordinate
	jsr AtariSetBallImage ; Draw ball image at A, Y positions.

	lda #1 ;set ball moving downward
	sta ZDIR_Y

	rts


display_char_coord
	lda #<CHAR_COORD_LABEL                
	sta ZEROPAGE_POINTER_1          
	lda #>CHAR_COORD_LABEL               
	sta ZEROPAGE_POINTER_1 + 1                                 
	lda #15                          
	sta PARAM1                      
	lda #24
	sta PARAM2                      
	jsr DisplayText
	
	ldx #24
	ldy #17
	lda xchar
	jsr DisplayByte
	
	ldx #24
	ldy #22
	lda ychar
	jsr DisplayByte

	rts


.local
;===============================================================================
;   CALCULATE THE BALL'S X CHARACTER CO-ORDINATE
;===============================================================================
; for Atari that's xchar = ( Player X - left ) / 4
;===============================================================================
calc_ball_xchar
	lda BALL_PLAYER_X
	sec
	sbc #PLAYFIELD_LEFT_EDGE_NORMAL ; minus Left border position ($30)
	lsr     ;/2
	lsr     ;/4   Atari has four color clocks per character 
	sta xchar

	rts


;===============================================================================
;   CALCULATE THE BALLS Y CHARACTER CO-ORDINATE
;===============================================================================
; ychar = (sprite0_y - top) / 8
;===============================================================================
calc_ball_ychar
	lda BALL_PLAYER_Y
	sec
	; displayable top of screen.
	; For Atari this is the top of the standard screen, minus
	; four scan lines for the extra, 25th line of text.
	sbc #(PM_1LINE_NORMAL_TOP-4) 
	lsr
	lsr
	lsr
	sta ychar

	rts


;===============================================================================
;   CHECK CHAR IS A BRICK CHARACTER
;===============================================================================
; Register A holds character code to check
; output boolean value to 'ZCOLLISION'
; 0 = false , 1 = true
;===============================================================================
; From the Atari perspecive, blank spaces are 0, and
; anything not a blank is non-zero.  Therefore any
; non-zero character is a brick.

check_is_brick
	pha  ; save A 
	lda #0
	sta ZCOLLISION
	pla ; restore A

	bne is_a_brick ; Atari -- any non-zero is a brick.

	rts

is_a_brick
	pha  ; save A 
	lda #1
	sta ZCOLLISION
	pla ; restore A

	rts


;===============================================================================
;   START GAME 
;===============================================================================
; reset everything about the game.
; clear sound
; draw game playfield
; start sprites
; reset brick count 
; zero score 
; set new ball count
;===============================================================================
start_game
	lda #$00 ; Atari blank space internal code
	jsr ClearScreen
	
	jsr clear_sound
	jsr draw_playfield
	jsr setup_sprites
	jsr reset_ball

	lda #112 ; (8 rows * 14 bricks)
	sta ZBRICK_COUNT

	lda #0
	sta game_over_flag
	
	sta score
	sta score+1
	jsr DisplayScore
	
	lda #5
	sta ZBALL_COUNT
	jsr DisplayBall

	rts


;===============================================================================
;   DRAW PLAYFIELD
;===============================================================================
draw_playfield
	lda #3
	sta PARAM2                      
	lda #0 ; Atari -- Row text 0 red
	sta PARAM3 ; repurpose for row text entry
	jsr draw_brick_row

	lda #5
	sta PARAM2                      
	lda #1 ; Atari -- Row text 1 orange
	sta PARAM3 ; repurpose for row text entry
	jsr draw_brick_row

	lda #7
	sta PARAM2                      
	lda #2 ; Atari -- Row text 2 green  
	sta PARAM3 ; repurpose for row text entry
	jsr draw_brick_row

	lda #9
	sta PARAM2                      
	lda #3 ; Atari -- Row text 3 yellow
	sta PARAM3 ; repurpose for row text entry
	jsr draw_brick_row

	rts


; A random thought... 
; The digits to screen conversion would work out 
; easier if the individual digits were kept in 
; separate bytes and not BCD packed. Altering 
; this would be a mod for beta version.

add_score
	sed
	clc
	lda score
	adc ZBRICK_POINTS
	sta score
	bcc ?return
	lda score+1
	adc #0
	sta  score+1       
?return
	cld
	
	rts


;===============================================================================
; DISPLAY SCORE
;===============================================================================
DisplayScore   ;display the score label
	lda #<SCORE_LABEL                
	sta ZEROPAGE_POINTER_1          
	lda #>SCORE_LABEL               
	sta ZEROPAGE_POINTER_1 + 1                                 
	lda #30                          
	sta PARAM1                      
	lda #24
	sta PARAM2                      
;	lda #COLOR_WHITE  
;	sta PARAM3
	jsr DisplayText
	
	jsr display_score

	rts
	
	
display_score
	;hi byte
	lda score+1
	pha ;store orginal value
	lsr ;shift out the first digit
	lsr
	lsr
	lsr
	clc
	adc #NUM_BIN_TO_TEXT ; add offset for binary 0 to text 0
	sta SCREEN_MEM+$3E4
	
	pla ;get orginal value
	and #~00001111 ; mask out last digit
	clc
	adc #NUM_BIN_TO_TEXT ; add offset for binary 0 to text 0
	sta SCREEN_MEM+$3E5

	;lo byte 
	lda score
	pha
	lsr ; /2
	lsr ; /4
	lsr ; /8
	lsr ; /16
	clc
	adc #NUM_BIN_TO_TEXT ; add offset for binary 0 to text 0
	sta SCREEN_MEM+$3E6
	
	pla
	and #~00001111 ; Atari atasm syntax
	clc
	adc #NUM_BIN_TO_TEXT ; add offset for binary 0 to text 0
	sta SCREEN_MEM+$3E7
	rts


display_ball_count
	clc
	lda ZBALL_COUNT
	adc #NUM_BIN_TO_TEXT ; add offset for binary 0 to text 0
	sta SCREEN_MEM+$3C5

	rts


DisplayBall
;display the ball label
	lda #<BALL_LABEL                
	sta ZEROPAGE_POINTER_1          
	lda #>BALL_LABEL               
	sta ZEROPAGE_POINTER_1 + 1                                 
	lda #0                          
	sta PARAM1                      
	lda #24
	sta PARAM2                      
	jsr DisplayText
	
	jsr display_ball_count

	rts


;===============================================================================
; DRAW A ROW OF BRICKS
;===============================================================================
; PARAM2 = Y
; PARAM3 = Color
; Instead, PARAM3 == row text entry
draw_brick_row
	lda #0                          
	sta PARAM1
	lda PARAM2
	sta brick_row
	
draw_brick_row_loop
	lda brick_row
	sta PARAM2
	jsr draw_brick
	clc        
	lda PARAM1
	adc #4
	sta PARAM1
	cmp #40
	bne draw_brick_row_loop

	rts


;===============================================================================
; DRAW A SINGLE BRICK
;===============================================================================
; PARAM1 = X
; PARAM2 = Y
; PARAM3 =  row text entry
;===============================================================================
draw_brick
	ldx PARAM3  ; which brick type     
	lda BRICK_TEXT_LO,x  
	sta ZEROPAGE_POINTER_1          
	lda BRICK_TEXT_HI,x
	sta ZEROPAGE_POINTER_1 + 1
	jsr DisplayText

	rts


erase_brick
	lda #<ERASE_BRICK_TEXT
	sta ZEROPAGE_POINTER_1          
	lda #>ERASE_BRICK_TEXT               
	sta ZEROPAGE_POINTER_1 + 1
	jsr DisplayText

	rts


;===============================================================================
; DISPLAY TITLE SCREEN
;===============================================================================
display_title
	jsr AtariMovePMOffScreen ; Make Players invisible by moving them off screen.

	lda #$00 ; On Atari internal code for blank space is 0.
	jsr ClearScreen
							   
	loadPointer ZEROPAGE_POINTER_1, TITLE1
	lda #1                          
	sta PARAM1                      
	lda #3
	sta PARAM2                      
	jsr DisplayText
										
	loadPointer ZEROPAGE_POINTER_1, TITLE2
	lda #1                          
	sta PARAM1                      
	lda #5
	sta PARAM2                      
	jsr DisplayText
							   
	loadPointer ZEROPAGE_POINTER_1, TITLE3
	lda #1                          
	sta PARAM1                      
	lda #7
	sta PARAM2                      
	jsr DisplayText
							 
	loadPointer ZEROPAGE_POINTER_1, TITLE4
	lda #1                          
	sta PARAM1                      
	lda #9
	sta PARAM2                      
	jsr DisplayText

	loadPointer ZEROPAGE_POINTER_1, CREDIT1_TEXT
	lda #5                       
	sta PARAM1                      
	lda #14
	sta PARAM2                      
	jsr DisplayText

	loadPointer ZEROPAGE_POINTER_1, CREDIT2_TEXT
	lda #4                        
	sta PARAM1                      
	lda #17
	sta PARAM2                      
	jsr DisplayText

	jsr display_start_message

	rts


display_start_message                                
	loadPointer ZEROPAGE_POINTER_1, START_TEXT
	lda #10                         
	sta PARAM1                      
	lda #21
	sta PARAM2                      
	jsr DisplayText
	
	rts


;===============================================================================
; Test Button Press/Button Release.
;===============================================================================

JoyButton
	lda #1 ; checks for a previous button action
	cmp BUTTON_RELEASED ; and clears it if set
	bne ?buttonTest
	lda #0                                  
	sta BUTTON_RELEASED
	
?buttonTest
	lda PTRIG0 ; Paddle trigger read by Atari OS vertical blank
	bne ?buttonNotPressed ; Not 0 is not pressed -- same for Atari
	lda #1   ; if it's pressed - save the result
	sta BUTTON_PRESSED ; and return - we want a single press
	rts      ; so we need to wait for the release

?buttonNotPressed
	lda BUTTON_PRESSED ; and check to see if it was pressed first
	bne ?buttonAction  ; if it was we go and set BUTTON_ACTION
	rts
	
?buttonAction
	lda #0
	sta BUTTON_PRESSED
	lda #1
	sta BUTTON_RELEASED
	;	button was pressed, so turn off Attract Mode
	lda #$00
	sta ATRACT

	rts



;===============================================================================
; Check for button press or auto_next timer.
;
; 0 means noting unusual happened.
;
; 1 means auto_next timer happened.  (mr roboto could be enabled)
;
; 2 means button was released.  (mr roboto can be disabled).
;
;===============================================================================
check_event
	jsr WaitFrame

	lda auto_next
	beq skip_auto_advance
	jsr reset_delay_timer
	
	lda #1 ; auto advance event
	sta last_event
	rts  

skip_auto_advance
	; If button was pressed then human player is playing.
	jsr JoyButton
	lda BUTTON_RELEASED
	beq no_input
	
	lda #2
	sta last_event
	rts

no_input	
	lda #0 ; No input or change occurred.
	sta last_event
	rts


;===============================================================================
; pause_1_sec
;
; Wait for a second to give the player time to release the 
; button after switching screens.
;===============================================================================
pause_1_second

	jsr reset_timer ; and reinitialize the timer.
wait_a_second
	lda RTCLOK+2
	cmp #60
	bne wait_a_second

	rts
	
	
;===============================================================================
; reset_delay_timer
;
; Clear the 29 second wait timer.
;===============================================================================
reset_delay_timer
	lda #0 ; zero the event flag.
	sta auto_next
	jsr reset_timer ; and reinitialize the timer.
	rts
	
	
;===============================================================================
; reset_timer
;===============================================================================
reset_timer
	lda #0	; reset real-time clock
	sta RTCLOK+2;
	sta RTCLOK+1;
	rts
	
	
;===============================================================================
; VBL WAIT
;===============================================================================
; Wait for the raster to reach line $f8 - if it's aleady there, wait for
; the next screen blank. This prevents mistimings if the code runs too fast
;===============================================================================
; The Atari OS already maintains a clock that ticks every vertical 
; blank.  So, when the clock ticks the frame has started.
; Alternatively, (1) we could also do this like the C64 and monitor 
; ANTIC's VCOUNT to wait for a specific screen position lower on 
; the screen.
; Alternatively (2) If the purpose is to synchronize code to begin 
; executing at the bottom of the frame that code goes in a Vertical
; Blank Interrupt.
; But, here we're just keeping it simple.
;
; And, every time this executes, run the sound service to play any
; audio updates currently in progress.
;===============================================================================
WaitFrame

	lda RTCLOK60			; get frame/jiffy counter
WaitTick60
	cmp RTCLOK60			; Loop until the clock changes
	beq WaitTick60

	; if the real-time clock has ticked off approx 29 seconds,  
	; then set flag to notify other code.
	lda RTCLOK+1;
	cmp #7	; Has 29 sec timer passed?
	bne skip_29secTick ; No.  So don't flag the event.
	inc auto_next	; flag the 29 second wait
	jsr reset_timer

skip_29secTick

	lda ZMR_ROBOTO ; in auto play mode?
	bne exit_waitFrame ; Yes. then exit to skip playing sound.

	lda #$00  ; When Mr Roboto is NOT running turn off the "attract"
	sta ATRACT ; mode color cycling for CRT anti-burn-in
	
	jsr AtariSoundService ; Play sound in progress if any.

exit_waitFrame
	rts


.local
;===============================================================================
; MAIN STOP TITLE
;===============================================================================
; Turn off the Title animation.
;===============================================================================
; A  modified.
;===============================================================================
; Set flag referenced by VBI to start/stop animation of the Title line.
;===============================================================================

MainStopTitle

	lda #0
	sta TITLE_STOP_GO
	
	rts


	
.local
;===============================================================================
; MAIN SET INITIAL BRICK POSITIONS
;===============================================================================
; Determine Horizontal Scroll Directions for each line.
; Set HSCROLL per line for each line of graphics.
; Set Display List LMS to corresponding starting position on each line.
;===============================================================================
; 
;===============================================================================
; * By default, the at rest or static position of the screen is 
;   always the center screen at LMS offset +20 on every line.
; * The expectation here is that the center screen is empty
;   and the new screen bricks are being introduced.
; * Placing a new screen of bricks requires updating screen data
;   and setting the lines to left or right line positions while
;   the bricks are NOT being displayed.  
;   (This should not be too hard since the bulk of the brick section 
;    is monopolized by a long running DLI, so MAIN line code won't get 
;    much working time until after the DLI.)
; * To animate bricks
;   - write the brick pattern into the center position, and 
;   - set all other scroll parameters, and
;   - reset the LMS to the offscreen position
;===============================================================================

MainSetInitialBrickPositions

	saveRegs ; Save regs so this is non-disruptive to caller

	lda RANDOM                   ; choose random Canned direction table entries.
	and #$38                     ; Resulting value 00, 08, 10, 18, 20, 28, 30, 38
	sta PARAM_89 ; Direction     ; save to use later.
	
	lda RANDOM                   ; choose random canned speed table entries.
	and #$18                     ; Resulting value 00, 08, 10, 18
	sta PARAM_88 ; Speed         ; save to use later.
	
	bne SkipChooseScrollDelay    ; If Speed is not 0 then don't pick random delay.
	
	lda PARAM_89 ; Direction     ; If direction is not 00 or 08 then don't pick random delay.
	cmp #$09
	bcs SkipChooseScrollDelay
	
	lda RANDOM
	and #$38                     ; Resulting value 00, 08, 10, 18, 20, 28, 30, 38
	sta PARAM_87 ; Delay         ; save to use later.
	
	clc
	bcc ?BeginInitScrollLoop
	
SkipChooseScrollDelay
	lda #0
	sta PARAM_87 ; Delay         ; save to use later.

	
?BeginInitScrollLoop
	ldx #0  ; Brick Row.  0 to 7.  (otherwise the TABLES need to be flipped in reverse)

InitBrickPositions
	stx PARAM_86 ; Row           ; Need to reload X later
	
	ldy PARAM_89 ; Direction
	lda TABLE_CANNED_BRICK_DIRECTIONS,y ; Get direction per canned list for the row.
	sty BRICK_SCREEN_DIRECTION,x ; Save direction -1, +1 for row.
	
	iny                          ; Now direction is adjusted to 0, 2

	lda BRICK_SCREEN_HSCROL,y    ; Get starting hscroll position per scroll direction.
	sta BRICK_CURRENT_HSCROL,x   ; Set for the current row.
	
	lda BRICK_LMS_OFFSETS,x      ; Get LMS low byte offset per the row.
	tax
	lda BRICK_SCREEN_LMS,y       ; Get Starting LMS position per scroll direction.
	sta BRICK_BASE,x             ; Set low byte of LMS to move row
	
	ldx PARAM_86 ; Row           ; Get the row number back.

	ldy PARAM_88 ; Speed
	lda TABLE_CANNED_BRICK_SPEED,y ; Get speed per canned list for the row.
	sta BRICK_SCREEN_HSCROL_MOVE,x ; Set for the current row.
	
	ldy PARAM_87 ; Delay
	lda TABLE_CANNED_BRICKS_DELAY,y ; Get delay per canned list for the row.
	sta BRICK_SCREEN_MOVE_DELAY,x   ; Set for the current row.
	
	inx                             ; Increment to the next row.
	cpx #8                          ; Reached the end?
	beq EndInitBrickPositions       ; Yes. Exit.
	
	; Not the end.  Increment everything else.
    
    inc PARAM_89 ; Direction
    inc PARAM_88 ; Speed
    inc PARAM_87 ; Delay
    
    clc
    bcc InitBrickPositions         ; Loop again.

EndInitBrickPositions

	safeRTS ; restore regs for safe exit


.local
;===============================================================================
; DISPLAY BYTE of data
;===============================================================================
; Displays a byte of data at a specified screen coordinate 
; in two-digit hex (0-F) format.
;===============================================================================
; X = screen line  
; Y = screen column  
; A = byte to display
; MODIFIES : ZEROPAGE_POINTER_1, ZEROPAGE_POINTER_3, PARAM_99
;===============================================================================
; Yes, "X" and "Y" appears to be flipped around.  But, this is done
; to allow the "X" to use indexed indirect addressing in the Y register.
;===============================================================================

DisplayByte

	sta PARAM_89                                    ; store the byte to retrieve later

	saveRegs ; Save regs so this is non-disruptive to caller

	lda SCREEN_LINE_OFFSET_TABLE_LO,x               ; look up the address for the screen line
	sta ZEROPAGE_POINTER_1                          ; store lower byte for address for screen
	lda SCREEN_LINE_OFFSET_TABLE_HI,x               ; store high byte for screen
	sta ZEROPAGE_POINTER_1 + 1

	lda PARAM_89                                    ; load the byte to be displayed

	lsr  ; divide by 16 to shift it into the low nybble ( value of 0-F)
	lsr
	lsr
	lsr
	tax 
	lda NYBBLE_TO_HEX,x  ; simplify. no math.  just lookup table.

	sta (ZEROPAGE_POINTER_1),y                      ; write the character code
	iny                                             ; in left to right order.
	lda PARAM_89                                    ; re-fetch the byte to display
									  
	and #$0F                                        ; low nybble is second character
	tax
	lda NYBBLE_TO_HEX,x  ; simplify. no math.  just lookup table.

	sta (ZEROPAGE_POINTER_1),y                      ; write character

	safeRTS ; restore regs for safe exit

NYBBLE_TO_HEX ; Values in Atari format
	.SBYTE "0123456789ABCDEF"


.local
;===============================================================================
; SOUND EFFECTS
;===============================================================================

sound_bing  ; bing/buzz on drop ball
	ldy #$01 ; index to bing sound in sound tables.
	jsr SetNewSound

	rts


sound_bounce ; hit a brick.
	ldy #$0E ; index to bounce sound in sound tables.
	jsr SetNewSound

	rts


sound_wall
	ldy #$1b ; index to bounce sound in sound tables.
	jsr SetNewSound

	rts
	
	
sound_paddle
	ldy #$28 ; index to bounce sound in sound tables.
	jsr SetNewSound

	rts


;===============================================================================
; CLEAR ALL SOUND
;===============================================================================
; Zero all sound voices. 
; Zero the sequencer table entries.
; Reset the Audio Control.
;===============================================================================
; The safest way to call this is to clear ENABLE_SOUND first to stop the 
; Veritcal Blank sequencer, OR to be 100% certain that this code will not be
; interrupted by the VBI. 
;===============================================================================

ClearAllSound

	ldy #7 ; four channels, frequency (AUDFx) and control (AUDCx)
	lda #0

?loop
	sta SOUND_INDEX,y ; turn off any sound in progress in the queue.
	sta AUDF1,y ; AUDFx and AUDCx  1, 2, 3, 4.
	dey
	bne ?loop

	lda #AUDCTL_CLOCK_64KHZ ; Set only this one bit for clock. (though, technically 0)
	sta AUDCTL ; Audio Control

	rts

	
.local
;===============================================================================
; SET NEW SOUND
;===============================================================================
; Start playing a new sound.
;===============================================================================
; Y = Index to sound table to add.
; MODIFIES : 
;===============================================================================
; Sound is distributed in round robin to each of the four sound channels 
; in order 1, 2, 3, 4. (or 0, 1, 2, 3, or actually, 0, 2, 4, 6 index values
; which allows the same index to pick the sound channel, and correctly offset
; the channel's control and frequency registers in POKEY.  
; Given the rate of new sounds introduced to the queue in most cases this 
; rotation allows previously queued sounds to finish playing before the 
; sound channel must be re-used for a new sound.
;===============================================================================

SetNewSound

	saveRegs ; put CPU flags and registers on stack

	lda ENABLE_SOUND        ; Is sound turned on?
	beq ExitSetNewSound     ; No.  Exit.
	
	ldx SOUND_CURRENT_VOICE ; Get the current channel index.
	sty SOUND_INDEX,x       ; Set the channel to the new sound index.
	
	inx                     ; Double increment channel index  for next channel.
	inx 
	cpx #8                  ; Exceeded max?
	bne SetNextChannelIndex ; No. 
	ldx #0                  ; Yes.  Reset to 0.
	
SetNextChannelIndex
	stx SOUND_CURRENT_VOICE ; Save the new channel index.
	
ExitSetNewSound
	safeRTS ; restore registers and CPU flags, then RTS

	
.local
;===============================================================================
; UPDATE SCORE
;===============================================================================
; Update the real score for the game.  Add the value of the brick 
; that was hit/removed from display to the player's score.  
; Notes:
; To facilitate simple translation between value and screen display 
; the score is managed by single bytes holding each place value
; from 0 to 9.  When values are added the maximum value of a byte
; is 9 and if larger, a decimal carry occurs to the next byte. 
; The score is stored in memory low to hi byte/digit position rather 
; than the way it would be displayed on screen.  This simplifies code here.
; The score shown on screen is a shadow of this value. The screen 
; score is animated by incrementing every few frames until it matches 
; the real score established here.
;===============================================================================
; Input: 
; ZBRICK_POINTS: Value of brick to add to score.
; 
; Output:
; REAL_SCORE:        Actual, current score. 
; REAL_SCORE_DIGITS: Current number of digits in use. 
;===============================================================================
; Mode 6 color text for score.
;===============================================================================

UpdateScore

	saveRegs ; put CPU flags and registers on stack

	ldx #1                ; Length of real digits.  
	stx REAL_SCORE_DIGITS ; Guaranteed to be at least 1.
	
	lda ZBRICK_POINTS

AddScoreDigit
	clc
	adc REAL_SCORE-1,x    ; Add brick points to score.
	sta REAL_SCORE-1,x
	
	cmp #$0a              ; Result less than 10?
	bcc EndUpdateScore    ; Yes.  Finished.
	
	sbc #$0a              ; No.  Remove 10
	sta REAL_SCORE,x      ; and save new value.
	
	lda #1                ; The 10 will carry to next position
	
	inx                   ; Increase length of score for next position
	stx REAL_SCORE_DIGITS ; Remember the new length
	
	cpx #12
	bne AddScoreDigit
	
EndUpdateScore
	safeRTS ; restore registers and CPU flags, then RTS



;===============================================================================
;   DISPLAY RELATED MEMORY
;===============================================================================
; This is loaded last, because it defines several large blocks and
; repeatedly forces (re)alignment to Page and K boundaries.
;
	.include "display.asm"


	
;===============================================================================
;   PROGRAM_INIT_ADDRESS
;===============================================================================
; Atari uses a structured executable file format that 
; loads data to specific memory and provides an automatic 
; run address.
;===============================================================================
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable it will automatically
; jump to the address placed in the DOS_RUN_ADDR.
;===============================================================================
;
	*=DOS_RUN_ADDR
	.word PRG_START

;===============================================================================

	.end ; finito
 
;===============================================================================
