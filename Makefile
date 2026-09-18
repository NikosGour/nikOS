ASM=nasm

SRC_DIR=prereq
OUT_DIR=out

$(OUT_DIR)/main_floppy.img: $(OUT_DIR)/main.bin
	cp $(OUT_DIR)/main.bin $(OUT_DIR)/main_floppy.img
	truncate -s 1440k $(OUT_DIR)/main_floppy.img

$(OUT_DIR)/main.bin: $(SRC_DIR)/main.asm
	$(ASM) $(SRC_DIR)/main.asm -f bin -o $(OUT_DIR)/main.bin
