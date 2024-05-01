# Author: Hamlet Taraz @ University of Arizona
#
# This program turns MARS into a MIDI piano, with 128 "different" sounds to choose
# from, and the ability to dynamically customize things like octave and note duration.
# Includes a functioning GUI which looks like a piano and keeps track of all notable information. Try it out!
#
# To use with MARS:
#   Open "Tools -> Keyboard and Display MMIO Simulator"
#     and click "Connect to MIPS"
#   Also Open "Tools -> Bitmap Display"
#     set "Unit Width/Height in Pixels" to 4
#     set "Display Width in Pixels" to 512
#     set "Display Height in Pixels" to 256
#     set "Base address for display" to 0x10010000 (static data)
#     and click "Connect to MIPS"
#   then type into the bottom box of the keyboard simulator and your keys will be registered!
#   See below for controls.
#
# Controls:
#   exit program - ESC
#   reset values - '`' (next to 1, under the escape key)
#
#   keyboard - 
#      w e   t y u   o p
#     a s d f g h j k l ;
#
#   tweaks - 
#                 inc/dec octave - '.' and ','
#     inc/dec note time by 100ms - '-' and '='
#                      by 1000ms - '_' and '+' (hold shift)
#           cycle through sounds - '[' and ']'
#                by 16 at a time - '{' and '}' (hold shift)
#
# Sound key (from https://courses.missouristate.edu/KenVollmar/mars/Help/SyscallHelp.html):
#	0-7	Piano			64-71	Reed
#	8-15	Chromatic Percussion	72-79	Pipe
#	16-23	Organ			80-87	Synth Lead
#	24-31	Guitar			88-95	Synth Pad
#	32-39	Bass			96-103	Synth Effects
#	40-47	Strings			104-111	Ethnic
#	48-55	Ensemble		112-119	Percussion
#	56-63	Brass			120-127	Sound Effects

.data

display:		# 128 columns * 64 rows * 4 bytes per cell
	.space	32768

timeCounts:		# array of times since each key was pressed
	.word	1000
	.word	1000
	.word	1000
	.word	1000
	
	.word	1000
	.word	1000
	.word	1000
	.word	1000
	
	.word	1000
	.word	1000
	.word	1000
	.word	1000
	
	.word	1000
	.word	1000
	.word	1000
	.word	1000
	
	.word	1000

.text

# void main():
#   drawInit() - initialize GUI
#   currSound = 0
#   currPitch = 60 (middle C on a piano)
#   currTime = 2000 (ms)
#   tick = 0
#   while true:   # loops forever until program is terminated
#     sleep for 1ms
#     tick++ &= 0xf
#     if (tick == 0) updateGUI(...)
#     if (!receiver.ready) continue
#     ch = receiver.char
#     check every control, if appliccable modify corresponding value or perform appropriate syscall
#     update time pressed for keyboard key when pressed
#     if (ch == ESCAPE) exit()

main:

	jal	drawInit		# drawInit() - initializes the GUI

	lui	$s0, 0xffff		# $s0 = address of receiver data
	
	addi	$s2, $zero, 0		# currSound = 0
	addi	$s3, $zero, 60		# currPitch = 60 (middle C on a piano)
	addi	$s5, $zero, 2000	# currTime = 2000 (ms)
	
	addi	$s7, $zero, 0		# tick = 0
	la	$s6, timeCounts		# $s6 = &timeCounts

readLoop:
	
	addi	$v0, $zero, 32		# sleep for 1ms (second special syscall!)
	addi	$a0, $zero, 1
	syscall
	
	addi	$s7, $s7, 1		# tick += 1
	andi	$s7, $s7, 0xf		# tick &= 0xf (0-15)
	bne	$s7, $zero, skipUpdate	# if (tick == 0) ... - only update GUI every 16 ticks
	
	add	$a0, $s6, $zero		# set up parameters for updateGUI
	add	$a1, $s2, $zero
	add	$a2, $s3, $zero
	add	$a3, $s5, $zero
	
	jal	updateGUI		# updateGUI(&timeCounts, currSound, currPitch, currTime)

skipUpdate:				# end if

	lw	$s1, 0($s0)		# $s1 = control bits from receiver data
	andi	$s1, $s1, 0x1		# $s1 = ready bit
	beq     $s1, $zero, readLoop	# loop until a character is found
	
	# when character is found:

	lw	$s1, 4($s0)		# ch = read character from receiver data
	addi	$v0, $zero, 31		# set up MIDI out syscall: $a0 will be pitch
	add	$a1, $s5, $zero		# $a1/duration = currTime
	add	$a2, $s2, $zero		# $a2/sound = currSound
	addi	$a3, $zero, 127		# $a3/volume = 127

	addi	$t0, $zero, 27		# if (ch == ESCAPE) ...
	beq	$s1, $t0, chEsc
	j	checkGrave

chEsc:

	addi	$v0, $zero, 10		# terminate program
	syscall

checkGrave:

	addi	$t0, $zero, '`'		# if (ch == '`') ...
	beq	$s1, $t0, chGrave
	j	checkA

chGrave:
	
	addi	$s2, $zero, 0		# currSound = 0
	addi	$s3, $zero, 60		# currPitch = 60 (middle C on a piano)
	addi	$s5, $zero, 2000	# currTime = 2000 (ms)
	
	j	readLoop

checkA:

	addi	$t0, $zero, 'a'		# if (ch == 'a' || ch == 'A') ...
	beq	$s1, $t0, chA
	addi	$t0, $zero, 'A'
	beq	$s1, $t0, chA
	j	checkW

chA:

	addi	$a0, $s3, 0		# $a0/pitch = currPitch + 0 (C)
	syscall				# play C note
	
	sw	$zero, 0($s6)		# reset time pressed to 0
	
	j	readLoop

checkW:

	addi	$t0, $zero, 'w'		# else if (ch == 'w' || ch == 'W') ...
	beq	$s1, $t0, chW
	addi	$t0, $zero, 'W'
	beq	$s1, $t0, chW
	j	checkS

chW:

	addi	$a0, $s3, 1		# $a0/pitch = currPitch + 1 (C#)
	syscall				# play C# note
	
	sw	$zero, 4($s6)		# reset time pressed to 0
	
	j	readLoop

checkS:

	addi	$t0, $zero, 's'		# else if (ch == 's' || ch == 'S') ...
	beq	$s1, $t0, chS
	addi	$t0, $zero, 'S'
	beq	$s1, $t0, chS
	j	checkE

chS:

	addi	$a0, $s3, 2		# $a0/pitch = currPitch + 2 (D)
	syscall				# play D note
	
	sw	$zero, 8($s6)		# reset time pressed to 0
	
	j	readLoop

checkE:

	addi	$t0, $zero, 'e'		# else if (ch == 'E' || ch == 'E') ...
	beq	$s1, $t0, chE
	addi	$t0, $zero, 'E'
	beq	$s1, $t0, chE
	j	checkD

chE:

	addi	$a0, $s3, 3		# $a0/pitch = currPitch + 3 (D#)
	syscall				# play D# note
	
	sw	$zero, 12($s6)		# reset time pressed to 0
	
	j	readLoop

checkD:

	addi	$t0, $zero, 'd'		# else if (ch == 'd' || ch == 'D') ...
	beq	$s1, $t0, chD
	addi	$t0, $zero, 'D'
	beq	$s1, $t0, chD
	j	checkF

chD:

	addi	$a0, $s3, 4		# $a0/pitch = currPitch + 4 (E)
	syscall				# play E note
	
	sw	$zero, 16($s6)		# reset time pressed to 0
	
	j	readLoop

checkF:

	addi	$t0, $zero, 'f'		# else if (ch == 'f' || ch == 'F') ...
	beq	$s1, $t0, chF
	addi	$t0, $zero, 'F'
	beq	$s1, $t0, chF
	j	checkT

chF:

	addi	$a0, $s3, 5		# $a0/pitch = currPitch + 5 (F)
	syscall				# play F note
	
	sw	$zero, 20($s6)		# reset time pressed to 0
	
	j	readLoop

checkT:

	addi	$t0, $zero, 't'		# else if (ch == 't' || ch == 'T') ...
	beq	$s1, $t0, chT
	addi	$t0, $zero, 'T'
	beq	$s1, $t0, chT
	j	checkG

chT:

	addi	$a0, $s3, 6		# $a0/pitch = currPitch + 6 (F#)
	syscall				# play F# note
	
	sw	$zero, 24($s6)		# reset time pressed to 0
	
	j	readLoop

checkG:

	addi	$t0, $zero, 'g'		# else if (ch == 'g' || ch == 'G') ...
	beq	$s1, $t0, chG
	addi	$t0, $zero, 'G'
	beq	$s1, $t0, chG
	j	checkY

chG:

	addi	$a0, $s3, 7		# $a0/pitch = currPitch + 7 (G)
	syscall				# play G note
	
	sw	$zero, 28($s6)		# reset time pressed to 0
	
	j	readLoop

checkY:

	addi	$t0, $zero, 'y'		# else if (ch == 'y' || ch == 'Y') ...
	beq	$s1, $t0, chY
	addi	$t0, $zero, 'Y'
	beq	$s1, $t0, chY
	j	checkH

chY:

	addi	$a0, $s3, 8		# $a0/pitch = currPitch + 8 (G#)
	syscall				# play G# note
	
	sw	$zero, 32($s6)		# reset time pressed to 0
	
	j	readLoop

checkH:

	addi	$t0, $zero, 'h'		# else if (ch == 'h' || ch == 'H') ...
	beq	$s1, $t0, chH
	addi	$t0, $zero, 'H'
	beq	$s1, $t0, chH
	j	checkU

chH:

	addi	$a0, $s3, 9		# $a0/pitch = currPitch + 9 (A)
	syscall				# play A note
	
	sw	$zero, 36($s6)		# reset time pressed to 0
	
	j	readLoop

checkU:

	addi	$t0, $zero, 'u'		# else if (ch == 'u' || ch == 'U') ...
	beq	$s1, $t0, chU
	addi	$t0, $zero, 'U'
	beq	$s1, $t0, chU
	j	checkJ

chU:

	addi	$a0, $s3, 10		# $a0/pitch = currPitch + 10 (A#)
	syscall				# play A# note
	
	sw	$zero, 40($s6)		# reset time pressed to 0
	
	j	readLoop

checkJ:

	addi	$t0, $zero, 'j'		# else if (ch == 'j' || ch == 'J') ...
	beq	$s1, $t0, chJ
	addi	$t0, $zero, 'J'
	beq	$s1, $t0, chJ
	j	checkK

chJ:

	addi	$a0, $s3, 11		# $a0/pitch = currPitch + 11 (B)
	syscall				# play B note
	
	sw	$zero, 44($s6)		# reset time pressed to 0
	
	j	readLoop

checkK:

	addi	$t0, $zero, 'k'		# else if (ch == 'k' || ch == 'K') ...
	beq	$s1, $t0, chK
	addi	$t0, $zero, 'K'
	beq	$s1, $t0, chK
	j	checkO

chK:

	addi	$a0, $s3, 12		# $a0/pitch = currPitch + 12 (C one octave higher)
	syscall				# play C note (one octave higher)
	
	sw	$zero, 48($s6)		# reset time pressed to 0
	
	j	readLoop

checkO:

	addi	$t0, $zero, 'o'		# else if (ch == 'o' || ch == 'O') ...
	beq	$s1, $t0, chO
	addi	$t0, $zero, 'O'
	beq	$s1, $t0, chO
	j	checkL

chO:

	addi	$a0, $s3, 13		# $a0/pitch = currPitch + 13 (C# one octave higher)
	syscall				# play C# note (one octave higher)
	
	sw	$zero, 52($s6)		# reset time pressed to 0
	
	j	readLoop

checkL:

	addi	$t0, $zero, 'l'		# else if (ch == 'l' || ch == 'L') ...
	beq	$s1, $t0, chL
	addi	$t0, $zero, 'L'
	beq	$s1, $t0, chL
	j	checkP

chL:

	addi	$a0, $s3, 14		# $a0/pitch = currPitch + 14 (D one octave higher)
	syscall				# play D note (one octave higher)
	
	sw	$zero, 56($s6)		# reset time pressed to 0
	
	j	readLoop

checkP:

	addi	$t0, $zero, 'p'		# else if (ch == 'p' || ch == 'P') ...
	beq	$s1, $t0, chP
	addi	$t0, $zero, 'P'
	beq	$s1, $t0, chP
	j	checkSemi

chP:

	addi	$a0, $s3, 15		# $a0/pitch = currPitch + 15 (D# one octave higher)
	syscall				# play D# note (one octave higher)
	
	sw	$zero, 60($s6)		# reset time pressed to 0
	
	j	readLoop

checkSemi:

	addi	$t0, $zero, ';'		# else if (ch == ';') ...
	beq	$s1, $t0, chSemi
	j	checkCom

chSemi:

	addi	$a0, $s3, 16		# $a0/pitch = currPitch + 16 (E one octave higher)
	syscall				# play E note (one octave higher)
	
	sw	$zero, 64($s6)		# reset time pressed to 0
	
	j	readLoop

checkCom:

	addi	$t0, $zero, ','		# else if (ch == ',') ...
	beq	$s1, $t0, chCom
	j	checkPer

chCom:

	addi	$s3, $s3, -12			# currPitch -= 12
	slt	$t0, $s3, $zero			# $t0 = currPitch < 0
	beq	$t0, $zero, NoClampOctUp	# if (currPitch < 0) ...

	addi	$s3, $zero, 0			# currPitch = 0

NoClampOctUp:					# end inner if

	j	readLoop

checkPer:

	addi	$t0, $zero, '.'		# else if (ch == '.') ...
	beq	$s1, $t0, chPer
	j	checkMin

chPer:

	addi	$s3, $s3, 12			# currPitch += 12
	slti	$t0, $s3, 109			# $t0 = currPitch <= 108
	bne	$t0, $zero, NoClampOctDown	# if (currPitch > 108) ...

	addi	$s3, $zero, 108			# currPitch = 108

NoClampOctDown:					# end inner if

	j	readLoop

checkMin:

	addi	$t0, $zero, '-'		# else if (ch == '-') ...
	beq	$s1, $t0, chMin
	j	checkEq

chMin:

	addi	$s5, $s5, -100			# currTime -= 100 (ms)
	slti	$t0, $s5, 100			# $t0 = currTime < 100
	beq	$t0, $zero, NoClampTimeUp	# if (currTime < 100) ...

	addi	$s5, $zero, 100			# currTime = 100

NoClampTimeUp:					# end inner if

	j	readLoop

checkEq:

	addi	$t0, $zero, '='		# else if (ch == '=') ...
	beq	$s1, $t0, chEq
	j	checkUnd

chEq:

	addi	$s5, $s5, 100			# currTime += 100 (ms)
	slti	$t0, $s5, 10001			# $t0 = currTime <= 10000
	bne	$t0, $zero, NoClampTimeDown	# if (currTime > 10000) ...

	addi	$s5, $zero, 10000		# currTime = 10000

NoClampTimeDown:				# end inner if

	j	readLoop

checkUnd:

	addi	$t0, $zero, '_'		# else if (ch == '_') ...
	beq	$s1, $t0, chUnd
	j	checkPlus

chUnd:

	addi	$s5, $s5, -1000			# currTime -= 1000 (ms)
	slti	$t0, $s5, 100			# $t0 = currTime < 100
	beq	$t0, $zero, NoClampTimeUp2	# if (currTime < 100) ...

	addi	$s5, $zero, 100			# currTime = 100

NoClampTimeUp2:					# end inner if

	j	readLoop

checkPlus:

	addi	$t0, $zero, '+'		# else if (ch == '+') ...
	beq	$s1, $t0, chPlus
	j	checkSBracO

chPlus:

	addi	$s5, $s5, 1000			# currTime += 1000 (ms)
	slti	$t0, $s5, 10001			# $t0 = currTime <= 10000
	bne	$t0, $zero, NoClampTimeDown2	# if (currTime > 10000) ...

	addi	$s5, $zero, 10000		# currTime = 10000

NoClampTimeDown2:				# end inner if

	j	readLoop

checkSBracO:

	addi	$t0, $zero, '['		# else if (ch == '[') ...
	beq	$s1, $t0, chSBracO
	j	checkSBracC

chSBracO:

	addi	$s2, $s2, -1		# currSound -= 1
	andi	$s2, $s2, 0x7f		# currSound &= 0x7f (limits currSound from 0-127)

	j	readLoop

checkSBracC:

	addi	$t0, $zero, ']'		# else if (ch == ']') ...
	beq	$s1, $t0, chSBracC
	j	checkCBracO

chSBracC:

	addi	$s2, $s2, 1		# currSound += 1
	andi	$s2, $s2, 0x7f		# currSound &= 0x7f (limits currSound from 0-127)
	
	j	readLoop

checkCBracO:

	addi	$t0, $zero, '{'		# else if (ch == '{') ...
	beq	$s1, $t0, chCBracO
	j	checkCBracC

chCBracO:

	addi	$s2, $s2, -16		# currSound -= 16
	andi	$s2, $s2, 0x7f		# currSound &= 0x7f (limits currSound from 0-127)

	j	readLoop

checkCBracC:

	addi	$t0, $zero, '}'		# else if (ch == '}') ...
	beq	$s1, $t0, chCBracC
	j	readLoop

chCBracC:

	addi	$s2, $s2, 16		# currSound += 16
	andi	$s2, $s2, 0x7f		# currSound &= 0x7f (limits currSound from 0-127)
	
	j       readLoop		# end loop





# void drawInit():
#   bruh it makes a buncha rectangles

drawInit:

	addiu	$sp, $sp, -24		# standard prologue - allocate 6 words of stack space
	sw	$fp, 0($sp)
	sw	$ra, 4($sp)
	addiu	$fp, $sp, 20
	
	addi	$a0, $zero, 0		# set up parameters for drawRect
	addi	$a1, $zero, 0
	addi	$a2, $zero, 128
	addi	$a3, $zero, 64
	lui	$t0, 0x88
	addi	$t0, $t0, 0x8888
	sw	$t0, -4($sp)		# drawRect(0, 0, 128, 64, gray)
	
	jal	drawRect
	
	addi	$a0, $zero, 13		# set up parameters for drawRect
	addi	$a1, $zero, 6
	addi	$a2, $zero, 101
	addi	$a3, $zero, 1
	sw	$zero, -4($sp)		# drawRect(13, 6, 101, 1, black)
	
	jal	drawRect
	
	addi	$a0, $zero, 13		# set up parameters for drawRect
	addi	$a1, $zero, 42
	addi	$a2, $zero, 101
	addi	$a3, $zero, 1
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(13, 42, 101, 1, black)
	
	addi	$a0, $zero, 14		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 99
	addi	$a3, $zero, 35
	addi	$t0, $zero, -1
	sw	$t0, -4($sp)
	
	jal	drawRect		# drawRect(14, 7, 99, 35, white)
	
	addi	$a0, $zero, 13		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(13, 7, 1, 35, black)
	
	addi	$a0, $zero, 23		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(23, 7, 1, 35, black)
	
	addi	$a0, $zero, 33		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(33, 7, 1, 35, black)
	
	addi	$a0, $zero, 43		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(43, 7, 1, 35, black)
	
	addi	$a0, $zero, 53		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(53, 7, 1, 35, black)
	
	addi	$a0, $zero, 63		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(63, 7, 1, 35, black)
	
	addi	$a0, $zero, 73		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(73, 7, 1, 35, black)
	
	addi	$a0, $zero, 83		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(83, 7, 1, 35, black)
	
	addi	$a0, $zero, 93		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(93, 7, 1, 35, black)
	
	addi	$a0, $zero, 103		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(103, 7, 1, 35, black)
	
	addi	$a0, $zero, 113		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 1
	addi	$a3, $zero, 35
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(113, 7, 1, 35, black)
	
	addi	$a0, $zero, 19		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 7
	addi	$a3, $zero, 20
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(19, 7, 7, 20, black)
	
	addi	$a0, $zero, 31		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 7
	addi	$a3, $zero, 20
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(31, 7, 7, 20, black)
	
	addi	$a0, $zero, 49		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 7
	addi	$a3, $zero, 20
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(49, 7, 7, 20, black)
	
	addi	$a0, $zero, 60		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 7
	addi	$a3, $zero, 20
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(60, 7, 7, 20, black)
	
	addi	$a0, $zero, 71		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 7
	addi	$a3, $zero, 20
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(71, 7, 7, 20, black)
	
	addi	$a0, $zero, 89		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 7
	addi	$a3, $zero, 20
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(89, 7, 7, 20, black)
	
	addi	$a0, $zero, 101		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 7
	addi	$a3, $zero, 20
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(101, 7, 7, 20, black)
	
	jal	drawOctave		# drawOctave()
	jal	drawSound		# drawSound()
	jal	drawTime		# drawTime()
	
	lw	$ra, 4($sp)		# standard epilogue - free 6 words of space and return
	lw	$fp, 0($sp)
	addiu	$sp, $sp, 24
	jr	$ra





# void updateGUI(&timeCounts, currSound, currPitch, currTime):
#   for every key in timeCounts, if and only if it is less than both the current time
#     and 1000ms since last pressed, make sure the key is colored in
#     and increment the timeCounts by 16 (since this function only runs every 16ms)
#   make sure sound bar shows what it should (binary representation of current sound)
#   make sure octave bar shows what it should
#   make sure duration bar shows what it should
#
# note: all the graphical updates should not run continuous updates, checking is done
#   beforehand to see if redrawing is necessary

updateGUI:

	addiu	$sp, $sp, -24		# standard prologue - allocate 6 words of stack space
	sw	$fp, 0($sp)
	sw	$ra, 4($sp)
	addiu	$fp, $sp, 20
	sw	$a0, 8($sp)		# store arguments onto stack for later recovery
	sw	$a1, 12($sp)
	sw	$a2, 16($sp)
	sw	$a3, 20($sp)
	
	la	$t6, display		# $t6 = &display


	
	lw	$t7, 0($a0)		# load timeCount for key 0
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xe38($t6)		# check color at (7 * 128 + 14) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey0Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey0After	# if (key 0 is not already white) ...
	
	addi	$a0, $zero, 14		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(14, 7, 5, 20, white)
	
	addi	$a0, $zero, 14		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(14, 27, 9, 15, white)
	
	j	ugKey0After

ugKey0Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey0After	# if (key 0 is white) ...
	
	addi	$a0, $zero, 14		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(14, 7, 5, 20, gray)
	
	addi	$a0, $zero, 14		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(14, 27, 9, 215, gray)

ugKey0After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 0
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 0($a0)


	
	lw	$t7, 4($a0)		# load timeCount for key 1
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xe50($t6)		# check color at (7 * 128 + 20) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	
	bne	$t0, $zero, ugKey1Pressed	# if (key is not pressed) ...
	
	beq	$t1, $zero, ugKey1After	# if (key 1 is not already black) ...
	
	addi	$a0, $zero, 20		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(20, 7, 5, 19, black)
	
	j	ugKey1After

ugKey1Pressed:				# ... else (outer if) ...
	
	bne	$t1, $zero, ugKey1After	# if (key 1 is black) ...
	
	addi	$a0, $zero, 20		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	lui	$t1, 0x33
	addi	$t1, $t1, 0x3333
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(20, 7, 5, 19, dark gray)

ugKey1After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 1
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 4($a0)


	
	lw	$t7, 8($a0)		# load timeCount for key 2
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xe68($t6)		# check color at (7 * 128 + 26) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey2Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey2After	# if (key 2 is not already white) ...
	
	addi	$a0, $zero, 26		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(26, 7, 5, 20, white)
	
	addi	$a0, $zero, 24		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(24, 27, 9, 15, white)
	
	j	ugKey2After

ugKey2Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey2After	# if (key 2 is white) ...
	
	addi	$a0, $zero, 26		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(26, 7, 5, 20, gray)
	
	addi	$a0, $zero, 24		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(24, 27, 9, 215, gray)

ugKey2After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 2
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 8($a0)


	
	lw	$t7, 12($a0)		# load timeCount for key 3
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xe80($t6)		# check color at (7 * 128 + 32) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	
	bne	$t0, $zero, ugKey3Pressed	# if (key is not pressed) ...

	beq	$t1, $zero, ugKey3After	# if (key 3 is not already black) ...
	
	addi	$a0, $zero, 32		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(32, 7, 5, 19, black)
	
	j	ugKey3After

ugKey3Pressed:				# ... else (outer if) ...
	
	bne	$t1, $zero, ugKey3After	# if (key 3 is black) ...
	
	addi	$a0, $zero, 32		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	lui	$t1, 0x33
	addi	$t1, $t1, 0x3333
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(32, 7, 5, 19, dark gray)

ugKey3After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 3
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 12($a0)


	
	lw	$t7, 16($a0)		# load timeCount for key 4
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xe98($t6)		# check color at (7 * 128 + 38) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey4Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey4After	# if (key 4 is not already white) ...
	
	addi	$a0, $zero, 38		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(38, 7, 5, 20, white)
	
	addi	$a0, $zero, 34		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(34, 27, 9, 15, white)
	
	j	ugKey4After

ugKey4Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey4After	# if (key 4 is white) ...
	
	addi	$a0, $zero, 38		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(38, 7, 5, 20, gray)
	
	addi	$a0, $zero, 34		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(34, 27, 9, 215, gray)

ugKey4After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 4
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 16($a0)


	
	lw	$t7, 20($a0)		# load timeCount for key 5
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xeb0($t6)		# check color at (7 * 128 + 44) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey5Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey5After	# if (key 5 is not already white) ...
	
	addi	$a0, $zero, 44		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(44, 7, 5, 20, white)
	
	addi	$a0, $zero, 44		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(44, 27, 9, 15, white)
	
	j	ugKey5After

ugKey5Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey5After	# if (key 5 is white) ...
	
	addi	$a0, $zero, 44		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(44, 7, 5, 20, gray)
	
	addi	$a0, $zero, 44		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(44, 27, 9, 215, gray)

ugKey5After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 5
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 20($a0)


	
	lw	$t7, 24($a0)		# load timeCount for key 6
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xec8($t6)		# check color at (7 * 128 + 50) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	
	bne	$t0, $zero, ugKey6Pressed	# if (key is not pressed) ...

	beq	$t1, $zero, ugKey6After	# if (key 6 is not already black) ...
	
	addi	$a0, $zero, 50		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(50, 7, 5, 19, black)
	
	j	ugKey6After

ugKey6Pressed:				# ... else (outer if) ...
	
	bne	$t1, $zero, ugKey6After	# if (key 6 is black) ...
	
	addi	$a0, $zero, 50		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	lui	$t1, 0x33
	addi	$t1, $t1, 0x3333
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(50, 7, 5, 19, dark gray)

ugKey6After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 6
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 24($a0)


	
	lw	$t7, 28($a0)		# load timeCount for key 7
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xee0($t6)		# check color at (7 * 128 + 56) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey7Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey7After	# if (key 7 is not already white) ...
	
	addi	$a0, $zero, 56		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 4
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(56, 7, 4, 20, white)
	
	addi	$a0, $zero, 54		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(54, 27, 9, 15, white)
	
	j	ugKey7After

ugKey7Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey7After	# if (key 7 is white) ...
	
	addi	$a0, $zero, 56		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 4
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(56, 7, 4, 20, gray)
	
	addi	$a0, $zero, 54		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(54, 27, 9, 215, gray)

ugKey7After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 7
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 28($a0)


	
	lw	$t7, 32($a0)		# load timeCount for key 8
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xef4($t6)		# check color at (7 * 128 + 61) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	
	bne	$t0, $zero, ugKey8Pressed	# if (key is not pressed) ...

	beq	$t1, $zero, ugKey8After	# if (key 8 is not already black) ...
	
	addi	$a0, $zero, 61		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(61, 7, 5, 19, black)
	
	j	ugKey8After

ugKey8Pressed:				# ... else (outer if) ...
	
	bne	$t1, $zero, ugKey8After	# if (key 8 is black) ...
	
	addi	$a0, $zero, 61		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	lui	$t1, 0x33
	addi	$t1, $t1, 0x3333
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(61, 7, 5, 19, dark gray)

ugKey8After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 8
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 32($a0)


	
	lw	$t7, 36($a0)		# load timeCount for key 9
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xf0c($t6)		# check color at (7 * 128 + 67) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey9Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey9After	# if (key 9 is not already white) ...
	
	addi	$a0, $zero, 67		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 4
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(67, 7, 4, 20, white)
	
	addi	$a0, $zero, 64		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(64, 27, 9, 15, white)
	
	j	ugKey9After

ugKey9Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey9After	# if (key 9 is white) ...
	
	addi	$a0, $zero, 67		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 4
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(67, 7, 4, 20, gray)
	
	addi	$a0, $zero, 64		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(64, 27, 9, 215, gray)

ugKey9After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 9
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 36($a0)


	
	lw	$t7, 40($a0)		# load timeCount for key 10
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xf20($t6)		# check color at (7 * 128 + 72) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	
	bne	$t0, $zero, ugKey10Pressed	# if (key is not pressed) ...

	beq	$t1, $zero, ugKey10After	# if (key 10 is not already black) ...
	
	addi	$a0, $zero, 72		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(72, 7, 5, 19, black)
	
	j	ugKey10After

ugKey10Pressed:				# ... else (outer if) ...
	
	bne	$t1, $zero, ugKey10After	# if (key 10 is black) ...
	
	addi	$a0, $zero, 72		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	lui	$t1, 0x33
	addi	$t1, $t1, 0x3333
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(72, 7, 5, 19, dark gray)

ugKey10After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 10
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 40($a0)


	
	lw	$t7, 44($a0)		# load timeCount for key 11
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xf38($t6)		# check color at (7 * 128 + 78) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey11Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey11After	# if (key 11 is not already white) ...
	
	addi	$a0, $zero, 78		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(78, 7, 5, 20, white)
	
	addi	$a0, $zero, 74		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(74, 27, 9, 15, white)
	
	j	ugKey11After

ugKey11Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey11After	# if (key 11 is white) ...
	
	addi	$a0, $zero, 78		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(78, 7, 5, 20, gray)
	
	addi	$a0, $zero, 74		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(74, 27, 9, 215, gray)

ugKey11After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 11
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 44($a0)


	
	lw	$t7, 48($a0)		# load timeCount for key 12
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xf50($t6)		# check color at (7 * 128 + 84) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey12Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey12After	# if (key 12 is not already white) ...
	
	addi	$a0, $zero, 84		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(84, 7, 5, 20, white)
	
	addi	$a0, $zero, 84		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(84, 27, 9, 15, white)
	
	j	ugKey12After

ugKey12Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey12After	# if (key 12 is white) ...
	
	addi	$a0, $zero, 84		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(84, 7, 5, 20, gray)
	
	addi	$a0, $zero, 84		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(84, 27, 9, 215, gray)

ugKey12After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 12
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 48($a0)


	
	lw	$t7, 52($a0)		# load timeCount for key 13
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xf68($t6)		# check color at (7 * 128 + 90) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	
	bne	$t0, $zero, ugKey13Pressed	# if (key is not pressed) ...

	beq	$t1, $zero, ugKey13After	# if (key 13 is not already black) ...
	
	addi	$a0, $zero, 90		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(90, 7, 5, 19, black)
	
	j	ugKey13After

ugKey13Pressed:				# ... else (outer if) ...
	
	bne	$t1, $zero, ugKey13After	# if (key 13 is black) ...
	
	addi	$a0, $zero, 90		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	lui	$t1, 0x33
	addi	$t1, $t1, 0x3333
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(90, 7, 5, 19, dark gray)

ugKey13After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 13
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 52($a0)


	
	lw	$t7, 56($a0)		# load timeCount for key 14
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xf80($t6)		# check color at (7 * 128 + 96) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey14Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey14After	# if (key 14 is not already white) ...
	
	addi	$a0, $zero, 96		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(96, 7, 5, 20, white)
	
	addi	$a0, $zero, 94		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(94, 27, 9, 15, white)
	
	j	ugKey14After

ugKey14Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey14After	# if (key 14 is white) ...
	
	addi	$a0, $zero, 96		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(96, 7, 5, 20, gray)
	
	addi	$a0, $zero, 94		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(94, 27, 9, 215, gray)

ugKey14After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 14
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 56($a0)


	
	lw	$t7, 60($a0)		# load timeCount for key 15
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xf98($t6)		# check color at (7 * 128 + 102) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	
	bne	$t0, $zero, ugKey15Pressed	# if (key is not pressed) ...

	beq	$t1, $zero, ugKey15After	# if (key 15 is not already black) ...
	
	addi	$a0, $zero, 102		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(102, 7, 5, 19, black)
	
	j	ugKey15After

ugKey15Pressed:				# ... else (outer if) ...
	
	bne	$t1, $zero, ugKey15After	# if (key 15 is black) ...
	
	addi	$a0, $zero, 102		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 19
	lui	$t1, 0x33
	addi	$t1, $t1, 0x3333
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(102, 7, 5, 19, dark gray)

ugKey15After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 15
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 60($a0)


	
	lw	$t7, 64($a0)		# load timeCount for key 16
	slt	$t0, $t7, $a3		# $t0 = key has been pressed for less than currTime
	slti	$t1, $t7, 1000		# $t1 = key has been pressed for less than 1s
	and	$t0, $t0, $t1		# $t0 = both ^
	
	lw	$t1, 0xfB0($t6)		# check color at (7 * 128 + 108) * 4
	andi	$t1, $t1, 0xff		# $t1 = color check bits
	addi	$t2, $zero, 0xff	# $t2 = white
	
	bne	$t0, $zero, ugKey16Pressed	# if (key is not pressed) ...
	
	beq	$t1, $t2, ugKey16After	# if (key 16 is not already white) ...
	
	addi	$a0, $zero, 108		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(108, 7, 5, 20, white)
	
	addi	$a0, $zero, 104		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(104, 27, 9, 15, white)
	
	j	ugKey16After

ugKey16Pressed:				# ... else (outer if) ...
	
	bne	$t1, $t2, ugKey16After	# if (key 16 is white) ...
	
	addi	$a0, $zero, 108		# set up parameters for drawRect
	addi	$a1, $zero, 7
	addi	$a2, $zero, 5
	addi	$a3, $zero, 20
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(108, 7, 5, 20, gray)
	
	addi	$a0, $zero, 104		# set up parameters for drawRect
	addi	$a1, $zero, 27
	addi	$a2, $zero, 9
	addi	$a3, $zero, 15
	lui	$t1, 0xbb
	addi	$t1, $t1, 0xbbbb
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(104, 27, 9, 215, gray)

ugKey16After:				# end outer if

	addi	$t7, $t7, 16		# increment timeCount for key 16
	lw	$a0, 8($sp)		# retrieve correct $a0 from stack
	sw	$t7, 64($a0)


	
	lw	$a1, 12($sp)		# retrieve correct currSound from stack
	addi	$t7, $zero, 0		# i = 0
	
ugSoundLoop:

	slti	$t1, $t7, 7		# while (i <= 6) ...
	beq	$t1, $zero, ugSoundLoopEnd
	
	srlv	$t1, $a1, $t7		# $t1 = currSound >> i
	andi	$t1, $t1, 0x1		# $t1 = (currSound >> i) & 0x1 (ith bit of currSound)
	
	addi	$t4, $zero, 6		# $t4 = 6
	sub	$t4, $t4, $t7		# $t4 = 6 - i
	sll	$t2, $t4, 4		# $t2 = 16 * (6 - i)
	add	$t2, $t6, $t2		# $t2 = &display[4*(6-i)]
	lw	$t2, 0x6ac8($t2)	# $t2 = display[4*(6-i) + (53 * 128 + 50)] (index into sound box)
	andi	$t2, $t2, 0xff		# $t2 = color check bits of ^
	addi	$t3, $zero, 0xff	# $t3 = white color check bits
	
	bne	$t1, $zero, ugSoundBit	# if (no bit in this spot) ...
	
	beq	$t2, $t3, ugSoundBitAfter	# if (pixel is not already white) ...
	
	sll	$a0, $t4, 2		# set up parameters for drawRect
	addi	$a0, $a0, 50
	addi	$a1, $zero, 53
	addi	$a2, $zero, 4
	addi	$a3, $zero, 5
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(50 + 4*(6-i), 53, 4, 5, white)
	
	j	ugSoundBitAfter

ugSoundBit:				# ... else (outer if) ...
	
	bne	$t2, $t3, ugSoundBitAfter	# if (pixel is white)
	
	sll	$a0, $t4, 2		# set up parameters for drawRect
	addi	$a0, $a0, 50
	addi	$a1, $zero, 53
	addi	$a2, $zero, 4
	addi	$a3, $zero, 5
	addi	$t1, $zero, 0x9900
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(50 + 4*(6-i), 53, 4, 5, green)
	
ugSoundBitAfter:

	addi	$t7, $t7, 1
	
	j	ugSoundLoop

ugSoundLoopEnd:


	
	lw	$a2, 16($sp)		# retrieve correct currPitch from stack
	addi	$t7, $zero, 12		# $t7 = 12
	div	$a2, $t7		# $t7 = currPitch / 12 (0-9)
	mflo	$t7
	sll	$t0, $t7, 1		# $t0 = 2 * (currPitch / 12)
	add	$t7, $t0, $t7		# $t7 = 3 * (currPitch / 12)
	
	sll	$t2, $t7, 2		# $t2 = 12 * (currPitch / 12)
	add	$t2, $t6, $t2		# $t2 = &display[3*(currPitch/12)]
	lw	$t2, 0x6a28($t2)	# $t2 = display[3*(currPitch/12) + (53 * 128 + 10)] (index into octave box)
	andi	$t2, $t2, 0xff		# $t2 = color check bits of ^
	addi	$t3, $zero, 0xff	# $t3 = white color check bits
	
	bne	$t2, $t3, ugOctAfter	# if (pixel is white) ...
	
	addi	$a0, $zero, 10		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 30
	addi	$a3, $zero, 5
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(10, 53, 30, 5, white)
	
	addi	$a0, $zero, 10		# set up parameters for drawRect
	add	$a0, $a0, $t7
	addi	$a1, $zero, 53
	addi	$a2, $zero, 3
	addi	$a3, $zero, 5
	lui	$t1, 0xee
	addi	$t1, $t1, 0x2222
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(10 + 3*(currPitch/12), 53, 3, 5, red)
	
ugOctAfter:


	
	lw	$a3, 20($sp)		# retrieve correct currTime from stack
	addi	$t4, $a3, 200		# $t4 = currTime + 200
	sll	$t7, $t4, 5		# $t7 = 32 * (currTime + 200)
	sll	$t0, $t4, 1		# $t0 = 2 * (currTime + 200)
	sub	$t7, $t7, $t0		# $t7 = 30 * (currTime + 200)
	addi	$t0, $zero, 10150	# $t0 = 10150
	div	$t7, $t0		# timeIndex = (30 * (currTime + 200)) / 10150
	mflo	$t7
	
	sll	$t2, $t7, 2		# $t2 = 4 * timeIndex
	add	$t2, $t6, $t2		# $t2 = &display[timeIndex]
	lw	$t1, 0x6b5c($t2)	# $t1 = display[timeIndex + (53 * 128 + 88) - 1] (index into duration box)
	andi	$t1, $t1, 0xff00	# $t1 = color check bits of ^ (different than usual bc blue)
	addi	$t3, $zero, 0xff00	# $t3 = white color check bits
	
	beq	$t1, $t3, ugDur		# if (pixel is white) update duration
	
	addi	$t4, $zero, 30		# $t4 = 30
	beq	$t7, $t4, ugDurAfter	# if (bar is full) dont check second condition
	
	addi	$t2, $t2, 4		# $t2 = &display[timeIndex + 1]
	lw	$t1, 0x6b5c($t2)	# $t1 = display[timeIndex + (53 * 128 + 88)] (index into duration box)
	andi	$t1, $t1, 0xff00	# $t1 = color check bits of ^ (different than usual bc blue)
	
	bne	$t1, $t3, ugDur		# if (pixel after this is not white) update duration
	
	j	ugDurAfter

ugDur:
	
	addi	$a0, $zero, 88		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 30
	addi	$a3, $zero, 5
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(88, 53, 30, 5, white)
	
	addi	$a0, $zero, 88		# set up parameters for drawRect
	addi	$a1, $zero, 53
	add	$a2, $t7, $zero
	addi	$a3, $zero, 5
	lui	$t1, 0xbb
	addi	$t1, $zero, 0x77ff
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(88, 53, timeIndex, 5, blue)
	
ugDurAfter:

	lw	$ra, 4($sp)		# standard epilogue - free 6 words of space and return
	lw	$fp, 0($sp)
	addiu	$sp, $sp, 24
	jr	$ra





# void drawRect(x, y, width, height, color):
#   for row from 0 to height:
#     for col from 0 to width:
#       display[128*(y+row) + x + 4*col] = color

drawRect:

	addiu	$sp, $sp, -28		# standard prologue - allocate 7 words of stack space for 5 args
	sw	$fp, 0($sp)
	sw	$ra, 4($sp)
	addiu	$fp, $sp, 24
	lw	$t1, 0($fp)		# $t1 = color
	
	la	$t0, display		# $t0 = &display
	sll	$t4, $a1, 9		# $t4 = 4 * 128 * y
	add	$t0, $t0, $t4		# $t0 = &display[128*y]
	sll	$t2, $a0, 2		# $t2 = 4 * x
	add	$t0, $t0, $t2		# $t0 = &display[128*y + x] (top left of rectangle to be drawn)
	
	addi	$t3, $zero, 0		# row = 0

drHLoop:

	slt	$t4, $t3, $a3		# while (row < height) ...
	beq	$t4, $zero, drHLoopEnd
	
	addi	$t2, $zero, 0		# col = 0

drWLoop:

	slt	$t4, $t2, $a2		# while (col < width) ...
	beq	$t4, $zero, drWLoopEnd
	
	sll	$t5, $t2, 2		# $t5 = 4 * col
	add	$t5, $t0, $t5		# $t0 = &display[128*(y+row) + x + 4*col]
	sw	$t1, 0($t5)		# display[128*(y+row) + x + 4*col] = color
	
	addi	$t2, $t2, 1		# col++
	
	j	drWLoop			# end inner loop

drWLoopEnd:

	addi	$t3, $t3, 1		# row++
	addi	$t0, $t0, 512		# $t0 = &display[128*(y+row) + x] (increments $t0 by one row)
	
	j	drHLoop			# end outer loop

drHLoopEnd:
	
	lw	$ra, 4($sp)		# standard epilogue - free 7 words of space (5 args) and return
	lw	$fp, 0($sp)
	addiu	$sp, $sp, 28
	jr	$ra
	




# void drawOctave():
#   draw O C T A V E
#   draw octave box

drawOctave:

	addiu	$sp, $sp, -24		# standard prologue - allocate 6 words of stack space
	sw	$fp, 0($sp)
	sw	$ra, 4($sp)
	addiu	$fp, $sp, 20

	la	$t0, display		# $t0 = &display

	sw	$zero, 0x6034($t0)	# O
	sw	$zero, 0x6038($t0)
	sw	$zero, 0x603c($t0)
	sw	$zero, 0x6234($t0)
	sw	$zero, 0x623c($t0)
	sw	$zero, 0x6434($t0)
	sw	$zero, 0x6438($t0)
	sw	$zero, 0x643c($t0)

	sw	$zero, 0x6044($t0)	# C
	sw	$zero, 0x6048($t0)
	sw	$zero, 0x604c($t0)
	sw	$zero, 0x6244($t0)
	sw	$zero, 0x6444($t0)
	sw	$zero, 0x6448($t0)
	sw	$zero, 0x644c($t0)

	sw	$zero, 0x6054($t0)	# T
	sw	$zero, 0x6058($t0)
	sw	$zero, 0x605c($t0)
	sw	$zero, 0x6258($t0)
	sw	$zero, 0x6458($t0)

	sw	$zero, 0x6064($t0)	# A
	sw	$zero, 0x6068($t0)
	sw	$zero, 0x606c($t0)
	sw	$zero, 0x6264($t0)
	sw	$zero, 0x6268($t0)
	sw	$zero, 0x626c($t0)
	sw	$zero, 0x6464($t0)
	sw	$zero, 0x646c($t0)

	sw	$zero, 0x6074($t0)	# V
	sw	$zero, 0x607c($t0)
	sw	$zero, 0x6274($t0)
	sw	$zero, 0x627c($t0)
	sw	$zero, 0x6474($t0)
	sw	$zero, 0x6478($t0)
	sw	$zero, 0x647c($t0)

	sw	$zero, 0x6084($t0)	# E
	sw	$zero, 0x6088($t0)
	sw	$zero, 0x608c($t0)
	sw	$zero, 0x6284($t0)
	sw	$zero, 0x6288($t0)
	sw	$zero, 0x6484($t0)
	sw	$zero, 0x6488($t0)
	sw	$zero, 0x648c($t0)
	
	addi	$a0, $zero, 9		# set up parameters for drawRect	
	addi	$a1, $zero, 52
	addi	$a2, $zero, 32
	addi	$a3, $zero, 1
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(9, 52, 32, 1, black)
	
	addi	$a0, $zero, 9		# set up parameters for drawRect
	addi	$a1, $zero, 58
	addi	$a2, $zero, 32
	addi	$a3, $zero, 1
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(9, 58, 32, 1, black)
	
	addi	$a0, $zero, 9		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 1
	addi	$a3, $zero, 5
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(9, 53, 1, 5, black)
	
	addi	$a0, $zero, 40		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 1
	addi	$a3, $zero, 5
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(40, 53, 1, 5, black)
	
	addi	$a0, $zero, 10		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 30
	addi	$a3, $zero, 5
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(10, 53, 30, 5, white)
	
	addi	$a0, $zero, 25		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 3
	addi	$a3, $zero, 5
	lui	$t1, 0xee
	addi	$t1, $t1, 0x2222
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(25, 53, 3, 5, red)
	
	lw	$ra, 4($sp)		# standard epilogue - free 6 words of space and return
	lw	$fp, 0($sp)
	addiu	$sp, $sp, 24
	jr	$ra





drawSound:

	addiu	$sp, $sp, -24		# standard prologue - allocate 6 words of stack space
	sw	$fp, 0($sp)
	sw	$ra, 4($sp)
	addiu	$fp, $sp, 20

	la	$t0, display		# $t0 = &display

	sw	$zero, 0x60d8($t0)	# S
	sw	$zero, 0x60dc($t0)
	sw	$zero, 0x62d8($t0)
	sw	$zero, 0x62dc($t0)
	sw	$zero, 0x62e0($t0)
	sw	$zero, 0x64dc($t0)
	sw	$zero, 0x64e0($t0)

	sw	$zero, 0x60e8($t0)	# O
	sw	$zero, 0x60ec($t0)
	sw	$zero, 0x60f0($t0)
	sw	$zero, 0x62e8($t0)
	sw	$zero, 0x62f0($t0)
	sw	$zero, 0x64e8($t0)
	sw	$zero, 0x64ec($t0)
	sw	$zero, 0x64f0($t0)

	sw	$zero, 0x60f8($t0)	# U
	sw	$zero, 0x6100($t0)
	sw	$zero, 0x62f8($t0)
	sw	$zero, 0x6300($t0)
	sw	$zero, 0x64f8($t0)
	sw	$zero, 0x64fc($t0)
	sw	$zero, 0x6500($t0)

	sw	$zero, 0x6108($t0)	# N
	sw	$zero, 0x610c($t0)
	sw	$zero, 0x6110($t0)
	sw	$zero, 0x6308($t0)
	sw	$zero, 0x6310($t0)
	sw	$zero, 0x6508($t0)
	sw	$zero, 0x6510($t0)

	sw	$zero, 0x6120($t0)	# D
	sw	$zero, 0x6318($t0)
	sw	$zero, 0x631c($t0)
	sw	$zero, 0x6320($t0)
	sw	$zero, 0x6518($t0)
	sw	$zero, 0x651c($t0)
	sw	$zero, 0x6520($t0)
	
	addi	$a0, $zero, 49		# set up parameters for drawRect
	addi	$a1, $zero, 52
	addi	$a2, $zero, 30
	addi	$a3, $zero, 1
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(49, 52, 30, 1, black)
	
	addi	$a0, $zero, 49		# set up parameters for drawRect
	addi	$a1, $zero, 58
	addi	$a2, $zero, 30
	addi	$a3, $zero, 1
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(49, 58, 30, 1, black)
	
	addi	$a0, $zero, 49		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 1
	addi	$a3, $zero, 5
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(49, 53, 1, 5, black)
	
	addi	$a0, $zero, 78		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 1
	addi	$a3, $zero, 5
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(78, 53, 1, 5, black)
	
	addi	$a0, $zero, 50		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 28
	addi	$a3, $zero, 5
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(50, 53, 28, 5, white)
	
	lw	$ra, 4($sp)		# standard epilogue - free 6 words of space and return
	lw	$fp, 0($sp)
	addiu	$sp, $sp, 24
	jr	$ra





drawTime:

	addiu	$sp, $sp, -24		# standard prologue - allocate 6 words of stack space
	sw	$fp, 0($sp)
	sw	$ra, 4($sp)
	addiu	$fp, $sp, 20

	la	$t0, display		# $t0 = &display

	sw	$zero, 0x6164($t0)	# D
	sw	$zero, 0x635c($t0)
	sw	$zero, 0x6360($t0)
	sw	$zero, 0x6364($t0)
	sw	$zero, 0x655c($t0)
	sw	$zero, 0x6560($t0)
	sw	$zero, 0x6564($t0)

	sw	$zero, 0x616c($t0)	# U
	sw	$zero, 0x6174($t0)
	sw	$zero, 0x636c($t0)
	sw	$zero, 0x6374($t0)
	sw	$zero, 0x656c($t0)
	sw	$zero, 0x6570($t0)
	sw	$zero, 0x6574($t0)

	sw	$zero, 0x617c($t0)	# R
	sw	$zero, 0x6180($t0)
	sw	$zero, 0x6184($t0)
	sw	$zero, 0x637c($t0)
	sw	$zero, 0x6384($t0)
	sw	$zero, 0x657c($t0)

	sw	$zero, 0x618c($t0)	# A
	sw	$zero, 0x6190($t0)
	sw	$zero, 0x6194($t0)
	sw	$zero, 0x638c($t0)
	sw	$zero, 0x6390($t0)
	sw	$zero, 0x6394($t0)
	sw	$zero, 0x658c($t0)
	sw	$zero, 0x6594($t0)

	sw	$zero, 0x619c($t0)	# T
	sw	$zero, 0x61a0($t0)
	sw	$zero, 0x61a4($t0)
	sw	$zero, 0x63a0($t0)
	sw	$zero, 0x65a0($t0)

	sw	$zero, 0x61ac($t0)	# I
	sw	$zero, 0x61b0($t0)
	sw	$zero, 0x61b4($t0)
	sw	$zero, 0x63b0($t0)
	sw	$zero, 0x65ac($t0)
	sw	$zero, 0x65b0($t0)
	sw	$zero, 0x65b4($t0)

	sw	$zero, 0x61bc($t0)	# O
	sw	$zero, 0x61c0($t0)
	sw	$zero, 0x61c4($t0)
	sw	$zero, 0x63bc($t0)
	sw	$zero, 0x63c4($t0)
	sw	$zero, 0x65bc($t0)
	sw	$zero, 0x65c0($t0)
	sw	$zero, 0x65c4($t0)

	sw	$zero, 0x61cc($t0)	# N
	sw	$zero, 0x61d0($t0)
	sw	$zero, 0x61d4($t0)
	sw	$zero, 0x63cc($t0)
	sw	$zero, 0x63d4($t0)
	sw	$zero, 0x65cc($t0)
	sw	$zero, 0x65d4($t0)
	
	addi	$a0, $zero, 87		# set up parameters for drawRect
	addi	$a1, $zero, 52
	addi	$a2, $zero, 32
	addi	$a3, $zero, 1
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(87, 52, 32, 1, black)
	
	addi	$a0, $zero, 87		# set up parameters for drawRect
	addi	$a1, $zero, 58
	addi	$a2, $zero, 32
	addi	$a3, $zero, 1
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(87, 58, 32, 1, black)
	
	addi	$a0, $zero, 87		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 1
	addi	$a3, $zero, 5
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(87, 53, 1, 5, black)
	
	addi	$a0, $zero, 118		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 1
	addi	$a3, $zero, 5
	sw	$zero, -4($sp)
	
	jal	drawRect		# drawRect(118, 53, 1, 5, black)
	
	addi	$a0, $zero, 88		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 30
	addi	$a3, $zero, 5
	addi	$t1, $zero, -1
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(88, 53, 30, 5, white)
	
	addi	$a0, $zero, 88		# set up parameters for drawRect
	addi	$a1, $zero, 53
	addi	$a2, $zero, 6
	addi	$a3, $zero, 5
	lui	$t1, 0xbb
	addi	$t1, $zero, 0x77ff
	sw	$t1, -4($sp)
	
	jal	drawRect		# drawRect(88, 53, 6, 5, blue)
	
	lw	$ra, 4($sp)		# standard epilogue - free 6 words of space and return
	lw	$fp, 0($sp)
	addiu	$sp, $sp, 24
	jr	$ra
