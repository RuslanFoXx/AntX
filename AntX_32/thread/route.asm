;------------------------------------------------
;	AntX Web Server
;	THREAD: Router
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc ThreadRouter ThrControl

	mov EDI, [TabSocketIoData]
	mov ECX, [ServerConfig.MaxConnections]
	xor EAX, EAX
	rep stosd

	inc EAX
	mov [ThreadSocketCtrl], EAX
;------------------------------------------------
;       * * *  Wait Completion
;------------------------------------------------
jmpWaitCompletionPort@Router:

	push WAIT_PORT_TIMEOUT
	push lpSocketIoData
	push lpPortIoCompletion
	push TransferredBytes
	push [hPortIOSocket]
	call [GetQueuedCompletionStatus]

	mov ECX, [ThreadServerCtrl]
	or  ECX, ECX 
	jz jmpEnd@Router
;------------------------------------------------
;       * * *  ReportError
;------------------------------------------------
	or EAX, EAX
	jnz jmpSetSocket@Router
		mov [TransferredBytes], EAX

		call [WSAGetLastError]
		cmp EAX, WAIT_TIMEOUT
		je jmpWaitCompletionPort@Router

		mov  DL, SRV_MSG_BreakConnect
		cmp EAX, ERROR_NETNAME_DELETED
		je jmpCloseSocket@Router

			mov [RouterReport.Error], EAX
			mov [RouterReport.Index], EDX
;------------------------------------------------
;       * * *  SystemRouter
;------------------------------------------------
jmpSetSocket@Router:
	mov ESI, [lpSocketIoData]
	or  ESI, ESI
	jz jmpWaitCompletionPort@Router

	mov EDX, [lpPortIoCompletion]
	or  EDX, EDX
	jnz jmpInternalError@Router

	mov  DL,SRV_MSG_Disconnected
	mov ECX, [TransferredBytes]
	or  ECX, ECX
	jz jmpCloseSocket@Router
;------------------------------------------------
;       * * *  ServerRouter
;------------------------------------------------
	add [ESI+PORT_IO_DATA.TransferredBytes], ECX
	add [ESI+PORT_IO_DATA.WSABuffer.buf], ECX

	mov AX, [ESI+PORT_IO_DATA.Route]
	cmp AL, ROUTE_SEND_FILE
	je jmpRespondFromFile@Router

	cmp AL, ROUTE_SEND_BUFFER
	je jmpRespondFromBuffer@Router

	cmp AL, ROUTE_RECV_BUFFER
	je jmpRequestToBuffer@Router

	cmp AL, ROUTE_RECV_FILE
	je jmpRequestToFile@Router

	or AL, AL 
	jnz jmpCloseSocket@Router
;------------------------------------------------
;       * * *  Get Method
;------------------------------------------------
	mov [ESI+PORT_IO_DATA.CountBytes], ECX
	xor EDX, EDX
	sub  CX, 4

	lea ESI, [ESI+PORT_IO_DATA.Buffer]
	lodsd
	and EAX, KEY_CASE_UP
	cmp EAX, 'GET'
	je jmpMethod@Router

		inc ESI
		dec ECX
		mov  BL, HTTP_501_NOT_IMPLEMENT
		mov  DL, SRV_ERR_Method
		cmp EAX, 'POST'
			jne jmpSelected@Router

jmpMethod@Router:
	mov [Method], EDX

	call HTTPRequest
	or EDX, EDX
	jnz jmpSelected@Router
;------------------------------------------------
;       * * *  SELECT0 METHOD GET/POST
;------------------------------------------------
;jmpSelectMethod@Router:
	mov ESI, [lpSocketIoData]
	mov EAX, [Method]
	or  EAX, EAX
	jnz jmpRecvMethod@Router
;------------------------------------------------
;       * * *  GET CGI-PROCESSOR
;------------------------------------------------
jmpSelectMode@Router:
	mov EDI, [ESI+PORT_IO_DATA.ExtRunProc]
	mov EAX, [EDI+ASK_EXT.Run]
	or  EAX, EAX
	jz jmpOpenFile@Router

jmpRunProcess@Router:
		mov EDI, [SetQueuedProcess]
		lea EAX, [EDI+4]
		cmp EAX, [MaxQueuedProcess]
		jb jmpSetProcess@Router
			mov EAX, [TabQueuedProcess]

jmpSetProcess@Router:
		mov  BL, HTTP_503_BUSY
		mov  DL, SRV_MSG_ProcessLimit
		cmp EAX, [GetQueuedProcess]
		je jmpSelected@Router

			mov [SetQueuedProcess], EAX
			mov [EDI], ESI

			mov EAX, [CountProcess]
			cmp  AL, MAXIMUM_WAIT_OBJECTS
			jae jmpWaitCompletionPort@Router

				push [RunProcessEvent]
				call [SetEvent]
				jmp jmpWaitCompletionPort@Router
;------------------------------------------------
;       * * *  OpenSendFile
;------------------------------------------------
jmpOpenFile@Router:
	mov [ESI+PORT_IO_DATA.ResurseId], EAX
	push EAX
	push FILE_ATTRIBUTE_READONLY
	push OPEN_EXISTING
	push EAX
	push FILE_SHARE_READ
	push GENERIC_READ
	lea EAX, [ESI+PORT_IO_DATA.Path]
	push EAX
	call [CreateFile]

	mov  DL, SRV_ERR_OpenFile
	cmp EAX, INVALID_HANDLE_VALUE
	je jmpNotFound@Router

		push EAX
		push EAX
		call [GetFileType]

		pop ECX
		xor EBX, EBX
		cmp EAX, FILE_TYPE_DISK
		je jmpHeaderMethod@Router
;------------------------------------------------
;       * * *  Http Code Selected
;------------------------------------------------
jmpAccessDenied@Router:
	mov BL, HTTP_403_FORBIDDEN
	mov DL, SRV_MSG_OpenAccess
	jmp jmpSelected@Router

jmpNotFound@Router:
	mov BL, HTTP_404_NOT_FOUND
	jmp jmpSelected@Router

jmpInternalError@Router:
	mov BL, HTTP_500_INTERNAL
;------------------------------------------------
;       * * *  CodeSelector
;------------------------------------------------
jmpSelected@Router:
	mov [Method], EBX
	call PostReport
;------------------------------------------------
;       * * *  Get StatFile
;------------------------------------------------
jmpMethodError@Router:
	mov ESI, [lpSocketIoData]
	mov EBX, [Method]
	mov EDI, szFileName
	call GetStatusFile

	mov ESI, [lpSocketIoData]
	mov EBX, [Method]
	or  ECX, ECX
	jnz jmpHeaderMethod@Router
		mov [ESI+PORT_IO_DATA.ExitCode], EBX

		cmp ECX, [ErrRunProcess.Run]
		jne jmpRunProcess@Router
;------------------------------------------------
;       * * *  Create Headers
;------------------------------------------------
jmpHeaderMethod@Router:
	mov ESI, [lpSocketIoData]
	mov [ESI+PORT_IO_DATA.hFile], ECX
	call CreateHttpHeader

	mov [ESI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER

	mov ECX, [ESI+PORT_IO_DATA.TotalBytes]
	jECXz jmpSendFromBuffer@Router

	mov [ESI+PORT_IO_DATA.Route], ROUTE_SEND_FILE
	jmp jmpSendFromFile@Router
;------------------------------------------------
;       * * *  Send From Buffer
;------------------------------------------------
jmpRespondFromBuffer@Router:
	mov ESI, [lpSocketIoData] 
	sub [ESI+PORT_IO_DATA.CountBytes], ECX
;------------------------------------------------
;       * * *  SendToBuffer
;------------------------------------------------
jmpSendFromBuffer@Router:
	mov ECX, [ESI+PORT_IO_DATA.CountBytes]
	mov  DL, SRV_MSG_Send
	xor EAX, EAX
	cmp ECX, EAX 
	jg jmpSending@Router
;------------------------------------------------
;       * * *  Post To Buffer
;------------------------------------------------
		cmp AX, [ESI+PORT_IO_DATA.Connection]
		je jmpCloseSocket@Router

			call PostReport

			mov ESI, [lpSocketIoData] 
			lea EDI, [ESI+PORT_IO_DATA.ResurseId]
			mov ECX, PORT_CLEAR_COUNT
			xor EAX, EAX
			rep stosd

			lea EDX, [ESI+PORT_IO_DATA.Buffer]
			mov [ESI+PORT_IO_DATA.WSABuffer.buf], EDX

			mov AX, HTTP_HEADER_SIZE
			jmp jmpSizeRecv@Router
;------------------------------------------------
;       * * *  Send From File
;------------------------------------------------
jmpRespondFromFile@Router:
	mov ESI, [lpSocketIoData]
	sub [ESI+PORT_IO_DATA.CountBytes], ECX
;------------------------------------------------
;       * * *  SendToFile
;------------------------------------------------
jmpSendFromFile@Router:
	mov ECX, [ESI+PORT_IO_DATA.CountBytes]
	cmp ECX, [ServerConfig.MaxSendSize] 
	jg jmpSending@Router

		mov [CountBytes], ECX
		mov EBX, [ServerConfig.MaxBufferSize]
		sub EBX, ECX

		mov EAX, [ESI+PORT_IO_DATA.WSABuffer.buf]
		lea EDX, [ESI+PORT_IO_DATA.Buffer]
		mov [ESI+PORT_IO_DATA.WSABuffer.buf], EDX

		xchg ESI, EAX
		mov  EDI, EDX
		add  EDX, ECX
		rep movsb

		mov ESI, EAX
		mov EAX, [ESI+PORT_IO_DATA.TotalBytes]
		cmp EAX, EBX
		jb jmpReadSend@Router
			mov EAX, EBX
;------------------------------------------------
;       * * *  Read SendFile
;------------------------------------------------
jmpReadSend@Router:
		push ECX
		push TotalBytes
		push EAX
		push EDX
		push [ESI+PORT_IO_DATA.hFile]
		call [ReadFile]

		mov DL, SRV_ERR_ReadFile
		or EAX, EAX
		jz jmpCloseSocket@Router
;------------------------------------------------
;       * * *  SendBuffer
;------------------------------------------------
			mov ESI, [lpSocketIoData] 
			mov EBX, [ESI+PORT_IO_DATA.TotalBytes]
			mov ECX, [CountBytes]
			mov EAX, [TotalBytes]
			add ECX, EAX
			sub EBX, EAX
			mov [CountBytes], ECX
			mov [ESI+PORT_IO_DATA.CountBytes], ECX
			mov [ESI+PORT_IO_DATA.TotalBytes], EBX
			or  EBX, EBX
			jnz jmpMaxSendSize@Router
;------------------------------------------------
;       * * *  Close File
;------------------------------------------------
jmpCloseSocketSend@Router:
				push [ESI+PORT_IO_DATA.hFile]
				xor EAX, EAX
				mov [ESI+PORT_IO_DATA.hFile], EAX
				call [CloseHandle]

				mov DL, SRV_ERR_ReadClose
				or EAX, EAX
				jz jmpCloseSocket@Router

					mov ESI, [lpSocketIoData] 
					xor EAX, EAX
					mov [ESI+PORT_IO_DATA.hFile], EAX
					mov [ESI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER
jmpMaxSendSize@Router:
			mov ECX, [CountBytes]
;------------------------------------------------
;       * * *  Sending
;------------------------------------------------
jmpSending@Router:
	mov EAX, [ServerConfig.MaxSendSize]
	cmp ECX, EAX
	jb jmpSizeSend@Router
		mov ECX, EAX

jmpSizeSend@Router:
	mov [ESI+PORT_IO_DATA.WSABuffer.len], ECX
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
	jz jmpWaitCompletionPort@Router

		call [WSAGetLastError]
		cmp EAX, ERROR_IO_PENDING
		je jmpWaitCompletionPort@Router

			mov DL, SRV_ERR_SendRouter
			jmp jmpCloseSocket@Router
;------------------------------------------------
;       * * *  RECV METHOD
;------------------------------------------------
jmpRecvMethod@Router:
	mov BL, HTTP_400_BAD_REQUEST
	mov DL, SRV_MSG_RecvDataSize

	mov EAX, [ESI+PORT_IO_DATA.TotalBytes]
	or  EAX, EAX
	jz jmpSelected@Router

		cmp EAX, [ServerConfig.MaxRecvFileSize]
		ja jmpSelected@Router
;------------------------------------------------
;       * * *  RECV Resurse
;------------------------------------------------
	mov  DL, SRV_ERR_RecvSize
	mov ECX, [ESI+PORT_IO_DATA.CountBytes]
	cmp EAX, ECX
	ja jmpRecvToResurse@Router
	jb jmpSendFileResurse@Router
;------------------------------------------------
;       * * *  SEND Resurse
;------------------------------------------------
jmpSendFromResurse@Router:
	mov DL, SRV_MSG_Recv

jmpSendFileResurse@Router:
	call PostReport

	mov ESI, [lpSocketIoData]
	jmp jmpSelectMode@Router
;------------------------------------------------
;       * * *  Set FileResurse
;------------------------------------------------
jmpRecvToResurse@Router:
	mov [ESI+PORT_IO_DATA.Route], ROUTE_RECV_BUFFER

	cmp EAX, [ServerConfig.MaxBufferSize]
	jbe jmpReceiving@Router

		mov EDI, szFileName
		mov ESI, [ServerConfig.lpTempFolder]
		xor EAX, EAX
		push EAX
		push FILE_ATTRIBUTE_NORMAL
		push CREATE_ALWAYS
		push EAX
		push EAX
		push GENERIC_WRITE
		push EDI

		lodsb
		mov ECX, EAX
		rep movsb

		mov AL, '\'
		stosb

		mov EDX, [ServerResurseId]
		inc EDX
		call HexToStr

		mov EAX, INS_TMP
		stosd
		mov [EDI], CL  ;   0
		call [CreateFile]
;------------------------------------------------
;       * * *  Create TempFile
;------------------------------------------------
		mov  DL, SRV_ERR_SaveFile
		cmp EAX, INVALID_HANDLE_VALUE
		je jmpInternalError@Router

			mov ESI, [lpSocketIoData] 
			mov [ESI+PORT_IO_DATA.hFile], EAX

			mov EAX, [ServerResurseId]
			inc EAX
			mov [ServerResurseId], EAX

			mov [ESI+PORT_IO_DATA.ResurseId], EAX
			mov [ESI+PORT_IO_DATA.Route], ROUTE_RECV_FILE
			jmp jmpRecvToFile@Router
;------------------------------------------------
;       * * *  RECV To File
;------------------------------------------------
jmpRequestToFile@Router:
	add [ESI+PORT_IO_DATA.CountBytes], ECX
;------------------------------------------------
;       * * *  RecvToFile
;------------------------------------------------
jmpRecvToFile@Router:
	mov EAX, [ESI+PORT_IO_DATA.TotalBytes]
	mov ECX, [ESI+PORT_IO_DATA.CountBytes]
	cmp ECX, [ServerConfig.MaxRecvBufferSize]
	ja jmpWriteFile@Router

		cmp ECX, EAX
		jb jmpReceiving@Router
;------------------------------------------------
;       * * *  Write File
;------------------------------------------------
jmpWriteFile@Router:
	xor EAX, EAX
	mov [ESI+PORT_IO_DATA.CountBytes], EAX
	push EAX
	push TotalBytes
	push ECX
	lea EAX, [ESI+PORT_IO_DATA.Buffer]
	mov [ESI+PORT_IO_DATA.WSABuffer.buf], EAX
	push EAX
	push [ESI+PORT_IO_DATA.hFile]
	call [WriteFile]

	mov DL, SRV_ERR_WriteFile
	or EAX, EAX
	jz jmpCloseSocket@Router

		mov ESI, [lpSocketIoData] 
		mov EAX, [ESI+PORT_IO_DATA.TotalBytes]
		sub EAX, [TotalBytes]
		jc jmpSaveSize@Router
;------------------------------------------------
;       * * *  Close File
;------------------------------------------------
			mov [ESI+PORT_IO_DATA.TotalBytes], EAX
			or EAX, EAX
			jnz jmpReceiving@Router

jmpRecvClose@Router:
				push [ESI+PORT_IO_DATA.hFile]
				call [CloseHandle]

				mov DL, SRV_ERR_SaveClose
				or EAX, EAX
				jz jmpCloseSocket@Router

					mov ESI, [lpSocketIoData]
					xor EAX, EAX
					mov [ESI+PORT_IO_DATA.hFile], EAX

					mov DL, SRV_MSG_Save
					jmp jmpSendFileResurse@Router

jmpSaveSize@Router:
		mov  DL, SRV_ERR_SaveSize
		call PostReport
		jmp jmpRecvClose@Router
;------------------------------------------------
;       * * *  RECV To Buffer
;------------------------------------------------
jmpRequestToBuffer@Router:
	add [ESI+PORT_IO_DATA.CountBytes], ECX

	mov  DL, SRV_ERR_RecvSize
	mov EAX, [ESI+PORT_IO_DATA.TotalBytes]
	mov ECX, [ESI+PORT_IO_DATA.CountBytes]
	cmp ECX, EAX
	je jmpSendFromResurse@Router
	ja jmpSendFileResurse@Router
;------------------------------------------------
;       * * *  Receiving
;------------------------------------------------
jmpReceiving@Router:
	mov ESI, [lpSocketIoData] 
	mov ECX, [ServerConfig.MaxRecvSize]
	cmp EAX, ECX
	jb jmpSizeRecv@Router
		mov EAX, ECX

jmpSizeRecv@Router:
	mov [ESI+PORT_IO_DATA.WSABuffer.len], EAX
	xor EAX, EAX
	push EAX
	push ESI
	push TransFlag
	push TransBytes
	inc EAX
	push EAX
	lea EAX, [ESI+PORT_IO_DATA.WSABuffer]
	push EAX
	push [ESI+PORT_IO_DATA.Socket]
	call [WSARecv] 

	or EAX, EAX
	jz jmpWaitCompletionPort@Router

		call [WSAGetLastError]
		cmp EAX, ERROR_IO_PENDING
		je jmpWaitCompletionPort@Router
			mov DL, SRV_ERR_RecvRouter
;------------------------------------------------
;       * * *  Close SocketPort
;------------------------------------------------
jmpCloseSocket@Router:
	call PostReport

	mov ESI, [lpSocketIoData]
	mov EDI, [ESI+PORT_IO_DATA.TablePort]
	xor EAX, EAX
	mov [EDI], EAX

	mov  EAX, [ESI+PORT_IO_DATA.Socket]
	push EAX
	push SD_BOTH
	push EAX
	call [shutdown]

	or EAX, EAX
	jz jmpClose@Router

		mov  DL, SRV_ERR_ShutDown
		call PostReport

jmpClose@Router:
	call [closesocket]
	or EAX, EAX
	jz jmpCloseFile@Router

		mov DL, SRV_ERR_SocketClose
		call PostReport
;------------------------------------------------
;       * * *  Close ReadFile / WriteFile
;------------------------------------------------
jmpCloseFile@Router:
	mov ESI, [lpSocketIoData]
	mov ECX, [ESI+PORT_IO_DATA.hFile]
	jECXz jmpSocketFree@Router

		push ECX
		call [CloseHandle]

jmpSocketFree@Router:
	mov DL, SRV_MSG_Close
	call PostReport

	push MEM_RELEASE
	xor EAX, EAX
	push EAX
	push [lpSocketIoData]
	call [VirtualFree]
	jmp jmpWaitCompletionPort@Router
;------------------------------------------------
;       * * *  End Thread  * * *
;------------------------------------------------
jmpEnd@Router:
	xor EAX, EAX
	mov [ThreadSocketCtrl], EAX
	push EAX
	call [ExitThread]
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------