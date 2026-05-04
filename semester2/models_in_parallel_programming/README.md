# --------------Course1-------------- 26.02.2026    
* 40% labs - can be delivered only during the semester  
* 25% research paper - we should focuse on the mchanisms that allows us to create prallel program, only one student can have a model!!!!
* 35% exam  
        
ONLY THE FINAL GRADE SHOULD BE > 4.5    
    
You can replace written exam with an app oriented exam      
    
NO mandatory presence at courses seminars or labs, but for labs is mandatory to present them   
    
## COMMAND TO START THE VPN        
`wg-quick up wireguard`     
## COMMAND TO STOP THE VPN     
`wg-quick down wireguard`      

## COMMAND TO CONNECT TO CLUSTER - SSH
`ssh bdcl0006@10.111.111.100 -p 22`
    
## COMMAND TO COPY LOCAL FILES TO CLUSTER NODE - SSH
`scp -J bdcl0006@10.111.111.100 "/media/darius/ADATA SE880/UBB Master 2025-2027/ubb_master_CNIHPC/semester2/models_in_parallel_programming/labs/lab1/lab1/generateMatrix" bdcl0006@compute068:~/`
    
## ON CLUSTER WHEN COMPILING A C++ PROJECT I SHOULD SPECIFY TO COMPILE WITH C++11 VERSION - SSH
`g++ -std=c++11 generateMatrix.cpp -o generateMatrix`

## COMPILE MPI PROGRAM on cluster
`/usr/mpi/gcc/openmpi-1.8.8/bin/mpicxx -std=c++11 -O3 main4a.cpp -o main4a`
## run mpi porgram on cluster
`/usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np 25 -hostfile nodes.txt ./main4a 1000 test1000/fileA.bin test1000/fileB.bin test1000/fileC.bin`
    
## COMMAND TO START THE VPN WHEN POWER ON THE PC
`systemctl enable wg-quick@wireguard`   
## COMMMAND TO DISABLE THE VPN TO START AT POWER ON
`systemctl disable wg-quick@wireguard`  
