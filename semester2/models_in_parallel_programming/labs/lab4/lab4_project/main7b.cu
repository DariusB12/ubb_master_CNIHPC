#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <mpi.h>
#include <time.h>

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true) {
   if (code != cudaSuccess) {
      fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

__global__ void matrixMulKernel(float *A_sub, float *B, float *C_sub, int M, int rows_per_proc) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < rows_per_proc && col < M) {
        float sum = 0;
        for (int i = 0; i < M; i++) {
            sum += A_sub[row * M + i] * B[i * M + col];
        }
        C_sub[row * M + col] = sum;
    }
}

double get_time_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0;
}


// COMPILARE: /usr/local/cuda-13/bin/nvcc `mpicc --showme:compile` `mpicc --showme:link` -arch=sm_80 -o main7b main7b.cu
// RULARE LOCAL: mpirun -np 4 ./main7b 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin

int main(int argc, char *argv[]) {
    int rank, size_proc;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size_proc);

    if (argc < 5) {
        if (rank == 0) printf("Utilizare: mpirun -np 4 %s <M> <A.bin> <B.bin> <C.bin>\n", argv[0]);
        MPI_Finalize();
        return 1;
    }

    int M = atoi(argv[1]);
    int rows_per_proc = M / size_proc;
    size_t full_size = (size_t)M * M * sizeof(float);
    size_t sub_size = (size_t)rows_per_proc * M * sizeof(float);

    float *h_A_sub = (float *)malloc(sub_size);
    float *h_B_all = (float *)malloc(full_size);
    float *h_C_sub = (float *)malloc(sub_size);
    float *h_C_final = NULL;

    double start_total = 0, start_read, end_read, start_mul, end_mul, start_write, end_write;

    if (rank == 0) start_total = get_time_ms();

    // --- 1. PARALLEL READING (MPI-IO) ---
    start_read = get_time_ms();
    
    MPI_File fh_a, fh_b;
    MPI_Status status;

    // Deschidem fișierul A pentru citire paralelă
    if (MPI_File_open(MPI_COMM_WORLD, argv[2], MPI_MODE_RDONLY, MPI_INFO_NULL, &fh_a) != MPI_SUCCESS) {
        if (rank == 0) fprintf(stderr, "Eroare deschidere fisier A\n");
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    // Fiecare proces calculează de unde începe bucata sa în fișierul A
    MPI_Offset offset_a = (MPI_Offset)rank * sub_size;
    MPI_File_read_at(fh_a, offset_a, h_A_sub, rows_per_proc * M, MPI_FLOAT, &status);
    MPI_File_close(&fh_a);

    // Citirea matricei B (Toți citesc tot pentru a evita Broadcast-ul ulterior)
    if (MPI_File_open(MPI_COMM_WORLD, argv[3], MPI_MODE_RDONLY, MPI_INFO_NULL, &fh_b) != MPI_SUCCESS) {
        if (rank == 0) fprintf(stderr, "Eroare deschidere fisier B\n");
        MPI_Abort(MPI_COMM_WORLD, 1);
    }
    // Toți pornesc de la începutul fișierului B
    MPI_File_read_at(fh_b, 0, h_B_all, M * M, MPI_FLOAT, &status);
    MPI_File_close(&fh_b);

    end_read = get_time_ms();

    // --- 2. PARALLEL MULTIPLICATION (CUDA) ---
    start_mul = get_time_ms();
    float *d_A_sub, *d_B, *d_C_sub;
    gpuErrchk(cudaMalloc(&d_A_sub, sub_size));
    gpuErrchk(cudaMalloc(&d_B, full_size));
    gpuErrchk(cudaMalloc(&d_C_sub, sub_size));

    gpuErrchk(cudaMemcpy(d_A_sub, h_A_sub, sub_size, cudaMemcpyHostToDevice));
    gpuErrchk(cudaMemcpy(d_B, h_B_all, full_size, cudaMemcpyHostToDevice));

    dim3 threadsPerBlock(32, 32); 
    dim3 blocksPerGrid((M + threadsPerBlock.x - 1) / threadsPerBlock.x,
                       (rows_per_proc + threadsPerBlock.y - 1) / threadsPerBlock.y);

    matrixMulKernel<<<blocksPerGrid, threadsPerBlock>>>(d_A_sub, d_B, d_C_sub, M, rows_per_proc);
    gpuErrchk(cudaPeekAtLastError());
    gpuErrchk(cudaDeviceSynchronize());

    gpuErrchk(cudaMemcpy(h_C_sub, d_C_sub, sub_size, cudaMemcpyDeviceToHost));
    end_mul = get_time_ms();

    // --- 3. PARALLEL WRITING (MPI-IO) ---
    start_write = get_time_ms();
    MPI_File fh_c;
    if (MPI_File_open(MPI_COMM_WORLD, argv[4], MPI_MODE_CREATE | MPI_MODE_WRONLY, MPI_INFO_NULL, &fh_c) != MPI_SUCCESS) {
        if (rank == 0) fprintf(stderr, "Eroare deschidere fisier C\n");
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    MPI_Offset offset_c = (MPI_Offset)rank * sub_size;
    MPI_File_write_at(fh_c, offset_c, h_C_sub, rows_per_proc * M, MPI_FLOAT, &status);
    MPI_File_close(&fh_c);
    end_write = get_time_ms();

    // Afișare timpi (doar Rank 0 colectează datele de timp pentru raport)
    if (rank == 0) {
        printf("t_reading: %.0f ms\n", end_read - start_read);
        printf("t_addition: %.0f ms\n", end_mul - start_mul);
        printf("t_writing: %.0f ms\n", end_write - start_write);
        printf("t_total: %.0f ms\n", get_time_ms() - start_total);
    }

    free(h_A_sub); free(h_B_all); free(h_C_sub);
    cudaFree(d_A_sub); cudaFree(d_B); cudaFree(d_C_sub);
    
    MPI_Finalize();
    return 0;
}