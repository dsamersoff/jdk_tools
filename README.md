This repo contains set of utilities to support JVM perfromance work
===================================================================


Specjbb supporting scripts
========================
This is the set of scripts to support specjbb performance tuning

## Content:

  **specjbb.py**   - report generation script (check help for usage guidelines)

  **ownsync.py**   - sync directory to ownCloud instance (check help for usage guidelines)
  
  **runscripts**   - template for specjbb run

  **tmux.conf**    - file to copy to ~/.tmux.conf, binds C-A  

  More information about individual scripts are inside the script it self

## Proposed flow:
  1. Create a folder **specjbb_cw_date**

    e.g. `specjbb_cw_20200518`
  
  2. Copy <specjbb_scripts>/runscripts to folder with meaningful name

    e.g.  `multivm-2G-2S-1T`

  3.  Edit **options.sh** and **set_system.sh** file as required

  4.  Edit **README.md** file and add short, one-line description of this run
  
    e.g.  `Turning on JVM NUMA`
  
  5.  Make **runme.sh** executable and run it with the number of similar runs you need, it's recommended to use tmux or screen    
  
       `./runme.sh 4`
  
  6.  Run specjbb.py to check run results
  
       `<specjbb_scripts>/bin/specjbb.py`  

  7.  Edit options.sh, set_system.sh, README.md as necessary (previous values are stored automatically within run folder) and run runme.sh again

  8.  Go to **specjbb_cw_date** folder, create another folder and perform another set of runs  

      e.g. `composite-2G-2S-1T`

  9.  Go to **specjbb_cw_date** folder, specjbb.py to generate report

      `specjbb.py`  - will output all results to the console

      `specjbb.py -o specjbb_cw_20200518.xlsx`  - will output all results and corresponding options.sh to xlsx file 

      `specjbb.py -p "multivm-2G*" -o specjbb_cw_20200518_mvm.xlsx` - will output results of all multivm runs 

  10. Backup results or entire data to a cloud

## Dependency

pip install pyocclient

pip install openpyxl

## Cloud support
ownsync script supports owncloud, cloud URL and credentials are stored in ~/.ownsync.ini this file is generated after first run with empty username/password and 4foo cloud url. All uploads are prefixed with uname of source machine for convenience.
