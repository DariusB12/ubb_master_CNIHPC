# DB in Cloud - Courses
## Course1 30.09.2025
Final grade:    
|   
|->30% written exam durring session     
|->25% MS teams homeworks + AWS acad    
|->25% project  
|->20% ...we'll think about it...   
### ATTENDANCES TO SEMINARS AND COURSES ARE NOT MANDATORY
AT LEAST 7 ATTENDANCES => 1p bonus at the exam  
### MySQL => we have to use triggers for maximum grade (final doc seminar 1)
. -> for 8->9   
. -> for 9->10  (the interrogation with AS FOR or PERIOD FOR)  

instanturi = instanta de timp   
    
DDL -> the STRUCTURE    
DML -> the OPERATIONS   
    
Data warehousing:   
-OLTP Online Transaction Process: DB in at least 3NF (removes all the operations that could appear at delete/insert)    
-OLAP Online Application Processing: star schema or snowflake schema    
   
OLAP star schema:   
![star schema img](../images/olap_star_schema.png)  
    
OLAP scnowflake schema:     
![snowflake schema img](../images/olap_snowflake_schema.png)
    
Take from OLTP -> modify so we are able to store on OLAP -> OLAP    
    
CDC (Change Data Capture) = tracks and records data modifications (inserts, updates, and deletes) from a source system => enables REAL-TIME analytics     
    
!!!!Smth. NULL can be compared only with IS NULL/IS NOT NULL    
Transaction time or System time     
    
Candidate key -> attributes that identifies the record uniquely     
Surogate key -> usually used as a primary key   
!!!! For the same PK we can have different time periods => add time to PK   
    
SCN (System Change No)  
    
Even if the data is deleted => they are still in the hystory (at valid time, the history is not kept)  
    
## Course2 7.10.2025

Transaction time:  
INTRETINUT DE SISTEM  
-functionalitati de rollback  
  
Oracle cel mai avansat dpdv al persp. temporale:  
oracle sql server, postgres(cu ajut extensiilor are suport temporal)  
  
  
Valid time:  
data correction (putem si noi sa il schimbam)  
  
pentru perioadele de validitate se ataseaza metadate (backwards compatibility) e.g. PERIOD FOR  
  
Oracle - valid time de la versiunea 12c  
  
### ------------------Cloud DB------------------  
  
Traditional Approach:  
The client purchases a server  
Clientul are nevoie de un DNS pentru ca noi sa ii putem furniza app  
  
DNS Domain Name Server, mappin the ip to a name  
Web server ajung req care sunt trimise la app server  
App server preg. response-uri si le trimite la web server  
