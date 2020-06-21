ATSCC=$(PATSHOME)/bin/patscc
ATSOPT=$(PATSHOME)/bin/patsopt

ATSFLAGS=-IATS ../node_modules

CFLAGS=-DATS_MEMALLOC_LIBC -D_DEFAULT_SOURCE -I . -I $(PATSHOME)/ccomp/runtime -I $(PATSHOME) -O3 -g
LIBS=-L $(PATSHOME)/ccomp/atslib/lib -L ../target -lats-threadpool -L ../node_modules/ats-shared-vt/target -lats-shared-vt -latslib -lpthread

APP     = tests
EXEDIR  = target
SRCDIR  = .
OBJDIR  = .build
vpath %.dats .
dir_guard=@mkdir -p $(@D)
SRCS    := tests.dats
OBJS    := $(patsubst %.dats,$(OBJDIR)/%.o,$(SRCS))

.PHONY: clean setup

all: $(EXEDIR)/$(APP)

$(EXEDIR)/$(APP): $(OBJS)
	$(dir_guard)
	$(CC) $(CFLAGS) -o $(EXEDIR)/$(APP) $(OBJS) $(LIBS)

.SECONDEXPANSION:
$(OBJDIR)/%.o: %.c
	$(dir_guard)
	$(CC) $(CFLAGS) -c $< -o $(OBJDIR)/$(@F)

$(OBJDIR)/%.c: %.dats
	$(dir_guard)
	$(ATSOPT) $(ATSFLAGS) -o $(OBJDIR)/$(@F) -d $<

RMF=rm -f

clean: 
	$(RMF) $(EXEDIR)/$(APP)
	$(RMF) $(OBJS)

run:
	LD_LIBRARY_PATH=../target ./target/tests