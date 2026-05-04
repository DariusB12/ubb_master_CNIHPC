#include <iostream>
#include <fstream>
#include <vector>
#include <chrono>
#include <thread>

#include <omp.h> // Header OpenMP

using namespace std;
using namespace std::chrono;

//PROGRAM FOR 3 a) OpenMP
// -sequential reading
// -parallel multiplication
// -Sequential writing
// no_threads = 20,40

//command to compile: g++ main3a.cpp -o main3a -fopenmp
// command to run: ./main3a 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin 20
// command to run: ./main3a 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin 40

int read_matrix_from_file(const char* fileName, vector<double>& matrix,int M) {
    // OPEN FILES WITH BINARY FLAG
    ifstream inA(fileName, ios::binary);


    if (!inA) {
        cerr << "Error: Could not open binary input files." << endl;
        return 1;
    }

    //NOW WE CAN READ ALL THE DATA BLOCK ONCE
    //reinterpret_cast= tells the compilator to treat the data as it is and to not interpret it
    inA.read(reinterpret_cast<char*>(matrix.data()), M * M * sizeof(double));

    if (inA.gcount() < (streamsize)(M * M * sizeof(double))) {
        cerr << "READ ERROR: fileA is smaller than expected!" << endl;
        return 1;
    }
    inA.close();
    return 0;
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

    if (read_matrix_from_file(fileA, A, M) == 1 || read_matrix_from_file(fileB, B, M) == 1)
        return 1;

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