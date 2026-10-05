ASM=nasm

SRC_DIR=prereq
OUT_DIR=out

.PHONY: all image kernel bootloader clean always

image: $(OUT_DIR)/main_floppy.img
$(OUT_DIR)/main_floppy.img: bootloader kernel
	# step for FAT12 fs
	## create an empty floppy image of 1.44MB (2880 sectors of 512 bytes)
	dd if=/dev/zero of=$(OUT_DIR)/main_floppy.img bs=512 count=2880
	## format the floppy image with FAT12 filesystem and label it "nikOS"
	mkfs.fat -F 12 -n "NIKOS" $(OUT_DIR)/main_floppy.img
	## copy the bootloader to the first sector of the floppy image
	dd if=$(OUT_DIR)/bootloader.bin of=$(OUT_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(OUT_DIR)/main_floppy.img $(OUT_DIR)/kernel.bin "::kernel.bin"


bootloader: $(OUT_DIR)/bootloader.bin
$(OUT_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/temp.asm -f bin -o $(OUT_DIR)/bootloader.bin

bootloader: $(OUT_DIR)/kernel.bin
$(OUT_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel.asm -f bin -o $(OUT_DIR)/kernel.bin


always:
	mkdir -p $(OUT_DIR)

clean:
	trash $(OUT_DIR)
