;------------------------------------------------
;	AntX Web Server
;	THREAD: Router
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
proc ThreadRouter   ;   RCX = ThrControl

local Method DWORD ?
;------------------------------------------------
	mov RDI, [TabSocketIoData]
	mov RCX, [ServerConfig.MaxConnections]
	xor RAX, RAX
	rep stosq
	inc RAX
	mov [ThreadSocketCtrl], EAX
	mov AL,  64
	sub RSP, RAX
;------------------------------------------------
;       * * *  Wait Completion
;------------------------------------------------
jmpWaitCompletionPort@Router:

	param 5, WAIT_PORT_TIMEOUT
	param 4, lpSocketIoData
	param 3, lpPortIoCompletion
	param 2, TransferredBytes
	param 1, [hPortIOSocket]
	call [GetQueuedCompletionStatus]

	mov ECX, [ThreadServerCtrl]
	or  ECX, ECX 
	jz jmpEnd@Router
;------------------------------------------------
;       * * *  ReportError
;------------------------------------------------
	or  EAX, EAX
	jnz jmpSetSocket@Router
		mov [TransferredBytes], RAX

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
	mov RSI, [lpSocketIoData]
	or  RSI, RSI
	jz jmpWaitCompletionPort@Router

	mov RDX, [lpPortIoCompletion]
	or  EDX, EDX
	jnz jmpInternalError@Router

	mov  DL, SRV_MSG_Disconnected
	mov RCX, [TransferredBytes]
	or  ECX, ECX
	jz jmpCloseSocket@Router
;------------------------------------------------
;       * * *  ServerRouter
;------------------------------------------------
	add [RSI+PORT_IO_DATA.TransferredBytes], RCX
	add [RSI+PORT_IO_DATA.WSABuffer.buf], RCX

	mov AX, [RSI+PORT_IO_DATA.Route]
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
;       * * *  ASK
;------------------------------------------------
	mov [RSI+PORT_IO_DATA.CountBytes], RCX
 	mov R15, RSI
 	mov R14, RCX
	xor R13, R13
	sub  CX, 4

	lea RSI,[RSI+PORT_IO_DATA.Buffer]
	lodsd
	and EAX, KEY_CASE_UP
	cmp EAX, 'GET'
	je jmpMethod@Router

		inc R13d
		inc RSI
		dec ECX

		mov  BL, HTTP_501_NOT_IMPLEMENT
		mov  DL, SRV_ERR_Method
		cmp EAX, 'POST'
		jne jmpSelected@Router

jmpMethod@Router:
	call HTTPRequest
	or EDX, EDX
	jnz jmpSelected@Router
;------------------------------------------------
;       * * *  SELECT0 METHOD GET/POST
;------------------------------------------------
;jmpSelectMethod@Router:
	mov RSI, R15
	or  R13, R13
	jnz jmpRecvMethod@Router
;------------------------------------------------
;       * * *  GET CGI-PROCESSOR
;------------------------------------------------
jmpSelectMode@Router:
	mov RDI, [RSI+PORT_IO_DATA.ExtRunProc]
	mov EAX, [RDI+ASK_EXT.Run]
	or  EAX, EAX
	jz jmpOpenFile@Router

jmpRunProcess@Router:
		mov RDI, [SetQueuedProcess]
		lea RAX, [RDI+8]
		cmp RAX, [MaxQueuedProcess]
		jb jmpSetProcess@Router
			mov RAX, [TabQueuedProcess]

jmpSetProcess@Router:
		mov BL, HTTP_503_BUSY
		mov DL, SRV_MSG_ProcessLimit
		cmp RAX, [GetQueuedProcess]
		je jmpSelected@Router

			mov [SetQueuedProcess], RAX
			mov [RDI], RSI

			mov RAX, [CountProcess]
			cmp  AL, MAXIMUM_WAIT_OBJECTS
			jae jmpWaitCompletionPort@Router

				param 1, [RunProcessEvent]
				call [SetEvent]
				jmp jmpWaitCompletionPort@Router
;------------------------------------------------
;       * * *  OpenSendFile
;------------------------------------------------
jmpOpenFile@Router:
	xor RAX, RAX
	mov [RSI+PORT_IO_DATA.ResurseId], RAX
	param 7, RAX  ;  0
	param 6, FILE_ATTRIBUTE_READONLY
	param 5, OPEN_EXISTING
	param 4, RAX  ;  0
	param 3, FILE_SHARE_READ 
	param 2, GENERIC_READ 
;   param 1, FileName
	lea RCX, [RSI+PORT_IO_DATA.Path]
	call [CreateFile]

	mov  DL, SRV_ERR_OpenFile
	cmp RAX, INVALID_HANDLE_VALUE
	je jmpNotFound@Router

		param 1, RAX
		mov [hFile], RAX
		call [GetFileType]

		mov RCX, [hFile]
		xor EBX, EBX
		cmp EAX, FILE_TYPE_DISK
		je jmpHeaderMethod1@Router
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
	mov RSI, [lpSocketIoData]
	mov EBX, [Method]
	mov RDI, szFileName
	call GetStatusFile

	mov RSI, [lpSocketIoData]
	mov EBX, [Method]

	or  RCX, RCX
	jnz jmpHeaderMethod1@Router
		mov [RSI+PORT_IO_DATA.ExitCode], EBX

		cmp ECX, [ErrRunProcess.Run]
		jne jmpRunProcess@Router
;------------------------------------------------
;       * * *  Create Headers
;------------------------------------------------
jmpHeaderMethod1@Router:
	mov RSI, [lpSocketIoData]
	mov [RSI+PORT_IO_DATA.hFile], RCX
	call CreateHttpHeader

	mov [RSI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER

	mov RCX, [RSI+PORT_IO_DATA.TotalBytes]
	jRCXz jmpSendFromBuffer@Router

	mov [RSI+PORT_IO_DATA.Route], ROUTE_SEND_FILE
	jmp jmpSendFromFile@Router
;------------------------------------------------
;       * * *  Send From Buffer
;------------------------------------------------
jmpRespondFromBuffer@Router:
	mov RSI, [lpSocketIoData] 
	sub [RSI+PORT_IO_DATA.CountBytes], RCX
;------------------------------------------------
;       * * *  SendToBuffer
;------------------------------------------------
jmpSendFromBuffer@Router:
	mov RCX, [RSI+PORT_IO_DATA.CountBytes]
	mov  DL, SRV_MSG_Send
	xor RAX, RAX
	cmp RCX, RAX 
	jg jmpSending@Router
;------------------------------------------------
;       * * *  Post To Buffer
;------------------------------------------------
		cmp AX, [RSI+PORT_IO_DATA.Connection]
		je jmpCloseSocket@Router

			call PostReport

			mov RSI, [lpSocketIoData] 
			lea RDI, [RSI+PORT_IO_DATA.ResurseId]
			mov RCX, PORT_CLEAR_COUNT
			xor RAX, RAX
			rep stosq

			lea RDX, [RSI+PORT_IO_DATA.Buffer]
			mov [RSI+PORT_IO_DATA.WSABuffer.buf], RDX

			mov AX, HTTP_HEADER_SIZE
			jmp jmpReceiving@Router
;------------------------------------------------
;       * * *  Send From File
;------------------------------------------------
jmpRespondFromFile@Router:
	mov RSI, [lpSocketIoData]
	sub [RSI+PORT_IO_DATA.CountBytes], RCX
;------------------------------------------------
;       * * *  SendToFile
;------------------------------------------------
jmpSendFromFile@Router:
	mov RCX, [RSI+PORT_IO_DATA.CountBytes]
	cmp RCX, [ServerConfig.MaxSendSize] 
	jg jmpSending@Router

		mov [CountBytes], RCX
		mov R10, [ServerConfig.MaxBufferSize]
		sub R10, RCX

		mov RBX, [RSI+PORT_IO_DATA.WSABuffer.buf]
		lea RDX, [RSI+PORT_IO_DATA.Buffer]
		mov [RSI+PORT_IO_DATA.WSABuffer.buf], RDX

		xchg RSI, RBX
		mov  RDI, RDX
		add  RDX, RCX
		rep movsb

		mov R8, [RBX+PORT_IO_DATA.TotalBytes]
		cmp R8, R10
		jb jmpReadSend@Router
			mov R8, R10
;------------------------------------------------
;       * * *  Read SendFile
;------------------------------------------------
jmpReadSend@Router:
		param 5, RCX
		param 4, TotalBytes
		param 1, [RBX+PORT_IO_DATA.hFile]
		call [ReadFile]

		mov DL, SRV_ERR_ReadFile
		or EAX, EAX
		jz jmpCloseSocket@Router
;------------------------------------------------
;       * * *  SendBuffer
;------------------------------------------------
			mov RSI, [lpSocketIoData] 
			mov RBX, [RSI+PORT_IO_DATA.TotalBytes]
			mov RCX, [CountBytes]
			mov RAX, [TotalBytes]
			add RCX, RAX
			sub RBX, RAX
			mov [CountBytes], RCX
			mov [RSI+PORT_IO_DATA.CountBytes], RCX
			mov [RSI+PORT_IO_DATA.TotalBytes], RBX
			or  RBX, RBX
			jnz jmpMaxSendSize@Router
;------------------------------------------------
;       * * *  Close File
;------------------------------------------------
jmpCloseSocketSend@Router:
				mov RCX, [RSI+PORT_IO_DATA.hFile]
				xor RAX, RAX
				mov [RSI+PORT_IO_DATA.hFile], RAX
				call [CloseHandle]

				mov DL, SRV_ERR_ReadClose
				or EAX, EAX
				jz jmpCloseSocket@Router

					mov RSI, [lpSocketIoData] 
					xor RAX, RAX
					mov [RSI+PORT_IO_DATA.hFile], RAX
					mov [RSI+PORT_IO_DATA.Route], ROUTE_SEND_BUFFER

jmpMaxSendSize@Router:
			mov RCX, [CountBytes]
;------------------------------------------------
;       * * *  Sending
;------------------------------------------------
jmpSending@Router:
	mov RAX, [ServerConfig.MaxSendSize]
	cmp RCX, RAX
	jb jmpSizeSend@Router
		mov RCX, RAX

jmpSizeSend@Router:
	mov [RSI+PORT_IO_DATA.WSABuffer.len], RCX
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
	

	mov RAX, [RSI+PORT_IO_DATA.TotalBytes]
	or  RAX, RAX
	jz jmpSelected@Router

		cmp RAX, [ServerConfig.MaxRecvFileSize]
		ja jmpSelected@Router
;------------------------------------------------
;       * * *  RECV Resurse
;------------------------------------------------
	mov  DL, SRV_ERR_RecvSize
	mov RCX, [RSI+PORT_IO_DATA.CountBytes]
	cmp RAX, RCX
	ja jmpRecvToResurse@Router
	jb jmpSendFileResurse@Router
;------------------------------------------------
;       * * *  SEND Resurse
;------------------------------------------------
jmpSendFromResurse@Router:
	mov DL, SRV_MSG_Recv

jmpSendFileResurse@Router:
	call PostReport

	mov RSI, [lpSocketIoData]
	jmp jmpSelectMode@Router
;------------------------------------------------
;       * * *  Set FileResurse
;------------------------------------------------
jmpRecvToResurse@Router:
	mov [RSI+PORT_IO_DATA.Route], ROUTE_RECV_BUFFER

	cmp RAX, [ServerConfig.MaxBufferSize]
	jbe jmpReceiving@Router

		mov RSI, [ServerConfig.lpTempFolder]
		mov R14, szFileName
		xor RAX, RAX
		lodsb
		mov RCX, RAX
		mov RDI, R14
		rep movsb

		mov AL, '\'
		stosb

		mov RDX, [ServerResurseId]
		inc RDX
		call HexToStr

		mov EAX, INS_TMP
		stosd
		mov [RDI], CL
;------------------------------------------------
;       * * *  Create TempFile
;------------------------------------------------
		param 7, RCX
		param 6, FILE_ATTRIBUTE_NORMAL
		param 5, CREATE_ALWAYS
		param 4, RCX
		param 3, RCX
		param 2, GENERIC_WRITE 
		param 1, R14
		call [CreateFile]

		mov  DL, SRV_ERR_SaveFile
		cmp RAX, INVALID_HANDLE_VALUE
		je jmpInternalError@Router

			mov RSI, [lpSocketIoData] 
			mov [RSI+PORT_IO_DATA.hFile], RAX

			mov RAX, [ServerResurseId]
			inc RAX
			mov [ServerResurseId], RAX

			mov [RSI+PORT_IO_DATA.ResurseId], RAX
			mov [RSI+PORT_IO_DATA.Route], ROUTE_RECV_FILE
			jmp jmpRecvToFile@Router
;------------------------------------------------
;       * * *  RECV To File
;------------------------------------------------
jmpRequestToFile@Router:
	add [RSI+PORT_IO_DATA.CountBytes], RCX
;------------------------------------------------
;       * * *  RecvToFile
;------------------------------------------------
jmpRecvToFile@Router:
	mov RAX, [RSI+PORT_IO_DATA.TotalBytes]
	mov R8,  [RSI+PORT_IO_DATA.CountBytes]
	cmp R8,  [ServerConfig.MaxRecvBufferSize]
	ja jmpWriteFile@Router

		cmp R8, RAX
		jb jmpReceiving@Router
;------------------------------------------------
;       * * *  Write File
;------------------------------------------------
jmpWriteFile@Router:
	xor RAX, RAX
	mov [RSI+PORT_IO_DATA.CountBytes], RAX
	param 5, RAX
	param 4, TotalBytes
	lea RDX, [RSI+PORT_IO_DATA.Buffer]
	param 1, [RSI+PORT_IO_DATA.hFile]
	mov [RSI+PORT_IO_DATA.WSABuffer.buf], RDX
	call [WriteFile]

	mov DL, SRV_ERR_WriteFile
	or EAX, EAX
	jz jmpCloseSocket@Router

		mov RSI, [lpSocketIoData] 
		mov RAX, [RSI+PORT_IO_DATA.TotalBytes]
		sub RAX, [TotalBytes]
		js jmpSaveSize@Router
;------------------------------------------------
;       * * *  Close File
;------------------------------------------------
			mov [RSI+PORT_IO_DATA.TotalBytes], RAX
			or  RAX, RAX
			jnz jmpReceiving@Router

jmpRecvClose@Router:
				param 1, [RSI+PORT_IO_DATA.hFile]
				call [CloseHandle]

				mov DL, SRV_ERR_SaveClose
				or EAX, EAX
				jz jmpCloseSocket@Router

					mov RSI, [lpSocketIoData]
					xor RAX, RAX
					mov [RSI+PORT_IO_DATA.hFile], RAX

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
	add [RSI+PORT_IO_DATA.CountBytes], RCX

	mov  DL, SRV_ERR_RecvSize
	mov RAX, [RSI+PORT_IO_DATA.TotalBytes]
	mov RCX, [RSI+PORT_IO_DATA.CountBytes]
	cmp RCX, RAX
	je jmpSendFromResurse@Router
	ja jmpSendFileResurse@Router
;------------------------------------------------
;       * * *  Receiving
;------------------------------------------------
jmpReceiving@Router:
	mov RSI, [lpSocketIoData] 
	;mov RAX, [RSI+PORT_IO_DATA.TotalBytes]
	mov RCX, [ServerConfig.MaxRecvSize]
	cmp RAX, RCX
	jb jmpSizeRecv@Router
		mov RAX, RCX

jmpSizeRecv@Router:
	mov [RSI+PORT_IO_DATA.WSABuffer.len], RAX
	param 3, 0
	param 7, R8
	param 6, RSI
	param 5, TransFlag
	param 4, TransBytes
	inc R8
	lea RDX, [RSI+PORT_IO_DATA.WSABuffer]
	param 1, [RSI+PORT_IO_DATA.Socket]
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

	mov RSI, [lpSocketIoData]
	mov RDI, [RSI+PORT_IO_DATA.TablePort]
	xor RAX, RAX
	mov [RDI], RAX

	mov  AL, SD_BOTH
	param 2, RAX
	param 1, [RSI+PORT_IO_DATA.Socket]
	mov [hFile], RCX
	call [shutdown]

	or EAX, EAX
	jz jmpSocket@Router

		mov  DL, SRV_ERR_ShutDown
		call PostReport

jmpSocket@Router:
	param 1, [hFile]
	call [closesocket]

	or EAX, EAX
	jz jmpCloseFile@Router

		mov  DL, SRV_ERR_SocketClose
		call PostReport
;------------------------------------------------
;       * * *  Close ReadFile / WriteFile
;------------------------------------------------
jmpCloseFile@Router:
	mov RSI, [lpSocketIoData]
	mov RCX, [RSI+PORT_IO_DATA.hFile]
	jRCXz jmpSocketFree@Router

		call [CloseHandle]

jmpSocketFree@Router:
	mov DL, SRV_MSG_Close
	call PostReport

	param 1, [lpSocketIoData]
	param 2, 0
	param 3, MEM_RELEASE
	call [VirtualFree]
	jmp jmpWaitCompletionPort@Router
;------------------------------------------------
;       * * *  End Thread  * * *
;------------------------------------------------
jmpEnd@Router:
	xor RAX, RAX
	param 1, RAX
	mov [ThreadSocketCtrl], EAX
	mov AL,  64
	add RSP, RAX
	call [ExitThread]
endp
;------------------------------------------------
;       * * *  END  * * *
;------------------------------------------------