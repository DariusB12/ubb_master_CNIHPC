# ------------------Seminar1----------------26.02.2026  
HOMEWORK TO DO: THE REQUIREMENTS PROBLEM    
DEADLINE- week 3/4

the problem will be implemented by us and presented at the seminar(tested) when we'll meet physically (seminar2/3)

No mandatory presence for seminars/courses  

![broadcast_requirements.jpeg](course1_imgs/broadcast_requirements.jpeg)   


# ------------------Course1----------------26.02.2026  
Ex Examination period   
Rx REexamination    
    
For projects we'll have assignments on teams    
    
We'll work from the book link on the courses site   
[https://www.cs.ubbcluj.ro/~rares/course/amcds/](https://www.cs.ubbcluj.ro/~rares/course/amcds/)    

4 big classes algorithms we are looking for:    
* basic algorithms
* broadcast
* shared memory
* consensus algorithms
    
Any distributed system will have to run on a network => needs cables    
Wires = fair loss link (the inf can be lost - e.g sb cuts the cable)    
    
Types of algorithms:    
* fail-stop - work with processes that can only fail when crashing  either works perfectly or is dead (the other nodes can detect that reliably)    
* fail silent - you can't figure out when are crashed
* fail noisy - similar to fail-stop you can detect...but it's not reliable
* fail recovery node - nodes that crash and recover 
* fail arbitrary - e.g in any airplane you have 4 of each sensor (4 of altitude snesors 4 of ... sensors) why 4? because if it fails, that sensor won;t shut up, will give wrong values => you need extra sensors to figure out which snesor is out of order
* randomized - do not try to solve the roblem perfectly, i tries to solve it with a probability margin
    
Type of algorithms base on what type of: type of Nodes, type links, what about the other nodes we can know      
        
EVENTS = INTERFACE (LIKE IN CLASSES)    
PROPERTIES = CONTRACT (LIKE IN CLASSES)     
CORRECT PROCESS = the process doesnt crash, doesnt behave malliciously  
There will be no implementation for FairLossLink because is the very base level (wires)     

## FairLossLink 
![fairloss_image.png](course1_imgs/fairloss_image.png)   



## StubbornLinks - algorithm = retransmit forever
![subborn_interface.png](course1_imgs/subborn_interface.png)     
Algorithm explanation:  
We set the timer delta times, and delta times is sent the message infinetely (timeout)  
![2_stubbornlink.png](course1_imgs/2_stubbornlink.png)   

## Perfect Links - are supposed to be a certain TCP
It will eventually be delivered but only once
### Abstraction
![perfecr_link_abstraction.png](course1_imgs/perfecr_link_abstraction.png)   
    
### Implementation
We store it into the `deliver` set to assure we dont send it twice    
![perfect_implementation.png](course1_imgs/perfect_implementation.png)       


## Failure Detection
E.g if it doesnt answer in five second after giving it a ping .... but we are using maths now   

### Abstraction
![abstraction_failure_detection.png](course1_imgs/abstraction_failure_detection.png)     

### IMplementation
for every p (EVERY NODE)    
alive - a set   
deliver - a set     
    
If a node doesnt answer within delta then is dead   
Delta is like a god given constant - is math -      
![failure_implementation.png](course1_imgs/failure_implementation.png)       

# ------------------Course2----------------05.03.2026  
If a node doesn't responds in delta time => it failed   

## EventuallyPErfectFailureDetection
Pi = a set with all the nodes included the current node     
suspected = empty set   
Timeout = when time expires     
![](course2_imgs/eventuallyperfectfailuredetection.png)
    
## Leader Election
![](course2_imgs/leader_election.png)


### Leader Election ALgorithm
![](course2_imgs/leader_election_algorithme.png)
every node will be identified by an ip (e.g)  maxrank = the nodes based on ips are sorted, thefirst one has rank 1 second rank 2 and so on  
         
Upside down T means undefined value!!!!         
The leader should be the right process with the maximum rank    


## Eventual Leader Detector
![](course2_imgs/eventual_leader_detector.png)   
    
### Eventual Leader Detector Algorithm
Each node will have its own delta (=> different time of responding)     
![](course2_imgs/eventual_leader_detector_algorithm.png)

### Elect lower epoch
![](course2_imgs/elect_lower_epoch.png)
![](course2_imgs/elect_lower_epoch_2.png)
Here we will not know wether a leader is dead or not    
the higher the epoch, the more crashed the node had

## COmbining abstractions
We define the so called "systems"
System types:   
* fail-stop   
* fail-noisy  
* fail-silent - we dont know anything about the other node health
* fail-recovery 
* fail-arbitrary
* randomized

## BEST EFFORT BORADCAST
![](course2_imgs/BEST_EFFORT_BROADCAST.png)
For a correct source all the correc porcesses will get it   

### Best Effort Broadcast algorithm
![](course2_imgs/best_effort_broadcast_elgorithm.png)


## Reliable Broadcast
![](course2_imgs/Reliable_Broadcast.png)
perfect links -if you send a mesasge is received the other side

### lazy reliable broadcast algorithm
![](course2_imgs/ laz_reliable_broadcast_algorithm.png)   
    
from[p] := [0]^N (^N means the no of nodes that we have)    

