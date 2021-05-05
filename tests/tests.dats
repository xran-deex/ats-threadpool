#include "ats-threadpool.hats"
staload "libats/SATS/athread.sats"

staload $POOL

#define DEBUG true

fn task1(x:int): void = () where {
    val _ = usleep(500000)
    val () = println!("Thread ", athread_self(), " working on task1: ", x)
}
fn task2(x:strptr): void = () where {
    val _ = usleep(1000000)
    // val _ = sleep(5)
    val () = println!("Thread ", athread_self(), " working on task2: ", x)
    val () = free(x)
}

implement main(argc, argv) = 0 where {
    val () = if(DEBUG) then println!("DEBUG!")
    val () = case argc of
            | 2 => println!("ARGS: ", argv[1])
            | _ => ()

    val p = make_pool(10)
    val () = init_pool(p)

    fun loop(p: !Pool, i: int): void = () where {
        val () = add_work(p, llam () => println!("CLOPTR: ", i))
        val x = copy("3")
        val () = add_work(p, llam () => task1(1))
        val () = add_work(p, llam () => task2(x))
        val () = if(i = 1) then () else loop(p, i-1)
    }
    val () = loop(p, 20)
    val () = add_work(p, llam () => {
        val () = println!("starting...")
        val _ = sleep(1)
        val () = println!("Hello")
        val _ = sleep(1)
        val () = println!("World")
        val _ = sleep(1)
        val () = println!("Done")
    })

    // val _ = sleep(1)
    val () = println!("Stopping...")
    val () = stop_pool(p)
}
