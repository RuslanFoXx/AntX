;------------------------------------------------
;	AntX Web Server
;	SYSTEM: Post & Write Report
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  Set FileReport  * * *
;------------------------------------------------
proc FileReport

	mov [SystemReport.Index], EDX
	call [WSAGetLastError]
	mov [SystemReport.Error], EAX

	mov EAX, SystemReport
	call WriteReport

	push [hFileReport]
	call [CloseHandle]

	xor EAX, EAX
	mov [hFileReport], EAX
	ret
endp
;------------------------------------------------
;       * * *  Add SocketReport  * * *
;------------------------------------------------
proc PostReport 

	mov [RouterHeader.Index], EDX
	call [WSAGetLastError]
	mov [RouterHeader.Error], EAX

	mov EDI, [SetRouteReport]
	lea EDX, [EDI+REPORT_INFO_PATH_SIZE]
	cmp EDX, [MaxRouteReport]
	jb jmpSetReport@PostReport
		mov EDX, [TabRouteReport]
;------------------------------------------------
;       * * *  Create Report
;------------------------------------------------
jmpSetReport@PostReport:
	cmp EDX, [GetRouteReport]
	je jmpEnd@PostReport

		mov ESI, RouterHeader
		movsd
		movsd

		mov ESI, [lpSocketIoData]
		lea ESI, [ESI+PORT_IO_DATA.NetHost]
		xor ECX, ECX
		mov CL,  REPORT_INFO_PORT
		rep movsd

		lea ESI, [ESI+20]
		mov  CX, [ESI]
			movsw
		rep movsb
		mov [SetRouteReport], EDX

jmpEnd@PostReport:
	ret
endp
;------------------------------------------------
;       * * *  Report Dispatcher  * * *
;------------------------------------------------
proc WriteReport

local PostLength DWORD ?
;------------------------------------------------
	mov [lpFileReport], EAX
;------------------------------------------------
;       * * *  Get Local Time
;------------------------------------------------
	push LocalTime
	call [GetLocalTime]

	mov ESI, LocalTime
	mov EDI, szTextReport
	mov EBX, sStrByteScale + 2
	xor EAX, EAX
	mov ECX, EAX
;------------------------------------------------
;           * * *  Set Date = YYYY-MM-DD
;------------------------------------------------
	mov CL, '-'
	mov AX, '20'
	stosw

	lodsw
	sub AX, DELTA_ZERO_YEAR
	mov AX, [EBX+EAX*4]
	stosw

	mov EAX, ECX
	stosb

	lodsw
	mov AX, [EBX+EAX*4]
	stosw

	mov EAX, ECX
	stosb

	lodsw
	lodsw
	mov AX, [EBX+EAX*4]
	stosw
;------------------------------------------------
;           * * *  Set Time = hh:mm:ss
;------------------------------------------------
	mov CL, ':'
	mov AL, ' '
	stosb

	lodsw
	mov AX, [EBX+EAX*4]
	stosw

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
;       * * *  Set Socket + Address (IP)
;------------------------------------------------
	mov EBX, [lpFileReport]
	mov ECX, [EBX+REPORT_INFO.Socket]
	jECXz jmpHostName@WriteReport

		mov AL, ' '
		stosb
		call IntToStr

		mov EBX, [lpFileReport]
		lea ESI, [EBX+REPORT_INFO.Address]
		lodsb
		mov CL, AL

		mov AL, ' '
		stosb
		rep movsb
;------------------------------------------------
;       * * *  Set HostName
;------------------------------------------------
jmpHostName@WriteReport:
	mov EBX, [lpFileReport]
	mov EDX, [EBX+REPORT_INFO.NetHost]
	or  EDX, EDX
	jz jmpIndex@WriteReport

		mov ESI, [EDX+NET_HOST.Name]
		xor EAX, EAX
		lodsb
		mov ECX, EAX

		mov AX, " '"
		stosw
		rep movsb
;------------------------------------------------
;       * * *  Set Url
;------------------------------------------------
		lea ESI, [EBX+REPORT_INFO.UrlSize]
		lodsw

		mov ECX, EAX
		jECXz jmpEndHostName@WriteReport

			mov EDX, [EDX+NET_HOST.SiteFolder]
			xor EAX, EAX
			mov AL, [EDX]

			add ESI, EAX
			sub ECX, EAX
			rep movsb

jmpEndHostName@WriteReport:
		mov AL, "'"
		stosb
;------------------------------------------------
;       * * *  Set Index
;------------------------------------------------
jmpIndex@WriteReport:
	xor EDX, EDX
	mov EAX, [EBX+REPORT_INFO.Index]
	mov  DL, AL
	push EDX
	push EDX

	mov AL, ' '
	stosb

	mov ESI, [lppReportMessages+EDX*4]
	or  ESI, ESI
	jnz jmpText@WriteReport

		mov AX, '[0'
		stosw
		mov AX, word[sStrByteScale+2+EDX*4]
		stosw
		mov AL, ']'
		stosb
		jmp jmpInformation@WriteReport
;------------------------------------------------
;       * * *  Copy Message
;------------------------------------------------
jmpText@WriteReport:
	xor EAX, EAX
	lodsb
	mov ECX, EAX
	rep movsb
;------------------------------------------------
;       * * *  Type InformationPort
;------------------------------------------------
jmpInformation@WriteReport:
	pop EAX
	cmp AL, MSG_NO_INFORMATION
	jae jmpReportEnd@WriteReport
;------------------------------------------------
;       * * *  SaveNumberName
;------------------------------------------------
		mov EDX, [EBX+REPORT_INFO.ResurseId]
		or  EDX, EDX
		jz jmpCountBytes@WriteReport

			mov EAX, ' id='
			stosd
			call HexToStr
			mov EBX, [lpFileReport]
;------------------------------------------------
;       * * *  Transceiver CountBytes
;------------------------------------------------
jmpCountBytes@WriteReport:
		mov ECX, [EBX+REPORT_INFO.TransferredBytes]
		jECXz jmpSysError@WriteReport

			mov AL, ' '
			stosb
			call IntToStr
			mov EAX, ' byt'
			stosd
			mov AX, 'es'
			stosw
			mov EBX, [lpFileReport]
;------------------------------------------------
;       * * *  System Error
;------------------------------------------------
jmpSysError@WriteReport:
	pop EAX
	cmp  AL, MSG_NO_ERROR
	jae jmpReportEnd@WriteReport
;------------------------------------------------
;       * * *  GetRunReurn
;------------------------------------------------
		mov ECX, [EBX+REPORT_INFO.Error]
		jECXz jmpRunReurn@WriteReport

		cmp ECX, ERROR_IO_PENDING
		je jmpRunReurn@WriteReport

			mov AX, ' ('
			stosw
			call IntToStr
			mov AL, ')'
			stosb

			mov EBX, [lpFileReport]

jmpRunReurn@WriteReport:
		mov ECX, [EBX+REPORT_INFO.ExitCode]
		jECXz jmpReportEnd@WriteReport

			mov EAX, ' AX='
			stosd
			call IntToStr
;------------------------------------------------
;       * * *  Get LogSize
;------------------------------------------------
jmpReportEnd@WriteReport:
	mov AX, CHR_CRLF
	stosw

	sub EDI, szTextReport
	mov [PostLength], EDI
;------------------------------------------------
;       * * *  Write Report
;------------------------------------------------
	mov ECX, [hFileReport]
	jECXz jmpOpen@WriteReport

		push ECX
		call [CloseHandle]

		xor ECX, ECX
		mov [hFileReport], ECX
;------------------------------------------------
;       * * *  Create ReportFile
;------------------------------------------------
jmpOpen@WriteReport:
	or ECX, ECX
	jnz jmpWrite@WriteReport

		push ECX
		push FILE_ATTRIBUTE_NORMAL
		push OPEN_ALWAYS
		push ECX
		push FILE_SHARE_READ
		push FILE_APPEND_DATA
		push szReportName
		call [CreateFile]

		cmp EAX, INVALID_HANDLE_VALUE
		je jmpEnd@WriteReport

			mov ECX, EAX
			mov [hFileReport], EAX
;------------------------------------------------
;       * * *  Write ReportFile
;------------------------------------------------
jmpWrite@WriteReport:
	xor EAX, EAX
	push EAX
	push PostBytes
	push [PostLength]
	push szTextReport
	push ECX
	call [WriteFile]
;------------------------------------------------
;       * * *  End Proc  * * *
;------------------------------------------------
jmpEnd@WriteReport:
	mov ESI, [lpFileReport]
	ret
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------
