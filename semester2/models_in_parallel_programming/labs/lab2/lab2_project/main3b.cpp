#include <iostream>
#include <fstream>
#include <vector>
#include <chrono>
#include <thread>

#include <omp.h> // Header OpenMP

using namespace std;
using namespace std::chrono;

//PROGRAM FOR 3 b) OpenMP
// -parallel reading
// -parallel multiplication
// -Sequential writing
// no_threads = 20,40

//command to compile: g++ main3b.cpp -o main3b -fopenmp
// command to run: ./main3b 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin 20
// command to run: ./main3b 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin 40

// --- READ PARALLEL WITH OPENMP ---
void read_matrix_parallel(const char* fileName, vector<double>& matrix, int M, int no_threads) {
    // open a parallel region to manage the stream of files
#pragma omp parallel num_threads(no_threads)
    {
        int tid = omp_get_thread_num();
        int n_threads = omp_get_num_threads();

        // CALCULATE THE INTERVAL OF ROWS FOR EACH THREAD
        int rows_per_thread = M / n_threads;
        int start_r = tid * rows_per_thread;
        int end_r = (tid == n_threads - 1) ? M : (tid + 1) * rows_per_thread;

        // EACH THREAD OPENS THE FILE
        ifstream in(fileName, ios::binary);
        if (!in) {
#pragma omp critical
            cerr << "Error: Thread " << tid << " could not open " << fileName << endl;
        } else {
            // POSITION THE CURSOR AT THE APPROPRIATE START POSITION FOR READING OF THE CURRENT THREAD
            streampos offset = (streampos)start_r * M * sizeof(double);
            in.seekg(offset);

            //READ THE NO OF ELEMENTS ALLOCATED TO THE THREAD
            size_t num_elements = (size_t)(end_r - start_r) * M;
            in.read(reinterpret_cast<char*>(matrix.data() + (size_t)start_r * M),
                    num_elements * sizeof(double));

            in.close();
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc < 6) {
        cerr << "Usage: " << argv[0] << " <M> <fileA> <fileB> <fileC> <no_threads>" << endl;
        return 1;
    }

    const int M = atoi(argv[1]);
    const char* fileA = argv[2];
    const char* fileB = argv[3];
    const char* fileC = argv[4];
    const int no_threads = atoi(argv[5]);

    // set the no of threads for parallel regions
    omp_set_num_threads(no_threads);

    vector<double> A(M * M);
    vector<double> B(M * M);
    vector<double> BT(M * M);
    vector<double> C(M * M, 0.0);

    auto start_total = high_resolution_clock::now();

    // --- CITIRE SECVENTIALA ---
    auto start_read = high_resolution_clock::now();

    read_matrix_parallel(fileA, A, M, no_threads);
    read_matrix_parallel(fileB, B, M, no_threads);

    auto end_read = high_resolution_clock::now();

    // MULTIPLICARE PARALELA---
    auto start_mult = high_resolution_clock::now();

    //---TRANSPUNERE PARALELA ---
    // directiva 'parallel for' imparte automat iteratiile lui 'i' intre thread-uri
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < M; ++i) {
        for (int j = 0; j < M; ++j) {
            BT[j * M + i] = B[i * M + j];
        }
    }

    // --- MULTIPLICARE PARALELA ---

    #pragma omp parallel for schedule(static)
    for (int i = 0; i < M; ++i) {
        for (int j = 0; j < M; ++j) {
            double sum = 0.0;
            for (int k = 0; k < M; ++k) {
                sum += A[i * M + k] * BT[j * M + k];
            }
            C[i * M + j] = sum;
        }
    }

    auto end_mult = high_resolution_clock::now();

    // --- SCRIERE SECVENTIALA ---
    auto start_write = high_resolution_clock::now();

    ofstream outC(fileC, ios::binary);

    if (outC) {
        outC.write(reinterpret_cast<const char*>(C.data()), (size_t)M * M * sizeof(double));
        outC.close();
    }
    auto end_write = high_resolution_clock::now();

    auto end_total = high_resolution_clock::now();

    // --- AFISARE TIMPI ---
    cout << "t_reading: " << duration_cast<milliseconds>(end_read - start_read).count() << " ms" << endl;
    cout << "t_addition: " << duration_cast<milliseconds>(end_mult - start_mult).count() << " ms" << endl;
    cout << "t_writing: " << duration_cast<milliseconds>(end_write - start_write).count() << " ms" << endl;
    cout << "t_total: " << duration_cast<milliseconds>(end_total - start_total).count() << " ms" << endl;

    return 0;
}