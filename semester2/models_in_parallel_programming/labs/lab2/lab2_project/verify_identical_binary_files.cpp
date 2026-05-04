#include <cstring>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>

using namespace std;

bool areFilesIdentical(const string& path1, const string& path2) {
    // 1. Deschidem ambele fișiere în mod binar
    ifstream f1(path1, ios::binary | ios::ate); // ios::ate pune cursorul la final
    ifstream f2(path2, ios::binary | ios::ate);

    if (!f1.is_open() || !f2.is_open()) {
        cerr << "Eroare: Nu s-au putut deschide fisierele pentru comparare." << endl;
        return false;
    }

    // 2. Verificăm dimensiunea (dacă diferă, fișierele nu sunt identice)
    if (f1.tellg() != f2.tellg()) {
        return false;
    }

    // Revenim la începutul fișierelor pentru citire
    f1.seekg(0, ios::beg);
    f2.seekg(0, ios::beg);

    // 3. Comparăm conținutul în blocuri (ex: 64 KB)
    const size_t BUFFER_SIZE = 65536;
    vector<char> buffer1(BUFFER_SIZE);
    vector<char> buffer2(BUFFER_SIZE);

    while (f1.good() && f2.good()) {
        f1.read(buffer1.data(), BUFFER_SIZE);
        f2.read(buffer2.data(), BUFFER_SIZE);

        // Vedem câți bytes s-au citit efectiv
        size_t count1 = f1.gcount();
        size_t count2 = f2.gcount();

        if (count1 != count2 || memcmp(buffer1.data(), buffer2.data(), count1) != 0) {
            return false;
        }
    }

    return true;
}

//command to compile:
// g++ verify_identical_binary_files.cpp -o verify_identical_binary_files
// VERIFIC REZULTATUL DIN MATRICEA C CU REZULTATUL OBITNUT IN FISIEURL BINAR DE LA EX 1
// ./verify_identical_binary_files Cmatrix_ex1.bin test1000/fileC.bin

int main(int argc, char* argv[]) {
    if (argc < 3) {
        cout << "Utilizare: " << argv[0] << " <fisier1> <fisier2>" << endl;
        return 1;
    }

    string file1 = argv[1];
    string file2 = argv[2];

    if (areFilesIdentical(file1, file2)) {
        cout << "Fisierele sunt IDENTICE." << endl;
    } else {
        cout << "Fisierele sunt DIFERITE." << endl;
    }

    return 0;
}