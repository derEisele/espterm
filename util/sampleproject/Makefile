# Esptool firmware download options
PORT			?= /dev/ttyUSB0
BAUD			:= 1000000

# SDK / Compiler settings
SDK_DIR			:= /opt/esp-open-sdk/esp_iot_sdk_v1.5.0
CC				:= xtensa-lx106-elf-gcc
LD				:= xtensa-lx106-elf-gcc
ESPTOOL			:= esptool.py
CFLAGS			:= -Os -g -O2 -Wpointer-arith -Wall -Wno-implicit-function-declaration -fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals
LDLIBS			:= -nostdlib -Wl,--start-group -lmain -lnet80211 -lwpa -llwip -lpp -lphy -Wl,--end-group -lgcc -lcrypto
LDFLAGS			:= -T$(SDK_DIR)/ld/eagle.app.v6.ld

# Directory structure
BUILDDIR		:= build
SRCDIR			:= src
OBJDIR			:= obj

# Project settings
TARGET			:= firmware
FLASH_FREQ		:= 40m
FLASH_MODE		:= qio
FLASH_SIZE		:= 32m
FLASH_OPT		:= --flash_freq $(FLASH_FREQ) --flash_mode $(FLASH_MODE) --flash_size $(FLASH_SIZE)

SRCS			:= $(wildcard  $(SRCDIR)/*.c)
OBJS			:= $(addprefix $(OBJDIR)/,$(notdir $(SRCS:.c=.o)))
DEPS			:= $(addprefix $(OBJDIR)/,$(notdir $(SRCS:.c=.d)))

TARGET_ELF		:= $(BUILDDIR)/$(TARGET).elf
TARGET_FLASH	:= $(BUILDDIR)/$(TARGET)-0x00000.bin
TARGET_IROM		:= $(BUILDDIR)/$(TARGET)-0x40000.bin

all: $(OBJDIR) $(BUILDDIR) $(TARGET_FLASH) $(TARGET_IROM)
	@echo Compilation successful
	@echo Use \'make flash\' to flash firmware

$(TARGET_FLASH) $(TARGET_IROM): $(TARGET_ELF)
	$(ESPTOOL) elf2image $(FLASH_OPT) $^ --output $(BUILDDIR)/$(TARGET)-

$(TARGET_ELF): $(OBJS)
	$(LD) -L $(SDK_DIR)/lib $(LDLIBS) $(LDFLAGS) $^ -o $@
				
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	$(CC) $(CFLAGS) -I $(SRCDIR)/ -I $(SDK_DIR)/include -I $(SDK_DIR)/include/json -MMD -MP -c $< -o $@

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

FOO = $PATH
flash: all
	@echo $(value FOO)
	$(ESPTOOL) --port $(PORT) --baud $(BAUD) write_flash $(FLASH_OPT) 0x00000 $(TARGET_FLASH) 0x40000 $(TARGET_IROM)

.PHONY: clean

clean:
	$(RM) -r $(OBJDIR)
	$(RM) -r $(BUILDDIR)

-include $(DEPS)
