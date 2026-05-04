#include <iostream>
#include <vector>
#include <chrono>
#include <mpi.h>
#include <omp.h>

using namespace std;
using namespace std::chrono;

//LOCALLY
//COMPILING MPI PROGRAM: mpicxx -fopenmp -O3 main5b.cpp -o main5b
// RUNNING MPI PROGRAM LOCALLY: mpirun -np 4 ./main5b 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin

//ON CLUSTER
// COMPILING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpicxx -fopenmp -std=c++11 -O3 main5b.cpp -o main5b
// hostfile nodes.txt contine nodurile pe care sa le foloseasca de pe cluster in cazul a 25 de procese
// compute060 slots=7
// compute061 slots=6
// compute062 slots=6
// compute063 slots=6

//RUNNING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 25 -hostfile nodes.txt ./main5b 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin
//RUNNING: /usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 64 -hostfile nodes.txt ./main5b 1000 test1000/fileA.bin test1000/fileB.bin test1000/correctRes.bin



int main(int argc, char** argv) {
    if (argc < 5) {
        cout << "Utilizare: mpirun -np P ./main N fileA fileB fileC" << endl;
        return 1;
    }

    int N = atoi(argv[1]);
    string fileA_path = argv[2];
    string fileB_path = argv[3];
    string fileC_path = argv[4];

    int provided;
    MPI_Init_thread(&argc, &argv, MPI_THREAD_FUNNELED, &provided);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    int rows_per_proc = N / size;
    vector<double> localA(rows_per_proc * N);
    vector<double> B(N * N);
    vector<double> localC(rows_per_proc * N);

    auto start_total = high_resolution_clock::now();
    
    // --- 1. Citire Paralela (MPI-IO) ---
    auto s_read = high_resolution_clock::now();

    // Citire paralela fileA: fiecare proces citeste bucata lui
    MPI_File fhA;
    MPI_File_open(MPI_COMM_WORLD, fileA_path.c_str(), MPI_MODE_RDONLY, MPI_INFO_NULL, &fhA);
    MPI_Offset offsetA = (MPI_Offset)rank * rows_per_proc * N * sizeof(double);
    MPI_File_read_at_all(fhA, offsetA, localA.data(), rows_per_proc * N, MPI_DOUBLE, MPI_STATUS_IGNORE);
    MPI_File_close(&fhA);

    // Citire paralela fileB: toate procesele citesc intreaga matrice B (read_all)
    MPI_File fhB;
    MPI_File_open(MPI_COMM_WORLD, fileB_path.c_str(), MPI_MODE_RDONLY, MPI_INFO_NULL, &fhB);
    MPI_File_read_at_all(fhB, 0, B.data(), N * N, MPI_DOUBLE, MPI_STATUS_IGNORE);
    MPI_File_close(&fhB);

    auto e_read = high_resolution_clock::now();
    milliseconds t_reading = duration_cast<milliseconds>(e_read - s_read);

    // --- 2. Multiplicare Paralela (MPI + 10 Threads) ---
    MPI_Barrier(MPI_COMM_WORLD);
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
    milliseconds t_multiplication = duration_cast<milliseconds>(e_mult - s_mult);

    // --- 3. Scriere Secventiala (Rank 0) ---
    // Colectam totul in Rank 0 pentru scriere secventiala conform cerintei b)
    vector<double> globalC;
    if (rank == 0) globalC.resize(N * N);

    MPI_Gather(localC.data(), rows_per_proc * N, MPI_DOUBLE,
               globalC.data(), rows_per_proc * N, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        auto s_write = high_resolution_clock::now();
        FILE* f = fopen(fileC_path.c_str(), "wb");
        fwrite(globalC.data(), sizeof(double), N * N, f);
        fclose(f);
        auto e_write = high_resolution_clock::now();

        milliseconds t_writing = duration_cast<milliseconds>(e_write - s_write);
        auto t_total = duration_cast<milliseconds>(high_resolution_clock::now() - start_total);

        // Afisare rezultate
        cout << "t_reading: " << t_reading.count() << " ms" << endl;
        cout << "t_addition: " << t_multiplication.count() << " ms" << endl;
        cout << "t_writing: " << t_writing.count() << " ms" << endl;
        cout << "t_total: " << t_total.count() << " ms" << endl;
    }

    MPI_Finalize();
    return 0;
}