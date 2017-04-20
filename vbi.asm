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
; History V 1.0
;===============================================================================
; vbi.asm contains the Vertical Blank Interrupt
;===============================================================================


; Insert the game's routine in the Deferred Vertical Blank Interrupt.
;
Set_VBI
	ldy #<Breakout_VBI ; LSB for routine
	ldx #>Breakout_VBI ; MSB for routine

	lda #7 ; Set Interrupt Vector 7 for Deferred VBI

	jsr SETVBV  ; and away we go.

	rts

	
; Remove the game's Deferred Vertical Blank Interrupt.
;
Remove_VBI
	ldy #<XITVBV ; LSB of JMP to end deferred VBI
	ldx #>XITVBV ; MSB of JMP to end deferred VBI

	lda #7 ; Set Interrupt Vector 7 for Deferred Vertical Blank Interrupt.

	jsr SETVBV  ; and away we go.

	rts


; The magic happens here.  That is, much of the game guts, 
; animation, and timing either occurs here or is established
; here.   Main line and DLIs are, for the most part, only 
; following directions determined here.
;
Breakout_VBI
; ==============================================================
; TITLE FLY IN
; ==============================================================
; It figures that the first idea to pop into the head in the 
; gratuitous eye candy department and the first to work on is 
; just about the most complicated thing going on in the program.
;
; The animated title has different phases (controlled by TITLE_PLAYING)
; 0 == not running -- title lines in 0/empty state.  (Game Over and main Title)
; 1 == clear. no movement. (Pause for a couple seconds before animation starts.)
; 2 == Text fly-in is in progress.
;      a) P/M hold bitmap of character and moves from right to left to its 
;         target location on screen
;      b) At target position the character values are put into Title0 and Title1 lines
;         and the P/M is removed from screen to HPOS value 0.
;      c) do until all 8 characters have traveled on to the screen.
; 3 == pause for a couple seconds for public admiration. 
; 4 == Text VSCROLLs to the top of the screen.  
;      a) when complete reset/return to state 1 for pause.
;
; (Estimating that even this could get boring after a while... thinking
; about doing random horizontal and vertical scrolling to move the title
; off the top of the screen.) 

	; Enforce sanity during the intial hacking and testing phase.
	; Force initial display values to be certain everything begins 
	; at the a known state.
	; Force the initial DLI just in case one goes crazy and the 
	; DLI chaining gets messed up. 
	; Most of this will be commented out when code is more final.

	lda #<DISPLAY_LIST ; Display List
	sta SDLSTL
	sta DLISTL
	lda #>DISPLAY_LIST
	sta SDLSTH
	sta DLISTH
	
	lda #<DLI_1 ; DLI Vector
	sta VDSLST
	lda #>DLI_1
	sta VDSLST+1
	
	lda #[ENABLE_DL_DMA|ENABLE_PM_DMA|PLAYFIELD_WIDTH_NARROW|PM_1LINE_RESOLUTION]
	sta SDMCTL; Display DMA control
	sta DMACTL
	
	lda #[NMI_DLI|NMI_VBI] ; Interrupt flags
	sta NMIEN
	
	lda #4 ; Finescrolling. 
	sta HSCROL ; Title text line is shifted by HSCROLL to center it.
	lda #0
	sta VSCROL

	lda #>CHARACTER_SET_01 ; Character set for title
	sta CHBAS
	sta CHBASE
	
	lda #>PLAYER_MISSILE_BASE ; Player/Missile graphics memory.
	sta PMBASE
	
	lda TITLE_HPOSP0
	sta HPOSP0
	
	lda #PM_SIZE_NORMAL
	sta SIZEP0
	
	lda #[FIFTH_PLAYER|1] ; Missiles = COLPF3.  Player/Missiles on top.  
	sta GPRIOR
	sta PRIOR
	
	; If Title is NOT running, and the main 
	; line wants it started, then start...
	ldy TITLE_PLAYING ; Is title currently running?
	bne Run_Title ; >0, yes.  continue to run.
	; no. it is off.
	lda TITLE_STOP_GO ; Does main line want to start title?
	bne Start_Title ; Yes, begin title.
	beq End_Title ; No.  Skip title things.

Stop_Title  ; stop/zero everything.
	; reset scroll to empty title.

	lda #0
	sta TITLE_PLAYING

	sta TITLE_HPOSP0
	sta TITLE_SIZEP0
	sta TITLE_GPRIOR

    sta TITLE_CURRENT_FLYIN
	
	ldx #0
	jsr Update_Title_Scroll ; Set vertical scroll and DLI values
	
	jsr Clear_Title_Lines ; Make sure Title text is erased
	
	lda #<TITLE_FRAME_EMPTY
	sta DISPLAY_LIST_TITLE_VECTOR ; Empty scroll window
	
	beq End_Title

Start_Title ; Step into the first phase -- pause before fly-in
	ldy #1 ; Enagage initial pause
	sty TITLE_PLAYING

	; Prep values for Stage 1.
	lda #120
	sta TITLE_TIMER

Run_Title
	lda TITLE_STOP_GO ; Does Mainline want this to stop?
	beq Stop_Title ; 0.  Yes.  clean screen.

	; Always move the colors.
	inc TITLE_COLOR_COUNTER ; next index in color table
	lda TITLE_COLOR_COUNTER
	cmp #43 ; 42 is last color index for title colors.
	bcc Title_Pause_1 ; No. Continue with next step.
	lda #0 ; Reset
	sta TITLE_COLOR_COUNTER

Title_Pause_1 ; Pause before title 
	ldy TITLE_PLAYING
	cpy #1 ; Is this #1 == Clear, no movement?
	bne Title_FlyIn

	dec TITLE_TIMER
	lda TITLE_TIMER
	
	bne End_Title ; Done messing with title until timer expires.

	lda #0
	sta TITLE_CURRENT_FLYIN  ; start at first character in list
	sta TITLE_HPOS0          ; reset HPOS to off screen.

	tax ; to update TITLE_SCROLL_COUNTER 
	jsr Update_Title_Scroll

	jsr Clear_Title_Lines

	ldy #2 ; Engage fly-in
	sty TITLE_PLAYING
	bne End_Title

; FLY IN:  Things going on....
; A P/M letter is in motion, OR
; (a P/M letter reached its target and must be replaced by a character)
; Time to start a new letter in motion, OR
; All letters are displayed, set mode to  Pause to admire the title.
Title_FlyIn 
	ldy TITLE_PLAYING
	cpy #2; Is this #2 == Text fly-in is in progress.
	bne Title_Pause_2

	ldx TITLE_HPOS0 ; if this is non-zero then a letter is in motion
    bne FlyingChar
    ldx TITLE_CURRENT_FLYIN ; if this is 8 then we should  be in admiration mode
    cpx #8  ; The scroller will reset this to 0 when done.
    bne FlyInStartChar
	
    ldy #3 ; DONE. Set to do the next step -- pause for admiration.
    sty TITLE_PLAYING

	ldy #120 ; how long to pause...
	sty TITLE_TIMER
    bne Title_Pause_2

; FLY IN PART 1 - Start the character
; establish the next character to fly in.
FlyInStartChar
    lda #$FE ; extreme right side
    sta TITLE_HPOS0 ; new horizontal position.
    ldx TITLE_CURRENT_FLYIN ; which character ?
	
	ldy TITLE_DLI_PMCOLOR_TABLE,x ; Tell DLI which color for Flying letter
	sty TITLE_DLI_PMCOLOR
	
	lda TITLE_DLI_COLPM_TABLE_LO,y
	sta ZTITLE_COLPM0       ; Page 0 address pointer for DLI_1
	lda TITLE_DLI_COLPM_TABLE_HI,y
	sta ZTITLE_COLPM0+1 

Copy_Char_Image_To_PM
    ldy TITLE_PM_IMAGE_LIST,x ; get starting image offset for character
    ldx #25 ; destination scan line
CopyCharToPM
    lda CHARACTER_SET,y ; copy from character set
    sta PMADR_BASE0,x ; to the P/M image memory
    iny
    inx
    cpx #41 ; ending scan line (16 total) 
    bne CopyCharToPM

    ldx TITLE_HPOS0

; FLY IN PART 2 - Move the current P/M character
FlyingChar
    dex ; move P/M left 2 color clocks
    dex
    stx TITLE_HPOS0; and set it.
    txa  ; needs to be in A so we can compare from a table.
    ldx TITLE_CURRENT_FLYIN 
    cmp TITLE_PM_TARGET_LIST,x ; destination PM position for character
    bne Title_Pause_2
    ; the flying P/M has reached target position. 
    ; Replace it with the character on screen.
    lda TITLE_PM_CHAR_POS,x ; get corresponding character postition.
    tay
    lda TITLE_CHAR_LIST,x ; get character
    sta TITLE_LINE0,y ; top half of title
	clc
    adc #1 ; determine the next screen byte value
    sta TITLE_LINE1,y ; bottom half of title
    
    ; Setup for next Character
    inc TITLE_CURRENT_FLYIN ; next flying chraracter
    lda #0
    sta TITLE_HPOS0 ; set P/M offscreen

	
; PAUSE:  Admire the title
Title_Pause_2
	ldy TITLE_PLAYING
	cpy #3 ; Is this #3 == pause for public admiration.
	bne Title_Scroll

	dec TITLE_TIMER
	lda TITLE_TIMER
	
	bne Title_Scroll
	
	; Timer Reached 0.
	; Init for next phase -- scrolling...
	
	ldy #4 ; Text  VSCROLL to top of screen
	sty TITLE_PLAYING		
	; Note that the end of Pause 1 updated the scroll counter to 0 and
	; reset all related values to the initial position.
	
; SCROLLING TITLE - Vertical scroll up
Title_Scroll
	ldy TITLE_PLAYING
	cpy #4; Is this #4 == Text  VSCROLL to top of screen in progress.
	bne End_Title

	ldx TITLE_SCROLL_COUNTER
	inx
	cpx #32 ; 0 to 31 is valid
	bne Title_update
	
	; Reached the end of scroll.  Next Phase is back to pause.
	ldy #1
	sty TITLE_PLAYING
	jsr Clear_Title_Lines

	ldx #0 ; reset scroll and DLI to initial position.
Title_Update
	jsr Update_Title_Scroll
		
; End of Title section.
End_Title


; ==============================================================
; BALL:
; ==============================================================
; Very simple.  
; MAIN code analyzes CURRENT position of the ball to set the NEW postion.
; VBI code updates the Player image and sets NEW as CURRENT.
; Everything else -- collisions and reactions are established by the MAIN code.

; 3 scanlines tall.   Just clear and redraw directly.

; Erase old image
	ldx #3
	lda #0
	ldy BALL_CURRENT_Y
	
Erase_Current_Ball
	sta PMADR_BASE0,y
	iny
	dex
	bne Erase_Current_Ball
;
; Is MAIN running with the ball?
	lda ENABLE_BALL
	bne Update_Ball
;
; No ball. Leave in non-visible/off screen state.
	lda #0
	beq End_Ball_Update
	
Update_Ball	
; Draw new image
	ldx #3
	lda #$C0 ; The Ball
	ldy BALL_NEW_Y
	sty BALL_CURRENT_Y
	
Draw_New_Ball
	sta PMADR_BASE0,y
	iny
	dex
	bne Draw_New_Ball
; 
; and set the next current position.
	lda BALL_NEW_X
	sta BALL_CURRENT_X

End_Ball_Update	
	sta BALL_HPOS ; And let the DLI know where to put it.


; ==============================================================
; THUMPER-BUMPER PROXIMITY FORCE FIELD:
; ==============================================================
; First, evaluate changes the MAIN routine requests.
; If ball proximity reches 0 begin (or force restart 
; of) the thumper animation.
; If the animation is in progress, do not observe 
; the proximity state/color change.
; If no animation is in progress, then update THUMPER
; color per the ball proximity.
;
; X is the Thumper type:
; 0 = horizontal, 
; 1 = left, 
; 2 = right
;
; Y is the current animation frame (if an animation 
; is in progress.)

	ldx #0 ; Thumper type 0 = horizontal, 1 = left, 2 = right
	
Loop_Next_Thumper	
	lda THUMPER_PROXIMITY,X     ; X lets us loop for Top, Left, and Right
	bne Check_Thumper_Anim      ; Proximity not 0, check if anim is in progress.
	; Proximity is 0, (force) (re)start of animation
	lda THUMPER_PROXIMITY_COLOR ; First entry is animation color
	sta THUMPER_COLOR,X         ; set the bumper color
	                            ; !AUDIO! should engage here
	ldy #1                      ; 1 is first starting animation frame.
	bne Update_Thumper_Frame
	
Check_Thumper_Anim 	
	ldy THUMPER_FRAME,x         ; Is Anim in progress? 
	bne Thumper_Frame_Inc       ; Yes. no proximity color change.
	                            ; No animation running.
	cmp #9                      ; Is proximity less than 9?
	bcs Next_Thumper_Bumper     ; No. Too far away. No change.
	                              ; Proximity! Force field reaction! 
	tay                           ; Turn proximity into ...
	lda THUMPER_PROXIMITY_COLOR,y ; ... color table lookup.
	sta THUMPER_COLOR,x           ; set new color for DLI
	jmp Next_Thumper_Bumper

Thumper_Frame_Inc
	ldy THUMPER_FRAME,x         ; Get current Frame
	beq Next_Thumper_Bumper     ; 0. No animation. Done.
	iny                         ; next frame.
	cpy THUMPER_FRAME_LIMIT,x   ; Reached the frame limit?
	bne Update_Thumper_Frame    ; No. Update frame.
	ldy #0                      ; Yes.  Return to frame 0.
	sty THUMPER_COLOR,x         ; proximity color off.
Update_Thumper_Frame            
	sty THUMPER_FRAME,x         ; Save frame counter;
	; The DLI will handle the color of all bumpers, and the 
	; Player/Missile placement of the left and right bumpers.
	; But, bumper type 0 (top/horizontal bumper) is different.
	; This bumper is done by changing the Display list. 
	; Rather not have MAIN do this and possibly miss the 
	; timing to update the address for the frame.
	; Here VBI updates the Display List routine vector.
	cpx #0 
	bne Next_Thumper_Bumper         ; For bumper 1 and 2 we're done.
	lda THUMPER_HORIZ_ANIM_TABLE,y  ; Get low byte of animation display list subroutine
	sta DISPLAY_LIST_THUMPER_VECTOR ; put it in the JMP target address.

Next_Thumper_Bumper
	inx                         ; next Thumper to animate
	cpx #3                      ; Reached the last thumper.
	bne Loop_Next_Thumper       ; Go do the next one.

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
;
; The VBI cares not about the game mode.  It only 
; cares whether or not the bricks lines should be 
; in motion and what direction to move them.
;
; Motion speed is a tricky thing. When moving a new
; set of game playfield bricks they must be in place 
; before the ball can travel down from the bottom 
; border of the bricks, to the paddle and back up to 
; the bottom row of bricks. 

; At current specs: 
; bottom of bricks = line 133 + 1 line = 134 
; Paddle = scan line 205 - 1 line = 204
; That is a distance of 70 lines travelled twice,
; a total of 140 scan lines.

; Taking into account worse case motion rounding when
; the ball hits the paddle that's potentially three
; less scan lines, or an actual 137 lines traveled. 
; At its fastest, the ball travels 3 scan lines per
; frame.
; 137 scan lines / 3 lines per frame means the new
; playfield must be moved into place in 45 frames
; or less.

; The scroll width of a full screen is 168 color 
; clocks. (160 for visible screen plus one byte 
; of pixels additional for spacing between screens).
; 168 color clocks / 45 frames is 3.7 color clocks
; per frame. 
; Therefore, rounding up to 4 color clocks per frame,
; the screen can transition in 42 frames, leaving 
; a few frames for safety.  

; Note that only the lowest line of bricks must be 
; in place at this time, so the ball can hit the 
; row. The other higher lines can begin moving later, 
; or move slower lending a more fluid look to 
; the transition.
; 
; The Title Logo and the Game Over graphics can 
; transition at any speed possible, since the ball
; is not dependant (or even visible) when these 
; graphics are on screen.

	lda BRICK_SCREEN_START_SCROLL ; MAIN says to start scrolling?
	beq Check_Brick_Scroll        ; No?  So, is Scroll already running.
	lda #0
	sta BRICK_SCREEN_START_SCROLL ; Turn off MAIN request.
	lda #1
	sta BRICK_SCREEN_IN_MOTION ; Turn On Scroll in progress.

Check_Brick_Scroll
	lda BRICK_SCREEN_IN_MOTION
	beq End_Brick_Scroll_Update

	ldx #7 ; start at last/bottom row.
	
Do_Row_Movement
	lda BRICK_SCREEN_MOVE_DELAY,x ; Delay for frame count?
	beq Move_Brick_Row
	dec BRICK_SCREEN_MOVE_DELAY,x
	clc
	bcc Do_Next_Brick_Row
	
Move_Brick_Row
	ldy BRICK_CURRENT_LMS_OFFSETS,x 
	lda BRICK_BASE,y                ; What is the LMS pointer now?
	cmp BRICK_SCREEN_TARGET_LMS,x   ; Does it match target?
	beq Finish_Brick_HScroll          ; Yes.  Is more HScroll needed?

	lda BRICK_SCREEN_LMS_MOVE,x 	; Are we going left or right?
	bmi Do_Brick_Right_Scroll		; minus means Right
	
; Doing Left
	lda BRICK_CURRENT_HSCROL,x      ; get the current Hscrol for this row.
	clc
	sbc BRICK_SCREEN_HSCROL_MOVE,X  ; decrement it to move line left.
	bcc Update_HScrol  ; If no carry, then no coarse scroll.
	clc                     ; Carry means this must be
	adc #8                  ; returned to positive. (using 8, not 16 color clocks)
	inc BRICK_BASE,y        ; Coarse scroll it
    bne Update_HScrol
	
Do_Brick_Right_Scroll		 
	lda BRICK_CURRENT_HSCROL,x      ; get the current Hscrol for this row.
	clc
	adc BRICK_SCREEN_HSCROL_MOVE,X  ; decrement it to move line left.
	cmp #8 ; if greater or equal to 8
	
	bcc Update_HScrol  ; If no carry, then no coarse scroll.
	clc                     ; Carry means this must be
	sbc #8                  ; returned to positive. (using 8, not 16 color clocks)
	inc BRICK_BASE,y        ; Coarse scroll it

Update_HScrol
	sta BRICK_CURRENT_HSCROL,X ; Save new HSCROL.
	jmp Do_Next_Brick_Row



Finish_Brick_HScroll ; Current LMS matches target LMS. More Hscroll may be needed.


Do_Next_Brick_Row
	dex
	bpl Do_Row_Movement
	bmi End_Brick_Scroll_Update
	
End_Brick_Scroll_Update

	
;===============================================================================
; BOOM-O-MATIC


;===============================================================================
; PADDLE


;===============================================================================
; BALL COUNTER


;===============================================================================
; SCORE


Exit_VBI
; Finito.
	jmp XITVBV


;=============================================
; Used more than once to initialize
; and then run the vertical scroll.
; Given the value of X, set the 
; TITLE_SCROLL_COUNTER, and update 
; all the scrolling variables.
Update_Title_Scroll
	stx TITLE_SCROLL_COUNTER

	lda TITLE_VSCROLL_TABLE,x ; Fine scroll position
	sta TITLE_VSCROLL

	ldy TITLE_SCROLL_TABLE,x ; Coarse scroll position
	lda TITLE_FRAME_TABLE,y
	sta DISPLAY_LIST_TITLE_VECTOR

	lda TITLE_WSYNC_OFFSET_TABLE,x ; Line Counter before color bars
	sta TITLE_WSYNC_OFFSET
	
	lda TITLE_WSYNC_COLOR_TABLE,x  ; Lines in the color bars
	sta TITLE_WSYNC_COLOR
	
	lda TITLE_COLOR_COUNTER_PLUS,x; increment color table again?
	beq End_Update_Title_Scroll
	ldy TITLE_COLOR_COUNTER
	iny ; next index in color table
	cpy #43 ; 42 is last color index for title colors.
	bne Update_Color_Counter 
	ldy #0
Update_Color_Counter	
	sty TITLE_COLOR_COUNTER

End_Update_Title_Scroll	
	rts
	
;=============================================
; Erase the Title text from the Title lines.
Clear_Title_Lines
	lda #0 ; clear/blank space
	ldx #7 ; 8 characters in title
Clear_Title_Char
	ldy TITLE_PM_CHAR_POS,x ; Get character offset
	sta TITLE_LINE0,y  ; clear first line
	sta TITLE_LINE1,y  ; clear second line
	dex
	bpl Clear_Title_Lines
	
	rts

	