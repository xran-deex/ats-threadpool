#include "./../HATS/includes.hats"

absvtype Pool

vtypedef work = () -<lincloptr1> void

fn {} make_pool(sz: intGte(0)): Pool
fn {} init_pool(pool: !Pool): void
fn {} pool_ref(p: !Pool): Pool
fn {} pool_unref(p: Pool): void
fn {} pool_destroy(p: Pool): void
fn {} add_work(p: !Pool, w: work): void
fn {} stop_pool(pool: Pool): void

