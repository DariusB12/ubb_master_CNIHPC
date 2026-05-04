#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <time.h>

// wrapper function pentru verificarea erorilor CUDA, daca o functie apelata cu gpuErrchk da eroare atunci nu lasam programul sa continue cu date gresite
#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true) {
   if (code != cudaSuccess) {
      fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

// Kernel CUDA pentru inmultirea matricelor
// Folosim un index global 1D pentru a mapa elementele matricei MxM
// __global__ Indică faptul că această funcție rulează pe GPU, dar este apelată de pe CPU.
__global__ void matrixMulKernel(float *A, float *B, float *C, int M) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < M && col < M) {
        float sum = 0;
        for (int i = 0; i < M; i++) {
            sum += A[row * M + i] * B[i * M + col];
        }
        C[row * M + col] = sum;
    }
}

double get_time_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0;
}

//COMPILARE: /usr/local/cuda-13/bin/nvcc -arch=sm_80 -o main main.cu
//RULARE LOCAL: ./main 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin

int main(int argc, char *argv[]) {
    if (argc < 5) {
        printf("Utilizare: %s <dim_matrice> <fileA.bin> <fileB.bin> <fileC.bin>\n", argv[0]);
        return 1;
    }

    int M = atoi(argv[1]);
    char *fileA = argv[2];
    char *fileB = argv[3];
    char *fileC = argv[4];
    size_t size = M * M * sizeof(float);

    double start_total = get_time_ms();

    // 1. Sequential Reading
    double start_read = get_time_ms();
    float *h_A = (float *)malloc(size);
    float *h_B = (float *)malloc(size);
    float *h_C = (float *)malloc(size);

    FILE *fa = fopen(fileA, "rb");
    FILE *fb = fopen(fileB, "rb");
    if (!fa || !fb) { printf("Eroare la deschiderea fisierelor de intrare!\n"); return 1; }

    fread(h_A, sizeof(float), M * M, fa);
    fread(h_B, sizeof(float), M * M, fb);
    fclose(fa);
    fclose(fb);
    double end_read = get_time_ms();

    // 2. Parallel Multiplication (CUDA)
    double start_mul = get_time_ms();
    float *d_A, *d_B, *d_C;

    /// alocare memorie direct pe VRAM al GPU
    gpuErrchk(cudaMalloc((void **)&d_A, size));
    gpuErrchk(cudaMalloc((void **)&d_B, size));
    gpuErrchk(cudaMalloc((void **)&d_C, size));

    // cudaMemcpy Copiază datele de pe RAM pe GPU. Acesta este adesea cel mai lent punct dintr-un program GPU.
    gpuErrchk(cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice));
    gpuErrchk(cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice));

    // Analiza Block Size:
    // Pentru 1024 threads, folosim un bloc 32x32 (32*32=1024)
    // Pentru 2048 threads, un bloc ar depasi limita hardware (limita e 1024 per bloc)
    int threadsPerDim = 32; // 32x32 = 1024
    // Daca vrei sa testezi "2048", ai putea pune 32x64, dar kernel-ul va returna eroare.

    dim3 threadsPerBlock(threadsPerDim, threadsPerDim);
    //restul vor da EROARE DEOARECE PE UN BLOC POT AVEA DOAR 1024 DE FIRE
    // dim3 threadsPerBlock(32, 64);
    // dim3 threadsPerBlock(64, 32);
    // dim3 threadsPerBlock(1024, 2);
    dim3 blocksPerGrid((M + threadsPerBlock.x - 1) / threadsPerBlock.x,
                       (M + threadsPerBlock.y - 1) / threadsPerBlock.y);


    matrixMulKernel<<<blocksPerGrid, threadsPerBlock>>>(d_A, d_B, d_C, M);
    // Verificăm dacă lansarea kernelului a avut succes (ex: dacă dimensiunile blocului sunt valide)
    //gpuErrchk(matrixMulKernel<<<...>>>) -> Va da eroare de compilare, pentru că un kernel nu returnează nimic (void) De aceea, trebuie să facem verificarea imediat după ce apelam matrixMUltiKernel
    // matrixMulKernel este o functie care ruleaza asincron motiv pentru care trebuie sa facem cudaPeekAtLasrError ca sa ne arate daca a avut cod de succes sau eroare
    //cudaPeekAtLastError() ne spune daca„A fost vreo problemă cu ce am lansat adineaori?”
    gpuErrchk(cudaPeekAtLastError());
    //cudaDeviceSynchronize(): CPU-ul așteaptă ca GPU-ul să termine toate calculele înainte de a merge mai departe
    //PENTRU CALCUL EXACT AL TIMPULUI DE MULTIPLICARE
    gpuErrchk(cudaDeviceSynchronize());

    //Aduce rezultatul (matricea C) înapoi în RAM pentru a putea fi salvat.
    gpuErrchk(cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost));
    double end_mul = get_time_ms();

    // 3. Sequential Writing
    double start_write = get_time_ms();
    FILE *fc = fopen(fileC, "wb");
    if (!fc) { printf("Eroare la crearea fisierului de iesire!\n"); return 1; }
    fwrite(h_C, sizeof(float), M * M, fc);
    fclose(fc);
    double end_write = get_time_ms();

    double end_total = get_time_ms();

    // Afisare Timpi
    printf("t_reading: %.0f ms\n", end_read - start_read);
    printf("t_addition: %.0f ms\n", end_mul - start_mul); // am numit multiplication in loc de addition conform cerintei de calcul
    printf("t_writing: %.0f ms\n", end_write - start_write);
    printf("t_total: %.0f ms\n", end_total - start_total);

    // Curatare
    free(h_A); free(h_B); free(h_C);
    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);

    return 0;
}