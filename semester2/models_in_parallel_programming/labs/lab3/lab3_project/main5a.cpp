#include <iostream>
#include <vector>
#include <fstream>
#include <chrono>
#include <mpi.h>
#include <omp.h>

using namespace std;
using namespace std::chrono;

// Citire matrice din format binar (fara header de dimensiune, conform cerintei noi)
void read_matrix_bin(const string& filename, vector<double>& mat, int N) {
    ifstream in(filename, ios::binary);
    if (!in) {
        cerr << "Eroare la deschiderea fisierului: " << filename << endl;
        return;
    }
    mat.resize(N * N);
    in.read(reinterpret_cast<char*>(mat.data()), N * N * sizeof(double));
    in.close();
}

void write_matrix_bin(const string& filename, const vector<double>& mat, int N) {
    ofstream out(filename, ios::binary);
    out.write(reinterpret_cast<const char*>(mat.data()), N * N * sizeof(double));
    out.close();
}


//LOCALLY
//COMPILING MPI PROGRAM: mpicxx -fopenmp -O3 main5a.cpp -o main5a
// RUNNING MPI PROGRAM LOCALLY: mpirun -np 4 ./main5a 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin

//ON CLUSTER
// COMPILING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpicxx -fopenmp -std=c++11 -O3 main5a.cpp -o main5a
// hostfile nodes.txt contine nodurile pe care sa le foloseasca de pe cluster in cazul a 25 de procese
// compute060 slots=7
// compute061 slots=6
// compute062 slots=6
// compute063 slots=6

//RUNNING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 25 -hostfile nodes.txt ./main5a 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin
//RUNNING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 64 -hostfile nodes.txt ./main5a 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin


int main(int argc, char** argv) {
    if (argc < 5) {
        cout << "Utilizare: mpirun -np P ./main N fileA fileB fileC" << endl;
        return 1;
    }

    int N = atoi(argv[1]);
    string fileA = argv[2];
    string fileB = argv[3];
    string fileC = argv[4];

    int provided;
    MPI_Init_thread(&argc, &argv, MPI_THREAD_FUNNELED, &provided);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    vector<double> A, B(N * N), C;
    milliseconds t_reading(0), t_multiplication(0), t_writing(0);
    auto start_total = high_resolution_clock::now();

    // --- 1. Citire Secventiala (Rank 0) ---
    if (rank == 0) {
        auto s_read = high_resolution_clock::now();
        read_matrix_bin(fileA, A, N);
        read_matrix_bin(fileB, B, N);
        t_reading = duration_cast<milliseconds>(high_resolution_clock::now() - s_read);
    }

    // Broadcast matricea B la toate procesele (este necesara integral pentru calcul)
    MPI_Bcast(B.data(), N * N, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    int rows_per_proc = N / size;
    vector<double> localA(rows_per_proc * N);
    vector<double> localC(rows_per_proc * N);

    // Distribuie randurile matricei A
    MPI_Scatter(A.data(), rows_per_proc * N, MPI_DOUBLE,
                localA.data(), rows_per_proc * N, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    // --- 2. Multiplicare Paralela (MPI + 10 Threads) ---
    MPI_Barrier(MPI_COMM_WORLD); // Sincronizare inainte de masurarea timpului de calcul
    auto s_mult = high_resolution_clock::now();

    #pragma omp parallel for num_threads(10) collapse(2)
    for (int i = 0; i < rows_per_proc; ++i) {
        for (int j = 0; j < N; ++j) {
            double sum = 0.0;
            for (int k = 0; k < N; ++k) {
                sum += localA[i * N + k] * B[k * N + j];
            }
            localC[i * N + j] = sum;
        }
    }

    auto e_mult = high_resolution_clock::now();
    t_multiplication = duration_cast<milliseconds>(e_mult - s_mult);

    // Colectare rezultate in C
    if (rank == 0) C.resize(N * N);
    MPI_Gather(localC.data(), rows_per_proc * N, MPI_DOUBLE,
               C.data(), rows_per_proc * N, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    // --- 3. Scriere Secventiala (Rank 0) ---
    if (rank == 0) {
        auto s_write = high_resolution_clock::now();
        write_matrix_bin(fileC, C, N);
        t_writing = duration_cast<milliseconds>(high_resolution_clock::now() - s_write);

        auto t_total = duration_cast<milliseconds>(high_resolution_clock::now() - start_total);

        // Afisare in formatul cerut
        cout << "t_reading: " << t_reading.count() << " ms" << endl;
        cout << "t_addition: " << t_multiplication.count() << " ms" << endl;
        cout << "t_writing: " << t_writing.count() << " ms" << endl;
        cout << "t_total: " << t_total.count() << " ms" << endl;
    }

    MPI_Finalize();
    return 0;
}