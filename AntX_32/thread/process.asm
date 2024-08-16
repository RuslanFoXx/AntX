;------------------------------------------------
;	AntX Web Server
;	THREAD:  Thread of Processor
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc ThreadProcessor ThrControl

local pRunPath   PCHAR ?
local pCmdLine   PCHAR ?
local pDirectory PCHAR ?
local hProcess   HANDLE ?
local lpProcessIoData LPPORT_IO_DATA ?
;------------------------------------------------
	xor EAX, EAX
	inc EAX
	mov [CountProcess], EAX
	mov [dSecurity.bInheritHandle], EAX
	mov [dSecurity.nLength], SECURITY_ATTRIBUTES_SIZE
	mov [StartRunInfo.cb], STARTUPINFO_SIZE
;------------------------------------------------
;   * * *  Wait Process
;------------------------------------------------
jmpWaitProcess@Processor:
	push WAIT_PROC_TIMEOUT
	xor EAX, EAX
	push EAX
	push RunProcessEvent
	push [CountProcess]
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
	lea EDI, [EAX*4]

	mov EAX, [CountProcess]
	dec EAX
	mov [CountProcess], EAX
	lea ESI, [EAX*4]

	mov EDX, [RunProcessEvent+EDI]
	mov [hProcess], EDX

	mov EBX, [RunProcessSocket+EDI]
	mov [lpProcessIoData], EBX

	mov EAX, [RunProcessEvent+ESI]
	mov [RunProcessEvent+EDI], EAX

	mov EAX, [RunProcessSocket+ESI]
	mov [RunProcessSocket+EDI], EAX
;------------------------------------------------
;   * * *  GetProcReturn
;------------------------------------------------
	lea  EAX, [EBX+PORT_IO_DATA.ExitCode]
	push EAX
	push EDX
	call [GetExitCodeProcess]

	mov DL, PRC_ERR_ExitProc
	or EAX, EAX
	jz jmpReport@Processor

		push [hProcess]
		call [CloseHandle]
;------------------------------------------------
;       * * *  Create Headers
;------------------------------------------------
	mov ESI, [lpProcessIoData]
	mov ECX, [ESI+PORT_IO_DATA.hFile]
	xor EBX, EBX

	or [ESI+PORT_IO_DATA.Route], SET_SEND_BIT
	jnz jmpCreateHeader@Processor
		mov BL, HTTP_201_CREATE

jmpCreateHeader@Processor:
	call CreateHttpHeader

	mov [ESI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER
	
	mov EDX, [ESI+PORT_IO_DATA.CountBytes]
	mov ECX, [ESI+PORT_IO_DATA.TotalBytes]
	jECXz jmpSending@Processor

		mov EAX, [ServerConfig.MaxBufferSize]
		sub EAX, EDX
		cmp EAX, ECX
		jg jmpReadPipe@Processor
			mov ECX, EAX
;------------------------------------------------
;       * * *  Read Pipe
;------------------------------------------------
jmpReadPipe@Processor:
		xor EAX, EAX
		push EAX
		push PipeBytes
		push ECX
		lea EAX, [ESI+EDX+PORT_IO_DATA.Buffer]
		push EAX
		push [ESI+PORT_IO_DATA.hFile]
		call [ReadFile]

		mov DL, PRC_ERR_PipeRead
		or EAX, EAX
		jz jmpReport@Processor
;------------------------------------------------
;       * * *  Set MaxBufferSize
;------------------------------------------------
			mov ESI, [lpProcessIoData]
			mov [ESI+PORT_IO_DATA.Route], ROUTE_SEND_FILE

			mov EAX, [PipeBytes]
			add [ESI+PORT_IO_DATA.CountBytes], EAX
			sub [ESI+PORT_IO_DATA.TotalBytes], EAX
			jnz jmpMaxSendSize@Processor

				push [ESI+PORT_IO_DATA.hFile]
				xor EAX, EAX
				mov [ESI+PORT_IO_DATA.hFile], EAX
				call [CloseHandle]

				mov ESI, [lpProcessIoData]
				mov [ESI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER

jmpMaxSendSize@Processor:
			mov EDX, [ESI+PORT_IO_DATA.CountBytes]
;------------------------------------------------
;       * * *  Sending Pipe
;------------------------------------------------
jmpSending@Processor:
	mov EAX, [ServerConfig.MaxSendSize]
	cmp EAX, EDX
	ja jmpSizeSend@Processor
		mov EDX, EAX

jmpSizeSend@Processor:
	mov [ESI+PORT_IO_DATA.WSABuffer.len], EDX
	xor EAX, EAX
	push EAX
	push ESI
	push EAX
	push TransBytes
	inc EAX
	push EAX 
	lea EAX, [ESI+PORT_IO_DATA.WSABuffer]
	push EAX
	push [ESI+PORT_IO_DATA.Socket]

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
	xor EAX, EAX
	mov  AL, MAXIMUM_WAIT_OBJECTS-1
	cmp EAX, [CountProcess]
	jbe jmpWaitProcess@Processor

		mov ESI, [GetQueuedProcess]
		cmp ESI, [SetQueuedProcess]
		je jmpWaitProcess@Processor

			lodsd

			cmp ESI, [MaxQueuedProcess]
			jb jmpGetProcess@Processor
				mov ESI, [TabQueuedProcess]

jmpGetProcess@Processor:
	mov [GetQueuedProcess], ESI
	mov EBX, EAX
	mov [lpProcessIoData], EAX
;------------------------------------------------
;   * * *  Set ProcStruct
;------------------------------------------------
	mov EDI, StartRunInfo+4
	xor EAX, EAX
	mov ECX, EAX
	mov CL,  STARTUPINFO_COUNT+PROCESS_INFORMATION_COUNT-1
	rep stosd

	mov [StartRunInfo.wShowWindow], SW_HIDE
	mov [StartRunInfo.dwFlags], STARTF_USESTDHANDLES
;------------------------------------------------
;   * * *  Set Path(Size)
;------------------------------------------------
	lea ESI, [EBX+PORT_IO_DATA.UrlSize]
	lodsw
	mov EDX, EAX
	mov [pRunPath], ESI
;------------------------------------------------
;   * * *  Set RunDir
;------------------------------------------------
	mov EBX, [EBX+PORT_IO_DATA.ExtRunProc]
	mov EAX, [EBX+ASK_EXT.Directory]
	mov ECX, EAX
	inc EAX
	or  ECX, ECX
	jnz jmpSetDir@Processor

		mov EDI, szProcDir
		mov ECX, EDX
		rep movsb

		mov ECX, EDX
		mov AL, '\'
		std
		repne scasb
		cld
		inc EDI
		xor EAX, EAX
		mov [EDI], AL

		mov EAX, szProcDir

jmpSetDir@Processor:
	mov [pDirectory], EAX
;------------------------------------------------
;   * * *  Set CmdLine
;------------------------------------------------
	mov ESI, [EBX+ASK_EXT.CmdLine]
	or  ESI, ESI
	jz jmpSetCmd@Processor

		mov EDI, szCmdPath
		mov ECX, EDX

		xor EAX, EAX
		lodsb
		mov EDX, EAX

		cmp word[ESI], '! '
		jne jmpCopyPath@Processor
			movsw

jmpCopyPath@Processor:
		cmp byte[ESI], '*'
		jne jmpCopyParam@Processor

			mov EAX, ESI
			inc EAX
			mov ESI, [pRunPath]
			rep movsb
			mov ESI, EAX

jmpCopyParam@Processor:
		mov ECX, EDX
		rep movsb

		mov [EDI], CL
		mov ESI, szCmdPath

jmpSetCmd@Processor:
	mov [pCmdLine], ESI
;------------------------------------------------
;   * * *  Set RunPath
;------------------------------------------------
	mov ECX, [EBX+ASK_EXT.RunPath]
	jECXz jmpSetRun@Processor

		inc ECX
		cmp byte[ECX], '*'
		je jmpStdInFile@Processor

jmpSetRun@Processor:
	mov [pRunPath], ECX
;------------------------------------------------
;   * * *  Std InFile
;------------------------------------------------
jmpStdInFile@Processor:
	mov ESI, [lpProcessIoData]
	mov ECX, [ESI+PORT_IO_DATA.CountBytes]
	mov EDX, [ESI+PORT_IO_DATA.ResurseId]
	or  EDX, EDX
	jz jmpInPipe@Processor

		lea EDI, [ESI+PORT_IO_DATA.Buffer]
		mov EAX, CONTENT_ID
		stosd
		call HexToStr

		mov [EDI], ECX
		mov CL, 20
;------------------------------------------------
;   * * *  Create InPipe
;------------------------------------------------
jmpInPipe@Processor:
	mov [PipeBytes], ECX
	push ECX
	push dSecurity
	push hInPipe
	push StartRunInfo.hStdInput
	call [CreatePipe]

	mov DL, PRC_ERR_PipeIn
	or EAX, EAX
	jz jmpReport@Processor

		mov ESI, [lpProcessIoData]
		mov EAX, [StartRunInfo.hStdInput]
		mov [ESI+PORT_IO_DATA.hFile], EAX

		xor EAX, EAX
		push EAX
		push PipeBytes
		push [PipeBytes]
		lea EAX, [ESI+PORT_IO_DATA.Buffer]
		push EAX
		push [hInPipe]
		call [WriteFile]

		mov DL, PRC_ERR_PipeWrite
		or EAX, EAX
		jz jmpReport@Processor

			push [hInPipe]
			call [CloseHandle]
;------------------------------------------------
;   * * *  Create StdPipe
;------------------------------------------------
jmpOutPipe@Processor:
	push [ServerConfig.MaxPipeSize]
	push dSecurity
	push StartRunInfo.hStdOutput
	push hOutPipe
	call [CreatePipe]

	mov DL, PRC_ERR_PipeOut
	or EAX, EAX
	jz jmpReport@Processor

		xor EAX, EAX
		push EAX
		inc EAX
		push EAX
		push [hOutPipe]
		call [SetHandleInformation]

		mov EAX, [StartRunInfo.hStdOutput]
		mov [StartRunInfo.hStdError], EAX

		mov ESI, [lpProcessIoData]
		mov EAX, [hOutPipe]
		mov [ESI+PORT_IO_DATA.hFile], EAX
;------------------------------------------------
;   * * *  Greate RunProcess
;------------------------------------------------
	push ProcRunInfo
	push StartRunInfo
	push [pDirectory]
	xor EAX, EAX
	push EAX
	push EAX
	inc EAX
	push EAX
	xor EAX, EAX
	push EAX
	push EAX
	push [pCmdLine]
	push [pRunPath]
	call [CreateProcess]

	mov DL, PRC_ERR_RunProc
	or EAX, EAX
	jz jmpReport@Processor
;------------------------------------------------
;   * * *  Set Handle
;------------------------------------------------
		push [ProcRunInfo.hThread]
		call [CloseHandle]

		mov EBX, [lpProcessIoData]
		mov EDI, [CountProcess]
		mov EAX, [ProcRunInfo.hProcess]

		mov [EBX+PORT_IO_DATA.hProcess], EAX
		mov [RunProcessEvent +EDI*4], EAX
		mov [RunProcessSocket+EDI*4], EBX
		inc [CountProcess]
		jmp jmpTabProcess@Processor
;------------------------------------------------
;       * * *  Open StatFile
;------------------------------------------------
jmpReport@Processor:
	mov ESI, [lpProcessIoData]
	mov EDI, szProcPath
	mov  BL, HTTP_500_INTERNAL
	call GetStatusFile

	mov  ESI, [lpProcessIoData]
	mov [ESI+PORT_IO_DATA.hFile], ECX 

	mov BL, HTTP_500_INTERNAL
	jmp jmpCreateHeader@Processor
;------------------------------------------------
;   * * *  Get AllError
;------------------------------------------------
jmpClose@Processor:
	mov  [SystemReport.Index], EDX
	call [GetLastError]

	mov ESI, [lpProcessIoData]
	mov [ESI+PORT_IO_DATA.ExitCode], EAX
	xor EAX, EAX
	push ESI
	push [SystemReport.Index]
	push EAX
	push [hPortIOSocket]
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
	mov ESI, RunProcessEvent
	mov ECX, [CountProcess]

jmpFreeProc@Processor:
	lodsd
	mov [hProcess], EAX

	push ECX
	push ESI

	push PipeBytes
	push EAX
	call [GetExitCodeProcess]
	or EAX, EAX
	jz jmpNextProc@Processor  

		mov EAX, [PipeBytes]
		cmp EAX, STILL_ACTIVE 
		jne jmpNextProc@Processor

			xor EAX, EAX
			push EAX
			push [hProcess]
			call [TerminateProcess]

jmpNextProc@Processor:
	push [hProcess]
	call [CloseHandle]

	pop ESI
	pop ECX
	loop jmpFreeProc@Processor
;------------------------------------------------
;       * * *  End Thread  * * *
;------------------------------------------------
	mov [ThreadProcessCtrl], ECX
	push ECX
	call [ExitThread]
endp
;------------------------------------------------
;   * * *  END  * * *
;------------------------------------------------
