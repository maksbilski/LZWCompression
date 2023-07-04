	.data
prompt: 	.asciz "Enter file path:\n"
filepath:    .space 100
dictionary: 	.space 0x4000
fout:	.asciz "compressed_file"

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
	
	# Close the file
	li 	a7, 57	# syscall number for close
	mv 	a0, s0	# file descriptor (a0)
	ecall

	# Alocate buffer for compressed file 
	li 	a7, 9 
	mv	a0, s1
	ecall
	mv 	s3, a0	# store address of the output buffer in s3
	mv 	s4, s3
	
	mv	a0, s1
	mv	a1, s2
	mv	a2, s3
	la 	a3, dictionary	# store pointer to end of the occupied dictionary array space.
	addi 	a3, a3, 2
	jal	encode
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
# s11 - pointer to the beginning of the dictionary (will remain unchanged)
# s5 - counter of processed bytes

encode:
	mv 	s11, a3					# s11 will be always pointing to the beginning of the dictionary
	lbu 	t0, (a1)			# load the first byte from the input buffer to t0
	li	s5, -1					# s5 will be a counter of processed bytes (initialize to -1)
	li 	t5, 0 					# t5 will be indicating if we should store an even byte or odd byte
encoding_loop:
	addi	s5, s5, 1			# increment count of processed bytes
	beq 	s5, a0, encode_exit	# if count of processed bytes is equal to input file size, finish encoding
	addi 	a1, a1, 1 			# increment input buffer pointer
	lbu	t1, (a1)				# load byte from input buffer to t1
	slli	t0, t0, 16 		
	or	t0, t0, t1				# concatenate the new byte to the encoded string	
	mv 	t1, s11					# load pointer to the beginning of the dictionary to t1
		
checking_if_word_in_dict:
	beq 	t1, a3, word_is_not_in_dict
	lw	t2, (t1)				# load element from the dictionary to t2
	addi 	t1, t1, 4			# increment t1 so it's pointing to the next element of dictionary
	bne	t0, t2, checking_if_word_in_dict
	
word_is_in_dict:
	sub 	t1, t1, s11			# compute how many bytes there are between begining of dictionary and position of found element
	addi 	t1, t1, -4
	srli 	t1, t1, 2		
	addi 	t0, t1, 256
	b 	encoding_loop
	
word_is_not_in_dict:
	sw	t0, (a3)
	addi	a3, a3, 4
	mv	t4, t0
	bnez 	t5, store_in_obuffer_half_full_byte
	
store_in_obuffer_fresh_byte:
	mv 	t1, t4
	srli	t1, t1, 20
	sb	t1, (a2)
	srli	t4, t4, 12
	andi	t4, t4, 0x000000f0
	sb	t4, 1(a2)
	addi 	a2, a2, 1
	li 	t5, 1
	b 	encoding_loop

store_in_obuffer_half_full_byte:
	srli	t4, t4, 16
	sb	t4, 1(a2)
	srli	t4, t4, 8
	lbu	t1, (a2)
	or	t4, t4, t1
	sb	t4, (a2)
	addi	a2, a2, 2
	li	t5, 0
	b	encoding_loop
	
encode_exit:
	mv a0, a2
	jr ra
