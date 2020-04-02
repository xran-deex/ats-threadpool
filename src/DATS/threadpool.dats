#include "./../HATS/includes.hats"
staload "./../SATS/threadpool.sats"

#define ATS_DYNLOADFLAG 0

#define DEBUG false

%{
#include <pthread.h>
%}

vtypedef func1(a:t@ype) = @{ func=a -<fun1> void, arg=a }
vtypedef func2 = @{ func=() -<fun1> void }
vtypedef func3 = @{ func=() -<lincloptr1> void }

datavtype func(a:t@ype) = 
| FUNC1 (a) of func1(a)
| FUNC2 of func2
| FUNC3 of func3

datavtype pool_(a:t@ype) = 
| {l1,l2,l3,l4,l5: agz} 
  POOL of @{ 
      size=intGt(0), 
      running=bool,
      num_working=intGte(0),
      num_alive=intGte(0),
      threads=List_vt(tid), 
      refcount=shared(ptr),
      has_work=bool,
      has_work_cv=condvar_vt(l1),
      has_work_mutex=mutex_vt(l2),
      thread_count_cv=condvar_vt(l3),
      thread_count_mutex=mutex_vt(l4), 
      queue_mutex=mutex_vt(l5),
      queue= [n:nat] deque(func(a), n)
  }

assume pool(a:t@ype) = pool_(a)

implement {a} pool_ref(pool) =
  let
    val+ @POOL(p) = pool
    val (pf | s) = shared_lock(p.refcount)
    val refcount = $UNSAFE.ptr2int(s)
    val () = if(DEBUG) then println!("pool_ref refcount: ", refcount+1)
    val () = shared_unlock(pf | p.refcount, $UNSAFE.int2ptr(refcount+1))
    prval () = fold@(pool)
  in
    $UN.castvwtp1{pool(a)}(pool)
  end

implement {a} pool_unref(pool) =
  let
    val+ @POOL(p) = pool
    val (pf | s) = shared_lock(p.refcount)
    val refcount = $UNSAFE.ptr2int(s)
    val () = shared_unlock(pf | p.refcount, s)
  in
    if refcount <= 1 then
      let
        val () = if(DEBUG) then println!("pool_unref refcount: ", refcount-1)
        prval () = fold@(pool)
        val () = pool_destroy(pool)
      in
      end
    else
      let
        val (pf | s) = shared_lock(p.refcount)
        val () = if(DEBUG) then println!("pool_unref refcount: ", refcount-1)
        val () = shared_unlock(pf | p.refcount, $UNSAFE.int2ptr(refcount-1))
        prval () = fold@(pool)
        prval () = $UN.cast2void(pool)
      in
      end
  end

implement {a} pool_destroy(pool) =
  let
    val @POOL(p) = pool
    val (pf | s) = shared_lock(p.refcount)
    val refcount = $UNSAFE.ptr2int(s)
    val () = shared_unlock(pf | p.refcount, s)
  in
      let
        val len = lindeque_length(p.queue)
        val () = if(DEBUG) then println!("There are ", len, " jobs still in the queue")
        val () = fold@(pool)
        fun drain(pool: !pool(a), i: int): void = () where {
            val @POOL(p) = pool
            val () = if(i = 0) then fold@(pool) else () where {
                val len = lindeque_length(p.queue)
                val () = assertloc(len > 0)
                val f = lindeque_takeout_atend(p.queue)
                val () = case+ f of
                        | ~FUNC1(_) => ()
                        | ~FUNC2(_) => ()
                        | ~FUNC3(f) => cloptr_free($UNSAFE.castvwtp0{cloptr(void)}(f.func))
                val () = fold@(pool)
                val () = drain(pool, i - 1)
            }
        }
        val () = drain(pool, len)
        val ~POOL(p) = pool
        val () = case+ shared_unref(p.refcount) of
               | ~None_vt () => ()
               | ~Some_vt(_) => ()
        val () = mutex_vt_destroy(p.has_work_mutex)
        val () = mutex_vt_destroy(p.thread_count_mutex)
        val () = mutex_vt_destroy(p.queue_mutex)
        val () = condvar_vt_destroy(p.thread_count_cv)
        val () = condvar_vt_destroy(p.has_work_cv)
        val () = list_vt_free(p.threads)
        val () = assertloc(lindeque_is_nil(p.queue))
        prval () = lindeque_free_nil(p.queue)
      in
      end
  end

implement {a} make_pool(sz) = p where {
  val () = assertloc(sz > 0)
  val p = POOL(@{
      size = sz,
      running = true,
      num_working = 0,
      num_alive = 0,
      threads = list_vt_nil(),
      refcount = shared_make($UNSAFE.int2ptr(1)),
      has_work = false,
      has_work_cv = unsafe_condvar_t2vt(condvar_create_exn()),
      has_work_mutex = unsafe_mutex_t2vt(mutex_create_exn()),
      thread_count_cv = unsafe_condvar_t2vt(condvar_create_exn()),
      thread_count_mutex = unsafe_mutex_t2vt(mutex_create_exn()),
      queue_mutex = unsafe_mutex_t2vt(mutex_create_exn()),
      queue = lindeque_nil()
  })
}

fn {a:t@ype} signal_has_work(pool: !pool(a)): void = () where {
  val @POOL(p) = pool
  val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.has_work_mutex))
  val () = p.has_work := true
  val () = condvar_signal(unsafe_condvar_vt2t(p.has_work_cv))
  val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.has_work_mutex))
  val () = fold@(pool)
}

fn signal_ready{l,l2:agz}(m: !mutex_vt(l), cv: !condvar_vt(l2)): void = () where {
  val (pf|()) = mutex_lock(unsafe_mutex_vt2t(m))
  val () = condvar_signal(unsafe_condvar_vt2t(cv))
  val () = mutex_unlock(pf | unsafe_mutex_vt2t(m))
}

fn {a:t@ype} queue_has_work(pool: !pool(a)): Option_vt(func(a)) = res where {
    val+ @POOL(p) = pool
    val len = lindeque_length(p.queue)
    val res = (case+ 0 of
              | _ when len <= 0 => (fold@(pool); None_vt())
              | _ when len = 1 => sm where {
                 val f = lindeque_takeout_atend(p.queue)
                 val () = fold@(pool)
                 val sm = Some_vt(f)
              }
              | _ when len > 1 => sm where {
                 val f = lindeque_takeout_atend(p.queue)
                 val () = fold@(pool)
                 val () = signal_has_work(pool)
                 val sm = Some_vt(f)
              }
              | _ => (fold@(pool); None_vt())): Option_vt(func(a))
   (* val () = fold@(pool) *)
}

fun {a:t@ype} wait_loop(pool: !pool(a)): void = () where {
  val+ POOL(p) = pool
  val () = if(p.has_work) then () else () where {
      val mutex = unsafe_mutex_vt2t(p.has_work_mutex)
      val (pf|()) = mutex_lock(mutex)
      val cv_haswork = unsafe_condvar_vt2t(p.has_work_cv)
      val () = if(DEBUG) then println!("waiting for work...")
      val () = condvar_wait(pf | cv_haswork, mutex)
      val _ = usleep(10)
      val () = mutex_unlock(pf | mutex)
      val () = wait_loop(pool)
  }
}

fun {a:t@ype} ready_wait(pool: !pool(a)): void = () where {
  val+ @POOL(p) = pool
  val () = if(DEBUG) then println!("READY: ", p.num_alive >= p.size)
  val mutex = unsafe_mutex_vt2t(p.thread_count_mutex)
  val (pf|()) = mutex_lock(mutex)
  fun loop{l:agz;a:t@ype}(pf: !locked_v(l) |pool: !pool(a), m: !mutex(l)): void = () where {
      val+ @POOL(p) = pool
      val () = if(p.num_alive < p.size) then () where {
          val cv_haswork = unsafe_condvar_vt2t(p.thread_count_cv)
          val () = if(DEBUG) then println!("thread done... ", p.size)
          val () = condvar_wait(pf | cv_haswork, m)
          val _ = usleep(10)
          val () = fold@(pool)
          val () = loop(pf | pool, m)
      } else fold@(pool)
  }
  val () = fold@(pool)
  val () = loop(pf | pool, mutex)
  val () = mutex_unlock(pf | mutex)
}

fun {a:t@ype} done_wait(pool: !pool(a)): void = () where {
  val+ @POOL(p) = pool
  val mutex = unsafe_mutex_vt2t(p.thread_count_mutex)
  val (pf|()) = mutex_lock(mutex)
  fun loop{l:agz;a:t@ype}(pf: !locked_v(l) |pool: !pool(a), m: !mutex(l)): void = () where {
      val+ @POOL(p) = pool
      val () = if(p.num_alive > 0) then () where {
          val cv_haswork = unsafe_condvar_vt2t(p.thread_count_cv)
          val () = if(DEBUG) then println!("thread done... ", p.size)
          val () = condvar_wait(pf | cv_haswork, m)
          val _ = usleep(10)
          val () = fold@(pool)
          val () = loop(pf | pool, m)
      } else fold@(pool)
  }
  val () = fold@(pool)
  val () = loop(pf | pool, mutex)
  val () = mutex_unlock(pf | mutex)
}

fun {a:t@ype} work_loop(pool: !pool(a)): void = () where {
  val () = wait_loop(pool)
  val () = if(DEBUG) then println!("done waiting... ", athread_self())
  val+ @POOL(p) = pool
  val () = if(DEBUG) then println!("threadpool is running: ", p.running)
  val () = if(p.running) then () where {
         val () = fold@(pool)
         val fopt = queue_has_work(pool)
         val+ @POOL(p) = pool
         val () = case+ fopt of
         | ~None_vt() => () where {
            // no work in the queue, so loop
            val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.has_work_mutex))
            val () = p.has_work := false
            val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.has_work_mutex))
            val () = fold@(pool)
            val () = work_loop(pool)
         }
         | ~Some_vt work => () where {
            // got some work to do...
            val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.thread_count_mutex))
            val () = p.num_working := p.num_working + 1
            val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
            val () = case+ work of
                     | ~FUNC1 w => w.func(w.arg)
                     | ~FUNC2 w => w.func()
                     | ~FUNC3 w => (w.func(); cloptr_free($UNSAFE.castvwtp0{cloptr(void)}(w.func)))
            val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.thread_count_mutex))
            val () = p.num_working := p.num_working - 1
            val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
            val () = fold@(pool)
            val () = work_loop(pool)
         }
    } else {
        // not running, so end the loop
        val () = fold@(pool)
        val () = if(DEBUG) then println!("work loop done... ", athread_self())
    }       
}

fun {a:t@ype} create_threads(pool: !pool(a), i: int): void = () where {
    val p1 = pool_ref(pool)
    val _ = athread_create_cloptr_exn(llam() =<cloptr1> () where {
      val+ @POOL(p) = p1
      val () = if(DEBUG) then println!("creating thread: ", athread_self())
      val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.thread_count_mutex))
      val () = p.num_alive := p.num_alive + 1
      val () = if(DEBUG) then println!("Num alive: ", p.num_alive)
      val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
      (* val () = signal_ready(p.thread_count_mutex, p.thread_count_cv) *)
      val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.thread_count_mutex))
      val () = condvar_signal(unsafe_condvar_vt2t(p.thread_count_cv))
      val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
      val () = fold@(p1)
      val () = work_loop(p1)
      val+ @POOL(p) = p1
      val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.thread_count_mutex))
      val () = p.num_alive := p.num_alive - 1
      val () = if(DEBUG) then println!("Num alive: ", p.num_alive)
      val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
      val () = assertloc(p.num_alive >= 0)
      (* val () = signal_ready(p.thread_count_mutex, p.thread_count_cv) *)
      val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.thread_count_mutex))
      val () = condvar_signal(unsafe_condvar_vt2t(p.thread_count_cv))
      val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
      val () = fold@(p1)
      val () = pool_unref(p1)
      val () = if(DEBUG) then println!("thread dead... ", athread_self())
    })
    val () = if (i = 1) then () else create_threads(pool, i-1)
    val () = ready_wait(pool)
  }

implement {a} init_pool(pool) = () where {
  val+ POOL(p) = pool
  val sz = p.size
  val () = create_threads(pool, sz)
}

fn {a:t@ype} add_work_helper(p: !pool(a), f: func(a)): void = () where {
  val+ @POOL(pool) = p
  val () = lindeque_insert_atbeg(pool.queue, f)
  val (pf|()) = mutex_lock(unsafe_mutex_vt2t(pool.has_work_mutex))
  val () = pool.has_work := true
  val () = condvar_signal(unsafe_condvar_vt2t(pool.has_work_cv))
  val () = mutex_unlock(pf | unsafe_mutex_vt2t(pool.has_work_mutex))
  prval() = fold@(p)
}

implement {a} add_work(p, f) = add_work_helper(p, FUNC2(@{func=f}))

implement {a} add_work2(p, f) = add_work_helper(p, FUNC3(@{func=f}))

implement {a} add_work_witharg(p, f, x) = add_work_helper(p, FUNC1(@{func=f, arg=x}))

implement {a} stop_pool(pool) = () where {
  val+ @POOL(p) = pool
  val () = p.running := false
  val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.thread_count_mutex))
  val () = if(DEBUG) then println!("Num alive: ", p.num_alive)
  val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
  val () = assertloc(p.num_alive >= 0)
  val () = fold@(pool)
  fun loopx(pool: !pool(a)): void = () where {
      val+ @POOL(p) = pool
      val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.thread_count_mutex))
      val () = if(DEBUG) then println!("NUMALIVE: ", p.num_alive)
      val () = if(p.num_alive > 0) then () where {
          val (pf2|()) = mutex_lock(unsafe_mutex_vt2t(p.has_work_mutex))
          val () = p.has_work := true
          val () = condvar_signal(unsafe_condvar_vt2t(p.has_work_cv))
          val () = mutex_unlock(pf2 | unsafe_mutex_vt2t(p.has_work_mutex))
          val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
          val _ = usleep(1)
          val () = fold@(pool)
          val () = loopx(pool)
      } else () where {
          val () = if(DEBUG) then println!("every thread is dead")
          val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.thread_count_mutex))
          val () = fold@(pool)
      }    
  }
  val () = loopx(pool)
  val+ @POOL(p) = pool
  val () = assertloc(p.num_alive = 0)
  prval () = fold@(pool)
  val _ = usleep(1000)
  val () = if(DEBUG) then println!("Cleaning up...")
  val () = done_wait(pool)
  val () = pool_unref(pool)
}
