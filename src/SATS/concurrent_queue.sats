#include "./../HATS/includes.hats"

absvtype CQueue(a:vt@ype)

datavtype queue_(a:vt@ype) = 
| {l: agz} 
  Q of @{ 
      queue_mutex=mutex_vt(l),
      queue= [n:nat] deque(a, n)
  }

fn{a:vt@ype} make_queue(): CQueue(a)
fn{a:vt@ype} enqueue(q: !CQueue(a), item: a): void
fn{a:vt@ype} dequeue(q: !CQueue(a)): a
fn{a:vt@ype} free_queue(q: CQueue(a)): void
fn{a:vt@ype} queue_length(q: !CQueue(a)): int