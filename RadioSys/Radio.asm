
.286p
.SEQ

	extrn	DosWrite:far

;-------------------------------------------

DATA16		SEGMENT	PARA PUBLIC 'AUTO'

nexthdr		dd	0FFFFFFFFh	; pointer to next device driver
devattr		dw	9880h		; attribute flags
stratof		dw 	offset strategy 	;offset of strategy routine entry
reserv1		dw	0
devname	db	'RADIO$  '	; device name for "DosOpen"
reserv2		db	8 dup (0)

devhelp		dd	0	; this is where we save the DevHelp pointer

freq		dw	0	; frequency

RPORT		dw	350h	; radio  port, 358 for types 6,8,10,12

portmask	db	0	; port mask
stereo		db	0a6h	; stereo mask

opncnt		db 	0

rq_init		equ	00h			; define requests
rq_open		equ	0dh
rq_close		equ	0eh
rq_ioctl		equ	10h

dh_PhysToVirt	equ	15h		; define device help routines
dh_PhysToUVirt	equ	17h
dh_SetIRQ	equ	1bh
dh_UnSetIRQ	equ	1ch
dh_EOI		equ	31h
dh_UnPhysToVirt	equ	32h
dh_SetTimer	equ	1dh
dh_ResetTimer	equ	1eh

end_of_data	label	byte            ; the rest isn't needed after init

initmsg		db	0Dh,0Ah
		db	'Radio Driver Loaded, port '
prtstr		db	'350'
		db	0Dh,0Ah
		db	0Dh,0Ah
initmsglen	equ	$-offset initmsg
byteswritten	dw	0

DATA16	ENDS

DGROUP	GROUP	DATA16

;-------------------------------------------

CODE16 	SEGMENT	PARA	'CODE'
        	assume cs:CODE16, ds:DATA16
	PUBLIC strategy
strategy PROC	FAR

	push	es
	push	bx
	call	strat
	pop	bx
	pop	es
	mov	word ptr es:[bx+3],ax
	ret
strategy	ENDP

;examine command code in req packet

strat	 PROC	NEAR

	mov	al,es:[bx+2]
	cmp	al,rq_init		; is it initialize ?
	jne	chkopn		; no - go on
	jmp	Initbrd		; yes - go do it
chkopn:	cmp	al,rq_open	; is it open ?
	jne	chkcls		; no - maybe close
	jmp	Openbrd	; yes - go open it
chkcls:	cmp	al,rq_close	; is it close ?
	jne	chkioc		; no - maybe IOCtl
	jmp	Closebrd	; yes - go close it
chkioc:	cmp	al,rq_ioctl	; is it IOCtl ?
	jne	cdone		; no - will thats it then
	jmp	IOCtlbrd		; yes go do it

;if none of the above, execute default stuff

cdone:	mov	ax,0100h    ;set the "done" flag
	ret
strat	 ENDP


;***********************************************************************
; Open routine
;
;***********************************************************************

Openbrd	PROC	NEAR
	cmp	opncnt,0	; is it already open ?
	jne	opndon		; yes - go on

	mov	stereo,0a6h	; stereo on
	or	portmask,1	; radio on
;	call 	outb		; don't send it yet
;	cmp	freq,0
;	je	opndon
;	call 	setfreq
opndon:	inc	opncnt		; count the open
	mov	ax,0100h ; set the "done" flag
	ret			; and return
Openbrd	ENDP

;*********************************************************************
; Close routine
;
;*********************************************************************

Closebrd PROC	NEAR
	cmp	opncnt,1	; is this the last open ?
	jne	clsdon		; no - go on
	and	portmask,0feh	; radio off
;	call 	outb		; don't send it yet, keep playing after close
clsdon:	dec	opncnt		; count the close
	mov	ax,0100h 	; set the "done" flag
	ret			; and return
Closebrd ENDP

;*********************************************************************
; IOCtl Routine
;
;*********************************************************************

IOCtlbrd PROC	NEAR
	mov	al,es:[bx+14]
	cmp	al,22h		; is test stereo ?
	jne	is24
	jmp	getstereo
is24:	cmp	al,24h		; is it get tuned ?
	jne	is62
	jmp	gettune
is62:	cmp	al,62h		;is it set frequency ?
	jne	is64
	jmp	setfrequency
is64:	cmp	al,64h		;is it set stereo ?
	jne	is66
	jmp	setstereo
is66:	cmp	al,66h		;is it set mute
	jne	iocerr		; no - go on
	jmp	setmute

iocerr:	mov ax,0c10ch
	ret

setfrequency:
	les	di,DWORD PTR es:[bx+15]	; Get the parameter block
	mov	ax,WORD PTR es:[di]	; get the freq
	mov	dx,WORD PTR es:[di+2]
	add	ax,29cch		; adjust for radio card
	adc	dx,0			; no frequency range test !!!!
	mov	cx,19h			; 0ah for types 1..6 and 11,12
	div	cx
	mov	freq,ax			; and store it
	call 	setfreq			; send to card
	jmp	iocrtn			; and return

setstereo:
	les	di,DWORD PTR es:[bx+15]	; Get the parameter block
	mov	ax,WORD PTR es:[di]	; get stereo on/off
	mov	ah,0a6h			; is stereo , default
	cmp	al,0			; is it off
	jne	ste
	mov	ah,0a4h			; is mono
ste:	mov	stereo,ah
	call 	setfreq			; send to card
	jmp	iocrtn			; and return

setmute:
	les	di,DWORD PTR es:[bx+15]	; Get the parameter block
	mov	ax,WORD PTR es:[di]	; mute on/off
	and	ax,1			
	and	portmask,0feh
	or	portmask,al
	call 	outb

iocrtn:	mov	ax,0100h    		;set the "done" flag
	ret

;error exit

getstereo:
	les	di,DWORD PTR es:[bx+19]	; get the result block
	call 	inb			; get 
	and	al,1
	xor	al,1
	mov	WORD PTR es:[di],ax	; store 
	jmp	iocrtn			; and return

gettune:
	les	di,DWORD PTR es:[bx+19]	; get the result block
	mov	cx,64h
	mov	bl,0
inlp:	call 	inb			; get 
	and	al,2
	or	bl,al
	loop	inlp			; make sure it's tuned
	mov	al,bl
	shr	al,1
	and	ax,1
	xor	al,1
	mov	WORD PTR es:[di],ax	; store 
	jmp	iocrtn			; and return

IOCtlbrd ENDP

; the following comes from a dissassembly of a windows dll (FMAPI.DLL) , more or less (more less)?
; this is realy complicated I don't now how, but it works only for types 9 and 10 for now
; types 1 to 5 are mono 

setfreq	PROC	NEAR
	mov	bl,portmask
	and 	bl,1
	push	bx
	and	portmask,0feh
	call	outb
	cmp	freq,0		; this is the only freq test, there is no freq range test!!!!
	jne	isok
	mov	freq,0ddch
isok:	mov	al,0a0h		; 60h for types 1..6 and 11,12
	call 	sfl
	mov	al,stereo
	call 	sfl
	pop	bx
	or	portmask,bl
	call	outb
	ret
setfreq	ENDP


sfl	PROC	NEAR
	push	ax
	or	portmask,2
	call 	outb
	mov	ax,freq
	call 	sfb
	mov	al,ah
	call 	sfb
	pop	ax
	call 	sfb
	and	portmask,0fdh
	call 	outb
	ret
sfl	ENDP


sfb	PROC	NEAR
	push	ax
	mov	bl,al
	mov	cx,8
sfblp:	and	portmask,7fh
	mov	al,bl
	shl	al,7
	and	al,80h
	or	portmask,al
	call 	outb
	and	portmask,0bfh
	call 	outb
	or	portmask,40h
	call 	outb
	shr	bl,1
	loop	sfblp
	pop	ax	
	ret
sfb	ENDP


outb	PROC	NEAR
	mov	dx,RPORT
	mov	al,portmask	
	out	dx,al		; do I/O
	call 	inb		; delay
	call 	inb
	call 	inb
	call 	inb
	ret
outb	ENDP


inb	PROC	NEAR
	mov	dx,RPORT
	in	al,dx		; do I/O
	and	ax,0ffh
	nop
	nop
	nop
	ret
inb	ENDP


end_of_code	label	byte		; code after this point is needed
					; only at initialization time

;*********************************************************************
; initialization routine - Just set things up
;
;*********************************************************************

Initbrd	PROC	NEAR

;save "DevHlp" call FAR PTR address

	mov	ax,es:[bx+14]		; get the device help address
	mov	word ptr devhelp,ax	; and store it away
	mov	ax,es:[bx+16]		; ...
	mov	word ptr devhelp+2,ax	; ...

	mov	portmask,0
	mov	stereo,0a6h
	call 	outb
	mov	portmask,02ah
	call 	outb

	push	es
	mov	si,es:[bx+18]
	mov	ax,es:[bx+20]
	mov	es,ax
	dec	si
parml:	inc	si			; test for param /P:<port>
	cmp	byte ptr es:[si],0ah
	je	noparm
	cmp	byte ptr es:[si],0dh
	je	noparm
	cmp	byte ptr es:[si],0
	je	noparm
	cmp	byte ptr es:[si],' '
	jne	parml
	inc	si
	cmp	byte ptr es:[si],'/'
	jne	parml
	inc	si
	cmp	byte ptr es:[si],'P'
	je	uppr
	cmp	byte ptr es:[si],'p'
	jne	parml
uppr:	inc	si
	cmp	byte ptr es:[si],':'
	jne	parml
	inc	si
	call	tstport
	cmp	dx,0
	je	parml
noparm:	pop	es


;display message

	push	1
	push	ds
	push	offset initmsg
	push	initmsglen
	push	ds
	push	offset byteswritten
	call 	DosWrite

;	call	setfreq			; do not play during boot
;	and	portmask,0feh
;	call	outb

;set ending offsets

cjsdon:	mov	word ptr es:[bx+14],offset end_of_code ; say how much code
	mov	word ptr es:[bx+16],offset end_of_data ; and data to keep

;set other req packet fields

	mov	word ptr es:[bx+18],0
	mov	word ptr es:[bx+20],0

;set status and exit

	mov	ax,0100h    ;"done"
	ret

Initbrd	ENDP

tstport	PROC	 NEAR	; check for valid port address
	xor	dx,dx
	mov	cx,3
lp3:	mov	al,es:[si]
	inc	si
	cmp	al,'0'
	jl	notp
	cmp	al,'9'
	jle	tisp
	and	al,0dfh	; to upper
	cmp	al,'A'	; maybe HEX
	jl	notp
	cmp	al,'F'
	jg	notp
	sub	al,7
tisp:	shl	dx,4
	and	ax,0fh
	or	dx,ax
	loop	lp3
	mov	RPORT,dx	; strore new port
	mov	di,offset prtstr	; and update message
	mov	cx,3
lps:	mov	al,dh
	shl	dx,4
	and	al,0fh
	or	al,'0'
	cmp	al,'9'
	jle	nhex
	add	al,7
nhex:	mov	[di],al
	inc	di
	loop	lps
 	mov	dx,RPORT
	jmp	fini
notp:	xor	dx,dx
fini:	ret

tstport	ENDP

CODE16	ENDS

	end
