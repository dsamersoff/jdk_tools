## Jenkins Support How-to

*** Warning! No job interference and congestion control are implemented, attempt 
    to run multiple jobs at the same time could lead to an inpredictable result***

### Prerequisites

1. Jenkins machine should be capable to build openjdk and run jtreg, 
   it should have working python3

2. Remote machine should be capable to run specjbb,
   sudo is working because specjbb should be run as root

3. Key-based ssh auth between two machines is working,
   passwd auth for remote user is turned-off


### Setup
 1. Install and run minimal jenkins 

 2. Checkout git workspace

 3. Copy or link specjbb_scripts folder to the $JENKINS_HOME

 4. Import all jobs using jenkins-cli
    java -jar jenkins-cli.jar  -auth '<user>':'<pass>' -s http://<jenkins-url> create-job <job-name> < <job-name>/config.xml


### Job tuning
 1. Adjust specjbb_scripts/jobscripts/config.sh to match your jenkins and remote machine settings
 
 2. Adjust jdk_specjbb_multivm/options.sh and jdk_specjbb_composite/options.sh to set desired specjbb option, 
    take care about memory pages 

 3. If you need to support more than one remote machine create a separate folder inside jobscripts, 
    copy config.sh and options.sh there and change it as necessary