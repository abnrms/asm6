# Asm 6 - MIDI piano in MIPS
Author: Hamlet Taraz @ University of Arizona
Course: CSC 252 Spring 2024
Instructor: Russ Lewis

This program turns MARS into a MIDI piano, with 128 "different" sounds to choose
from, and the ability to dynamically customize things like octave and note duration.
Includes a functioning GUI which looks like a piano and keeps track of all notable information. Try it out!

YouTube Video: https://youtu.be/RdQx3S_ph6Y

## To use with MARS:
  Open Mars4.5la.jar
  Open asm6.s in MARS simulator
  Make sure "Settings -> Initialize Program Counter to global 'main' if defined" is checked
  Make sure "Permit extended (pseudo) instructions and formats" is checked
    Note: It should only be necessary for the la instruction!

  Open "Tools -> Keyboard and Display MMIO Simulator"
    and click "Connect to MIPS"
  Also Open "Tools -> Bitmap Display"
    set "Unit Width/Height in Pixels" to 4
    set "Display Width in Pixels" to 512
    set "Display Height in Pixels" to 256
    set "Base address for display" to 0x10010000 (static data)
    and click "Connect to MIPS"
  then type into the bottom box of the keyboard simulator and your keys will be registered!
  See below for controls.

## Controls:
  exit program - ESC
  reset values - '`' (next to 1, under the escape key)

  keyboard - 
     w e   t y u   o p
    a s d f g h j k l ;

  tweaks - 
                inc/dec octave - '.' and ','
    inc/dec note time by 100ms - '-' and '='
                     by 1000ms - '_' and '+' (hold shift)
          cycle through sounds - '[' and ']'
               by 16 at a time - '{' and '}' (hold shift)

## Sound key:
  Source: https://courses.missouristate.edu/KenVollmar/mars/Help/SyscallHelp.html

	0-7	    Piano			        64-71	Reed
	8-15	Chromatic Percussion	72-79	Pipe
	16-23	Organ		    	    80-87	Synth Lead
	24-31	Guitar		        	88-95	Synth Pad
	32-39	Bass		        	96-103	Synth Effects
	40-47	Strings		        	104-111	Ethnic
	48-55	Ensemble	        	112-119	Percussion
	56-63	Brass		        	120-127	Sound Effects
