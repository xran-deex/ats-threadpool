ATSCC=$(PATSHOME)/bin/patscc
ATSOPT=$(PATSHOME)/bin/patsopt

ATSFLAGS=-IATS node_modules

CFLAGS=-DATS_MEMALLOC_LIBC -D_DEFAULT_SOURCE -I $(PATSHOME)/ccomp/runtime -I $(PATSHOME) -O3
LIBS=-L $(PATSHOME)/ccomp/atslib/lib -latslib

APP     = libats-threadpool.a
ifndef STATICLIB
	CFLAGS+=-fpic
	LIBS+=-shared
	APP     = libats-threadpool.so
endif

EXEDIR  = target
ifdef OUTDIR
	EXEDIR = $(OUTDIR)
endif
SRCDIR  = src
OBJDIR  = .build
vpath %.dats src
vpath %.dats src/DATS
vpath %.sats src/SATS
dir_guard=@mkdir -p $(@D)
SRCS    := $(shell find $(SRCDIR) -name '*.dats' -type f -exec basename {} \;)
OBJS    := $(patsubst %.dats,$(OBJDIR)/%.o,$(SRCS))

.PHONY: clean setup

all: $(EXEDIR)/$(APP)

$(EXEDIR)/$(APP): $(OBJS)
	$(dir_guard)
ifdef STATICLIB
	ar rcs $@ $(OBJS)
endif
ifndef STATICLIB
	$(CC) $(CFLAGS) -o $(EXEDIR)/$(APP) $(OBJS) $(LIBS)
endif

.SECONDEXPANSION:
$(OBJDIR)/%.o: %.c
	$(dir_guard)
	$(CC) $(CFLAGS) -c $< -o $(OBJDIR)/$(@F)

$(OBJDIR)/%.c: %.dats node_modules
	$(dir_guard)
	$(ATSOPT) $(ATSFLAGS) -o $(OBJDIR)/$(@F) -d $<

RMF=rm -f

clean: 
	$(RMF) $(EXEDIR)/$(APP)
	$(RMF) $(OBJS)
	+make -C tests clean
	+make -C node_modules/ats-shared-vt clean

node_modules:
	npm install

buildall: all
	+make -C node_modules/ats-shared-vt
	+make -C tests

test: buildall
	+make -C tests run