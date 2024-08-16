;------------------------------------------------
;	AntX Web Server
;	RESURSE: Structures + DataType
;	ver.1.75 (x64)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  Macros Param of Call
;------------------------------------------------
macro param n, expr
{
	if n in <0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16>
	if n eq 0
		if expr eq 0
			xor RAX, RAX
		else
			mov RAX, expr
		end if
	else if n eq 1
		if expr eq 0
			xor RCX, RCX
		else
			mov RCX, expr
		end if
	else if n eq 2
		if expr eq 0
			xor RDX, RDX
		else
			mov RDX, expr
		end if
	else if n eq 3
		if expr eq 0
			xor R8, R8
		else
			mov R8, expr
		end if
	else if n eq 4
		if expr eq 0
			xor R9, R9
		else
			mov R9, expr
		end if
	else
		mov qword [RSP+(n*8-8)], expr
	end if
	else
		display "parameter " #`n# " is not valid."
		param n, expr
  end if
}
;------------------------------------------------
;       * * *  DataType
;------------------------------------------------
BYTE					equ db
WORD					equ dw
DWORD					equ dd
QWORD					equ dq
PCHAR					equ dq

LPVOID					equ dq
HANDLE					equ dq
SOCKET					equ dq
LPHANDLE				equ dq
WSAEVENT				equ dq
SERVICE_STATUS_HANDLE	equ dq

STARTUPINFO_SIZE		equ 104
STARTUPINFO_COUNT		equ 13
PROCESS_INFORMATION_COUNT	equ  3
SOCKADDR_IN_SIZE		equ 16
MAXIMUM_WAIT_OBJECTS	equ 64
MAX_URL_SIZE			equ 1024
;------------------------------------------------
;       * * *  SERVICE_STATUS  * * *
;------------------------------------------------
struct SERVICE_STATUS
	dwServiceType		dd ?
	dwCurrentState		dd ?
	dwControlsAccepted	dd ?
	dwWin32ExitCode		dd ?
	dwServiceSpecificExitCode	dd ?
	dwCheckPoint		dd ?
	dwWaitHint			dd ?
ends

LPSERVICE_STATUS		equ LPVOID
SERVICE_STATUS_SIZE		equ 28
SERVICE_STATUS_COUNT	equ  7
;------------------------------------------------
;       * * *  SECURITY_ATTRIBUTES  * * *
;------------------------------------------------
struct SECURITY_ATTRIBUTES
	nLength				dq ?
	lpSecurityDescriptor	dq ?
	bInheritHandle		dq ?
ends

LPSECURITY_ATTRIBUTES	equ LPVOID
SECURITY_ATTRIBUTES_SIZE	equ 24
;------------------------------------------------
;       * * *  WSABUF  * * *
;------------------------------------------------
struct WSABUF
	len					dq ?
	buf					dq ?
ends

LPWSABUF				equ LPVOID
WSABUF_SIZE				equ 16
;------------------------------------------------
;       * * *  WSAOVERLAPPED  * * *
;------------------------------------------------
struct WSAOVERLAPPED
	Internal			dq ?
	InternalHigh		dq ?
	OffsetLow			dq ?
	OffsetHigh			dq ?
	hEvent				dq ?
ends

LPWSAOVERLAPPED			equ LPVOID
WSAOVERLAPPED_SIZE		equ 40
;------------------------------------------------
;       * * *  WSANETWORKEVENTS  * * *
;------------------------------------------------
struct WSANETWORKEVENTS
	lNetworkEvents		dd ?
	iErrorCode			dd 10 dup(?)
ends

LPWSANETWORKEVENTS		equ LPVOID
WSANETWORKEVENTS_SIZE	equ 44
;------------------------------------------------
;       * * *  RESPONT_HEADER  * * *
;------------------------------------------------
struct RESPONT_HEADER
	Http_200_Ok			dq ?
	Http_201_Create		dq ?
	Http_400_BadRequest	dq ?
	Http_403_Forbidden	dq ?
	Http_404_NotFound	dq ?
;	Http_405_Allowed	dq ?
	Http_500_Internal	dq ?
	Http_501_NotImplement	dq ?
	Http_503_Busy		dq ?
ends

LPRESPONT_HEADER		equ LPVOID
RESPONT_HEADER_SIZE		equ 64
RESPONT_HEADER_COUNT	equ  8
;------------------------------------------------
;       * * *  SERVER_CONFIG  * * *
;------------------------------------------------
struct SERVER_CONFIG
	MaxRecvBufferSize	dq ?
	MaxRecvFileSize		dq ?
	MaxReportStack		dq ?
	MaxConnections		dq ?
	MaxRunning			dq ?
	MaxTimeOut			dq ?
	MaxBufferSize		dq ?
	MaxHeadSize			dq ?
	MaxRecvSize			dq ?
	MaxSendSize			dq ?
	MaxPipeSize			dq ?

	lpTempFolder		dq ?
	lpReportPath		dq ?
ends

LPSERVER_CONFIG			equ LPVOID
SERVER_CONFIG_SIZE		equ 104
SERVER_CONFIG_COUNT		equ 13
SERVER_CONFIG_PARAM		equ 12
SERVER_CONFIG_DWORD		equ 10
;------------------------------------------------
;       * * *  ASK_EXT  * * *
;------------------------------------------------
struct ASK_EXT
	AskExt				dd ?
	Type				dd ?
	Disposition			dd ?
	Directory			dd ?
	RunPath				dd ?
	CmdLine				dd ?
	Run					dd ?
ends

LPASK_EXT				equ LPVOID
ASK_EXT_SIZE			equ 28
ASK_EXT_COUNT			equ  7
ASK_EXT_PARAM			equ  6
;------------------------------------------------
;       * * *  NET_HOST  * * *
;------------------------------------------------
struct NET_HOST
	Name				dd ?
	Address				dd ?
	SiteFolder			dd ?
	CodeFolder			dd ?
	IndexPage			dd ?
	Socket				dd ?
	Event				dd ?
	Reserved			dd ?
ends

LPNET_HOST				equ LPVOID
NET_HOST_SIZE			equ 32
NET_HOST_COUNT			equ  8
NET_HOST_PARAM			equ  5
;------------------------------------------------
;       * * *  PORT_IO_DATA  * * *
;------------------------------------------------
struct PORT_IO_DATA
	Overlapped			WSAOVERLAPPED ?
	WSABuffer			WSABUF ?
	ExtRunProc			dq ?
	TimeLimit			dq ?
	TablePort			dq ?
	NetHost				dq ?
	Socket				dq ?
	Address				db 16 dup (?)
	ResurseId			dq ?
	TransferredBytes	dq ?
	ExitCode			dd ?
	Connection			dw ?
	Route				dw ?
	hProcess			dq ?
	hFile				dq ?
	TotalBytes			dq ?
	CountBytes			dq ?
	UrlSize				dw ?
	Path				db MAX_URL_SIZE+6 dup (?)
	Buffer				dq ?
ends

LPPORT_IO_DATA			equ LPVOID
PORT_DATA_SIZE			equ 1208
PORT_CLEAR_COUNT		equ  8
;------------------------------------------------
;       * * *  REPORT_HEADER  * * *
;------------------------------------------------
struct REPORT_HEADER
	Index				dd ?
	Error				dd ?
ends

LPREPORT_HEADER			equ LPVOID
REPORT_HEADER_SIZE		equ  8
REPORT_HEADER_COUNT		equ  1
;------------------------------------------------
;       * * *  REPORT_INFO  * * *
;------------------------------------------------
struct REPORT_INFO
	Index				dd ?
	Error				dd ?
	NetHost				dq ?
	Socket				dq ?
	Address				db 16 dup (?)
	ResurseId			dq ?
	TransferredBytes	dq ?
	ExitCode			dd ?
	UrlSize				dw ?,?
ends

LPREPORT_INFO			equ LPVOID
REPORT_INFO_SIZE		equ 64
REPORT_INFO_COUNT		equ  8
REPORT_INFO_PORT		equ  6
REPORT_INFO_PATH_SIZE	equ REPORT_INFO_SIZE+MAX_URL_SIZE
;------------------------------------------------
;       * * *  ACCEPT_HEADER  * * *
;------------------------------------------------
struct ACCEPT_HEADER
	TimeLimit			dq ?
	Index				dd ?
	Error				dd ?
	NetHost				dq ?
	Socket				dq ?
	Address				db 16 dup (?)
ends

LPACCEPT_HEADER			equ LPVOID
ACCEPT_HEADER_SIZE		equ 48
ACCEPT_HEADER_COUNT		equ  6
ACCEPT_HEADER_REPORT	equ  5
ACCEPT_HEADER_CLEAR		equ  3
;------------------------------------------------
;       * * *   END  * * *
;------------------------------------------------
