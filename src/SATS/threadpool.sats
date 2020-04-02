#include "./../HATS/includes.hats"

absvtype pool(a:t@ype)

fn {a:t@ype} make_pool(sz: intGte(0)): pool(a)
fn {a:t@ype} init_pool(pool: !pool(a)): void
fn {a:t@ype} pool_ref(p: !pool(a)): pool(a)
fn {a:t@ype} pool_unref(p: pool(a)): void
fn {a:t@ype} pool_destroy(p: pool(a)): void
fn {a:t@ype} add_work(p: !pool(a), f: () -<fun1> void): void
fn {a:t@ype} add_work2(p: !pool(a), f: () -<lincloptr1> void): void
fn {a:t@ype} add_work_witharg(p: !pool(a), f: a -<fun1> void, arg: a): void
fn {a:t@ype} stop_pool(pool: pool(a)): void

