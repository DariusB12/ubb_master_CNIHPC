#include <iostream>
#include <fstream>
#include <vector>
#include <chrono>
#include <thread>

using namespace std;
using namespace std::chrono;

//PROGRAM FOR 2 a)
// -sequential reading
// -parallel multiplication
// -Sequential writing
// no_threads = 20,40

//command to compile: g++ main2a.cpp -o main2a
// command to run: ./main2a 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin 20
// command to run: ./main2a 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin 40

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

void multiply_worker(int start_row, int end_row, int M,
                     const vector<double>& A,
                     const vector<double>& BT,
                     vector<double>& C) {
    for (int i = start_row; i < end_row; ++i) {
        for (int j = 0; j < M; ++j) {
            double sum = 0.0;
            for (int k = 0; k < M; ++k) {
                sum += A[i * M + k] * BT[j * M + k];
            }
            C[i * M + j] = sum;
        }
    }
}

void transpose_worker(int start_row, int end_row, int M,
                      const vector<double>& B,
                      vector<double>& BT) {
    for (int i = start_row; i < end_row; ++i) {
        for (int j = 0; j < M; ++j) {
            // elem(i,j) din B devine elem(j,i) in BT
            BT[j * M + i] = B[i * M + j];
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

    // MATRIX AS VECTOR
    vector<double> A(M * M);
    vector<double> B(M * M);
    vector<double> C(M * M, 0.0);

    auto start_total = high_resolution_clock::now();

    // --- CITIRE BINARA ---
    auto start_read = high_resolution_clock::now();

    if (read_matrix_from_file(fileA, A, M) ==1 || read_matrix_from_file(fileB, B, M) == 1)
        return 1;

    auto end_read = high_resolution_clock::now();

    // Transpusa matrice B
    vector<double> BT(M * M);

    auto start_mult = high_resolution_clock::now();

    //--- TRANSPUNERE PARALELA ---
    vector<thread> transpose_threads;
    int rows_per_thread = M / no_threads;

    for (int i = 0; i < no_threads; ++i) {
        int start_r = i * rows_per_thread;
        int end_r = (i == no_threads - 1) ? M : (i + 1) * rows_per_thread;

        transpose_threads.push_back(thread(transpose_worker, start_r, end_r, M, ref(B), ref(BT)));
    }

    for (auto& th : transpose_threads) {
        th.join();
    }


    // --- MULTIPLICARE PARALELA ---
    vector<thread> threads;
    rows_per_thread = M / no_threads;

    for (int i = 0; i < no_threads; ++i) {
        int start_r = i * rows_per_thread;
        // the last thread receives the rows until the end row M (exclusive)
        int end_r = (i == no_threads - 1) ? M : (i + 1) * rows_per_thread;

        threads.push_back(thread(multiply_worker, start_r, end_r, M, ref(A), ref(BT), ref(C)));
    }

    // astept toate threadurile sa se termine
    for (auto& th : threads) {
        th.join();
    }

    auto end_mult = high_resolution_clock::now();

    // --- SCRIERE BINARA ---
    auto start_write = high_resolution_clock::now();

    ofstream outC(fileC, ios::binary);
    if (!outC) {
        cerr << "Error: Could not open file for writing." << endl;
        return 1;
    }

    // WRITE ALL THE MATRIX AS A SINGLE BINARY FILE
    outC.write(reinterpret_cast<const char*>(C.data()), M * M * sizeof(double));
    outC.close();

    auto end_write = high_resolution_clock::now();
    auto end_total = high_resolution_clock::now();

    auto t_reading = duration_cast<milliseconds>(end_read - start_read).count();
    auto t_addition = duration_cast<milliseconds>(end_mult - start_mult).count();
    auto t_writing = duration_cast<milliseconds>(end_write - start_write).count();
    auto t_total = duration_cast<milliseconds>(end_total - start_total).count();

    cout << "t_reading: " << t_reading << " ms" << endl;
    cout << "t_addition: " << t_addition << " ms" << endl;
    cout << "t_writing: " << t_writing << " ms" << endl;
    cout << "t_total: " << t_total << " ms" << endl;

    return 0;
}