%{
#include <pthread.h>
%}

#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"
staload "libats/SATS/lindeque_dllist.sats"
staload _ = "libats/DATS/lindeque_dllist.dats"
staload _ = "libats/DATS/gnode.dats"
staload _ = "libats/DATS/dllist.dats"
staload "libats/SATS/athread.sats"
staload _ = "libats/DATS/athread.dats"
staload _ = "libats/DATS/athread_posix.dats"
staload "libats/libc/SATS/unistd.sats"
#include "ats-channel/ats-channel.hats"
#include "ats-shared-vt/ats-shared-vt.hats"
