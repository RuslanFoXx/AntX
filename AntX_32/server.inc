;------------------------------------------------
;	AntX Web Server
;	MAIN: Define Constant
;	ver.1.75 (x32)
;	(c) Kyiv, Ruslan FoXx
;	01 July 2024
;------------------------------------------------
include 'win32a.inc'

include 'include\type.inc'
include 'include\const.inc'
include 'include\report.inc'
;------------------------------------------------
;       * * *  Limit Constants
;------------------------------------------------
STACK_FRAME_CLEAR         equ ( TabRunProcess - ThreadServerCtrl ) / 4 + 1
DELTA_ZERO_YEAR           equ  2000
MAX_INT_SCALE             equ  256

FILE_APPEND_DATA          equ 4

SET_WSA_VER               equ 0202h
INTERNET_PORT             equ 20480
ERROR_NETNAME_DELETED     equ 64
ERROR_IO_PENDING          equ 997
INVALID_SOCKET            equ -1

FD_ACCEPT_ERROR           equ 12
SOL_SOCKET                equ 0FFFFh
SO_REUSEADDR              equ  4
SD_BOTH                   equ  2
IPPROTO_TCP               equ  6

SERVICE_WIN32_OWN_PROCESS equ 010h
SERVICE_CONTROL_STOP      equ 001h
SERVICE_CONTROL_SHUTDOWN  equ 005h

SERVICE_ACCEPT_STOP       equ 001h
SERVICE_ACCEPT_SHUTDOWN   equ 004h

SERVICE_START_PENDING     equ 002h
SERVICE_STOP_PENDING      equ 003h
SERVICE_RUNNING           equ 004h
;------------------------------------------------
;       * * *  Status To Send/Revc  * * *
;              Send/Recv | File/Buffer | Conn/Close
;------------------------------------------------
SET_TRANS_BIT             equ  1   ;  0001
SET_SEND_BIT              equ  2   ;  0010
SET_FILE_BIT              equ  4   ;  0100
SET_PROC_BIT              equ  8   ;  1000

ROUTE_RECV_CONNECT        equ  0   ;  0000
ROUTE_RECV_BUFFER         equ  1   ;  0001
ROUTE_RECV_FILE           equ  5   ;  0101
ROUTE_RECV_END            equ  2   ;  0010

ROUTE_SEND_BUFFER         equ  3   ;  0011
ROUTE_SEND_FILE           equ  7   ;  0111

ROUTE_PROC_RECV           equ  8   ;  1000
ROUTE_PROC_SEND           equ  9   ;  1010
ROUTE_CLOSE               equ  0
;------------------------------------------------
;       * * *  Socket Constants
;------------------------------------------------
MAX_NET_HOST              equ  MAXIMUM_WAIT_OBJECTS
MAX_NET_PROC              equ (MAXIMUM_WAIT_OBJECTS-1)
MAX_RUN_PROC              equ 255

MAX_PROCESS               equ 4096
MAX_SOCKET                equ 65535

MAX_PROCESS               equ 4096
MAX_SOCKET                equ 65535
MAX_REPORT                equ 16384

MAX_NET_TIMEOUT           equ 3600
WAIT_SERVICE_HINT         equ 5000
WAIT_LIST_TIMEOUT         equ 2000
WAIT_PORT_TIMEOUT         equ 2000
WAIT_POST_TIMEOUT         equ 2000
WAIT_PROC_TIMEOUT         equ 2000
WORK_PROC_TIMEOUT         equ  500
WORK_EXIT_TIMEOUT         equ 1000
;------------------------------------------------
;       * * *  Limit Constants
;------------------------------------------------
MAX_CONFIG_COUNT          equ  1024
MAX_PARAM_LENGTH          equ   255

DATA_BUFFER_OFFSET        equ   256
CONFIG_BUFFER_SIZE        equ 16384
REPORT_BUFFER_SIZE        equ  2048

MAX_PATH_SIZE             equ  1024
MAX_URL_SIZE              equ  2048
NET_MAX_FILE              equ 0FFFFFFFFh
LOG_MAX_FILE              equ 1000000

HTTP_HEADER_SIZE          equ  4096
NET_MIN_FRAME             equ   256
NET_MAX_FRAME             equ 16384
;------------------------------------------------
;       * * *   END  * * *
;------------------------------------------------
