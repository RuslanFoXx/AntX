;------------------------------------------------
;	AntX Web Server
;	RESURSE: Structures + DataType
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
;       * * *  DataType
;------------------------------------------------
BYTE					equ db
WORD					equ dw
DWORD					equ dd
QWORD					equ qd
PCHAR					equ dd

LPVOID					equ dd
HANDLE					equ dd
SOCKET					equ dd
LPHANDLE				equ dd
WSAEVENT				equ dd
SERVICE_STATUS_HANDLE	equ dd

STARTUPINFO_SIZE		equ 72
STARTUPINFO_COUNT		equ 18
PROCESS_INFORMATION_COUNT	equ  4
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
	nLength				dd ?
	lpSecurityDescriptor	dd ?
	bInheritHandle		dd ?
ends

LPSECURITY_ATTRIBUTES	equ LPVOID
SECURITY_ATTRIBUTES_SIZE	equ 12
;------------------------------------------------
;       * * *  WSABUF  * * *
;------------------------------------------------
struct WSABUF
	len					dd ?
	buf					dd ?
ends

LPWSABUF				equ LPVOID
WSABUF_SIZE				equ 8
;------------------------------------------------
;       * * *  WSAOVERLAPPED  * * *
;------------------------------------------------
struct WSAOVERLAPPED
	Internal			dd ?
	InternalHigh		dd ?
	OffsetLow			dd ?
	OffsetHigh			dd ?
	hEvent				dd ?
ends

LPWSAOVERLAPPED			equ LPVOID
WSAOVERLAPPED_SIZE		equ 20
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
	Http_200_Ok			dd ?
	Http_201_Create		dd ?
	Http_400_BadRequest	dd ?
	Http_403_Forbidden	dd ?
	Http_404_NotFound	dd ?
;	Http_405_Allowed	dd ?
	Http_500_Internal	dd ?
	Http_501_NotImplement	dd ?
	Http_503_Busy		dd ?
ends

LPRESPONT_HEADER		equ LPVOID
RESPONT_HEADER_SIZE		equ 32
RESPONT_HEADER_COUNT	equ  8
;------------------------------------------------
;       * * *  SERVER_CONFIG  * * *
;------------------------------------------------
struct SERVER_CONFIG
	MaxRecvBufferSize	dd ?
	MaxRecvFileSize		dd ?
	MaxReportStack		dd ?
	MaxConnections		dd ?
	MaxRunning			dd ?
	MaxTimeOut			dd ?
	MaxBufferSize		dd ?
	MaxHeadSize			dd ?
	MaxRecvSize			dd ?
	MaxSendSize			dd ?
	MaxPipeSize			dd ?

	lpTempFolder		dd ?
	lpReportPath		dd ?
ends

LPSERVER_CONFIG			equ LPVOID
SERVER_CONFIG_SIZE		equ 52
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
	ExtRunProc			dd ?
	TimeLimit			dd ?
	TablePort			dd ?
	NetHost				dd ?
	Socket				dd ?
	Address				db 16 dup (?)
	ResurseId			dd ?
	TransferredBytes	dd ?
	ExitCode			dd ?
	Connection			dw ?
	Route				dw ?
	hProcess			dd ?
	hFile				dd ?
	TotalBytes			dd ?
	CountBytes			dd ?
	UrlSize				dw ?
	Path				db MAX_URL_SIZE+2 dup (?)
	Buffer				dd ?
ends

LPPORT_IO_DATA			equ LPVOID
PORT_DATA_SIZE			equ 1128
PORT_CLEAR_COUNT		equ 10
;------------------------------------------------
;       * * *  REPORT_HEADER  * * *
;------------------------------------------------
struct REPORT_HEADER
	Index				dd ?
	Error				dd ?
ends

LPREPORT_HEADER			equ LPVOID
REPORT_HEADER_SIZE		equ  8
REPORT_HEADER_COUNT		equ  2
;------------------------------------------------
;       * * *  REPORT_INFO  * * *
;------------------------------------------------
struct REPORT_INFO
	Index				dd ?
	Error				dd ?
	NetHost				dd ?
	Socket				dd ?
	Address				db 16 dup (?)
	ResurseId			dd ?
	TransferredBytes	dd ?
	ExitCode			dd ?
	UrlSize				dw ?,?
ends

LPREPORT_INFO			equ LPVOID
REPORT_INFO_SIZE		equ 48
REPORT_INFO_COUNT		equ 12
REPORT_INFO_PORT		equ  9
REPORT_INFO_PATH_SIZE	equ REPORT_INFO_SIZE+MAX_URL_SIZE
;------------------------------------------------
;       * * *  ACCEPT_HEADER  * * *
;------------------------------------------------
struct ACCEPT_HEADER
	TimeLimit			dd ?
	TablePort			dd ?
	NetHost				dd ?
	Socket				dd ?
	Address				db 16 dup (?)
ends

LPACCEPT_HEADER			equ LPVOID
ACCEPT_HEADER_SIZE		equ 32
ACCEPT_HEADER_COUNT		equ  8
ACCEPT_HEADER_REPORT	equ  8
ACCEPT_HEADER_CLEAR		equ  3
;------------------------------------------------
;       * * *   END  * * *
;------------------------------------------------
