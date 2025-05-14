# Overview
This is a basic shell script to total up the capacity in each PowerFlex Replication Consistency Group.

The script will create a .csv file with the capacity information by host.

![Screenshot of the script completing a run.](https://github.com/murphyry/powerflex-replication-capacity/blob/main/rcg_script_output_example.png)

![Screenshot of the csv output from the script.](https://github.com/murphyry/powerflex-replication-capacity/blob/main/rcg_csv_example.png)

# Directions
### Pre-reqs:
- This script makes API calls to the PowerFlex Manager API using the curl package. Check if curl is installed by running ```curl -V```
- This script parses the API call output using the jq package. Check if jq is installed by running ```jq```
- This script performs division on variables using the bc package. Check if bc is installed by running ```bc```
### Download the script:
- ```wget https://raw.githubusercontent.com/murphyry/powerflex-replication-capacity/refs/heads/main/powerflex_rcg_capacity.sh```
### Edit the script and add your PowerFlex Manager username, password, and IP address in the "SCRIPT VARIABLES" section:
- ```vim powerflex_rcg_capacity.sh```
### Make the script executable:
- ```chmod +x powerflex_rcg_capacity.sh```
### Run the script to generate the .csv file:
- ```./powerflex_rcg_capacity.sh```

