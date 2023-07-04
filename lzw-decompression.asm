	.data
prompt: 	.asciz "Enter file path:\n"
filepath:    .space 100
dictionary: 	.space 0x4000
fout:	.asciz "decompressed_file.txt"

	.text
main:
	# Print out prompt
	li	a7, 4
	la	a0, prompt
	ecall

	# Store entered file path in the buffer
	li 	a7, 8
	la 	a0, filepath
	li 	a1, 100
	ecall

	# Replace newline character at the end of filepath with null terminator	
	la 	t1, filepath
replace_newline_with_null:
	lb 	t0, (t1)
	addi 	t1, t1, 1
	bnez 	t0, replace_newline_with_null
	sb	zero, -2(t1)	

	# Open the file
	li 	a7, 1024
	li 	a1, 0     	# file mode (a0) - READ_ONLY
	ecall
	mv 	s0, a0    	# Save the file descriptor

	# Get file size using lseek
	li 	a7, 62
	mv 	a0, s0 	# file descriptor (a0)
	li 	a1, 0	# offset (a1)
	li 	a2, 2	# whence (a2) - SEEK_END
	ecall
	mv	s1, a0	# store the file size in s1
	
	# Alocate buffer for file content (file size already in a0)
	li 	a7, 9 
	ecall
	mv 	s2, a0	# store address of the input buffer in s2

 	# Previous lseek call has set the file descriptor postition to end of file
 	# So now we have to call lseek again to set the file descriptor to beggining of file	
	li 	a7, 62 
	mv 	a0, s0	# file descriptor (a0)
	li 	a1, 0	# offset (a1)
	li 	a2, 0	# whence (a2) - SEEK_BEGIN
	ecall
	
	# Write the opened file contents to buffer allocated in heap
	li 	a7, 63
	mv 	a0, s0  	# file descriptor (a0)
	mv 	a1, s2	# address of the buffer (a1)
	mv 	a2, s1	# maximum length to read (a2)
	ecall
	
	mv	s6, a0
	addi	s6, s6, -1
	
	# Close the file
	li 	a7, 57	# syscall number for close
	mv 	a0, s0	# file descriptor (a0)
	ecall

	# Alocate buffer for decompressed file 
	li 	a7, 9
	slli	s1, s1, 8
	mv	a0, s1
	ecall
	mv 	s3, a0	# store address of the output buffer in s3
	mv 	s4, s3	# save pointer to the beginning of the output buffer

	mv	a0, s1
	mv	a1, s2
	mv	a2, s3
	la 	a3, dictionary	# store pointer to end of the occupied dictionary array space.
	addi 	a3, a3, 2
	jal	decode
	mv	s3, a0

	# Open (for writing) a file that does not exist
	li   	a7, 1024     # system call for open file
	la   	a0, fout     # output file name
	li   	a1, 1        # Open for writing (flags are 0: read, 1: write)
	ecall            
	mv   	s6, a0       # save the file descriptor

	# Write to file just opened
	li   	a7, 64       # system call for write to file
	mv   	a0, s6       # file descriptor
	mv   	a1, s4   	 # address of buffer from which to write
	sub	a2, s3, s4
	ecall 
	
	# Close the file
	li   	a7, 57       # system call for close file
	mv   	a0, s6       # file descriptor to close
	ecall

	# Exit
	li 	a7, 93	# syscall number for exit
	li 	a0, 0	# exit status (a0)
	ecall
	
#========================================================================================

# in: a0 - input file size
# in: a1 - pointer to the input buffer
# in: a2 - pointer to the output buffer
# in: a3 - pointer to the dictionary buffer
# out: a0 - pointer to the last empty element of output buffer
# s5 - pointer to the beginning of the dictionary (will remain unchanged)
# s11 - counter of processed bytes
decode:
	mv 	s5, a3			# save pointer the beginning of dictionary in s5
	lbu 	t0, (a1)	# load first byte from encoded file
	lbu 	t1, 1(a1)	# load second byte from encoded file
	addi	a1, a1, 1   # increment pointer to the input buffer
	slli	t0, t0, 4
	srli 	t1, t1, 4
	or 	t0, t0, t1
	sb 	t0, (a2)
	addi 	a2, a2, 1
	li	s11, 2
	li	t5, 1
	
decoding_loop:
	beq 	s11, s6, finish
	bnez	t5, process_odd_codeword
	addi	s11, s11, 2
	lbu	t1, (a1)		# load byte from input buffer
	addi 	a1, a1, 1	# increment pointer to input buffer	
	andi 	t2, t1, 0x000000f0
	bnez 	t2, decode_from_dictionary_even
	lbu	t3, (a1)
	slli	t1, t1, 4
	srli	t3, t3, 4
	or 	t1, t1, t3
	li	t5, 1
	b	store_byte_in_output_buffer
	
process_odd_codeword:
	addi	s11, s11, 1
	lbu	t1, (a1)		# load byte from input buffer
	addi 	a1, a1, 2	# increment pointer to input buffer by two
	andi 	t1, t1, 0x0000000f
	bnez	t1, decode_from_dictionary_odd
	lbu	t1, -1(a1)
	li	t5, 0

store_byte_in_output_buffer:
	sb	t1, (a2)
	addi	a2, a2, 1
	slli	t0, t0, 16	# make place for the byte we stored in encoded string register
	or 	t0, t0, t1		# concatenate the byte we just stored in enccoded string register

add_to_dictionary:
	sw	t0, (a3)
	addi	a3, a3, 4
	b 	decoding_loop

decode_from_dictionary_even:
	lbu	t2, (a1)
	slli	t1, t1, 4
	andi	t2, t2, 0x000000f0
	srli	t2, t2, 4
	or	t1, t1, t2
	li	t5, 1
	b 	store_pointer_to_beginning_of_decoded_word
	
decode_from_dictionary_odd:
	lbu	t2, -1(a1)
	slli	t1, t1, 8
	or 	t1, t2, t1
	li	t5, 0
	
store_pointer_to_beginning_of_decoded_word:
	mv	t2, a2
	mv      	s10, t1 		# store t1, because later we will have to restore it to t0

decode_from_dictionary_loop:
	addi   	s10, s10, -256 		
	slli    	s10, s10, 2
	add     	t3, s5, s10 
	lw      	s10, (t3)    
	addi    	a2, a2, 1
	srli    	s10, s10, 16
	srli    	t4, s10, 8
	bnez    	t4, decode_from_dictionary_loop
	sb      	s10, (a2)
	addi    	a2, a2, 1
	mv      	s9, a2

reverse_stored_bytes_loop:
	addi    	s9, s9, -1
	beq     	s9, t2, before_adding_to_dictonary
	lbu     	s7, (t2)
	lbu     	s8, (s9)

swap:
	sb      	s7, (s9)
	sb      	s8, (t2)
	addi    	t2, t2, 1
	bne     	t2, s9, reverse_stored_bytes_loop

before_adding_to_dictonary:
	slli	t0, t0, 16
	or	t0, t0, s10
	sw	t0, (a3)
	addi	a3, a3, 4
	mv	t0, t1
	b 	decoding_loop
	
finish:	
	beqz	t5, decode_exit
	addi 	s11, s11, -1
	b 	process_odd_codeword

decode_exit:
	mv a0, a2
	jr ra
