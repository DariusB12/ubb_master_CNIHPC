#include <iostream>
#include <fstream>
#include <iomanip>
#include <random>
#include <string>

// PROGRAM TO GENERATE A RANDOM MATRIX IN THE GIVEN FILENAME OF A SPECIFIED SIZE (MxM)
int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Please introduce followinf args: " <<  "<M> <file_name>" << std::endl;
        return 1;
    }

    int M = std::stoi(argv[1]);
    std::string file_name = argv[2];

    // (ofstream::trunc sterge continutul daca exista)
    std::ofstream file(file_name, std::ios::out | std::ios::trunc);

    if (!file.is_open()) {
        std::cerr << "Error creating/opening the file: " << file_name << std::endl;
        return 1;
    }

    // set the precision to 2 decimals when writing
    file << std::fixed << std::setprecision(2);

    // Get a different random number each time the program runs
    srand(time(0));

    for (int i = 0; i < M; ++i) {
        for (int j = 0; j < M; ++j) {
            // random value between 100 and 5000 which divided by 100 gives me a double value  between 0.1 and 50.00
            double valoare = ((rand() % 5000) + 100) / 100.0;
            
            file << valoare;
            // writing separator
            if (j < M - 1) {
                file << " ";
            }
        }
        // end of line
        file << "\n";
    }

    file.close();
    std::cout << "Matrix generated successfully" << M << "x" << M << " in the file: " << file_name << std::endl;

    return 0;
}