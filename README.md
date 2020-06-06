Specjbb supporting scripts
========================
This is the set of scripts to support specjbb performance tuning

## Content:

  specjbb.py   - report generation script
  ownsync.py   - sync directory to ownCloud instance
  runscripts   - template for specjbb run
  
  More information about individual scripts are inside the script it self

## Proposed flow:
  1. Create a folder **specjbb_cw_<date>**

     `specjbb_cw_20200518`
  
  2. Copy <specjbb_scripts>/runscripts to folder with meaningful name
      `multivm-2G-2S-1T`

  3.  Edit **options.sh** and **set_system.sh** file as required

  4.  Edit **README.md** file and add short, one-line description of this run
  
      `Turning on JVM NUMA`
  
  5.  Make **runme.sh** executable and run it with the number of similar runs you plan   
  
       `./runme.sh 4`
  
  6.  Run specjbb.py to check run results
  
       `<specjbb_scripts>/bin/specjbb.py`  

  7.  Edit options.sh, set_system.sh, README.md as necessary (previous values are stored within run automatically within run folder) and run runme.sh again

  8.  Go to specjbb_cw_<date> folder, create another folder and perform another set of runs  

      `composite-2G-2S-1T`

  9.  Go to specjbb_cw_<date> folder, specjbb.py to generate report

      `specjbb.py`  - will output all results to the console

      `specjbb.py -o specjbb_cw_20200518.xlsx`  - will output all results and corresponding options.sh to xlsx file 

      `specjbb.py -p "multivm-2G*" -o specjbb_cw_20200518_mvm.xlsx` - will output results of all multivm runs 
 
## Dependency

pip install pyocclient

pip install openpyxl

