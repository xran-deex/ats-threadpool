#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"
staload _ = "libats/DATS/lindeque_dllist.dats"
staload _ = "libats/DATS/gnode.dats"
staload _ = "libats/DATS/dllist.dats"
staload _ = "libats/DATS/athread.dats"
staload _ = "libats/DATS/deqarray.dats"
staload _ = "libats/DATS/athread_posix.dats"

staload POOL = "./SATS/threadpool.sats"

staload _  = "./DATS/threadpool.dats"
#include "ats-channel.hats"
#include "ats-shared-vt.hats"
