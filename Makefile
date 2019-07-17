# Directory structure
SRCDIR := src
OBJDIR := obj

# GResources (UI File)
GLIB_COMPILE_RES	:= glib-compile-resources
GRESOURCES_XML		:= $(SRCDIR)/gresource.xml
GRESOURCES_C		:= $(SRCDIR)/gresources.c
GRESOURCES_FILES	:= $(SRCDIR)/mainwindow.ui

# Compiler settings
TARGET		:= espterm
VALAC		:= valac
PACKAGES	:= gtk+-3.0 vte-2.91 gmodule-2.0 posix linux
SRCS		:= $(wildcard $(SRCDIR)/*.vala) $(wildcard $(SRCDIR)/*.c)
VALAOPTS	:= --target-glib 2.38 -X -Wno-incompatible-pointer-types
PKGS_OPT	:= $(addprefix --pkg ,$(PACKAGES))

# Install / Uninstall settings
INSTDIR			:= $(DESTDIR)/usr/bin
DESKTOP_FILE	:= espterm.desktop
DESKTOP_DIR   := $(DESTDIR)/usr/share/applications/
ICON_FILE		:= espterm.png
ICON_DIR		:= $(DESTDIR)/usr/share/pixmaps

all: $(TARGET)
	@echo Compilation successful

$(TARGET): $(SRCS) $(GRESOURCES_C)
	$(VALAC) $^ $(VALAOPTS) $(PKGS_OPT) --gresources $(GRESOURCES_XML) -o $(TARGET)

$(GRESOURCES_C): $(GRESOURCES_XML) $(GRESOURCES_FILES)
	$(GLIB_COMPILE_RES) $(GRESOURCES_XML) --sourcedir=$(SRCDIR) --target=$@ --c-name _my --generate-source

install: $(TARGET)
	install --mode=755 $(TARGET) $(INSTDIR)/
	install --mode=755 $(ICON_FILE) $(ICON_DIR)/
	install --mode=644 $(DESKTOP_FILE) $(DESKTOP_DIR)/

uninstall:
	$(RM) $(INSTDIR)/$(TARGET)
	$(RM) $(ICON_DIR)/$(ICON_FILE)
	$(RM) $(DESTDIR)/usr/share/applications/$(DESKTOP_FILE)

run: $(TARGET)
	./$(TARGET)

.PHONY: clean

clean:
	$(RM) $(TARGET)
	$(RM) $(GRESOURCES_C)
	$(RM) $(SRCDIR)/*.vala.c
