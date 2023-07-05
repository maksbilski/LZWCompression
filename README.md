# LZW File Compression and Decompression with RISC-V Assembly
This repository contains assembly code for an efficient file compression and decompression utility, based on the LZW (Lempel-Ziv-Welch) algorithm. The algorithm is particularly effective for compressing files that contain repetitive sequences of bytes and can achieve compression ratios of up to 70%. The assembly code is written in RISC-V assembly language.

## Contents

- **`LZW-compression.asm`**: Contains the assembly code for compressing an input file using the LZW algorithm.
- **`LZW-decompression.asm`**: Contains the assembly code for decompressing files compressed using the LZW algorithm.

## About LZW Algorithm

LZW is a dictionary-based compression algorithm that's well-suited for files with repetitive sequences. As it processes the input data, it creates a dictionary of sequences it has seen, and replaces repeated sequences with references to the dictionary. This is particularly efficient for files with lots of repeated patterns, and can result in significant compression ratios.

In scenarios where the file contains substantial repetitive byte sequences, my implementation of LZW can compress the file size by up to 70%-90% of its original size.
