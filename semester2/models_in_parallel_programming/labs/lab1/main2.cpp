#include <iostream>
#include <fstream>
#include <vector>
#include <chrono>

using namespace std;
using namespace std::chrono;

//PROGRAM FOR 1 B) WHEN FILES ARE BIANRY FILES .BIN
int main(int argc, char *argv[]) {
    if (argc < 5) {
        cerr << "Usage: " << argv[0] << " <M> <fileA> <fileB> <fileC>" << endl;
        return 1;
    }

    const int M = atoi(argv[1]);
    const char* fileA = argv[2];
    const char* fileB = argv[3];
    const char* fileC = argv[4];

    auto start_total = high_resolution_clock::now();

    // MATRIX AS VECTOR
    vector<double> A(M * M);
    vector<double> B(M * M);
    vector<double> C(M * M, 0.0);

    // --- CITIRE BINARA ---
    auto start_read = high_resolution_clock::now();

    // OPEN FILES WITH BINARY FLAG
    ifstream inA(fileA, ios::binary);
    ifstream inB(fileB, ios::binary);

    if (!inA || !inB) {
        cerr << "Error: Could not open binary input files." << endl;
        return 1;
    }

    //NOW WE CAN READ ALL THE DATA BLOCK ONCE
    //reinterpret_cast= tells the compilator to treat the data as it is and to not interpret it
    inA.read(reinterpret_cast<char*>(A.data()), M * M * sizeof(double));
    inB.read(reinterpret_cast<char*>(B.data()), M * M * sizeof(double));

    if (inA.gcount() < (streamsize)(M * M * sizeof(double))) {
        cerr << "READ ERROR: fileA is smaller than expected!" << endl;
        return 1;
    }

    inA.close();
    inB.close();
    auto end_read = high_resolution_clock::now();

    // --- MULTIPLICARE ---
    auto start_mult = high_resolution_clock::now();
    for (int i = 0; i < M; ++i) {
        for (int k = 0; k < M; ++k) {
            double temp = A[i * M + k];
            for (int j = 0; j < M; ++j) {
                C[i * M + j] += temp * B[k * M + j];
            }
        }
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