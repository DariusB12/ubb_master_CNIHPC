#include <iostream>
#include <fstream>
#include <vector>
#include <chrono>
#include <thread>

using namespace std;
using namespace std::chrono;

//PROGRAM FOR 2 b)
// -parallel reading
// -parallel multiplication
// -Sequential writing
// no_threads = 20,40

//command to compile: g++ main2b.cpp -o main2b
// command to run: ./main2b 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin 20
// command to run: ./main2b 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin 40

void read_worker(const char* fileName, int start_row, int end_row, int M, vector<double>& matrix) {
    // open the file locally inside the thread
    ifstream in(fileName, ios::binary);
    if (!in) {
        cerr << "Error opening file in thread!" << endl;
        return;
    }

    // offset-ul unde trebuie sa incepem sa citim (offset în bytes)
    streampos offset = (streampos)start_row * M * sizeof(double);

    //pozitionez cursorul la offset
    in.seekg(offset);

    //calculate how many elements we need to read
    size_t num_elements = (size_t)(end_row - start_row) * M;

    // matrix.data() =the starting pointer of the matrix, we add the offset of rows
    in.read(reinterpret_cast<char*>(matrix.data() + (size_t)start_row * M),
            num_elements * sizeof(double));

    in.close();
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

    // --- CITIRE BINARA PARALELA ---

    auto start_read = high_resolution_clock::now();

    vector<thread> read_threads;
    int rows_per_thread = M / no_threads;

    for (int i = 0; i < no_threads; ++i) {
        int start_r = i * rows_per_thread;
        int end_r = (i == no_threads - 1) ? M : (i + 1) * rows_per_thread;

        //add thread for reading matrix A
        read_threads.push_back(thread(read_worker, fileA, start_r, end_r, M, ref(A)));
        //add thread for reading matrix B
        read_threads.push_back(thread(read_worker, fileB, start_r, end_r, M, ref(B)));
    }

    for (auto& th : read_threads) {
        th.join();
    }

    auto end_read = high_resolution_clock::now();

    // Transpusa matrice B
    vector<double> BT(M * M);

    auto start_mult = high_resolution_clock::now();

    //--- TRANSPUNERE PARALELA ---
    vector<thread> transpose_threads;
    rows_per_thread = M / no_threads;

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