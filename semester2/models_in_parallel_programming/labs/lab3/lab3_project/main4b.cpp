#include <mpi.h>
#include <iostream>
#include <vector>
#include <fstream>
#include <cmath>
#include <chrono>
#include <cstdlib>
#include <string>

using namespace std;
using namespace std::chrono;

// Functie pentru inmultirea locala a blocurilor (optimizata IKJ)
void local_multiply(int size, const vector<double>& A, const vector<double>& B, vector<double>& C) {
    for (int i = 0; i < size; ++i) {
        for (int k = 0; k < size; ++k) {
            double temp = A[i * size + k];
            for (int j = 0; j < size; ++j) {
                C[i * size + j] += temp * B[k * size + j];
            }
        }
    }
}

//LOCALLY
//COMPILING MPI PROGRAM: mpicxx -O3 main4b.cpp -o main4b
// RUNNING MPI PROGRAM LOCALLY: mpirun -np 4 ./main4b 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin
//ON CLUSTER
// COMPILING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpicxx -std=c++11 -O3 main4b.cpp -o main4b
// hostfile nodes.txt contine nodurile pe care sa le foloseasca de pe cluster in cazul a 25 de procese
// compute060 slots=7
// compute061 slots=6
// compute062 slots=6
// compute063 slots=6

//RUNNING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 25 -hostfile nodes.txt ./main4b 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin
//RUNNING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 64 -hostfile nodes.txt ./main4b 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int world_size, world_rank;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    if (argc < 5) {
        if (world_rank == 0) cerr << "Utilizare: mpirun -np <P> " << argv[0] << " <M> <fileA> <fileB> <fileC>" << endl;
        MPI_Finalize();
        return 1;
    }

    int M = atoi(argv[1]);
    string fileA = argv[2];
    string fileB = argv[3];
    string fileC = argv[4];

    int q = sqrt(world_size);
    int blockSize = M / q;

    int dims[2] = {q, q};
    int periods[2] = {1, 1};
    MPI_Comm cart_comm;
    MPI_Cart_create(MPI_COMM_WORLD, 2, dims, periods, 1, &cart_comm);

    int coords[2];
    MPI_Cart_coords(cart_comm, world_rank, 2, coords);

    vector<double> localA(blockSize * blockSize);
    vector<double> localB(blockSize * blockSize);
    vector<double> localC(blockSize * blockSize, 0.0);

    // --- START CRONOMETRU TOTAL ---
    auto start_total = high_resolution_clock::now();

    // 1. CITIRE PARALELA (MPI-IO)
    auto start_reading = high_resolution_clock::now();
    MPI_File fhA, fhB;
    MPI_Datatype block_type;
    int sizes[2]    = {M, M};
    int subsizes[2] = {blockSize, blockSize};
    int starts[2]   = {coords[0] * blockSize, coords[1] * blockSize};

    MPI_Type_create_subarray(2, sizes, subsizes, starts, MPI_ORDER_C, MPI_DOUBLE, &block_type);
    MPI_Type_commit(&block_type);

    MPI_File_open(MPI_COMM_WORLD, (char*)fileA.c_str(), MPI_MODE_RDONLY, MPI_INFO_NULL, &fhA);
    MPI_File_set_view(fhA, 0, MPI_DOUBLE, block_type, (char*)"native", MPI_INFO_NULL);
    MPI_File_read_all(fhA, localA.data(), blockSize * blockSize, MPI_DOUBLE, MPI_STATUS_IGNORE);
    MPI_File_close(&fhA);

    MPI_File_open(MPI_COMM_WORLD, (char*)fileB.c_str(), MPI_MODE_RDONLY, MPI_INFO_NULL, &fhB);
    MPI_File_set_view(fhB, 0, MPI_DOUBLE, block_type, (char*)"native", MPI_INFO_NULL);
    MPI_File_read_all(fhB, localB.data(), blockSize * blockSize, MPI_DOUBLE, MPI_STATUS_IGNORE);
    MPI_File_close(&fhB);
    auto end_reading = high_resolution_clock::now();

    // 2. MULTIPLICARE PARALELA (CANNON) - t_addition
    auto start_addition = high_resolution_clock::now();
    int left, right, up, down;
    MPI_Cart_shift(cart_comm, 1, coords[0], &left, &right);
    MPI_Sendrecv_replace(localA.data(), blockSize * blockSize, MPI_DOUBLE, left, 10, right, 10, cart_comm, MPI_STATUS_IGNORE);
    MPI_Cart_shift(cart_comm, 0, coords[1], &up, &down);
    MPI_Sendrecv_replace(localB.data(), blockSize * blockSize, MPI_DOUBLE, up, 11, down, 11, cart_comm, MPI_STATUS_IGNORE);

    MPI_Cart_shift(cart_comm, 1, 1, &left, &right);
    MPI_Cart_shift(cart_comm, 0, 1, &up, &down);

    for (int step = 0; step < q; ++step) {
        local_multiply(blockSize, localA, localB, localC);
        MPI_Sendrecv_replace(localA.data(), blockSize * blockSize, MPI_DOUBLE, left, 20, right, 20, cart_comm, MPI_STATUS_IGNORE);
        MPI_Sendrecv_replace(localB.data(), blockSize * blockSize, MPI_DOUBLE, up, 21, down, 21, cart_comm, MPI_STATUS_IGNORE);
    }
    auto end_addition = high_resolution_clock::now();

    // 3. COLECTARE SI SCRIERE SECVENTIALA - t_writing
    auto start_writing = high_resolution_clock::now();
    vector<double> C_full;
    if (world_rank == 0) C_full.resize(M * M);

    if (world_rank != 0) {
        MPI_Send(localC.data(), blockSize * blockSize, MPI_DOUBLE, 0, 30, cart_comm);
    } else {
        for (int r = 0; r < blockSize; ++r)
            for (int c = 0; c < blockSize; ++c)
                C_full[(coords[0] * blockSize + r) * M + (coords[1] * blockSize + c)] = localC[r * blockSize + c];

        for (int p = 1; p < world_size; ++p) {
            vector<double> tempC(blockSize * blockSize);
            int p_coords[2];
            MPI_Recv(tempC.data(), blockSize * blockSize, MPI_DOUBLE, p, 30, cart_comm, MPI_STATUS_IGNORE);
            MPI_Cart_coords(cart_comm, p, 2, p_coords);
            for (int r = 0; r < blockSize; ++r)
                for (int c = 0; c < blockSize; ++c)
                    C_full[(p_coords[0] * blockSize + r) * M + (p_coords[1] * blockSize + c)] = tempC[r * blockSize + c];
        }

        ofstream outC(fileC.c_str(), ios::binary);
        outC.write(reinterpret_cast<char*>(C_full.data()), M * M * sizeof(double));
        outC.close();
    }
    auto end_writing = high_resolution_clock::now();
    auto end_total = high_resolution_clock::now();

    // --- AFISARE FORMATA ---
    if (world_rank == 0) {
        cout << "t_reading: " << duration_cast<milliseconds>(end_reading - start_reading).count() << " ms" << endl;
        cout << "t_addition: " << duration_cast<milliseconds>(end_addition - start_addition).count() << " ms" << endl;
        cout << "t_writing: " << duration_cast<milliseconds>(end_writing - start_writing).count() << " ms" << endl;
        cout << "t_total: " << duration_cast<milliseconds>(end_total - start_total).count() << " ms" << endl;
    }

    MPI_Type_free(&block_type);
    MPI_Finalize();
    return 0;
}