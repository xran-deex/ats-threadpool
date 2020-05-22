#include "./../HATS/includes.hats"
staload "./../SATS/threadpool.sats"

#define ATS_DYNLOADFLAG 0

#define DEBUG false

%{
#include <pthread.h>
%}

datavtype Pool_ = 
| {l1,l2,l3,l4:agz} 
  POOL of
  @{ 
      thread_cnt=intGt(0), 
      running=bool,
      alive_cnt=intGte(0),
      working_cnt=intGte(0),
      refcount=shared(ptr),
      work_cond=condvar_vt(l1),
      work_mutex=mutex_vt(l2),
      working_cond=condvar_vt(l3),
      alive_cond=condvar_vt(l4),
      queue= [n:nat] deque(work, n)
  }


assume Pool = Pool_

implement {} pool_ref(pool) =
  let
    val+ @POOL(p) = pool
    val (pf | s) = shared_lock(p.refcount)
    val refcount = $UNSAFE.ptr2int(s)
    val () = if(DEBUG) then println!("pool_ref refcount: ", refcount+1)
    val () = shared_unlock(pf | p.refcount, $UNSAFE.int2ptr(refcount+1))
    prval () = fold@(pool)
  in
    $UNSAFE.castvwtp1{Pool}(pool)
  end

implement {} pool_unref(pool) =
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

implement {} pool_destroy(pool) =
  let
    val @POOL(p) = pool
    val (pf | s) = shared_lock(p.refcount)
    val refcount = $UNSAFE.ptr2int(s)
    val () = shared_unlock(pf | p.refcount, s)
    prval () = fold@(pool)
  in
      let
        val ~POOL(p) = pool
        val () = case+ shared_unref(p.refcount) of
               | ~None_vt () => ()
               | ~Some_vt(_) => ()
        val () = mutex_vt_destroy(p.work_mutex)
        val () = condvar_vt_destroy(p.work_cond)
        val () = condvar_vt_destroy(p.working_cond)
        val () = condvar_vt_destroy(p.alive_cond)
        val () = assertloc(lindeque_is_nil(p.queue))
        prval () = lindeque_free_nil(p.queue)
      in
      end
  end

implement {} make_pool(sz) = p where {
  val () = assertloc(sz > 0)
  val p = POOL(@{
      thread_cnt = sz,
      running = true,
      alive_cnt = 0,
      working_cnt = 0,
      refcount = shared_make($UNSAFE.int2ptr(1)),
      work_cond = unsafe_condvar_t2vt(condvar_create_exn()),
      work_mutex = unsafe_mutex_t2vt(mutex_create_exn()),
      working_cond = unsafe_condvar_t2vt(condvar_create_exn()),
      alive_cond = unsafe_condvar_t2vt(condvar_create_exn()),
      queue = lindeque_nil()
  })
}

fn {} queue_has_work(pool: !Pool): Option_vt(work) = res where {
    val+ @POOL(p) = pool
    val len = lindeque_length(p.queue)
    val () = if(DEBUG) then println!("queue length: ", len)
    val res = (case+ 0 of
              | _ when len = 1 => sm where {
                 val () = if(DEBUG) then println!("checking work...")
                 val f = lindeque_takeout_atend(p.queue)
                 val () = if(DEBUG) then println!("got work...")
                 val sm = Some_vt(f)
              }
              | _ when len > 1 => sm where {
                 val () = if(DEBUG) then println!("checking work...")
                 val f = lindeque_takeout_atend(p.queue)
                 val () = if(DEBUG) then println!("got work out of queue: ", athread_self())
                 val sm = Some_vt(f)
              }
              | _ => None_vt()): Option_vt(work)
    val () = fold@(pool)
}

fun {} wait_loop{l:agz}(pf: !locked_v(l) | pool: !Pool, mutex: !mutex(l)): void = () where {
  val+POOL(p) = pool
  val len = lindeque_length(p.queue)
  val () = if(p.running && len = 0) then {
      val cv_haswork = unsafe_condvar_vt2t(p.work_cond)
      val () = if(DEBUG) then println!("waiting for work...")
      val () = condvar_wait(pf | cv_haswork, mutex)
      val () = wait_loop(pf | pool, mutex)
  }
}

fun {} done_wait(pool: !Pool): void = () where {
  val+ @POOL(p) = pool
  val mutex = unsafe_mutex_vt2t(p.work_mutex)
  val (pf|()) = mutex_lock(mutex)
  fun loop{l:agz;a:t@ype}(pf: !locked_v(l) |pool: !Pool, m: !mutex(l)): void = {
      val+ @POOL(p) = pool
      val () = if(p.alive_cnt > 0) then () where {
          val cv_haswork = unsafe_condvar_vt2t(p.alive_cond)
          val () = if(DEBUG) then println!("working count... ", p.alive_cnt)
          val () = condvar_wait(pf | cv_haswork, m)
          val () = fold@(pool)
          val () = loop(pf | pool, m)
      } else {
          val () = if(DEBUG) then println!("working count... ", p.working_cnt)
        prval() = fold@(pool)
      }
  }
  val () = fold@(pool)
  val () = loop(pf | pool, mutex)
  val () = mutex_unlock(pf | mutex)
}

fun{} work_loop(pool: !Pool): void = () where {
  val+@POOL(p) = pool
  val mutex = unsafe_mutex_vt2t(p.work_mutex)
  val running = p.running
  val len = lindeque_length(p.queue)
  val () = fold@(pool)
  val (pf |()) = mutex_lock(mutex)
  val () = wait_loop(pf | pool, mutex)
  // continue while the threadpool is running OR if there are still work in the queue
  val () = if(running || len > 0) then {
         val () = if(DEBUG) then println!("checking for work in queue ", athread_self())
         val fopt = queue_has_work(pool)
         val () = if(DEBUG) then println!("checking for work in queue (after)", athread_self())
         val+ @POOL(p) = pool
         val () = case+ fopt of
         | ~None_vt() => () where {
            // no work in the queue, so loop
            val () = mutex_unlock(pf | mutex)
            val () = fold@(pool)
            val () = work_loop(pool)
         }
         | ~Some_vt work => () where {
            // got some work to do..._
            val () = if(DEBUG) then println!("work in queue ", athread_self())
            val () = p.working_cnt := p.working_cnt + 1
            val () = mutex_unlock(pf | mutex)

            val () = work()
            val () = cloptr_free($UNSAFE.castvwtp0{cloptr(void)}(work))

            val (pf1|()) = mutex_lock(mutex)
            val () = p.working_cnt := p.working_cnt - 1
            val () = mutex_unlock(pf1 | mutex)
            val () = fold@(pool)
            val () = if(DEBUG) then println!("done working in queue ", athread_self())
            val () = work_loop(pool)
         }
    } else {
        // not running, so end the loop
        val () = if(DEBUG) then println!("work loop done... ", athread_self())
        val () = mutex_unlock(pf | mutex)
    }       
}

fn{} increment_alive(pool: !Pool): void = {
  val+ @POOL(p) = pool
  val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.work_mutex))
  val () = p.alive_cnt := p.alive_cnt + 1
  val () = if(DEBUG) then println!("Num alive: ", p.alive_cnt)
  val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.work_mutex))
  val () = fold@(pool)
}

fn{} signal_done(pool: !Pool): void = {
  val+ @POOL(p) = pool
  val (pf|()) = mutex_lock(unsafe_mutex_vt2t(p.work_mutex))
  val () = p.alive_cnt := p.alive_cnt - 1
  val () = condvar_signal(unsafe_condvar_vt2t(p.alive_cond))
  val () = if(DEBUG) then println!("Num alive: ", p.alive_cnt)
  val () = mutex_unlock(pf | unsafe_mutex_vt2t(p.work_mutex))
  val () = assertloc(p.alive_cnt >= 0)
  val () = fold@(pool)
}

fun {} create_threads(pool: !Pool, i: int): void = () where {
    val p1 = pool_ref(pool)
    val _ = athread_create_cloptr_exn(llam() =<cloptr1> () where {
      val () = if(DEBUG) then println!("creating thread: ", athread_self())
      val () = increment_alive(p1)

      val () = work_loop(p1)

      val () = signal_done(p1)

      val () = pool_unref(p1)
      val () = if(DEBUG) then println!("thread dead... ", athread_self())
    })
    val () = if (i = 1) then () else create_threads(pool, i-1)
    // val () = ready_wait(pool)
  }

implement {} init_pool(pool) = () where {
  val+ POOL(p) = pool
  val sz = p.thread_cnt
  val () = create_threads(pool, sz)
}

fn {} add_work_helper(p: !Pool, f: work): void = () where {
  val+ @POOL(pool) = p
  val (pf|()) = mutex_lock(unsafe_mutex_vt2t(pool.work_mutex))
  val () = lindeque_insert_atbeg(pool.queue, f)
  val () = condvar_signal(unsafe_condvar_vt2t(pool.work_cond))
  val () = mutex_unlock(pf | unsafe_mutex_vt2t(pool.work_mutex))
  prval() = fold@(p)
}

implement {} add_work(p, f) = add_work_helper(p, f)

fun{} drain{l:agz}(pf: !locked_v(l) | pool: !Pool, i: int, mutex: !mutex(l)): void = () where {
      val @POOL(p) = pool
      val () = if(i = 0) then {
          prval() = fold@(pool)
      } else {
          val len = lindeque_length(p.queue)
          val () = assertloc(len > 0)
          val f = lindeque_takeout_atend(p.queue)
          val () = cloptr_free($UNSAFE.castvwtp0{cloptr(void)}(f))
          val () = fold@(pool)
          val () = drain(pf | pool, i - 1, mutex)
      }
  }

implement {} stop_pool(pool) = () where {
  val+@POOL(p) = pool
  val mutex = unsafe_mutex_vt2t(p.work_mutex)
  val (pf|()) = mutex_lock(mutex)
  val len = lindeque_length(p.queue)
  val () = if(DEBUG) then println!("There are ", len, " jobs still in the queue")
  val () = fold@(pool)

  // val () = drain(pf | pool, len, mutex)

  val+ @POOL(p) = pool
  val () = p.running := false
  val () = condvar_broadcast(unsafe_condvar_vt2t(p.work_cond))
  val () = fold@(pool)
  val () = mutex_unlock(pf | mutex)

  val () = if(DEBUG) then println!("Cleaning up...")
  val () = done_wait(pool)

  val () = pool_unref(pool)
  val _ = usleep(10)
}
