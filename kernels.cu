#include "arena.h"
#include "br_asm.h"
#include "cpu_util.h"
#include "expand.h"
#include "timer.h"
#include "util.h"
#include <stdio.h>
#include <cuda/std/atomic>

#ifdef __i386__
#define MAX_PARALLEL (6)  // maximum number of chases in parallel
#else
#define MAX_PARALLEL (10)
#endif

typedef struct chase_t chase_t;

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      printf("GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

typedef union {
  char pad[AVOID_FALSE_SHARING];
  struct {
    unsigned thread_num;        // which thread is this
    unsigned count;             // count of number of iterations
    void *cycle[MAX_PARALLEL];  // initial address for the chases
    const char *extra_args;
    int dummy;  // useful for confusing the compiler

    const struct generate_chase_common_args *genchase_args;
    size_t nr_threads;
    const chase_t *chase;
    void *flush_arena;
    size_t cache_flush_size;
    bool use_longer_chase;
    int branch_chunk_size;
  } x;
} per_thread_t;

__global__ void chase_simple_kernel(per_thread_t *t) {
  void *p = t->x.cycle[0];

  do {
    x200(p = *(void **)p;)
//   } while (__sync_add_and_fetch(&t->x.count, 200));
  } while (((cuda::std::atomic<unsigned> *)&t->x.count)->fetch_add(200) + 200);
  printf("CIAOOOOOO\n");
  // we never actually reach here, but the compiler doesn't know that
  t->x.dummy = (uintptr_t)p;
}

extern "C" {
    void chase_simple_kernel_gpu(per_thread_t *t) {
        chase_simple_kernel<<<1, 1>>>(t);
        cudaDeviceSynchronize();
    }
}