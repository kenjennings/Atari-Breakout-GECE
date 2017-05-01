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

	; Enforce sanity during the intial hacking and testing phase.
	; Force initial display values to be certain everything begins 
	; at the a known state.
	; Force the initial DLI just in case one goes crazy and the 
	; DLI chaining gets messed up. 
	; This will be commented out when code is more final.

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
	sta SDMCTL ; Display DMA control
	sta DMACTL
	
	lda #[NMI_DLI|NMI_VBI] ; Interrupt flags ON
	sta NMIEN
	
	lda #4 ; Finescrolling. 
	sta HSCROL      ; Title text line is shifted by HSCROLL to center it.
	lda #0
	sta VSCROL

	lda #>CHARACTER_SET_01 ; Character set for title
	sta CHBAS
	sta CHBASE
	
	lda #>PLAYER_MISSILE_BASE ; Player/Missile graphics memory.
	sta PMBASE
	
	lda TITLE_HPOSP0    ; reset horizontal position for Player as Title character
	sta HPOSP0
	
	lda #PM_SIZE_NORMAL ; reset size for Player as Title character 
	sta SIZEP0
	
	lda #[FIFTH_PLAYER|1] ; Missiles = COLPF3.  Player/Missiles on top.  
	sta GPRIOR
	sta PRIOR

	lda #[ENABLE_PLAYERS|ENABLE_MISSILES]
	sta GRACTL ; Graphics Control, P/M DMA 
	
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
	
	; If Title is NOT running, and the main 
	; line wants it started, then start...
	
	ldy TITLE_PLAYING  ; Is title currently running?
	bne Run_Title      ; >0, yes.  continue to run.
	                   ; no. it is off.
	lda TITLE_STOP_GO  ; Does main line want to start title?
	bne Start_Title    ; Yes, begin title.
	beq End_Title      ; No.  Skip title things.

Stop_Title  ; stop/zero everything.
	        ; reset to empty title.

	lda #0
	sta TITLE_PLAYING

	sta TITLE_HPOSP0
	sta TITLE_SIZEP0
	sta TITLE_GPRIOR

	sta TITLE_CURRENT_FLYIN
	
	ldx #0
	jsr Update_Title_Scroll ; Set vertical scroll and DLI values
	
	jsr Clear_Title_Lines   ; Make sure Title text is erased
	
	lda #<TITLE_FRAME_EMPTY
	sta DISPLAY_LIST_TITLE_VECTOR ; Empty scroll window
	
	beq End_Title

Start_Title                 ; Step into the first phase -- pause before fly-in
	ldy #1                  ; Enagage initial pause
	sty TITLE_PLAYING

	; Prep values for Stage 1.
	lda #120
	sta TITLE_TIMER

Run_Title
	lda TITLE_STOP_GO       ; Does Mainline want this to stop?
	beq Stop_Title          ; 0. Yes. clean screen.

	                        ; Always move the colors.
	inc TITLE_COLOR_COUNTER ; next index in color table
	lda TITLE_COLOR_COUNTER
	cmp #43                 ; 42 is last color index for title colors.
	bcc Title_Pause_1       ; No. Continue with next step.
	lda #0                  ; Reset
	sta TITLE_COLOR_COUNTER

Title_Pause_1               ; Pause before title 
	ldy TITLE_PLAYING
	cpy #1                  ; Is this #1 == Clear, no movement?
	bne Title_FlyIn         ; No, things are in motion.

	dec TITLE_TIMER         ; Decrement timer
	lda TITLE_TIMER         ; Is it still > 0 ?
	bne End_Title           ; Yes. Done messing with title until timer expires.

	lda #0                  ; No. Do Flying Text
	sta TITLE_CURRENT_FLYIN ; start at first character in list
	sta TITLE_HPOS0         ; reset HPOS to off screen.

	tax ; to update TITLE_SCROLL_COUNTER 
	jsr Update_Title_Scroll  

	jsr Clear_Title_Lines

	ldy #2                  ; Engage fly-in
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
;	
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
;
; Draw new image	
Update_Ball	
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
;
; and unicorn colorfy it.
	lda RANDOM
	and #$F0 ; random color
	ora #$0F ; sparkle white it
	sta BALL_COLOR

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
; 
; Scrolling to the left screen needs a special case, 
; because the final stopping location is outside the 
; 0 - 7 color clock positions used for scrolling.
; (and using 0-15 would make this even more weird.)
; 
; Reminders: 
; Move view right/screen contents Left = Decrement HSCROL, Increment LMS
; Move view left/screen contents Right = Increment HSCROL, Decrement LMS.
;
; Two different screen moves here.  
;
; The first is an immediate move to the declared positions.  This would 
; be used to reset to starting positions before setting up a scroll.
;
; The second scroll is fine scroll from current position to target position.
;
	lda BRICK_SCREEN_IMMEDIATE_POSITION ; move screen directly.
	beq Fine_Scroll_Display             ; if not set, then try fine scroll
	
	ldx #7
Do_Next_Immediate_Move
	ldy BRICK_CURRENT_LMS_OFFSETS,x  ; Y = current position of LMS low byte in Display List
	lda BRICK_SCREEN_TARGET_LMS,x    ; Get destination position.
	sta BRICK_BASE,y                 ; Set the new Display List LMS pointer.
	lda BRICK_SCREEN_TARGET_HSCROL,x ; get the destination position.
	sta BRICK_CURRENT_HSCROL,x       ; set the current Hscrol for this row.
	
	dex
	bpl Do_Next_Immediate_Move

	lda #0  ; Clear the immediate move flag, and skip over doing fine scroll...
	sta BRICK_SCREEN_IMMEDIATE_POSITION
	beq End_Brick_Scroll_Update

Fine_Scroll_Display   
	lda BRICK_SCREEN_START_SCROLL ; MAIN says to start scrolling?
	beq Check_Brick_Scroll        ; No?  So, is a Scroll already running.
	; and if a scroll is already in progress when MAIN toggles
	; the BRICK_SCREEN_START_SCROLL flag it really has no effect.
	; the current scroll keeps on scrolling.
	lda #0
	sta BRICK_SCREEN_START_SCROLL ; Turn off MAIN request.
	inc BRICK_SCREEN_IN_MOTION    ; Temporarily flag Scroll in progress.

Check_Brick_Scroll
	lda BRICK_SCREEN_IN_MOTION
	beq End_Brick_Scroll_Update

	lda #0     ; Temporarily indicate no motion
	sta BRICK_SCREEN_IN_MOTION 
	
	ldx #7 ; start at last/bottom row.
	
Check_Pause_or_Movement
	lda BRICK_SCREEN_MOVE_DELAY,x ; Delay for frame count?
	beq Move_Brick_Row
	inc BRICK_SCREEN_IN_MOTION ; indicate things in progress
	dec BRICK_SCREEN_MOVE_DELAY,x
	jmp Do_Next_Brick_Row
	
Move_Brick_Row
	ldy BRICK_CURRENT_LMS_OFFSETS,x ; Y = current position of LMS low byte in Display List
	lda BRICK_BASE,y                ; What is the Display List LMS pointer now?
	cmp BRICK_SCREEN_TARGET_LMS,x   ; Does it match target?
	beq Finish_Brick_HScroll        ; Yes.  Then is more HScroll needed?

	lda BRICK_SCREEN_DIRECTION,x 	; Are we going left or right?
	bpl Do_Bricks_Right_Scroll		; -1 = view Right/graphics left, +1 = view left/graphics right

; scroll View Right/screen contents left 
	lda BRICK_CURRENT_HSCROL,x      ; get the current Hscrol for this row.
	sec
	sbc BRICK_SCREEN_HSCROL_MOVE,X  ; decrement it to move graphics left.
	bpl Update_HScrol       ; If not negative, then no coarse scroll.
	clc                     ; Add to return this...
	adc #8                  ; ... to positive. (using 8, not 16 color clocks)
	inc BRICK_BASE,y        ; IncrementLMS to Coarse scroll it
	bne Update_HScrol
	
Do_Bricks_Right_Scroll	    ; Move view left/screen contents Right
	lda BRICK_CURRENT_HSCROL,x      ; get the current Hscrol for this row.
	clc
	adc BRICK_SCREEN_HSCROL_MOVE,X  ; increment it to move graphics right.
	cmp #8 ; if greater or equal to 8
	bcc Update_HScrol       ; If no carry, then less than 8/limit.
	sec                     
	sbc #8                  ; Subtract 8 (using 8, not 16 color clocks)
	dec BRICK_BASE,y        ; Coarse scroll it
	; need special compensation to check for end position, because that 
	; is at byte 0, hscrol 8, not hscrol 0-7
	lda BRICK_BASE,y
	bpl Update_HScrol ; still positive, so we did not pass byte 0, hscrol 8
	lda #0            ; back it up to the end position...
	sta BRICK_BASE,y  ; byte 0
	lda #8            ; hscrol 8
	bpl Update_HScrol

; The current LMS matches the target LMS. 
; a final Hscroll may be needed.
Finish_Brick_HScroll 
	lda BRICK_CURRENT_HSCROL,X
	cmp BRICK_SCREEN_TARGET_HSCROL,x
	beq Do_Next_Brick_Row ; Everything matches. nothing to do.

	lda BRICK_SCREEN_DIRECTION,x 	; Are we going left or right?
	bpl Do_Finish_Right_Scroll		; -1 = view left/graphics right, +1 = view Right/graphics left
	
; scroll View Left/screen contents right 
	lda BRICK_CURRENT_HSCROL,x      ; get the current Hscrol for this row.
	sec
	sbc BRICK_SCREEN_HSCROL_MOVE,X  ; decrement it to move graphics left.
	bmi Set_Left_Home               ; If it went negative reset to end position.
	bpl Update_HScrol               ; If not negative, then no coarse scroll.
Set_Left_Home
	lda BRICK_SCREEN_TARGET_HSCROL,x ; if it went negative then reset to home
	sta BRICK_CURRENT_HSCROL,X
	jmp Update_HScrol
	
Do_Finish_Right_Scroll
	lda BRICK_CURRENT_HSCROL,x      ; get the current Hscrol for this row.
	clc
	adc BRICK_SCREEN_HSCROL_MOVE,X  ; increment it to move line right.
	cmp BRICK_SCREEN_TARGET_HSCROL,X ; if greater or equal to, then set to limit
	bcc Update_HScrol       ; If no carry, then did not exceed limit.
	lda BRICK_SCREEN_TARGET_HSCROL,X                     

Update_HScrol
	inc BRICK_SCREEN_IN_MOTION ; indicate things in motion
	sta BRICK_CURRENT_HSCROL,X ; Save new HSCROL.

Do_Next_Brick_Row
	dex
	bpl Do_Row_Movement
	
End_Brick_Scroll_Update


;===============================================================================
; BOOM-O-MATIC
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

;
; First, is boom enabled?
;
	lda ENABLE_BOOM
	bne Add_New_Boom
	; No boom. MAIN should have zero'd all HPOS and animation states.
	jmp End_Boom_O_Matic

	; New Rules for New Boom.   
	; The code was becoming insane.  So, there are now limits on behavior.
	;
	; MAIN must set request 1 first, so there will be no situation 
	; when request 1 is not set and request 2 is set.
	; Boom cycles are always set in order 1, then 2.
	; Therefore, when adding a new cycle the current 
	; state of Boom 1 is copied to Boom 2 and the new Boom
	; is inserted in Boom 1.  This simplifies the madness.

Add_New_Boom ; Add any new requests to the lists.
	ldx #7 

New_Boom_Loop
	lda BOOM_1_REQUEST,x ; is request flag set?
	beq Next_Boom_Test ; no, therefore, so 2 is not set either.
	lda BOOM_1_CYCLE,x ; If this is 0 then use it.
	beq Assign_Boom_1
	; Boom 1 already in use.
	; First Move Boom 1 state to Boom 2.
	jsr Push_Boom_1_To_Boom_2
	
	; Assign request 1 to Boom 1.
Assign_Boom_1
	lda BOOM_1_REQUEST_BRICK,x ; Get requested brick, 0 to 13
	sta BOOM_1_BRICK,x         ; assign to current animation
	lda #1                     ; set first frame of animation
	sta BOOM_1_CYCLE,x

	; Try assigning new request 2.
Try_New_Boom_2
	lda BOOM_2_REQUEST,x ; is request flag set?
	beq Next_Boom_Test ; no, therefore, done adding boom for this row.
	; Do not need to test the cycle, since if we got 
	; here Request 1 was already assigned to Boom 1.
	; So, push current Boom 1 to Boom 2.
	jsr Push_Boom_1_To_Boom_2
	; Assign request 2 to Boom 1.
	lda BOOM_2_REQUEST_BRICK,x ; Get requested brick, 0 to 13
	sta BOOM_1_BRICK,x         ; assign to current animation
	lda #1                     ; set first frame of animation
	sta BOOM_1_CYCLE,x

Next_Boom_Test
	dex
	bpl New_Boom_Loop
	
; Next walk through the current Boom cycles, do the 
; animation changes and update the values.
Animate_Boom_O_Matic
	ldx #7 

New_Boom_Animation_Loop
	ldy BOOM_1_CYCLE,x   ; If this is not zero, 
	bne Boom_Animation_1 ; then animate it.
	; if cycle is 0 it could be because the last frame
	; reached the end of animation.  
	lda #0                ; Force HPOS 0, just in case.
	sta BOOM_1_HPOS,x
	sta BOOM_2_HPOS,x
	beq Next_Boom_Animation

Boom_Animation_1
	dey                ; makes cycle 1 - 9 easier to lookup as 0 - 8
	sty PARAM7         ; Save Cycle
	stx PARAM6         ; Save Row

	lda BOOM_CYCLE_SIZE,y ; Get P/M Horizontal Size for this cycle
	sta BOOM_1_SIZE,y     ; Set size.

	; P/M position varies by brick, and by cycle.
	ldy BOOM_1_BRICK,x          ; Get Brick
	lda BRICK_XPOS_LEFT_TABLE,y ; get brick HPOS
	ldy PARAM7                  ; get current cycle.
	clc
	adc BOOM_CYCLE_HPOS,y       ; adjust HPOS by the current cycle.
	sta BOOM_1_HPOS,x
	
	; P/M Color is based on row and by cycle.
	; Multiply row times 9 in offset table, then add row to get entry.
	ldy BOOM_CYCLE_OFFSET,x
	lda BOOM_CYCLE_COLOR,y
	sta BOOM_1_COLPM,x
	
	; Last: copy 7 bytes of P/M image to correct Y pos.
	; Convert row to P/M ypos.
	; multiply cycle times 9.
	; copy 7 bytes from table to p/m base.
	ldy BRICK_YPOS_TOP_TABLE,x ; Get scan line of top of brick.
	dey                        ; -1.  one line higher for exploding brick.
	sta ZEROPAGE_POINTER_8     ; low byte for player/missile address. 
	lda #>PMADR_BASE1          ; Player 1 Base,  
	sta ZEROPAGE_POINTER_8+1   ; high byte.
	
	lda BOOM_CYCLE_OFFSET,x   ; Get Starting offset for animation for this frame
	tax
	ldy #$00
	
Loop_Copy_PM_1_Boom
	lda BOOM_ANIMATION_FRAMES,x ; Read from animation table
	sta (ZEROPAGE_POINTER_8),y  ; Store in Player memory
	inx                         ; increment... to next byte
	iny
	cpy #8                      ; stop at 7 bytes.
	bne Loop_Copy_PM_1_Boom

	; Boom 1 is done.
	; Now try Boom 2.
	;
	ldx PARAM6  	; Get the real row back.

	ldy BOOM_2_CYCLE,x   ; If this is not zero, 
	bne Boom_Animation_2 ; then animate it.
	beq Next_Boom_Animation

Boom_Animation_2
	dey                ; makes cycle 1 - 9 easier to lookup as 0 - 8
	sty PARAM7         ; Save Cycle

	lda BOOM_CYCLE_SIZE,y ; Get P/M Horizontal Size for this cycle
	sta BOOM_2_SIZE,y     ; Set size.

	; P/M position varies by brick, and by cycle.
	ldy BOOM_2_BRICK,x          ; Get Brick
	lda BRICK_XPOS_LEFT_TABLE,y ; get brick HPOS
	ldy PARAM7                  ; get current cycle.
	clc
	adc BOOM_CYCLE_HPOS,y       ; adjust HPOS by the current cycle.
	sta BOOM_2_HPOS,x
	
	; P/M Color is based on row and by cycle.
	; Multiply row times 9 in offset table, then add row to get entry.
	ldy BOOM_CYCLE_OFFSET,x
	lda BOOM_CYCLE_COLOR,y
	sta BOOM_2_COLPM,x
	
	; Last: copy 7 bytes of P/M image to correct Y pos.
	; Convert row to P/M ypos.
	; multiply cycle times 9.
	; copy 7 bytes from table to p/m base.
	ldy BRICK_YPOS_TOP_TABLE,x ; Get scan line of top of brick.
	dey                        ; -1.  one line higher for exploding brick.
	sta ZEROPAGE_POINTER_8     ; low byte for player/missile address. 
	lda #>PMADR_BASE2          ; Player 2 Base,  
	sta ZEROPAGE_POINTER_8+1   ; high byte.
	
	lda BOOM_CYCLE_OFFSET,x   ; Get Starting offset for animation for this frame
	tax
	ldy #$00
	
Loop_Copy_PM_2_Boom
	lda BOOM_ANIMATION_FRAMES,x ; Read from animation table
	sta (ZEROPAGE_POINTER_8),y  ; Store in Player memory
	inx                         ; increment... to next byte
	iny
	cpy #8                      ; stop at 7 bytes.
	bne Loop_Copy_PM_2_Boom

Next_Boom_Animation
	dex
	bpl New_Boom_Animation_Loop

End_Boom_O_Matic


;===============================================================================
; SCROLL PROMPTS AND CREDITS
;===============================================================================
; VBI manages text fade in/out, and 
; the vertical scroll up of the prompt or
; 
; Future enhancement ideee-er:
; Allow user to rotate the Paddle to control 
; the position of the long scrolling text.
; Kewl.

; First, is scrolling window enabled?
;
	lda ENABLE_CREDIT_SCROLL
	beq End_Credit_Prompt_Scroll ; Nope. Skip everything.

	; Yes, we are moving...
	; If the timer is expired
	ldy SCROLL_CURRENT_TICK ; If Tick reaches 0, 
	beq Reset_Scroll_Delay  ; then restart. (and do a scroll action)
	
	dec SCROLL_CURRENT_TICK ;
	bpl End_Credit_Prompt_Scroll ; 0 will be caught above.
	
Reset_Scroll_Delay
	ldy SCROLL_TICK_DELAY
	sty SCROLL_CURRENT_TICK

; Check for fade actions first.
	ldy SCROLL_DO_FADE  ; MAIN Direct new Fade?
	beq Do_Scroll_Fade_In_Progress ; Nope.  check if we're already busy.

	sty SCROLL_IN_FADE ; Save direction to do a text fade.
	ldy #0             ; and turn off the
	sty SCROLL_DO_FADE ; direction from MAIN

Do_Scroll_Fade_In_Progress
	ldy SCROLL_IN_FADE ; Are we in a fade?
	beq Do_Line_Scroll ; Nope. Go scroll lines.
	dey                ; Was it 1 for Fade up? 
	beq Do_Scroll_Fade_Up
	; Therefore it must be 2 (or more, so what) 
	; do fade down. 6 to 0
	ldy SCROLL_CURRENT_FADE ; Get current fade
	beq Fade_Finished       ; is it 0? Then stop fade.
	dey                     ; decrement fade.
	bpl Set_New_Fade        ; save new fade value

Do_Scroll_Fade_Up
	; do fade up. 0 to 6
	ldy SCROLL_CURRENT_FADE ; Get current fade
	cmp #6                  ; Did we reach the end already?
	bne Do_Increment_Fade   ; Nope.
	ldy #0                  ; At the end, so  
	beq Fade_Finished       ; stop the fade.
Do_Increment_Fade
	iny                     ; increment fade.

Set_New_Fade
	sty SCROLL_CURRENT_FADE ; save for DLI.
	bpl Do_Line_Scroll      ; continue by moving text window.

Fade_Finished ; Code comes here when Y = 0 to stop the fade.
	sty SCROLL_IN_FADE

Do_Line_Scroll
	ldy SCROLL_CURRENT_VSCROLL ; Get current fine scroll
	iny                        ; Move starting scan line +1 to scroll text up
	cmp #8                     ; Exceeded line limit?
	bne Update_Current_Vscroll ; No. Just update new value

	; Then it is time to Coarse scroll the entire window.
	; First check if the current line has reached the limit. 
	ldy SCROLL_CURRENT_LINE    ; Is current position
	cpy SCROLL_MAX_LINES       ; at the end?
	beq Restart_Scroll_Lines   ; Yes.  Reset to 0/first line.
	iny                        ; No.  Increment line.
	bpl Update_Scroll_Lines    ; Set new value

Restart_Scroll_Lines
	ldy #0                     ; Yes.  Reset to first line

Update_Scroll_Lines
	sty SCROLL_CURRENT_LINE   ; Y is the new starting line for the window.

	lda SCROLL_BASE           ; Copy the base address of 
	sta ZEROPAGE_POINTER_8    ; the text array/list into
	lda SCROLL_BASE+1         ; Page 0.
	sta ZEROPAGE_POINTER_8+1
	
	; Since this is an array of words multiply Y times 2.
	tya ; Multiply starting line index * 2 for 
	asl a ; table lookup.
	tay

	; Coarse scrolling the window.
	; Copy 7 addresses from the scroll table 
	; into the display list LMS instructions.
	; X indexes instructions/LMS in Display list.
	; Y indexes addresses from the text address table.
	ldx #0
Coarse_Scroll_Text_LMS
	lda (ZEROPAGE_POINTER_8),y       ; Get Low Byte.
	sta DISPLAY_LIST_TEXT_SCROLL_0,x ; Low Byte of LMS.
	iny                              ; words.  next byte is high byte.
	inx
	lda (ZEROPAGE_POINTER_8),y       ; Get High Byte.
	sta DISPLAY_LIST_TEXT_SCROLL_0,x ; High Byte of LMS.
	iny                              ; words.  next byte is low byte.
	inx                              ; FYI: X is now indexed to a Mode instruction.
	inx                              ; Skip over Mode instruction. Next is the LMS low byte
	cpx #21                          ; If this is not the end, 
	bne Coarse_Scroll_Text_LMS       ; then do another address.
	
	ldy #0 ; reset Current fine scroll to first position 
	
Update_Current_Vscroll
	sty SCROLL_CURRENT_VSCROLL
	
End_Credit_Prompt_Scroll


;===============================================================================
; PADDLE CONTROL
;===============================================================================
; Positioning is very simple. Lookup potentiometer value in
; the table.  Set Player HPOS accordingly.

; The paddle reacts to ball proximity and strikes similar 
; to the way the bumpers work.  MAIN sets the value.
; distance == (PADDLE_Y - BALL_Y) / 4 only when Ball Y 
; is less than/equal to Paddle Y. AND X is within a
; 1 pixel limit of the paddle size.

	lda ENABLE_PADDLE        ; Is Paddle enabled?
	bne Do_Paddle_Movement   ; Yes. Animate it.
	
	ldy #0                   ; Tell DLI what it can do
	sty PADDLE_HPOS          ; with the paddle.
	iny                      ; Now its Frame 1, which....
	sty PADDLE_FRAME         ; will trick the color animation routine
	beq Check_Paddle_Anim    ; into restoring default color.
	
	; Set Paddle postion based on its size and 
	; the value of the potentiometer.
Do_Paddle_Movement
	ldy PADDL0               ; POKEY Potentiometer
	lda PADDLE_SIZE          ; MAIN set normal/small paddle size
	beq Normal_Paddle
	lda PADDLE_SMALL_POSITION_TABLE,y ; Convert POT to X HPOS
	bne Update_Paddle_HPOS
	
Normal_Paddle
	lda PADDLE_NORMAL_POSITION_TABLE,y ; Convert POT to X HPOS

Update_Paddle_HPOS
	sta PADDLE_HPOS
	
	; Animate color changes for Paddle Strike
	lda PADDLE_STRIKE        ; Did MAIN signal paddle strike?
	beq Check_Paddle_Anim    ; No.  But is there already an animation in progress?
	lda #0
	sta PADDLE_STRIKE        ; Turn off notification from MAIN.
	lda #10                  ; Pretend prior VBI did the 10th 
	sta PADDLE_FRAME         ; frame to restart animation.
	
Check_Paddle_Anim
	ldy PADDLE_FRAME         ; Is color animation in progress?
	beq End_Paddle_Movement  ; No. Exit.
	dey                      ; Yes.  Move to next frame.
	sty PADDLE_FRAME         ; Save new frame.
	lda PADDLE_STRIKE_COLOR_FRAMES,y ; Get new color for frame.
	sta PADDLE_STRIKE_COLOR          ; Set new color for DLI.
	
End_Paddle_Movement


;===============================================================================
; BALL COUNTER
;===============================================================================
; Mode 6 color text for label.
; Color 1  == "BALLS" 
;-------------------------------------------
; Missile 0 == Sine Wave Ball
; Player 0 == Sine Wave Ball
; Player 1 == Sine Wave Ball
; Player 2 == Sine Wave Ball
; Player 3 == Sine Wave Ball
;-------------------------------------------
; MAIN can shift all HPOS to 0 when it wants
; the ball counter disabled.

	lda ENABLE_BALL_COUNTER ; is it enabled?
	beq End_Ball_Counter    ; just end this.
	
	lda RANDOM              ; Update the counter unicorn sparkle.
	and #$F0                ; Random colors.
	ora #$0A                ; Medium-ish brightness
	sta BALL_COUNTER_COLOR
	
	dec SINE_WAVE_DELAY     ; Decrement frame delay
	bpl End_Ball_Counter    ; Does not pass 0? Just end this.
	
	lda #4                  ; reset the delay
	sta SINE_WAVE_DELAY
	
	ldx BALL_COUNTER        ; How many balls to animate?
	dex                     ; Make 1-5 into 0-4
	bmi End_Ball_Counter    ; crossed from 0 to -1, so no balls left
	
	; By using Missile first, then Players 0, 1, 2, 3 I'm taking
	; advantage of the fact that they each use a page in memory 
	; consecutive to each other.  Therefore during the loop only 
	; the high byte of the zero page pointer needs to be adjusted 
	; and that can be done by an INC directly. 
	
	lda #$00                ; Get ready to establish pointer for P/M memory
	sta ZEROPAGE_POINTER_8  
	lda #>PMADR_MISSILE     ; Get first Player (Missile) memory high byte
	sta ZEROPAGE_POINTER_8+1
	
Do_Ball_Counter_Animation
	stx PARAM6                    ; Save current ball counter.  need this later.
	
	lda BALL_COUNTER_SINE_STATE,X ; Get which frame Ball X is on
	tax                           ; Put the sine state into the index.
	ldy SINEWAVE,x                ; Get Y position for this sine state/frame
	
	lda #$00                      ; Zero the old ball:
	sta (BALL_COUNTER_PM_TABLE),Y ; Zero.
	iny                           ; Next scan line...
	sta (BALL_COUNTER_PM_TABLE),Y ; etc...
	iny
	sta (BALL_COUNTER_PM_TABLE),Y 
	
	dex                           ; decrement the sine state/frame counter
	bpl Update_Sine_State         ; Update if it is not -1.
	ldx #14                       ; It hit -1. Reset to initial state.

Update_Sine_State
	txa                           ; Hold new sine state/frame in A
	ldx PARAM6                    ; Get the ball counter back into index
	sta BALL_COUNTER_SINE_STATE,X ; Save the new state for this ball.
	tax                           ; Put the sine state back into the index.
	ldy SINEWAVE,x                ; Get Y position for this new sine state/frame

	lda #$C0                      ; Draw the new ball:
	sta (BALL_COUNTER_PM_TABLE),Y ; Draw.
	iny                           ; Next scan line...
	sta (BALL_COUNTER_PM_TABLE),Y ; etc...
	iny
	sta (BALL_COUNTER_PM_TABLE),Y 

	inc ZEROPAGE_POINTER_8+1      ; Prep high byte for next Player object
	
	ldx PARAM6                    ; Get the ball counter back into index
	dex                           ; Decrement for next ball
	bpl Do_Ball_Counter_Animation ; If this is not -1, then animate next ball.
	
End_Ball_Counter



;===============================================================================
; SCORE
;===============================================================================
; Mode 6 color text for score.
; Color 2  == score
; Color 3  == score
;-------------------------------------------

	lda ENABLE_SCORE 
	beq End_Score_Display

	lda REAL_SCORE_DIGITS ; is there game score zero?
	beq End_Score_Display ; Yes. So nothing to count/display.

	dec DISPLAYED_SCORE_DELAY ; Was a count update done recently?
	bpl End_Score_Display     ; Yes.  So, no new update.

	; At this point scoring is enabled, the game score is non-zero,
	; and if a score update occurred the timer is expired.
	
	; determine if the real score differs from displayed score.
	ldx #0

Find_Score_Difference	
	lda DISPLAYED_SCORE,x          ; Get digit of displayed score.
	cmp REAL_SCORE,x               ; Compare to real score.
	bne Do_Update_Displayed_Score  ; Different! Go update display.
	inx                            ; Move on to next digit.
	cmp #12                        ; Really?  You're beating 999,999,999,999 ?
	beq No_New_Digits              ; No. No you're not. Not in this lifetime.
	cmp REAL_SCORE_DIGITS          ; Compare to actual digits used in real score.
	bne Find_Score_Difference      ; Haven't reached the last used digit. Try the next.
	
No_New_Digits	
	; No digit is unmatched.  
	inc DISPLAYED_SCORE_DELAY ; reset delay to 0 since there is no update now.
	beq End_Score_Display     ; we're done here.

Do_Update_Displayed_Score
	stx PARAM6                ; Save the position of the first different digit
	clc                       ; make sure no carry is being dragged around.
	
Increment_Score
	adc #1                    ; Add 1 to displayed score digit
	cmp #10                   ; Did single-digit 9 increment into double-digit 10?
	bne Save_And_Do_Display   ; No. So, display what is changed.
	lda #0                    ; Yes.  Reset this digit to 0.
	sta DISPLAYED_SCORE,x     ; Save the update.
	inx                       ; Move to next digit position.
	lda DISPLAYED_SCORE,x     ; Get next digit of displayed score.
	bcc Increment_Score       ; go back and increment this new column.

Save_And_Do_Display
	sta DISPLAYED_SCORE,x     ; save the last update from above
	
	; update screen starting from X going 
	; back to what was saved in PARAM6
Do_Update_Display
	adc #1                           ; increment 0 to 9 to char 1 to 10.
	ora DISPLAYED_SCORE_CHAR_COLOR,x ; Add color to score byte
	ldy DISPLAYED_SCORE_POSITION,x   ; Get screen offset
	sta SCORE_LINE0,y                ; Display top half of number character.
	adc #10                          ; Add 10 to character value.        
	sta SCORE_LINE1,y                ; Display bottom half or number character.
	dex                              ; move backwards to previous position
	lda DISPLAYED_SCORE,x            ; get byte value at that position (borderline dangerous)
	cpx PARAM6                       ; compare to first position saved earlier.
	bcs Do_Update_Display            ; if greater than/equal to, then display this digit.

	lda #10                   ; Reset displayed score delay
	sta DISPLAYED_SCORE_DELAY 
	
	; Here initiate an audio bling.
	
End_Score_Display



;===============================================================================
; SOUND EFFECTS
;===============================================================================
; Voice 0 and 1 == ball impacts -- paddle, walls, lost ball
; (There is no sound for hitting bricks, since that sound
; is actually the score counting "dings".)
; Voice 2 and 3 == score counter
;-------------------------------------------------------------------------------
; The world's cheapest, and cheesiest sequencer. 
;-------------------------------------------------------------------------------
; For each channel, play one sound value from a table at each frame. 
; At 60fps this is a sound change (frequency and volume ) once
; per sound channel every 16.6ms (approximately)
; 
; If the current index is zero then no change for sound channel. 
; Apply the Control and Frequency values from the tables 
; to AUDC and AUDF1. 
; If Control and Frequency are both 0 then the sound is over, so 
; zero the index. 
; If either Control or Frequency are non-zero, then increment the 
; index for the next call.
;
; AUDC and AUDF registers are interleaved.  So, accessing each 
; channel by index is two bytes per index/increment.
;-------------------------------------------------------------------------------

	lda ENABLE_SOUND
	beq exitSoundService
	
	ldx #6                  ; Start at last channel 0 to 3 (3 * 2 = 6)
	
Play_Sound_Channel	
	ldy SOUND_INDEX,x       ; Get current sound progress
	beq Next_Sound_Channel  ; If zero, then no sound.

	lda SOUND_AUDC_TABLE,y  ; Load current sound into registers
	sta AUDC1,x
	lda SOUND_AUDF_TABLE,y
	sta AUDF1,x

	; if AUDC and AUDF values are both zero then zero the index
	ora SOUND_AUDC_TABLE,y  ; if AUDC and AUDF values are not zero
	bne Update_Sound_Index  ; then incement index for next sound
	
	sta SOUND_INDEX,x       ; otherwise, if 0, then reset index to 0
	beq Next_Sound_Channel  ; Do next sound channel

Update_Sound_Index
	inc SOUND_INDEX,x       ; increment index value for next frame.

Next_Sound_Channel
	dex                     ; increment channel index (twice)
	dex
	bpl Play_Sound_Channel  ; if channel index did not go to -1 then do next 
	
exitSoundService

	

;===============================================================================
; THE END OF USER DEFERRED VBI ROUTINE 
;===============================================================================

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


;=============================================
; Push the current state of Boom 1 to Boom 2.
; X = current row.
Push_Boom_1_To_Boom_2
	lda BOOM_1_BRICK,x
	sta BOOM_2_BRICK,x
	lda BOOM_1_CYCLE,x
	sta BOOM_2_CYCLE_x

	rts

	
;=============================================
; Remove Score Display
Remove_Score_Display
	lda #<EMPTY_LINE
	sta DISPLAY_LIST_SCORE_LMS
	lda #>EMPTY_LINE
	sta DISPLAY_LIST_SCORE_LMS+1
	lda #<EMPTY_LINE
	sta DISPLAY_LIST_SCORE_LMS+3
	lda #>EMPTY_LINE
	sta DISPLAY_LIST_SCORE_LMS+4
	
	rts
	

;=============================================
; Restore score display
Restore_Score_Display
	lda #<SCORE_LINE0
	sta DISPLAY_LIST_SCORE_LMS
	lda #>SCORE_LINE0
	sta DISPLAY_LIST_SCORE_LMS+1
	lda #<SCORE_LINE1
	sta DISPLAY_LIST_SCORE_LMS+3
	lda #>SCORE_LINE1
	sta DISPLAY_LIST_SCORE_LMS+4
	
	rts
	
	
