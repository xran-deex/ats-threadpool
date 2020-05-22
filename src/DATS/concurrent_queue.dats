#include "./../HATS/includes.hats"
staload "./../SATS/concurrent_queue.sats"

#define ATS_DYNLOADFLAG 0

%{
#include <pthread.h>
%}

assume CQueue(a) = queue_(a)

implement{a} make_queue() = q where {
    val q = Q(@{
        queue_mutex = unsafe_mutex_t2vt(mutex_create_exn()),
        queue = lindeque_nil()
    })
}

implement{a} enqueue(q, item) = {
    val+@Q(queue) = q
    val (pf|()) = mutex_lock(unsafe_mutex_vt2t(queue.queue_mutex))
    val () = lindeque_insert_atbeg(queue.queue, item)
    val () = mutex_unlock(pf | unsafe_mutex_vt2t(queue.queue_mutex))
    prval() = fold@q
}

implement{a} dequeue(q) = res where {
    val+@Q(queue) = q
    val (pf|()) = mutex_lock(unsafe_mutex_vt2t(queue.queue_mutex))
    val len = lindeque_length(queue.queue)
    val () = assertloc(len > 0)
    val res = lindeque_takeout_atend(queue.queue)
    val () = mutex_unlock(pf | unsafe_mutex_vt2t(queue.queue_mutex))
    prval() = fold@q
}

implement{a} queue_length(q) = res where {
    val+@Q(queue) = q
    val (pf|()) = mutex_lock(unsafe_mutex_vt2t(queue.queue_mutex))
    val res = lindeque_length(queue.queue)
    val () = mutex_unlock(pf | unsafe_mutex_vt2t(queue.queue_mutex))
    prval() = fold@q
}

implement{a} free_queue(q) = {
    val~Q(queue) = q
    val () = mutex_vt_destroy(queue.queue_mutex)
    val res = lindeque_length(queue.queue)
    val () = assertloc(res = 0)
    prval () = lindeque_free_nil(queue.queue)
}