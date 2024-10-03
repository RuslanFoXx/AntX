;------------------------------------------------
;	AntX Web Server
;	MAIN: Main + Config + ServiceStart
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
format PE CONSOLE
include 'server.inc'
section '.code' code readable executable

	mov EDI, ThreadServerCtrl
	xor EAX, EAX
	mov ECX, EAX
	mov  CX, STACK_FRAME_CLEAR
	rep stosd

	inc EAX
	mov [SetOptionPort], EAX
;------------------------------------------------
;   * * *  Set Digital Scale
;------------------------------------------------
	mov EDI, sStrByteScale
	mov ECX, MAX_INT_SCALE
	mov  DX, '00'
	mov EBX, EDX

jmpSetScale@Main:
	cmp DH, '9'
	jbe jmpSet10@Main
		mov DH, '0'
		inc DL

jmpSet10@Main:
		cmp DL, '9'
		jbe jmpSet100@Main
			mov DL, '0'
			inc BH

jmpSet100@Main:
	mov EAX, EBX
	stosw

	mov EAX, EDX
	stosw

	inc DH
	loop jmpSetScale@Main
;------------------------------------------------
;   * * *  Get CommandLine
;------------------------------------------------
	call [GetCommandLine]
	or EAX, EAX
	jz jmpError@Main

		mov ESI, EAX
		xor EDX, EDX
		mov EBX, EDX
		mov AL, [ESI]
		cmp AL, '"'
		je jmpSetEnd@Main

		cmp AL, "'"
		jne jmpGetPath@Main

jmpSetEnd@Main:
			mov DL, AL
			inc ESI

jmpGetPath@Main:
		mov EDI, szReportName
		mov [pFind], ESI
		mov [lppReportMessages], EDI

jmpCopyPath@Main:
		lodsb
		stosb
		cmp AL, '.'
		jne jmpNextPath@Main

			mov EBX, ESI
			mov ECX, EDI

jmpNextPath@Main:
		cmp AL, DL
		jne jmpCopyPath@Main

jmpPathEnd@Main:
		mov DL, SYS_ERR_CommandLine
		or EBX, EBX
		jz jmpError@Main

	mov dword[ECX], EXT_LOG
	mov dword[EBX], EXT_INI
;------------------------------------------------
;   * * *  OpenConfig
;------------------------------------------------
	xor EAX, EAX
	push EAX
	push FILE_ATTRIBUTE_READONLY
	push OPEN_EXISTING
	push EAX
	push FILE_SHARE_READ
	push GENERIC_READ
	push [pFind]
	call [CreateFile]

	xor EDX, EDX
	cmp EAX, INVALID_HANDLE_VALUE
	je jmpError@Main

		push EAX
		xor ECX, ECX
		push ECX
		push CountBytes
		push CONFIG_BUFFER_SIZE
		push _DataBuffer_
		push EAX
		call [ReadFile]
		call [CloseHandle]

		xor EDX, EDX
		mov ECX,[CountBytes]
		or  ECX, ECX
		jz jmpError@Main
;------------------------------------------------
;   * * *  Get Config Strings
;------------------------------------------------
	mov EDI, _DataBuffer_
	mov ESI, TabConfig
	mov EBX, EDX
	mov EDX, MAX_CONFIG_COUNT
	mov  BL, 4

jmpTextScan@Main:
	mov [ESI], EDI
	add ESI, EBX

jmpTextSkip@Main:
	mov AL, CHR_LF
	repne scasb
	jne jmpTextEnd@Main
	jECXz jmpTextEnd@Main

	dec EDX
	jnz jmpTextScan@Main

jmpTextEnd@Main:
	xor EAX, EAX
	mov [ESI], EAX
;------------------------------------------------
;   * * *  Init Table HTTP Tags
;------------------------------------------------
	mov EDI, lppTagRespont
	mov  CL, RESPONT_HEADER_COUNT
	mov EAX, szTagOk
	rep stosd
;------------------------------------------------
;   * * *  Find KeyWord
;------------------------------------------------
	mov EDI, TotalHost
	mov EAX, ECX
	mov  AL, MAX_NET_HOST
	stosd
	mov  AL, MAX_RUN_PROC
	stosd
	mov EAX, TabNetHost
	stosd
	mov EAX, TabRunProcess
	stosd
	stosd
	mov EAX, TabConfig
	stosd
	mov [DefRunProcess.Type], szHeaderTextHtml

jmpFindConfig@Main:
	mov ESI, [pBuffer]
	lodsd
	or EAX, EAX
	jz jmpScanEnd@Main

		mov [pBuffer], ESI
		mov EBX, EAX
		cmp byte[EBX], '#'
		je jmpFindConfig@Main
;------------------------------------------------
;   * * *  Get ConfigParam
;------------------------------------------------
	mov EDI, EBX
	xor ECX, ECX
	mov  CL, MAX_PARAM_LENGTH
	mov  AL, '='
	repne scasb
	jne jmpErrorParam@Main

		mov [pFind], EBX
		inc EBX
		mov EDX, EDI
		sub EDX, EBX
		mov ESI, EDI
		mov AL,  ' '

jmpFindParam@Main:
	scasb
	jbe jmpFindParam@Main

		mov EAX, EDI
		dec EAX
		sub EAX, ESI
		jz jmpSetParam@Main

			dec ESI
			mov [ESI],AL

			dec EDI
			xor EAX, EAX
			mov [EDI],AL

			mov EAX, ESI

jmpSetParam@Main:
	mov [Param], EAX
;------------------------------------------------
;   * * *  Find KeyParam
;------------------------------------------------
	mov ESI, sServerConfigParam
	xor ECX, ECX
	mov EBX, ECX

jmpFindKey@Main:
	inc EBX
	add ESI, ECX
	xor EAX, EAX
	lodsb
	mov ECX, EAX
	jECXz jmpReport@Main

		cmp EAX, EDX
		jne jmpFindKey@Main

			mov EDI, [pFind]
			repe cmpsb
			jne jmpFindKey@Main
;------------------------------------------------
;   * * *  Select Table
;------------------------------------------------
			mov ESI, [Param]
			shl EBX, 2
			cmp BL, CFG_INDEX_HOST
			je jmpHost@Main
			ja jmpSetHost@Main

			cmp BL, CFG_INDEX_PROCESS
			je jmpAsk@Main
			ja jmpSetAsk@Main

			mov [ServerConfig+EBX], ESI
			jmp jmpFindConfig@Main
;------------------------------------------------
;   * * *  Set Report
;------------------------------------------------
jmpReport@Main:
	mov ESI,[pFind]
	mov AX, [ESI]
	mov EBX, ECX
	sub AX,'00'
	mov BL, AH
	mov CL, 10
	mul CL
	add BL, AL
	mov ESI,[Param]
	cmp BL, REPORT_MESSAGE_COUNT-1
	ja jmpErrorParam@Main

	mov [lppReportMessages+EBX*4], ESI
	jmp jmpFindConfig@Main
;------------------------------------------------
;   * * *  Set ExtAsk
;------------------------------------------------
jmpAsk@Main:
	mov EDX, ErrRunProcess
	or  ESI, ESI
	jz jmpGetAsk@Main

	mov EDX, DefRunProcess
	mov AX, [ESI]
	cmp AH, '*'
	je jmpGetAsk@Main

	dec [TotalProcess]
	jz jmpErrorParam@Main

		mov EDI, [SetRunProc]
		mov [GetRunProc], EDI

		xchg EDX, ESI
		mov   CL, ASK_EXT_COUNT
		rep movsd

		mov ESI, EDX
		mov [SetRunProc], EDI

jmpSetAsk@Main:
		mov EDI, [GetRunProc]
		mov [EDI+EBX-CFG_OFFSET_PROCESS], ESI
		jmp jmpFindConfig@Main

jmpGetAsk@Main:
	mov [GetRunProc], EDX
	jmp jmpFindConfig@Main
;------------------------------------------------
;   * * *  Set Host
;------------------------------------------------
jmpHost@Main:
	dec [TotalHost]
	jz jmpErrorParam@Main

		mov CL, NET_HOST_SIZE
		add [GetNetHost], ECX

jmpSetHost@Main:
	mov EDI, [GetNetHost]
	mov [EDI+EBX-CFG_OFFSET_HOST], ESI
	jmp jmpFindConfig@Main
;------------------------------------------------
;   * * *  Config Error
;------------------------------------------------
jmpErrorParam@Main:
	mov [lppReportMessages], ESI
	mov EAX, [pBuffer]
	sub EAX, TabConfig
	shr EAX, 2
	mov [SystemReport.ExitCode], EAX

	xor EDX, EDX
	jmp jmpError@Main
;------------------------------------------------
;       * * *  Set Report FileName
;------------------------------------------------
jmpScanEnd@Main:
	mov  DL, CFG_ERR_SystemParam
	mov ESI, [ServerConfig.lpReportPath]
	or  ESI, ESI
	jz jmpError@Main

		mov EDI, szReportName
		xor EAX, EAX
		lodsb
		inc EAX
		mov ECX, EAX
		rep movsb
;------------------------------------------------
;       * * *  Startup WSAver.2.2
;------------------------------------------------
	push WSockVer
	push SET_WSA_VER
	call [WSAStartup]

	mov DL, SYS_ERR_WSAversion
	or EAX, EAX
	jnz jmpError@Main
;------------------------------------------------
;   * * *  Start Server
;------------------------------------------------
	push ServiceTable
	call [StartServiceCtrlDispatcher]

	or EAX, EAX
	jnz jmpEnd@Main
		mov DL, SYS_ERR_Dispatcher
;------------------------------------------------
;   * * *  Server Error
;------------------------------------------------
jmpError@Main:
	call FileReport
;------------------------------------------------
;   * * *  Stop Server
;------------------------------------------------
jmpEnd@Main:
	mov  DL, SYS_MSG_Stop
	call FileReport

	xor EAX, EAX
	push EAX
	call [ExitProcess]
;------------------------------------------------
include 'resource.asm'
;------------------------------------------------
;   * * *   END  * * *
;------------------------------------------------
