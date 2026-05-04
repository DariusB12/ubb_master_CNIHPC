#include <mpi.h>
#include <iostream>
#include <vector>
#include <fstream>
#include <cmath>
#include <chrono>

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
//COMPILING MPI PROGRAM: mpicxx -O3 main4a.cpp -o main4a
// RUNNING MPI PROGRAM LOCALLY: mpirun -np 4 ./main4a 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin
//ON CLUSTER
// COMPILING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpicxx -std=c++11 -O3 main4a.cpp -o main4a
// hostfile nodes.txt contine nodurile pe care sa le foloseasca de pe cluster in cazul a 25 de procese
// compute060 slots=7
// compute061 slots=6
// compute062 slots=6
// compute063 slots=6

//RUNNING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 25 -hostfile nodes.txt ./main4a 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin
//RUNNING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 64 -hostfile nodes.txt ./main4a 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin

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
    if (q * q != world_size) {
        if (world_rank == 0) cerr << "Eroare: Numarul de procese trebuie sa fie un patrat perfect (ex: 25, 64)!" << endl;
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    int blockSize = M / q;
    auto start_total = high_resolution_clock::now();

    // 1. CITIRE SECVENTIALA (Doar Rank 0)
    auto start_reading = high_resolution_clock::now();
    vector<double> A_full, B_full;
    if (world_rank == 0) {
        A_full.resize(M * M);
        B_full.resize(M * M);
        ifstream inA(fileA, ios::binary);
        ifstream inB(fileB, ios::binary);
        if (!inA || !inB) {
            cerr << "Eroare la deschiderea fisierelor binare!" << endl;
            MPI_Abort(MPI_COMM_WORLD, 1);
        }
        inA.read(reinterpret_cast<char*>(A_full.data()), M * M * sizeof(double));
        inB.read(reinterpret_cast<char*>(B_full.data()), M * M * sizeof(double));
        inA.close(); inB.close();
    }
    auto end_reading = high_resolution_clock::now();

    // 2. CREARE TOPOLOGIE CARTESIANA
    int dims[2] = {q, q};
    int periods[2] = {1, 1};
    MPI_Comm cart_comm;
    MPI_Cart_create(MPI_COMM_WORLD, 2, dims, periods, 1, &cart_comm);

    int coords[2];
    MPI_Cart_coords(cart_comm, world_rank, 2, coords);

    // 3. DISTRIBUIRE DATE (Scattering)
    // Vom folosi un tip de date MPI Subarray pentru a extrage blocurile corect din matricea mare
    vector<double> localA(blockSize * blockSize);
    vector<double> localB(blockSize * blockSize);
    vector<double> localC(blockSize * blockSize, 0.0);

    if (world_rank == 0) {
        for (int i = 0; i < q; ++i) {
            for (int j = 0; j < q; ++j) {
                vector<double> tempA(blockSize * blockSize);
                vector<double> tempB(blockSize * blockSize);
                for (int r = 0; r < blockSize; ++r) {
                    for (int c = 0; c < blockSize; ++c) {
                        tempA[r * blockSize + c] = A_full[(i * blockSize + r) * M + (j * blockSize + c)];
                        tempB[r * blockSize + c] = B_full[(i * blockSize + r) * M + (j * blockSize + c)];
                    }
                }
                int dest_rank;
                int dest_coords[2] = {i, j};
                MPI_Cart_rank(cart_comm, dest_coords, &dest_rank);
                if (dest_rank == 0) {
                    localA = tempA;
                    localB = tempB;
                } else {
                    MPI_Send(tempA.data(), blockSize * blockSize, MPI_DOUBLE, dest_rank, 0, cart_comm);
                    MPI_Send(tempB.data(), blockSize * blockSize, MPI_DOUBLE, dest_rank, 1, cart_comm);
                }
            }
        }
    } else {
        MPI_Recv(localA.data(), blockSize * blockSize, MPI_DOUBLE, 0, 0, cart_comm, MPI_STATUS_IGNORE);
        MPI_Recv(localB.data(), blockSize * blockSize, MPI_DOUBLE, 0, 1, cart_comm, MPI_STATUS_IGNORE);
    }

    // 4. ALGO CANNON: ALINIERE INITIALA
    int left, right, up, down;
    // Shift A pe randuri: row i cu i pozitii la stanga
    MPI_Cart_shift(cart_comm, 1, coords[0], &left, &right);
    MPI_Sendrecv_replace(localA.data(), blockSize * blockSize, MPI_DOUBLE, left, 10, right, 10, cart_comm, MPI_STATUS_IGNORE);

    // Shift B pe coloane: col j cu j pozitii in sus
    MPI_Cart_shift(cart_comm, 0, coords[1], &up, &down);
    MPI_Sendrecv_replace(localB.data(), blockSize * blockSize, MPI_DOUBLE, up, 11, down, 11, cart_comm, MPI_STATUS_IGNORE);

    // 5. ALGO CANNON: PASII DE CALCUL SI SHIFTare
    MPI_Cart_shift(cart_comm, 1, 1, &left, &right); // Shift stanga cu 1
    MPI_Cart_shift(cart_comm, 0, 1, &up, &down);    // Shift sus cu 1

    auto start_mult = high_resolution_clock::now();
    for (int step = 0; step < q; ++step) {
        local_multiply(blockSize, localA, localB, localC);

        // Shiftare circulara pentru pasul urmator
        MPI_Sendrecv_replace(localA.data(), blockSize * blockSize, MPI_DOUBLE, left, 20, right, 20, cart_comm, MPI_STATUS_IGNORE);
        MPI_Sendrecv_replace(localB.data(), blockSize * blockSize, MPI_DOUBLE, up, 21, down, 21, cart_comm, MPI_STATUS_IGNORE);
    }
    auto end_mult = high_resolution_clock::now();

    // 6. COLECTARE REZULTATE (Gather)
    vector<double> C_full;
    if (world_rank == 0) C_full.resize(M * M);

    if (world_rank != 0) {
        MPI_Send(localC.data(), blockSize * blockSize, MPI_DOUBLE, 0, 30, cart_comm);
    } else {
        // Punem localC al lui Rank 0 in matricea mare
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
    }

    // 7. SCRIERE SECVENTIALA
    auto start_writing = high_resolution_clock::now();
    if (world_rank == 0) {
        ofstream outC(fileC, ios::binary);
        outC.write(reinterpret_cast<char*>(C_full.data()), M * M * sizeof(double));
        outC.close();

        auto end_writing = high_resolution_clock::now();
        auto end_total = high_resolution_clock::now();

        cout << "t_reading: " << duration_cast<milliseconds>(end_reading - start_reading).count() << " ms" << endl;
        cout << "t_addition: " << duration_cast<milliseconds>(end_mult - start_mult).count() << " ms" << endl;
        cout << "t_writing: " << duration_cast<milliseconds>(end_writing - start_writing).count() << " ms" << endl;
        cout << "t_total: " << duration_cast<milliseconds>(end_total - start_total).count() << " ms" << endl;
    }

    MPI_Finalize();
    return 0;
}