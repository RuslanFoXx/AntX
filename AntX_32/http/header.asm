;------------------------------------------------
;	AntX Web Server
;	SYSTEM: Headers
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  Get Status SocketPort  * * *
;------------------------------------------------
proc CreateHttpHeader

local lpHeaderIoData dd ?
local HeaderMethod   dd ?
;------------------------------------------------
;   mov ESI, lpIoSocketPort
;   mov ECX, hFile
;   mov BL,  index

	mov [lpHeaderIoData], ESI
	xor EAX, EAX
	mov [ESI+PORT_IO_DATA.CountBytes], EAX
	mov [ESI+PORT_IO_DATA.TotalBytes], EAX
	mov [ESI+PORT_IO_DATA.TransferredBytes], EAX

	mov AL, BL
	mov [HeaderMethod], EAX

	lea EAX, [ESI+PORT_IO_DATA.Buffer]
	mov [ESI+PORT_IO_DATA.WSABuffer.buf], EAX
	push ESI
;------------------------------------------------
;       * * *  Get FileSize  * * *
;------------------------------------------------
	jECXz jmpSetExt@Header

		lea  EAX, [ESI+PORT_IO_DATA.TotalBytes]
		push EAX
		push ECX
		call [GetFileSizeEx]

jmpSetExt@Header:
	pop ESI
	mov EBX, [ESI+PORT_IO_DATA.ExtRunProc]

jmpGetDate@Header:
	mov EAX, [EBX+ASK_EXT.Type]
	or  EAX, EAX
	jz jmpEnd@Header
;------------------------------------------------
;           * * *  Get Date + Time
;------------------------------------------------
		push ServerTime
		call [GetSystemTime]
;------------------------------------------------
;       * * *  Index Method
;------------------------------------------------
		mov ESI, [lpHeaderIoData]
		lea EDI, [ESI+PORT_IO_DATA.Buffer]
		push EDI
		push ESI

		mov EAX, HEADER_HTTP
		stosd
		mov EAX, HEADER_HTTP_VER
		stosd
		mov AL, ' '
		stosb

		mov EBX, [HeaderMethod]
		mov EAX, dword[sGetHttpMethod+1+EBX]
		and EAX, 20FFFFFFh
		or  EAX, 20000000h
		stosd

		mov ESI, [lppTagRespont+EBX]
		xor EAX, EAX
		lodsb
		mov ECX, EAX
		rep movsb
;------------------------------------------------
;       * * *  Set Server Information
;------------------------------------------------
		mov  CL, szHeaderType - szHeaderServer
		mov ESI, szHeaderServer
		rep movsb
;------------------------------------------------
;           * * *  Set Date = Www, DD Mmm YYYY
;------------------------------------------------
		mov ESI, ServerTime
		mov EBX, sStrByteScale + 2
		mov EAX, ECX

		lodsw
		sub  AX, DELTA_ZERO_YEAR
		mov  AX, [EBX+EAX*4]
		mov EDX, EAX

		mov EAX, ECX
		lodsw
		dec EAX
		mov EAX, dword[sMonthDateHeader+EAX*4]
		push EAX

		mov EAX, ECX
		lodsw
		mov EAX, dword[sWeekDateHeader+EAX*4]
		stosd

		mov CL, ' '
		mov EAX, ECX
		stosb

		lodsw
		mov AX, [EBX+EAX*4]
		stosw

		mov EAX, ECX
		stosb

		pop EAX
		stosd

		mov AX, '20'
		stosw

		mov EAX, EDX
		stosw
;------------------------------------------------
;           * * *  Set Time = hh:mm:ss
;------------------------------------------------
		mov EAX, ECX
		stosb

		lodsw
		mov AX, [EBX+EAX*4]
		stosw

		mov CL, ':'
		mov EAX, ECX
		stosb

		lodsw
		mov AX, [EBX+EAX*4]
		stosw

		mov EAX, ECX
		stosb

		lodsw
		mov AX, [EBX+EAX*4]
		stosw
;------------------------------------------------
;       * * *  Set Server Information
;------------------------------------------------
		mov  CL, szHeaderDisposition - szHeaderType
		mov ESI, szHeaderType
		rep movsb
;------------------------------------------------
;       * * *  Set Content Type
;------------------------------------------------
		pop EBX
		mov EDX, [EBX+PORT_IO_DATA.ExtRunProc]
		mov ESI, [EDX+ASK_EXT.Type]
		lodsb
		mov CL, AL
		rep movsb
;------------------------------------------------
;       * * *  Set Content Disposition
;------------------------------------------------
		mov EDX, [EDX+ASK_EXT.Disposition]
		or  EDX, EDX
		jz jmpContentLength@Header

			mov  CL, szHeaderLength - szHeaderDisposition
			mov ESI, szHeaderDisposition
			rep movsb

			mov ESI, EDX 
			lodsb
			mov CL, AL
			rep movsb
;------------------------------------------------
;       * * *  Set Content Length
;------------------------------------------------
jmpContentLength@Header:
		mov  CL, szHeaderConnection - szHeaderLength
		mov ESI, szHeaderLength
		rep movsb

		mov ECX, [EBX+PORT_IO_DATA.TotalBytes]
;		jECXz jmpHeaderConnect@Header

			push EBX
;			dec EDI
			call IntToStr
			pop EBX
;------------------------------------------------
;       * * *  Set Connection
;------------------------------------------------
jmpHeaderConnect@Header:
		mov  CL, szClose - szHeaderConnection
		mov ESI, szHeaderConnection
		rep movsb

		mov CL, szKeepAlive - szClose 
		mov AX, [EBX+PORT_IO_DATA.Connection]
		or  AX, AX
		jz jmpEndHeader@Header

			mov  CL, szKeepAliveEnd - szKeepAlive
			mov ESI, szKeepAlive

jmpEndHeader@Header:
		rep movsb
;------------------------------------------------
;       * * *  End Header
;------------------------------------------------
		mov EAX, END_CRLF
		stosd

		pop EDX
		mov EAX, EDI
		sub EAX, EDX
		mov ESI, EBX
		mov [ESI+PORT_IO_DATA.CountBytes], EAX

jmpEnd@Header:
	ret
endp
;------------------------------------------------
;       * * *  Set StatusFile  * * *
;------------------------------------------------
proc GetStatusFile

	xor EAX, EAX
	mov [ESI+PORT_IO_DATA.Connection], AX
	mov [ESI+PORT_IO_DATA.ExtRunProc], ErrRunProcess

	push EAX
	push FILE_ATTRIBUTE_READONLY
	push OPEN_EXISTING
	push EAX
	push FILE_SHARE_READ
	push GENERIC_READ
	push EDI

	mov ESI, [ESI+PORT_IO_DATA.NetHost]
	mov ESI, [ESI+NET_HOST.CodeFolder]
	mov AL, BL
	mov EBX, EAX
	lodsb
	mov ECX, EAX
	rep movsb

	mov AL, '\'
	stosb
	mov EAX, dword[sGetHttpMethod+1+EBX]
	and EAX, 20FFFFFFh
	or  EAX, 2E000000h
	stosd
	mov EAX, EXT_HTML
	stosd
	call [CreateFile]

	xor ECX, ECX
	cmp EAX, INVALID_HANDLE_VALUE
	je jmpEnd@GetStatusFile
		mov ECX, EAX

jmpEnd@GetStatusFile:
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------