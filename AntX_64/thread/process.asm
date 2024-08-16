;------------------------------------------------
;	AntX Web Server
;	THREAD:  Thread of Processor
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc ThreadProcessor   ;   RCX = ThrControl

local pRunPath    PCHAR ?
local pCmdLine    PCHAR ?
local pDirectory  PCHAR ?
local hProcess    HANDLE ?
local lpProcessIoData LPPORT_IO_DATA ?
;------------------------------------------------
	xor RAX, RAX
	inc EAX
	mov [CountProcess], RAX
	mov [dSecurity.bInheritHandle], RAX

	mov AL, SECURITY_ATTRIBUTES_SIZE
	mov [dSecurity.nLength], RAX

	mov AL, STARTUPINFO_SIZE
	mov [StartRunInfo.cb], EAX

	mov AL,  80
	sub RSP, RAX
;------------------------------------------------
;   * * *  Wait Process
;------------------------------------------------
jmpWaitProcess@Processor:
	param 4, WAIT_PROC_TIMEOUT
	param 3, 0
	param 2, RunProcessEvent
	param 1, [CountProcess]
	call [WaitForMultipleObjects]

	or EAX, EAX
	jz jmpTabProcess@Processor

	cmp EAX, WAIT_FAILED
	je jmpWaitError@Processor

	mov ECX, [ThreadServerCtrl]
	or  ECX, ECX 
	jz jmpEnd@Processor

	cmp EAX, WAIT_TIMEOUT
	je jmpWaitProcess@Processor
;------------------------------------------------
;       * * *  Get ProcEvent
;------------------------------------------------
	lea RDI, [RAX*8]

	mov RAX, [CountProcess]
	dec RAX
	mov [CountProcess], RAX
	lea RSI, [RAX*8]

	mov RBX, [RunProcessSocket+RDI]
	mov [lpProcessIoData], RBX

	mov RCX, [RunProcessEvent+RDI]
	mov [hProcess], RCX

	mov RAX, [RunProcessEvent+RSI]
	mov [RunProcessEvent+RDI], RAX

	mov RAX, [RunProcessSocket+RSI]
	mov [RunProcessSocket+RDI], RAX
;------------------------------------------------
;   * * *  GetProcReturn
;------------------------------------------------
	lea RDX, [RBX+PORT_IO_DATA.ExitCode]
	call [GetExitCodeProcess]

	mov DL, PRC_ERR_ExitProc
	or EAX, EAX
	jz jmpReport@Processor

		param 1, [hProcess]
		call [CloseHandle]
;------------------------------------------------
;       * * *  Create Headers
;------------------------------------------------
	mov RSI, [lpProcessIoData] 
	mov RCX, [RSI+PORT_IO_DATA.hFile]
	xor RBX, RBX

	or [RSI+PORT_IO_DATA.Route], SET_SEND_BIT
	jnz jmpCreateHeader@Processor
		mov BL, HTTP_201_CREATE

jmpCreateHeader@Processor:
	call CreateHttpHeader

	mov [RSI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER

	mov RDX, [RSI+PORT_IO_DATA.CountBytes]
	mov R8, [RSI+PORT_IO_DATA.TotalBytes]
	or  R8, R8
	jz jmpSending@Processor

		mov RAX, [ServerConfig.MaxBufferSize]
		sub RAX, RDX
		cmp RAX, R8
		jg jmpReadPipe@Processor
			mov R8, RAX
;------------------------------------------------
;       * * *  Read Pipe
;------------------------------------------------
jmpReadPipe@Processor:
		xor RAX, RAX
		param 5, RAX
		param 4, PipeBytes
		lea RDX, [RSI+RDX+PORT_IO_DATA.Buffer]
		param 1, [RSI+PORT_IO_DATA.hFile]
		call [ReadFile]

		mov DL, SRV_ERR_ReadFile
		or EAX, EAX
		jz jmpReport@Processor
;------------------------------------------------
;       * * *  Set MaxBufferSize
;------------------------------------------------
			mov RSI, [lpProcessIoData]
			mov [RSI+PORT_IO_DATA.Route], ROUTE_SEND_FILE

			mov RAX, [PipeBytes]
			add [RSI+PORT_IO_DATA.CountBytes], RAX
			sub [RSI+PORT_IO_DATA.TotalBytes], RAX
			jnz jmpMaxSendSize@Processor

				mov RCX, [RSI+PORT_IO_DATA.hFile]
				xor RAX, RAX
				mov [RSI+PORT_IO_DATA.hFile], RAX
				call [CloseHandle]

				mov RSI, [lpProcessIoData]
				mov [RSI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER

jmpMaxSendSize@Processor:
			mov RDX, [RSI+PORT_IO_DATA.CountBytes]
;------------------------------------------------
;       * * *  Sending Pipe
;------------------------------------------------
jmpSending@Processor:
	mov RAX, [ServerConfig.MaxSendSize]
	cmp RAX, RDX
	ja jmpSizeSend@Processor
		mov RDX, RAX

jmpSizeSend@Processor:
	mov [RSI+PORT_IO_DATA.WSABuffer.len], RDX
	param 3, 0
	param 7, R8
	param 6, RSI
	param 5, R8
	inc R8
	param 4, TransBytes
	lea RDX, [RSI+PORT_IO_DATA.WSABuffer]
	param 1, [RSI+PORT_IO_DATA.Socket]
	call [WSASend]

	or EAX, EAX
	jz jmpTabProcess@Processor

		call [WSAGetLastError]
		mov  DL, SRV_ERR_SendPipe
		cmp EAX, ERROR_IO_PENDING
		jne jmpClose@Processor
;------------------------------------------------
;       * * *  GetQueueProcess
;------------------------------------------------
jmpTabProcess@Processor:
	xor RAX, RAX
	mov  AL, MAXIMUM_WAIT_OBJECTS-1
	cmp RAX, [CountProcess]
	jbe jmpWaitProcess@Processor

		mov RSI, [GetQueuedProcess]
		cmp RSI, [SetQueuedProcess]
		je jmpWaitProcess@Processor

			lodsq

			cmp RSI, [MaxQueuedProcess]
			jb jmpGetProcess@Processor
				mov RSI, [TabQueuedProcess]

jmpGetProcess@Processor:
	mov [GetQueuedProcess], RSI
	mov RBX, RAX
	mov [lpProcessIoData], RAX
;------------------------------------------------
;   * * *  Set ProcStruct
;------------------------------------------------
	xor RAX, RAX
	mov RCX, RAX
	mov RDI, RAX
	mov RDI, StartRunInfo+8
	mov  CL, STARTUPINFO_COUNT + PROCESS_INFORMATION_COUNT-1
	rep stosq

	mov [StartRunInfo.wShowWindow], SW_HIDE
	mov [StartRunInfo.dwFlags], STARTF_USESTDHANDLES
;------------------------------------------------
;   * * *  Set Path(Size)
;------------------------------------------------
	lea RSI, [RBX+PORT_IO_DATA.UrlSize]
	lodsw
	mov R8,  RAX
	mov R10, RSI
;------------------------------------------------
;   * * *  Set RunDir
;------------------------------------------------
	mov RBX, [RBX+PORT_IO_DATA.ExtRunProc]
	mov EAX, [RBX+ASK_EXT.Directory]
	mov R12, RAX
	inc R12
	or  RAX, RAX
	jnz jmpSetDir@Processor

		mov R12d, szProcDir
		mov RDI, R12
		mov RCX, R8
		rep movsb

		mov RCX, R8
		mov AL, '\'
		std
		repne scasb
		cld

		inc RDI
		xor RAX, RAX
		mov [RDI], AL

jmpSetDir@Processor:
	mov [pDirectory], R12
;------------------------------------------------
;   * * *  Set CmdLine
;------------------------------------------------
	mov R12d, [RBX+ASK_EXT.CmdLine]
	or  R12d, R12d
	jz jmpSetCmd@Processor

		mov RSI,  R12
		mov R12d, szCmdPath
		mov RDI,  R12

		xor RAX, RAX
		lodsb
		mov RDX,  RAX

		cmp word[RSI], '! '
		jne jmpCopyPath@Processor
			movsw

jmpCopyPath@Processor:
		cmp byte[RSI], '*'
		jne jmpCopyParam@Processor

			mov RAX, RSI
			inc RAX

			mov RSI, R10
			mov RCX, R8
			rep movsb

			mov RSI, RAX

jmpCopyParam@Processor:
		 mov RCX, RDX
		 rep movsb
		 mov [RDI], CL

jmpSetCmd@Processor:
	mov [pCmdLine], R12
;------------------------------------------------
;   * * *  Set RunPath
;------------------------------------------------
	mov ECX, [RBX+ASK_EXT.RunPath]
	jECXz jmpSetRun@Processor

		inc RCX
		cmp byte[RCX], '*'
		jne jmpSetRun@Processor
			mov RCX, R10

jmpSetRun@Processor:
	mov [pRunPath],  RCX
;------------------------------------------------
;   * * *  Std InFile
;------------------------------------------------
	mov RSI, [lpProcessIoData]
	mov RCX, [RSI+PORT_IO_DATA.CountBytes]
	mov RDX, [RSI+PORT_IO_DATA.ResurseId]
	or  RDX, RDX
	jz jmpInPipe@Processor
;------------------------------------------------
;   * * *  Std InFile
;------------------------------------------------
		lea RDI, [RSI+PORT_IO_DATA.Buffer]
		mov EAX, CONTENT_ID
		stosd
		call HexToStr

		mov [RDI], ECX
		mov CL, 20
;------------------------------------------------
;   * * *  Create InPipe
;------------------------------------------------
jmpInPipe@Processor:
	mov [PipeBytes], RCX
	param 4, RCX
	param 3, dSecurity
	param 2, hInPipe
	param 1, StartRunInfo.hStdInput
	call [CreatePipe]

	mov DL, PRC_ERR_PipeIn
	or EAX, EAX
	jz jmpReport@Processor

		mov RSI, [lpProcessIoData]
		mov RAX, [StartRunInfo.hStdInput]
		mov [RSI+PORT_IO_DATA.hFile], RAX

		param 5, 0
		param 4, PipeBytes
		param 3, [PipeBytes]
		lea RDX, [RSI+PORT_IO_DATA.Buffer]
		param 1, [hInPipe]
		call [WriteFile]

		mov DL, PRC_ERR_PipeWrite
		or EAX, EAX
		jz jmpReport@Processor

			param 1, [hInPipe]
			call [CloseHandle]
;------------------------------------------------
;   * * *  Create StdPipe
;------------------------------------------------
jmpOutPipe@Processor:
	param 4, [ServerConfig.MaxPipeSize]
	param 3, dSecurity
	param 2, StartRunInfo.hStdOutput
	param 1, hOutPipe
	call [CreatePipe]

	mov DL, PRC_ERR_PipeOut
	or EAX, EAX
	jz jmpReport@Processor

		param 1, [hOutPipe]
		param 2, 0
		param 3, RDX
		inc RDX
		call [SetHandleInformation]

		mov RAX, [StartRunInfo.hStdOutput]
		mov [StartRunInfo.hStdError], RAX

		mov RSI, [lpProcessIoData]
		mov RAX, [hOutPipe]
		mov [RSI+PORT_IO_DATA.hFile], RAX
;------------------------------------------------
;   * * *  Greate RunProcess
;------------------------------------------------
		param 10, ProcRunInfo
		param 9, StartRunInfo
		mov RAX, [pDirectory]
		param 8, RAX
		xor RAX, RAX
		param 7, RAX
		param 6, RAX
		param 4, RAX
		param 3, RAX
		inc RAX
		param 5, RAX
		param 2, [pCmdLine]
		param 1, [pRunPath]
		call [CreateProcess]

		mov DL, PRC_ERR_RunProc
		or EAX, EAX
		jz jmpReport@Processor
;------------------------------------------------
;   * * *  Set Handle
;------------------------------------------------
			param 1, [ProcRunInfo.hThread]
			call [CloseHandle]

			mov RBX, [lpProcessIoData]
			mov RDI, [CountProcess]
			mov RAX, [ProcRunInfo.hProcess]

			mov [RBX+PORT_IO_DATA.hProcess], RAX
			mov [RunProcessEvent +RDI*8], RAX
			mov [RunProcessSocket+RDI*8], RBX
			inc [CountProcess]
			jmp jmpTabProcess@Processor
;------------------------------------------------
;       * * *  Open StatFile
;------------------------------------------------
jmpReport@Processor:
	mov RSI, [lpProcessIoData]
	mov RDI, szProcPath
	mov  BL, HTTP_500_INTERNAL
	call GetStatusFile

	mov RSI, [lpProcessIoData]
	mov [RSI+PORT_IO_DATA.hFile], RCX 

	mov BL, HTTP_500_INTERNAL
	jmp jmpCreateHeader@Processor
;------------------------------------------------
;   * * *  Get AllError
;------------------------------------------------
jmpClose@Processor:
	mov  [SystemReport.Index], EDX
	call [GetLastError]

	mov RSI, [lpProcessIoData]
	mov [RSI+PORT_IO_DATA.ExitCode], EAX

	param 2, 0
	param 3, RDX
	param 4, RSI
	mov EDX, [SystemReport.Index]
	param 1, [hPortIOSocket]
	call [PostQueuedCompletionStatus]

	or EAX, EAX
	jnz  jmpTabProcess@Processor
;------------------------------------------------
;       * * *  Process Error
;------------------------------------------------
jmpWaitError@Processor:
	call [GetLastError]
	mov  [SystemReport.Error], EAX
	mov  [SystemReport.Index], PRC_ERR_WaitProc
;------------------------------------------------
;   * * *  Terminate All Processes
;------------------------------------------------
jmpEnd@Processor:
	mov RSI, RunProcessEvent

jmpFreeProc@Processor:
	lodsq

	mov [hProcess], RAX
	mov [TotalProcess], RSI

	param 1, RAX
	param 2, PipeBytes
	call [GetExitCodeProcess]
	or EAX, EAX
	jz jmpNextProc@Processor  

		mov RAX, [PipeBytes]
		cmp EAX, STILL_ACTIVE 
		jne jmpNextProc@Processor

			param 1, [hProcess]
			param 2, 0
			call [TerminateProcess]

jmpNextProc@Processor:
	param 1, [hProcess]
	call [CloseHandle]

	mov RSI, [TotalProcess]
	dec [CountProcess]
	jnz jmpFreeProc@Processor
;------------------------------------------------
;       * * *  End Thread  * * *
;------------------------------------------------
	xor RAX, RAX
	param 1, RAX
	mov [ThreadProcessCtrl], EAX
	mov AL,  80
	add RSP, RAX
	call [ExitThread]
endp
;------------------------------------------------
;   * * *  END  * * *
;------------------------------------------------
