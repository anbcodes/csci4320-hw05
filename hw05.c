#include <math.h>
#include <mpi.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>

typedef unsigned long long ticks;

// IBM POWER9 System clock with 512MHZ resolution.
static __inline__ ticks getticks(void)
{
  unsigned int tbl, tbu0, tbu1;

  do {
    __asm__ __volatile__ ("mftbu %0" : "=r"(tbu0));
    __asm__ __volatile__ ("mftb %0" : "=r"(tbl));
    __asm__ __volatile__ ("mftbu %0" : "=r"(tbu1));
  } while (tbu0 != tbu1);

  return (((unsigned long long)tbu0) << 32) | tbl;
  // return 0;
}


int main(int argc, char** argv) {
  // Initialize MPI
  MPI_Init(&argc, &argv);

  if (argc != 3) {
    printf("Usage: %s NumElements HaloSize\n", argv[0]);
    return -1;
  }

  // Parse parameters
  // TODO

  // Get rank
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  // Get total ranks
  int totalRanks;
  MPI_Comm_size(MPI_COMM_WORLD, &totalRanks);

  // Get the name of the processor
  char processor_name[MPI_MAX_PROCESSOR_NAME];
  int name_len;
  MPI_Get_processor_name(processor_name, &name_len);

  // Print off a hello world message
  printf("Hello world on processor %s, rank %d"
	 " out of %d processors\n",
	 processor_name, rank, totalRanks);

  bool isMainProcess = (rank == 0);
  if (isMainProcess) {
    // Main process setup code
  }

  // === Multi-process code start ===

  MPI_Barrier(MPI_COMM_WORLD);

  // === Multi-process code end ===

  if (isMainProcess) {
    // Main process end up code
  }

  MPI_Finalize();

  return 0;
}
