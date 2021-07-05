	
	.data
inputfile: .space 260
outputfile: .asciiz "result.c"

buff_in: .space 512		
buff_out: .space 512
formula: .byte 92 120 		#\x formula for escape sequence
formula2: .byte 34		#Formula for extra quotation marks

prompt1: .asciiz "Enter c file name (with extension): "
error_msg: .asciiz "\nFile not found! Terminating the program!\n"
error_msg2: .asciiz "\nUnexpected error while operating on file! Terminating the program\n"


# VARIABLES MEANING IN CODE #################################
# t0 = stores file descriptor of input file		    #	
# t1 = stores file descriptor of output file		    #
# t2 = stores value of buff_in character		    #
# t3 = check byte-size of character		            #
# t4, t5 = use to change character into unicode form	    #
# t6, t7 = use to remove 0x0a from end of inputfile	    #
# t8 = stores previous character 			    #
#############################################################

	.text

.macro print_string (%what_to_print)
	li $v0, 4
	la $a0, %what_to_print
	syscall
.end_macro

main:
	#Print prompt
	print_string(prompt1)
	
	#enter file name
	li $v0, 8
	la $a0, inputfile
	li $a1, 260
	syscall
	
	#Reparing file name
	la $t6, inputfile
	jal repair_inputfile
	
	#Open File to read
	li $v0, 13
	la $a0, inputfile
	li $a1, 0
	li $a2, 0
	syscall

	#Check if file exists
	bltz $v0, open_error
	move $t0 $v0
	
	#Open File to write 
	li $v0, 13
	la $a0, outputfile
	li $a1, 1
	li $a2, 0
	syscall
	move $t1 $v0
	
	li $t2, 0 # initialize current character
	li $t8, 0 # initialize previous character
	
	la $s0, buff_in # counter of input buffer
	la $s1, 0 	# counter of input buffer
	
	la $s2, buff_out # address of output buffer
	li $s3, 512  	 # counter of output buffer
	
	li $s4, 0 # stores character to putc fun.

	j check_character
	
get_character:	
	beqz $s1, load_buff_in
	
	addiu $s0, $s0, 1
	subiu $s1, $s1, 1
	
	lbu $v1, 0($s0)
	beqz $v1, EOF
	
	jr $ra
load_buff_in:
	li $v0, 14
	move $a0, $t0
	la $a1, buff_in
	li $a2, 512
	syscall

	bltz $v0, ERR 
	beqz $v0, EOF
	
	la $s0, buff_in
	lbu $v1, 0($s0)
	
	move $s1, $v0
	subiu $s1, $s1, 1
	
	jr $ra
EOF:
	li $v1, -1
	jr $ra
ERR:
	print_string(error_msg2)
	li $v1, -1
	jr $ra
	
put_character:
	beqz $s3, save_clear
	
	sb $s4, 0($s2)
	addiu $s2, $s2, 1
	subiu $s3, $s3, 1
	move $v1, $s4
	
	jr $ra
save_clear:
	li $v0, 15
	move $a0, $t1
	la $a1, buff_out
	li $a2, 512
	syscall
	
	bltz $v0, ERR
	
	la $s2, buff_out 	
	li $s3, 512  	 
	
	sb $s4, 0($s2)
	addiu $s2, $s2, 1
	subiu $s3, $s3, 1
	move $v1, $s4
	
	jr $ra
	
check_character:	
	move $t8, $t2
	jal get_character
	move $t2, $v1
	
	bgtu $t8, 127, if_add_quotation_marks	#If Previous character was non ASCII, check if string needs extra quotation marks
	
	bltz $t2, finish			# $t2 < 0
	bltu $t2, 128, ascii_character   	# 0 <= $t2 <= 127
	bgtu $t2, 127, two_bytes_character 	# $t2 => 128 

	#If next character after non-ASCII character is 0-9 or A-F or a-f c file will treat it as part of unicode which is not the case, adding extra quotation marks to prevent that	
if_add_quotation_marks:
	bltu $t2, 48, ascii_character
	bltu $t2, 58, add_quotation_marks
	bltu $t2, 65, ascii_character 
	bltu $t2, 71, add_quotation_marks
	bltu $t2, 97, ascii_character 
	bltu $t2, 103, add_quotation_marks
	bltu $t2, 128, ascii_character 
	bgtu $t2, 127, two_bytes_character 
	
	# Simply adding ASCII character to new file
ascii_character:
	move $s4, $t2
	jal put_character
	j check_character 
	
	# Out of ASCII range character, checking if bigger size than 2 bytes, if not adding in UTF-8 form to new file	
two_bytes_character:
	and $t3, $t2, 0x20 			# bitwise with 00100000, if 3rd bit is equal 1 then character have at least three bytes, if not it has two bytes 
	beq $t3, 0x20, three_bytes_character	# no need to check 1st byte because it is equal 0 for ASCII range and we definately have non-ASCII range 
						# and 2nd bit has no impact on size of non-ASCII character (always 1)
	jal store_unicode_c_formula		# Writing to buff_in "\x" as it is how we start escape seq. in c files 
	and $t4, $t2, 0x1F			# bitwise with 00011111 as we will save to unicode last 5 bits 
	add $t4, $t4, 0xC0			# adding 11000000 as first 3 bits are set for first byte, in the end we got first byte value of unicode
	srl $t4, $t4, 4				# Converting it hexadecimal value: shifting 4 times to the right which is equal division by 16
	move $t5, $t4				# As \x unicode consist of two-pieces hexadecimal number, we know that second division will be equal 0 and we can  store first division result
	jal convert_and_store			# as reminder of second devision and because Hexadecimal is written in opposite direction to division we call convert function to change reminder 
	sll $t4, $t4, 4				# shifting 4 times to the left which is equal to multiplication by 16
	sub $t5, $t2, $t4			# Substracting mult. result from basic number to get reminder of first division			
	jal convert_and_store			# Calling convert_and_store to change reminder into hexadecimal value
	jal store_unicode_c_formula 		# Writing to buff_in "\x"
	jal next_byte				# Converting second byte of two-byte character
	j check_character			# Come back to checking input buff_in character
	
	# Another Character out of ASCII range, preparing character to be stored as unicode, this time it is three-byte size
three_bytes_character:
	and $t3, $t2, 0x10			# Process of converting is the same as in case of two-byte size character thus I will not describe each line 
	beq $t3, 0x10, four_bytes_character	# 0x10 = 00010000 
	
	jal store_unicode_c_formula
	and $t4, $t2, 0xF			# 0xF =  00001111
	add $t4, $t4, 0xE0			# 0xE0 = 11100000
	srl $t4, $t4, 4
	move $t5, $t4
	jal convert_and_store
	sll $t4, $t4, 4
	sub $t5, $t2, $t4
	jal convert_and_store
	jal store_unicode_c_formula
	jal next_byte
	jal store_unicode_c_formula
	jal next_byte
	j check_character
	
	#Same way as in the upper label
four_bytes_character:
	jal store_unicode_c_formula     # Do not need to check for bigger size as four bites are maximum for UTF-8
	and $t4, $t2, 0x7		# 0x7 =  00000111
	add $t4, $t4, 0xF0		# 0xF0 = 11110000
	srl $t4, $t4, 4
	move $t5, $t4
	jal convert_and_store
	sll $t4, $t4, 4
	sub $t5, $t2, $t4
	jal convert_and_store
	jal store_unicode_c_formula
	jal next_byte
	jal store_unicode_c_formula
	jal next_byte
	jal store_unicode_c_formula
	jal next_byte
	j check_character

	#Function responsible for 2nd, 3rd and 4th byte as process of their convertion is the same
next_byte: 
	addiu $sp, $sp, -4	# saving register value to being able to come back to size-byte functions.
	sw $ra, ($sp)
	 
	jal get_character
	move $t2, $v1	
	and $t4, $t2, 0x3F	# 0x3F = 00111111
	add $t4, $t4, 0x80	# 0x80 = 10000000
	srl $t4, $t4, 4
	move $t5, $t4
	jal convert_and_store
	sll $t4, $t4, 4
	sub $t5, $t2, $t4
	jal convert_and_store
	
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	jr $ra	
	
	# One of the fun. responsible for converting into hex. value, depending what is the value of reminder it goes to other function
convert_and_store:
	bleu $t5, 9, convert_and_store_integer	  #if reminder is between 0 and 9 it will convert it as integer character
	bgeu $t5, 10, convert_and_store_letter    #if reminder is between 10 and 15 it will convert it as letter character A-F

convert_and_store_integer:
	addiu $t5, $t5, 48 	# adding 48 to get into range of integer values in ASCII code
	move $s4, $t5		# storing character
	addiu $sp, $sp, -4	# saving register value to being able to come back to size-byte functions.
	sw $ra, ($sp)
	jal put_character
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	jr $ra 			# jumping back to byte-size functions

convert_and_store_letter:
	addiu $t5, $t5, 55 	# same as higher but going for character range in ASCII code
	move $s4, $t5		# storing character
	addiu $sp, $sp, -4	# saving register value to being able to come back to size-byte functions.
	sw $ra, ($sp)
	jal put_character
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	jr $ra
	
	# Writing "\x" formula to output buff_in
store_unicode_c_formula:
	addiu $sp, $sp, -4	# saving register value to being able to come back to size-byte functions.
	sw $ra, ($sp)
	
	lb $s4, formula
	jal put_character
	lb $s4, formula + 1
	jal put_character
	
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	jr $ra
	
	# Adding quotation marks
add_quotation_marks:
	lb $s4, formula2
	jal put_character
	lb $s4, formula2
	jal put_character
	
	bltz $t2, finish			# If EOF finish
	bltu $t2, 128, ascii_character   	# If character value is in ASCII range, going to put_character label
	bgtu $t2, 127, two_bytes_character 	# If character is out of ASCII range, going to two_bytes_character label	
	
	#As inputfile buff_in will be ended with 0x0a character, program will not recognize file and will not open any file so function below will remove this character
repair_inputfile:
	lbu $t7, 0($t6)
	bne $t7, 0x0a, move_pointer
	sb $zero, 0($t6)
	jr $ra
move_pointer:
	addiu $t6, $t6, 1
	j repair_inputfile
	
	#Print error message 
open_error:
	print_string(error_msg)
	li $v0, 10
	syscall
	
	#Terminating the program	
finish: 	
	beq $s3, 512, terminate
	
	li $t9, 512
	sub $t9, $t9, $s3
	
	li $v0, 15
	move $a0, $t1
	la $a1, buff_out
	move $a2, $t9 
	syscall
	
	j terminate
	
terminate:
	li $v0, 16
	move $a0, $t0
	syscall
	
	li $v0, 16
	move $a0, $t1
	syscall
	 
	li $v0, 10
	syscall
