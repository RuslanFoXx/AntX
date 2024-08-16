;------------------------------------------------
;	AntX Web Server
;	SYSTEM: Strings
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  INT To String  * * *
;------------------------------------------------
proc IntToStr

;   mov EDI, pBuffer
;   mov ECX, Value

jmpSign@IntToStr:
	xor EBX, EBX
	mov  BL, 10
	mov EAX, ECX

jmpScan@IntToStr:
	inc EDI
	xor EDX, EDX
	div EBX

	or EAX, EAX
	jnz jmpScan@IntToStr

	mov ESI, EDI
	mov EAX, ECX

jmpDiv@IntToStr:
	dec EDI
	xor EDX, EDX
	div EBX

	add DL, '0'
	mov [EDI], DL

	or EAX, EAX
	jnz jmpDiv@IntToStr

	mov EDI, ESI 
	xor ECX, ECX
	ret
endp
;------------------------------------------------
;       * * *  HEX To String  * * *
;------------------------------------------------
proc HexToStr

;   mov EDI, pBuffer
;   mov EDX, Value
	mov ESI, sHexScaleChar
	xor ECX, ECX
	mov EBX, ECX
	mov CL,  8

jmpScan@HexToStr:
	rol EDX, 4
	mov BL,  DL
	and BL,  0Fh
	mov AL, [ESI+EBX]
	stosb
	loop jmpScan@HexToStr
	ret
endp
;------------------------------------------------
;       * * *  String To DWORD  * * *
;------------------------------------------------
proc StrToWord

;   mov ESI, pBuffer
	xor EDX, EDX
	or  ESI, ESI
	jz jmpEnd@StrToWord

	mov ECX, EDX
	mov EBX, EDX
	mov BL,  10

jmpScan@StrToWord:
	lodsb
	cmp AL, '0'
	jb jmpEnd@StrToWord

	cmp AL, '9' 
	ja jmpEnd@StrToWord

	sub AL, '0'
	mov CL, AL

	mov EAX, EDX
	mul EBX 
	add EAX, ECX
	mov EDX, EAX
	jmp jmpScan@StrToWord

jmpEnd@StrToWord:
	mov EAX, EDX
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------
