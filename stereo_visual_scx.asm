INCLUDE "hardware.inc"

/*
	Sprites- $FE00-$FE9F
	Sprite 1: right channel, bottom/left on screen, $FE00-$FE03
	Sprite 2: left channel, top/right on screen, $FE04-$FE07
	Sprite Y: LY+16
	Each channel is 64 pixels tall -> 128 total pixels -> 11 pixels from screen, 
	10 pixels from each other, added to 8 
	(right: x=18 to x=81, middle: x=82 to x=91, left: x=92 to x=155)
	right middle: x=50, left middle: x=124

	Enable OAM interrupts (rSTAT = %xx1xxxxx), wait manually for hblank
*/

left_sample equ $80
right_sample equ $81
left_trans equ $82
right_trans equ $83
mv_store equ $84
amp_lut equ $03
lyc_lut equ $05

SECTION "STAT interrupt", ROM0[$48]
playSample:
	bit 7, h
	jr z, nopLY
	ld h, $2f
	inc bc
	ld [hl], c
	inc h
	ld [hl], b
	ld h, $40
	jr prepLY
nopLY:
REPT 13
	nop
ENDR
	;bank change takes 18 m cycles
prepLY:
	ld d, lyc_lut
	ldh a, [rLYC]
	ld e, a
	ld a, [de]
	ldh [rLYC], a
	;LYC takes 11 m cycles
	;at this point, we are 8 m cycles into rendering.
	;SCX and WX need to be changed in hblank.
	
	push bc
	ld bc, $f00f
	ld a, [hli]
	ld e, a
	and b
	ld d, a
	or c
	ldh [rNR12], a
	swap e
	ld a, e
	and b
	ld b, a
	or c
	ldh [rNR22], a
	ld a, [hli]
	ld e, a
	and c
	or d
	ld d, a ;right sample ;ldh [right_sample], a
	ld a, e
	swap a
	and c
	or b
	ld c, e ;master volume
	ld b, d ;right sample
	ld e, a ;left sample
	ld d, amp_lut
	ld a, [de]
	;43 m cycles have passed from the last section,
	;so we are probably in hblank because we are 51 m cycles into rendering.
	ldh [rSCX], a
	inc d
	ld e, b
	ld a, [de]
	ldh [rWX], a
	;right here, 53 m cycles have passed.
	
	;takes 82 m cycles
	;plus loading takes 100 m cycles
	;total: 105 m cycles including ISR
	;we have a whopping 9 m cycles left until the interrupt fires again, holy shit!
	;so there's still 5 m cycles left after the RETI.
	ld a, $80
	ldh [rNR50], a
	ldh [rNR24], a
	ldh [rNR14], a
	ld a, c
	ldh [rNR50], a
	pop bc
	;loading takes 18 m cycles
	reti

	/*
	up to this point, sample playing takes 52 m-cycles.
	if hblank is shortened by 1 m-cycle if scx&7>0, then accounting for 9 m-cycles
	to enter the sample loading routine, it goes 10 m-cycles into OAM scan.
	however, the first SCX can be written to inside of hblank,
	and bc doesn't have to be popped from the stack until the bank changer,
	and c is unmodified through the sample player, so the routine can be timed so that
	part of the sample playback routine executes, and then SCX is written to.
	*/
waitLine:
	jr waitLine

SECTION "Header", ROM0[$100]

EntryPoint:
	di
	jp Start

REPT $150 - $104
	db 0
ENDR

SECTION "Game code", ROM0[$150]

Start:
	di
	nop
	xor a
	ldh [rNR52], a
	cpl
	ldh [rNR52], a

waitVblank:
	ldh a, [rLY]
	cp 145
	jr nz, waitVblank

	xor a
	ldh [rLCDC], a
	ldh [rLYC], a
	ld a, $40
	ldh [rSTAT], a
	xor a
	ldh [rWY], a
	ldh [rSCY], a
	ld a, 8
	ldh [rSCX], a
	ld a, 96
	ldh [rWX], a

	ld a, $FC
	ldh [rBGP], a
	; BG map: 2nd and 12th columns of tiles is $7F repeating,
	; otherwise tiles are $FF
	ld c, 16
	xor a
	ld de, $8010
loadVizTile:
	ld [de], a
	inc e
	dec c
	jr nz, loadVizTile
	xor a
	cpl
	ld c, 16
	ld e, $00
zeroTile0:
	ld [de], a
	inc e
	dec c
	jr nz, zeroTile0

	ld hl, BGMap
	ld de, $9800
	ld bc, BGMapEnd-BGMap
copyBG:
	ld a, [hli]
	ld [de], a
	inc de
	dec c
	jr nz, copyBG
	dec b
	jr nz, copyBG

	ld a, %10110001
	ldh [rLCDC], a

	ld hl, $4000
	ld bc, $0001
	ld de, $0000
	ld sp, $cfff

	ld a, $e0
	ldh [rNR13], a
	ldh [rNR23], a

	ld a, $c0
	ldh [rNR11], a
	ldh [rNR21], a

	ld a, $0f
	ldh [rNR12], a
	ldh [rNR22], a

	ld a, $87
	ldh [rDIV], a
	ldh [rNR14], a

stallPulse1:
	ldh a, [rDIV]
	cp 9
	jr nz, stallPulse1

	xor a
	ldh [rNR13], a

	ld a, $80
	ldh [rNR14], a

	ld a, $87
	ldh [rDIV], a
	ldh [rNR24], a

stallPulse2:
	ldh a, [rDIV]
	cp 9
	jr nz, stallPulse2

	xor a
	ldh [rNR23], a
	nop
	nop

	ld a, $80
	ldh [rNR24], a
	ldh [rNR14], a

	ld a, $12
	ldh [rNR51], a
	ld a, $77
	ldh [rNR50], a
	ld a, %00000010
	ldh [rIE], a
	ei
	jp waitLine

SECTION "Amplitude LUT", ROM0[$300]
	INCBIN "scx_lut_stereo.bin"

SECTION "LYC LUT", ROM0[$500]
	INCBIN "lyc_lut.bin"

SECTION "BG data", ROM0[$900]
BGMap:
REPT 32
	db $01
	REPT 31
		db $00
	ENDR
ENDR
BGMapEnd: