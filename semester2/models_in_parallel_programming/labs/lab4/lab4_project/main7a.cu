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

// Kernel modificat pentru a procesa doar un numar specific de randuri (rows_per_proc)
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

// COMPILARE: /usr/local/cuda-13/bin/nvcc `mpicc --showme:compile` `mpicc --showme:link` -arch=sm_80 -o main7a main7a.cu
// RULARE LOCAL: mpirun -np 4 ./main7a 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin
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

    float *h_A = NULL, *h_B = NULL, *h_C = NULL;
    float *h_A_sub = (float *)malloc(sub_size);
    float *h_B_all = (float *)malloc(full_size);
    float *h_C_sub = (float *)malloc(sub_size);

    double start_total, start_read, end_read, start_mul, end_mul, start_write, end_write;

    if (rank == 0) {
        start_total = get_time_ms();
        start_read = get_time_ms();
        h_A = (float *)malloc(full_size);
        h_B = (float *)malloc(full_size);
        h_C = (float *)malloc(full_size);

        FILE *fa = fopen(argv[2], "rb");
        FILE *fb = fopen(argv[3], "rb");
        fread(h_A, sizeof(float), M * M, fa);
        fread(h_B, sizeof(float), M * M, fb);
        fclose(fa); fclose(fb);
        end_read = get_time_ms();
        
        // Copiem B pentru procesul 0 in buffer-ul de broadcast
        memcpy(h_B_all, h_B, full_size);
        start_mul = get_time_ms();
    }

    // Distribuirea datelor
    // 1. Trimitem bucati din A catre toti
    MPI_Scatter(h_A, rows_per_proc * M, MPI_FLOAT, h_A_sub, rows_per_proc * M, MPI_FLOAT, 0, MPI_COMM_WORLD);
    // 2. Trimitem toata matricea B catre toti
    MPI_Bcast(h_B_all, M * M, MPI_FLOAT, 0, MPI_COMM_WORLD);

    // --- Calcul CUDA pe fiecare proces ---
    float *d_A_sub, *d_B, *d_C_sub;
    gpuErrchk(cudaMalloc(&d_A_sub, sub_size));
    gpuErrchk(cudaMalloc(&d_B, full_size));
    gpuErrchk(cudaMalloc(&d_C_sub, sub_size));

    gpuErrchk(cudaMemcpy(d_A_sub, h_A_sub, sub_size, cudaMemcpyHostToDevice));
    gpuErrchk(cudaMemcpy(d_B, h_B_all, full_size, cudaMemcpyHostToDevice));

    // Analiza Block Size: 1024 (32x32)
    dim3 threadsPerBlock(32, 32); 
    dim3 blocksPerGrid((M + threadsPerBlock.x - 1) / threadsPerBlock.x,
                       (rows_per_proc + threadsPerBlock.y - 1) / threadsPerBlock.y);

    matrixMulKernel<<<blocksPerGrid, threadsPerBlock>>>(d_A_sub, d_B, d_C_sub, M, rows_per_proc);
    gpuErrchk(cudaPeekAtLastError());
    gpuErrchk(cudaDeviceSynchronize());

    gpuErrchk(cudaMemcpy(h_C_sub, d_C_sub, sub_size, cudaMemcpyDeviceToHost));

    // Colectarea rezultatelor
    MPI_Gather(h_C_sub, rows_per_proc * M, MPI_FLOAT, h_C, rows_per_proc * M, MPI_FLOAT, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        end_mul = get_time_ms();
        start_write = get_time_ms();
        FILE *fc = fopen(argv[4], "wb");
        fwrite(h_C, sizeof(float), M * M, fc);
        fclose(fc);
        end_write = get_time_ms();

        printf("t_reading: %.0f ms\n", end_read - start_read);
        printf("t_addition: %.0f ms\n", end_mul - start_mul);
        printf("t_writing: %.0f ms\n", end_write - start_write);
        printf("t_total: %.0f ms\n", get_time_ms() - start_total);

        free(h_A); free(h_B); free(h_C);
    }

    free(h_A_sub); free(h_B_all); free(h_C_sub);
    cudaFree(d_A_sub); cudaFree(d_B); cudaFree(d_C_sub);
    
    MPI_Finalize();
    return 0;
}