#include <iostream>
#include <fstream>
#include <vector>
#include <chrono>

using namespace std;
using namespace std::chrono;

// PROGRAM FOR 1 A) THE FILES ARE TEXT FILES .TXT
//command to compile: g++ main.cpp -o main
// command to run: /main 1000 test1000/fileA.txt test1000/fileB.txt test1000/fileC.txt
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

    // I put the matrices into vectors for better opperability
    vector<double> A(M * M);
    vector<double> B(M * M);
    vector<double> C(M * M, 0.0);

    //READ
    auto start_read = high_resolution_clock::now();

    ifstream inA(fileA);
    ifstream inB(fileB);

    if (!inA.is_open()) {
        cerr << "Error: Could not open file " << fileA << endl;
        return 1;
    }
    if (!inB.is_open()) {
        cerr << "Error: Could not open file " << fileB << endl;
        return 1;
    }

    cout<<"Reading A"<<endl;

    for (int i = 0; i < M * M; ++i) {
        if (!(inA >> A[i])) { //checks if the read was successful
            cerr << "READ ERROR: Failed at index " << i << " in " << fileA << endl;
            if (inA.eof()) cerr << "Reached End of File unexpectedly." << endl;
            else cerr << "format mismatch (found non-numeric character)." << endl;
            return 1;
        }
        // cout << A[i] << " ";
    }
    cout<<"Reading B"<<endl;
    for (int i = 0; i < M * M; ++i) {
        if (!(inB >> B[i])) { //checks if the read was successful
            cerr << "READ ERROR: Failed at index " << i << " in " << fileB << endl;
            if (inB.eof()) cerr << "Reached End of File unexpectedly." << endl;
            else cerr << "found non-numeric character" << endl;
            return 1;
        }
        // cout << B[i] << " ";
    }
    inA.close();
    inB.close();
    //END READ
    auto end_read = high_resolution_clock::now();

    //SEQUENTIAL MULTIPLICATION with transpose
    auto start_mult = high_resolution_clock::now();

    // 1. Create the transpose of B to optimize cache access
    vector<double> BT(M * M);
    for (int i = 0; i < M; ++i) {
        for (int j = 0; j < M; ++j) {
            BT[i * M + j] = B[j * M + i];
        }
    }

    // 2. Compute multiplication using the transpose
    // Now both rows from A and "rows" from BT (which are columns of B) are accessed linearly
    for (int i = 0; i < M; ++i) {
        for (int j = 0; j < M; ++j) {
            double sum = 0.0;
            for (int k = 0; k < M; ++k) {
                sum += A[i * M + k] * BT[j * M + k];
            }
            C[i * M + j] = sum;
        }
    }

    //END SEQUENTIAL MULTIPLICATION
    auto end_mult = high_resolution_clock::now();

    //WRITING
    auto start_write = high_resolution_clock::now();

    ofstream outC(fileC);
    outC.precision(10); // writitng with precision of 10 decimals
    for (int i = 0; i < M; ++i) {
        for (int j = 0; j < M; ++j) {
            outC << C[i * M + j] << (j == M - 1 ? "" : " ");
        }
        outC << "\n";
    }
    outC.close();
    //END WRITING
    auto end_write = high_resolution_clock::now();

    auto end_total = high_resolution_clock::now();

    auto t_reading = duration_cast<milliseconds>(end_read - start_read).count();
    auto t_addition = duration_cast<milliseconds>(end_mult - start_mult).count();
    auto t_writing = duration_cast<milliseconds>(end_write - start_write).count();
    auto t_total = duration_cast<milliseconds>(end_total - start_total).count();

    // Output Results
    cout << "t_reading: " << t_reading << " ms" << endl;
    cout << "t_addition: " << t_addition << " ms" << endl; // Note: problem asks for multiplication time here
    cout << "t_writing: " << t_writing << " ms" << endl;
    cout << "t_total: " << t_total << " ms" << endl;

    return 0;
}