#include "./../ats-threadpool.hats"
staload "libats/SATS/athread.sats"

staload $POOL

#define DEBUG true

fn task1(x:int): void = () where {
    val _ = usleep(5000)
    val () = println!("Thread ", athread_self(), " working on task1: ", x)
}
fn task2(x:int): void = () where {
    val _ = usleep(5000)
    val () = println!("Thread ", athread_self(), " working on task2: ", x)
}

implement main(argc, argv) = 0 where {
    val () = if(DEBUG) then println!("DEBUG!")
    val () = case argc of
            | 2 => println!("ARGS: ", argv[1])
            | _ => ()

    val p = make_pool<int>(5)
    val () = init_pool(p)

    fun loop(p: !pool(int), i: int): void = () where {
        val () = add_work(p, lam () => println!("!!!"))
        val () = add_work2(p, llam () => println!("CLOPTR: ", i))
        val () = add_work_witharg(p, task1, 1)
        val () = add_work_witharg(p, task2, 3)
        val () = if(i = 1) then () else loop(p, i-1)
    }
    val () = loop(p, 20)

    val _ = sleep(1)
    val () = println!("Stopping...")
    val () = stop_pool(p)
}
