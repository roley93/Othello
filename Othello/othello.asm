option casemap:none
INCLUDE Irvine32.inc
INCLUDE GraphWin.inc

LoadMenuA PROTO :DWORD,:DWORD
BeginPaint PROTO :DWORD,:DWORD
EndPaint PROTO :DWORD,:DWORD
Rectangle PROTO :DWORD,:DWORD,:DWORD,:DWORD,:DWORD
Ellipse PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
InvalidateRect PROTO :DWORD,:DWORD,:DWORD
CreateSolidBrush PROTO :DWORD
CreatePen PROTO :DWORD,:DWORD,:DWORD
SelectObject PROTO :DWORD, :DWORD
LineTo PROTO :DWORD,:DWORD,:DWORD
MoveToEx PROTO :DWORD, :DWORD, :DWORD, :DWORD


.const
 IDM_NEWGAME equ 1
 IDM_EXITGAME equ 2


HDC			typedef DWORD
HMENU		typedef DWORD
HPEN		typedef DWORD
HBRUSH		typedef DWORD
COLORREF	typedef DWORD
WM_PAINT equ 0Fh
WM_MOUSEMOVE equ 0200h

;==================== DATA =======================
.data

; F Means empty, 0 is black, 1 is white
gameArray BYTE -1, -1, -1, -1, -1, -1, -1, -1 ; NOTE: changed from ARRAY
	  BYTE -1, -1, -1, -1, -1, -1, -1, -1
	  BYTE -1, -1, -1, -1, -1, -1, -1, -1
	  BYTE -1, -1, -1, -1, -1, -1, -1, -1
	  BYTE -1, -1, -1, -1, -1, -1, -1, -1
	  BYTE -1, -1, -1, -1, -1, -1, -1, -1
	  BYTE -1, -1, -1, -1, -1, -1, -1, -1
	  BYTE -1, -1, -1, -1, -1, -1, -1, -1

helperArray BYTE -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ; NOTE: gameArray + helperArray has to be after each other

posX BYTE 0
posY BYTE 0
hdc DWORD 0 ; global variable of the device context

startGame BYTE 0 ; Indicates whether the game has been started or not
currentPlayer BYTE 0 ; Player Black or Player White
mouseClick BYTE 0
successfulHit BYTE 0

WindowName  BYTE "Othello by Roland Schiller 2016",0
className   BYTE "ASMWin",0
MenuName	BYTE "FirstMenu",0

BTOP   DWORD 50
BLEFT  DWORD 50


; Define the Application's Window class structure.
MainWin WNDCLASS <NULL,WinProc,NULL,NULL,NULL,NULL,NULL, \
	COLOR_WINDOW,NULL,className>

PAINTSTRUCT STRUCT
hDC DWORD ?
fErase DWORD ?
rcPaint RECT <>
fRestore DWORD ?
fIncUpdate DWORD ?
rgbReserved BYTE 32 dup(?)
PAINTSTRUCT ENDS


msg	      MSGStruct <>
winRect   RECT <>
clientArea RECT <>
hMainWnd  DWORD ?
hInstance DWORD ?






.data?
hMenu HMENU ?
mPoint POINT <>
;=================== CODE =========================
.code
WinMain PROC
; Get a handle to the current process.
	INVOKE GetModuleHandle, NULL
	mov hInstance, eax
	mov MainWin.hInstance, eax

; Load the program's icon and cursor.
	INVOKE LoadIcon, NULL, IDI_APPLICATION
	mov MainWin.hIcon, eax
	INVOKE LoadCursor, NULL, IDC_ARROW
	mov MainWin.hCursor, eax

; Register the window class.
	INVOKE RegisterClass, ADDR MainWin
	.IF eax == 0
	  call ErrorHandler
	  jmp Exit_Program
	.ENDIF
	INVOKE LoadMenuA, hInstance, offset MenuName
	mov hMenu,eax

; Create the application's main window.
; Returns a handle to the main window in EAX.
	INVOKE CreateWindowEx, 0, ADDR className,
	  ADDR WindowName,524288,
	  0,0,930,
	  950,NULL,hMenu,hInstance,NULL
	mov hMainWnd,eax
; Show and draw the window.

	INVOKE ShowWindow, hMainWnd, SW_SHOW
	INVOKE UpdateWindow, hMainWnd
	INVOKE GetWindowRect, hMainWnd,ADDR clientArea
; Begin the program's message-handling loop.

Message_Loop:
	; Get next message from the queue.
	INVOKE GetMessage, ADDR msg, NULL,NULL,NULL
	; Quit if no more messages.

	.IF eax == 0
	  jmp Exit_Program
	.ENDIF

	; Relay the message to the program's WinProc.
	INVOKE DispatchMessage, ADDR msg
    jmp Message_Loop

Exit_Program:
	  INVOKE ExitProcess,0
WinMain ENDP

drawPawn PROC uses eax ebx ecx edx, pawnPosX:BYTE, pawnPosY:BYTE, playerColor:BYTE
		LOCAL brush:HBRUSH
		LOCAL ellipseXTopLeft:DWORD
		LOCAL ellipseYTopLeft:DWORD
		LOCAL ellipseXBottomRight:DWORD
		LOCAL ellipseYBottomRight:DWORD
		mov al, playerColor
		;Color
		.IF playerColor == 0
			mov eax, 00000000h
		.ELSE
			mov eax, 00FFFFFFh
		.ENDIF

		INVOKE CreateSolidBrush, eax ; inner circle
		mov brush, eax
		INVOKE SelectObject, hdc, brush


		;Calculatute coordinates for row, upper left corner
		mov ebx, 100
		mov eax, DWORD PTR pawnPosX ; Row
		mul ebx
		add eax, BTOP
		mov ellipseXTopLeft, eax

		;Calculate coordintes for col
		xor edx, edx
		mov ebx, 100
		mov eax, DWORD PTR pawnPosY
		mul ebx
		add eax, BLEFT
		mov ellipseYTopLeft, eax

		mov eax, ellipseXTopLeft ; The lower right corner of the ellipse
		add eax, 100
		mov ellipseXBottomRight, eax


		mov ebx, ellipseYTopLeft ; Same
		add ebx, 100
		mov ellipseYBottomRight, eax



		INVOKE Ellipse,hdc,ellipseYTopLeft,ellipseXTopLeft,ebx,eax ; drawing in the rectangle

		ret
drawPawn endp

neighCheck PROC uses ebx edi  edx esi ecx  initialPositionX:BYTE, initialPositionY:BYTE, shiftingAmount:BYTE, shiftingPositionX:BYTE, shiftingPositionY:BYTE
		LOCAL successfulFlip:BYTE
		LOCAL opponent:BYTE
		LOCAL iterator:BYTE
		LOCAL temporaryPositionX:BYTE
		LOCAL temporaryPositionY:BYTE

		mov successfulFlip, 0
		mov iterator, 1

		mov al, initialPositionY ; row
		mov ah, initialPositionX ; column

		; becasue we cant into fucking memory to memory
		mov temporaryPositionX, ah
		mov temporaryPositionY, al

		.IF currentPlayer == 0
			mov opponent, 1
		.ELSE 
			mov opponent, 0
		.ENDIF

		mov edi, offset gameArray
		mov esi, offset helperArray
		xor eax, eax
		;Get gameArray index by position and point edi to clicked index
		mov al, temporaryPositionY ; row
		shl al, 3 ;multiply by 8
		add al, temporaryPositionX ; column
		add edi,  eax ; add it to memory address

		mov cl, initialPositionY 
		mov ch, initialPositionX

		mov BYTE PTR [esi], ch ; store the original positions as the zero index of helper array
		inc esi
		mov [esi], cl
		inc esi

		;The actual neighbourchedck takes place here, after this label based on what you pushed here, will start checking the neighbour
		check:
			add edi, DWORD PTR shiftingAmount ; shifts the index of the gameArray to the dedired location, eg north -8, east +1, south -8, west +1

			; Out of bounds check by checking if its outside from the first index of gameArray to the end of it
			.IF edi < offset gameArray ;start of gameArray
				jmp failedNeighbourCheck
			.ELSEIF edi > offset helperArray ; end of gameArray
				jmp failedNeighbourCheck
			.ENDIF

			;checking for the out of bounds on the sides
			xor edx, edx
			mov eax, edi
			sub eax, offset gameArray ;get the gameArray index itself subtracting the original gameArray offset from the current one
			mov ebx, 8
			div ebx ; divide by 8 to determine wether we are at a side.
			; edx will contain the remainder. if remainder is 0, we are at the left side, if 7, right side
			; depending on which side we are in, we want to skip certain neighbourchecks
			.IF edx == 7 ; right side
				.IF shiftingAmount == 1 ; EAST
					jmp failedNeighbourCheck
				.ELSEIF shiftingAmount == 9 ; SOUTHEAST
					jmp failedNeighbourCheck
				.ELSEIF shiftingAmount == -7 ; NORTHEAST
					jmp failedNeighbourCheck
				.ENDIF
			.ENDIF
			.IF edx == 0 ; left side
				.IF shiftingAmount == -1 ; WEST
					jmp failedNeighbourCheck
				.ELSEIF shiftingAmount == -9 ; NORTHWEST
					jmp failedNeighbourCheck
				.ELSEIF shiftingAmount == 7  ; SOUTHWEST
					jmp failedNeighbourCheck
				.ENDIF
			.ENDIF

			xor eax, eax
			mov al, BYTE PTR [edi]
			.IF al != -1 ; if empty, skip
				.IF al == opponent ; if not enemy, skip
					mov ah, temporaryPositionX
					add ah, shiftingPositionX
					mov temporaryPositionX, ah
					mov BYTE PTR [esi], ah

					inc esi

					mov al, temporaryPositionY
					add al, shiftingPositionY
					mov temporaryPositionY, al
					mov BYTE PTR [esi], al 

					inc esi
					inc iterator
					jmp check
				.ELSE
					mov successfulFlip, 1 ; boolean to check wheter we had a valid turn
				.ENDIF
			.ENDIF

			failedNeighbourCheck:
			.IF iterator > 1
				.IF successfulFlip ==1
					mov esi, offset helperArray
					xor ecx, ecx
					mov cl, iterator
					.WHILE ecx != 0
						;Drawing from the helper Array
						mov dh, BYTE PTR [esi]
						inc esi
						mov dl, BYTE PTR [esi]
						inc esi
						INVOKE drawPawn, dl, dh, currentPlayer

						;setting the new values of the gameArray
						xor eax, eax
						mov edi, offset gameArray ; calculating the index of array
						mov al, dl ; row
						shl al, 3 ; multipylng by 8
						add al, dh ; column
						add edi, eax ; add it to memory address

						mov bh, currentPlayer ; set the array for winning players number
						mov BYTE PTR [edi], bh

						dec ecx
					.ENDW

					mov successfulHit, 1 ; successful enemy pawn kill, lets you switchpalyer
				.ENDIF
			.ENDIF

		ret
neighCheck ENDP

newGame PROC
	;Clearing the game gameArray of previous values by running a loop setting everthing to zero

	mov esi, offset gameArray
	mov ecx, 80 ; 64 of gameArray + 16 of helperArray
	.WHILE ecx != 0
		mov BYTE PTR [esi], -1
		inc esi
		dec ecx
	.ENDW

	; set the starting pawns value to gameArray
	mov esi, offset gameArray

	add esi, 27
	mov BYTE PTR [esi], 1

	add esi, 1
	mov BYTE PTR [esi], 0

	add esi, 7
	mov BYTE PTR [esi], 0

	add esi, 1
	mov BYTE PTR [esi], 1

	mov currentPlayer, 0

ret
newGame ENDP


playerSwitch PROC ; NOTE: was playerSwitch, cleaned up with modern .IF macro, removed the player indicator
		.IF currentPlayer == 0
			mov currentPlayer, 1
		.ELSE
			mov currentPlayer, 0
		.ENDIF
ret
playerSwitch ENDP


;This procedure is for checking the value from the gameArray where we clicked
getPositionalValue PROC uses ebx ecx edx esi, position:WORD ; NOTE: was getValue

	mov esi, offset gameArray
	mov ebx, DWORD PTR position ; move the position to temp register

	mov al, bl ; row
	mov cl, 8
	mul cl
	add al, bh ; column
	add esi,  eax ; add it to memory address

	xor eax, eax ; clean return register

	mov al, [esi] ; return what we have in the clicked position 
	ret 4

getPositionalValue ENDP

getPositionFromBoard PROC uses ebx ecx edx esi edi PosX:DWORD, PosY:DWORD ; NOTE: it was getPositionFromBoard, converted it to INVOKE form call. Did an overal overhaul, not logicaly, just cleanup

		;If they are beyond the table reach
		;Making sure it between the bounds

		;NOTE: have to move all the edges of the board into these registers, since it doesnt compare memory to memory for some reason....
		mov ebx, BLEFT ; LEFT STARTING POSITION OF BOARD
		mov esi, BTOP ; TOP

		mov edx, BLEFT
		add edx, 800 ; RIGHT

		mov ecx, BTOP
		add ecx, 800 ; BOTTOM

		;Compare if player clicked outside the bounds
		.IF PosX > edx ; if out of bounds, we return -1 as an indicator not to continue
			mov eax, -1
			jmp skipOutofBounds
		.ELSEIF  PosX < ebx
			mov eax, -1
			jmp skipOutofBounds
		.ELSEIF PosY > ecx
			mov eax, -1
			jmp skipOutofBounds
		.ELSEIF  PosY < esi
			mov eax, -1
			jmp skipOutofBounds 
		.ENDIF

		xor edx, edx ;

		mov ebx, 100 ;divide the coordinates by 100, you will get which rectangle you clicked on X axis
		mov eax, PosX
		sub eax, BLEFT
		div ebx
		mov cl, al ; X

		xor edx, edx ; same for Y

		mov eax, PosY
		sub eax, BTOP
		div ebx
		mov ch, al ; Y

		mov al, ch	;X coordinate is col
		mov ah, cl	;Y coordinate is row

		skipOutofBounds:

		ret 4 ; returns EAX. AL part is the X coord, AH is the Y
getPositionFromBoard ENDP



drawBoard PROC uses eax ebx ecx esi edi
		LOCAL brush:HBRUSH
		LOCAL BRIGHT:WORD
		LOCAL BBOTTOM:WORD

		;Creating the grid
		INVOKE CreateSolidBrush, 0000FF00h ; green table board 00 B G R
		mov brush, eax
		INVOKE SelectObject, hdc, brush

		mov eax, BTOP
		add eax, 800
		mov BBOTTOM, ax

		mov eax, BLEFT
		add eax, 800
		mov BRIGHT, ax

		INVOKE Rectangle,hdc,BLEFT,BTOP,BRIGHT,BBOTTOM ; actually drawing the rectangle after all these preparations..

		;Now comes the lines
		xor esi ,esi
		mov esi, BTOP ;starting coordinate
		mov edi, 7
		INVOKE MoveToEx, hdc, 0, 0, 0 ; X, Y ; move back to 0,0
		.WHILE edi != 0
			add esi, 100
			INVOKE MoveToEx, hdc, BLEFT, esi, 0 ; X, Y
			INVOKE LineTo,hdc,  BRIGHT, esi ; TOP
			dec edi
		.ENDW
		

		xor esi ,esi
		mov esi, BLEFT ;starting coordinate
		mov edi, 7

		.WHILE edi != 0
			add esi, 100
			INVOKE MoveToEx, hdc, esi, BTOP, 0 ; X, Y
			INVOKE LineTo,hdc,  esi, BBOTTOM ; TOP
			dec edi
		.ENDW
		ret
drawBoard ENDP

WinProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
	LOCAL ps:PAINTSTRUCT
	mov eax, localMsg

	.IF eax == WM_LBUTTONDOWN	
		  mov eax,lParam
		  and eax,0FFFFh
		  mov mPoint.X,eax
		  mov eax,lParam
		  shr eax,16
		  mov mPoint.Y,eax
		  mov mouseClick,TRUE
		  INVOKE InvalidateRect,hWnd,NULL, FALSE
		  jmp WinProcExit

	.ELSEIF eax == WM_CREATE		
		  jmp WinProcExit

	.ELSEIF eax == WM_PAINT
	      INVOKE BeginPaint,hWnd,ADDR ps
	      mov hdc,eax

	.IF startGame == 1
		INVOKE newGame

		INVOKE drawBoard

		INVOKE drawPawn, 4, 4, 1 ;Pawn E5
		INVOKE drawPawn, 3, 4, 0 ;Pawn D5
		INVOKE drawPawn, 4, 3, 0 ;Pawn E4
		INVOKE drawPawn, 3, 3, 1 ;Pawn D4
		
		
		

		mov startGame, 0
	.ENDIF
		.IF mouseClick
			INVOKE getPositionFromBoard, mPoint.X, mPoint.Y ; getting the position of the pawn

			.IF eax != -1 ; if you get -1, it means the click was out of bounds, therefore skip the upcoming operations
				mov posY, al ; store the row value for later use
				mov posX, ah ; store the column value for later use
				INVOKE getPositionalValue, ax ; ax contains  column, row in order

				.IF al == -1 ; if the clicked positions value is empy(-1) we can start calculating neighbourcheck
					
					.IF posY != 0
						INVOKE neighCheck, posX, posY, -8, 0,-1 ; NORTH
					.ENDIF

					.IF posY != 0
						.IF posX != 7
							INVOKE neighCheck, posX, posY, -7, 1,-1 ; NORTHEAST
						.ENDIF
					.ENDIF

					.IF posX != 7
						INVOKE neighCheck, posX, posY,  1, 1, 0 ; EAST
					.ENDIF

					.IF posY != 7
						.IF posX != 7
							INVOKE neighCheck, posX, posY,  9, 1, 1 ; SOUTHEAST
						.ENDIF
					.ENDIF

					.IF posY != 7
						INVOKE neighCheck, posX, posY,  8, 0, 1 ; SOUTH
					.ENDIF

					.IF posY != 7
						.IF posX != 0
							INVOKE neighCheck, posX, posY,  7, -1, 1 ; SOUTHWEST
						.ENDIF
					.ENDIF

					.IF posX != 0
						INVOKE neighCheck, posX, posY, -1,-1, 0 ; WEST
					.ENDIF	

					.IF posY != 0
						.IF posX != 0
							INVOKE neighCheck, posX, posY,  -9, -1, -1 ; NORTHWEST
						.ENDIF
					.ENDIF					
					
					.IF successfulHit == 1 ; we only call playerswitch, if you killed your opponets pawn, 
						INVOKE playerSwitch
					.ENDIF

					mov successfulHit, 0

				.ENDIF
			.ENDIF
		.ENDIF
		INVOKE EndPaint,hWnd,ADDR ps
		jmp WinProcExit
	 .ELSEIF localMsg == WM_COMMAND 
        mov eax,wParam 
        .IF ax == IDM_NEWGAME
			mov startGame, 1
			INVOKE newGame
			invoke InvalidateRect,hWnd,NULL,FALSE
        .ELSEIF ax == IDM_EXITGAME
			INVOKE ExitProcess,0
        .ELSE 
            jmp WinProcExit 
        .ENDIF 
	.ELSEIF eax == WM_CLOSE		; close window?
	  INVOKE PostQuitMessage,0
	  jmp WinProcExit
	.ELSE		; other message?
	  INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
	  jmp WinProcExit
	.ENDIF

WinProcExit:
	ret
WinProc ENDP
.code
;---------------------------------------------------
ErrorHandler PROC
; Display the appropriate system error message.
;---------------------------------------------------
.data
pErrorMsg  DWORD ?		; ptr to error message
messageID  DWORD ?
.code
	INVOKE GetLastError	; Returns message ID in EAX
	mov messageID,eax

	; Get the corresponding message string.
	INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + \
	  FORMAT_MESSAGE_FROM_SYSTEM,NULL,messageID,NULL,
	  ADDR pErrorMsg,NULL,NULL

	; Display the error message.
	INVOKE MessageBox,NULL, pErrorMsg, ADDR messageID,
	  MB_ICONERROR+MB_OK

	; Free the error message string.
	INVOKE LocalFree, pErrorMsg
	ret
ErrorHandler ENDP

END WinMain