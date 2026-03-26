#include <iostream>
#include <fstream>
#include <vector>

int main(int argc, char *argv[]) {
    if (argc < 4) {
        std::cerr << "Usage: " << argv[0] << "<path/fileToTransform> <path/BinaryFileName> <matrix size>" << std::endl;
        return 1;
    }
    const std::string& textFile = argv[1];
    const std::string& binFile = argv[2];
    int M = atoi(argv[3]);

    std::ifstream in(textFile);
    std::ofstream out(binFile, std::ios::binary);

    if (!in.is_open() || !out.is_open()) {
        std::cerr << "Eroare la deschiderea fisierelor!" << std::endl;
        return 1;
    }

    double value;
    //Citim element cu element din text si scriem binar
    for (int i = 0; i < M * M; ++i) {
        if (in >> value) {
            // write primeste adresa de memorie si dimensiunea in bytes
            out.write(reinterpret_cast<char*>(&value), sizeof(double));
        }
    }

    in.close();
    out.close();
    std::cout << "Conversie finalizata cu succes!" << std::endl;
    return 0;
}