; void line(FILE *file, int X0, int Y0, int X1, iny Y1, unsigned color)
; ebp - 4 Xinc
; ebp - 8 Yinc
section	.text
global  _line

_line:
prologue:
	push ebp 
	mov	ebp, esp
	sub esp, 8
	push ebx
	push edi
	push esi

parameter:
	mov eax, [ebp+20]  ; get X1
	mov ecx, [ebp+12]  ; get X0
	sub eax, ecx	   ; X = |X1 - X0|
	push eax		   ; preserve value of difference 

	mov ebx, [ebp+24] ; get Y1
	mov edx, [ebp+16] ; get Y0

	sub ebx, edx   ; chceck if difference is negative if it is, negate
	push ebx	   ; preserve value of difference 
	mov esi, ebx
	neg ebx
	cmovl ebx, esi ; Y = |Y1 - Y0|
	cmp eax, ebx   ; Choose the bigger difference of coordinates
	cmovl eax, ebx 
	mov ecx, eax; step parameter
	
	pop ebx	; restore both differences before abs() 
	pop eax
	test ecx, ecx ; if divider = 0 then draw one pixel and finish
	jz prepare_bitmap
	mov edi, eax  ; safe X value
	xor edx, edx  ; zeroing register for reminder 
	test ebx, ebx ; check if we will decrement or increment Y
	js negative_y
	xor esi, esi
	jmp calculate
negative_y:
	mov esi, -1
calculate:
	idiv ecx	 
	test edx, edx
	jz x_equal_one ; jump if division X by divider is equal 1
	mov eax, edi ; calculating Xinc and making it 16.16 format
	sal eax, 16
	xor edx, edx
	idiv ecx
	mov edi, eax

	mov eax, ebx ; calculating Yinc and making it 16.16 format
	mov edx, esi
	idiv ecx
	mov ebx, eax
	sal ebx, 16
	mov eax, edi
	jmp prepare_bitmap
x_equal_one:
	sal eax, 16  ; prepare Xinc to be in 16.16 format
	mov edi, eax
	
	mov eax, ebx
	mov edx, esi
	idiv ecx
	test edx, edx
	jz y_equal_one ; jump if division Y by divider is equal 1 or -1
	mov eax, ebx   ; calculating Yinc and making it 16.16 format
	sal eax, 16
	mov edx, esi
	idiv ecx
	mov ebx, eax
	mov eax, edi
	jmp prepare_bitmap
y_equal_one:
	mov ebx, eax 		; prepare Yinc to be in 16.16 format
	mov eax, edi
	sal ebx, 16

prepare_bitmap:
	mov [ebp-4], eax  	; preserve Xinc and Yinc for future calculation of coordinates
	mov [ebp-8], ebx

	inc ecx 	  
	mov esi, [ebp+8]  	; procedure to move to the beginning of bitmap
	mov edi, [esi+10]
	add edi, esi
	
	mov edx, [esi+18] 

	mov ebx, [ebp+16] 	; Y0
	sal ebx, 16		  	; transform into 16.16 format
	mov eax, [ebp+12] 	; X0
	sal eax, 16		  	; transform into 16.16 format

set_pixel:
	mov esi, edx   		; Height of bitmap
	
	push edx 			; preserve counter
	mov edx, ebx 		; preserve 16.16 format for future calc.
	add edx, 0x8000 	; round up (1 and 15 zeroes)
	sar edx, 16   		; create no frac. number
	imul esi, edx 		; find proper row
	
	mov edx, eax    	; preserve 16.16 format for future calc.
	add edx, 0x8000 	; round up (1 and 15 zeroes)
	sar edx, 16     	; create no frac. number
	add esi, edx    	; find proper column

	add esi, edi		; move to the place where 
	
	mov dl, [ebp+28] 	; color pixel
	mov [esi], dl

	pop edx

	add eax, [ebp-4]	; increament X
	add ebx, [ebp-8]	; increament Y
	
	dec ecx				; sub 1 and check if it reaches 0
	jnz set_pixel		; if counter equal 0, goes to epilogue

epilogue:
	pop esi
	pop edi
	pop ebx
	leave
	ret

;CODE OF ALGORITHM
;
;    int dx = X1 - X0; 
;    int dy = Y1 - Y0; 
;  
;   int steps = abs(dx) > abs(dy) ? abs(dx) : abs(dy); 
;  
;    float Xinc = dx / (float) steps; 
;    float Yinc = dy / (float) steps; 
;
;    float X = X0; 
;    float Y = Y0; 
;    for (int i = 0; i <= steps; i++) 
;    { 
;        set_pixel  
;        X += Xinc;           // increment in x at each step 
;        Y += Yinc;           // increment in y at each step 
;    } 