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
  MPI_Init(&argc, &argv);

  int blockSize, rank, totalRanks, numBytes, stride;
  char* outputFilepath, *data;
  MPI_File outputMPIFile;
  ticks start = 0, finish = 0;
  double readSeconds, writeSeconds;

  // parse command line arguments
  if (argc != 3) {
    printf("Usage: %s [block size=1|2|4|8|16] [output-file]\n", argv[0]);
    return -1;
  }
  blockSize = atoi(argv[1]);
  outputFilepath = argv[2];

  // get MPI info
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &totalRanks);

  // allocate blocksize MB of data
  numBytes = blockSize * 1024 * 1024;
  stride = numBytes * totalRanks;
  data = (char*)malloc(numBytes);
  if (data == NULL) {
    fprintf(stderr, "Error: Process %d failed to allocate memory\n", rank);
    MPI_Abort(MPI_COMM_WORLD, -1);
  }
  // fill with dummy data
  for (int i = 0; i < numBytes; i++) {
    data[i] = 1;
  }
  MPI_Barrier(MPI_COMM_WORLD);

  // time the data write
  start = getticks();
  MPI_File_open(MPI_COMM_WORLD, outputFilepath, MPI_MODE_CREATE | MPI_MODE_WRONLY, MPI_INFO_NULL, &outputMPIFile);
  // each rank writes its own block of data 32 times (interleaved with the other ranks)
  for (int i = 0; i < 32; i++) {
    MPI_File_write_at(outputMPIFile, i * stride + rank * numBytes, data, numBytes, MPI_CHAR, MPI_STATUS_IGNORE);
  }
  MPI_File_close(&outputMPIFile);
  MPI_Barrier(MPI_COMM_WORLD);
  finish = getticks();
  writeSeconds = (double)(finish - start) / (double)512000000.0;
  
  // time the data read
  start = getticks();
  MPI_File_open(MPI_COMM_WORLD, outputFilepath, MPI_MODE_RDONLY, MPI_INFO_NULL, &outputMPIFile);
  // each rank reads its own block of data 32 times (interleaved with the other ranks)
  for (int i = 0; i < 32; i++) {
    MPI_File_read_at(outputMPIFile, i * stride + rank * numBytes, data, numBytes, MPI_CHAR, MPI_STATUS_IGNORE);
  }
  MPI_File_close(&outputMPIFile);
  MPI_Barrier(MPI_COMM_WORLD);
  finish = getticks();
  readSeconds = (double)(finish - start) / (double)512000000.0;
  
  // print the MB/s (only rank 0 reports)
  if (rank == 0) {
    double readMbPerSecond = (double) (blockSize * totalRanks * 32) / readSeconds;
    double writeMbPerSecond = (double) (blockSize * totalRanks * 32) / writeSeconds;
    printf("Read: %lf\n", readMbPerSecond);
    printf("Write: %lf\n", writeMbPerSecond);
  }

  // clean up
  free(data);
  MPI_Finalize();

  return 0;
}
