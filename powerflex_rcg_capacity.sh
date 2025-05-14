#!/bin/bash 

########################################################################################################################################################### 
#SCRIPT VARIABLES - SET YOUR POWERFLEX MANAGER CREDENTIALS HERE
########################################################################################################################################################### 
PFXM_IP='YOUR_PFXM_IP'
PFXM_USER='YOUR_PFMX_USER'
PFXM_PASSWORD='YOUR_PFXM_USER_PASSWORD'

###########################################################################################################################################################  

#SCRIPT COLORS FOR ECHO OUTPUT  
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
LIGHT_PURPLE='\033[1;35m'
YELLOW='\033[1;33m'  
NC='\033[0m'

#START SCRIPT
echo " "
echo -e "${YELLOW}######################################################################################################## ${NC}"
echo -e "${YELLOW}# PowerFlex 4.6+ Replication Capacity Script ${NC}"
echo -e "${YELLOW}# Version: 1.0.0"
echo -e "${YELLOW}# Requirements: curl, jq, and bc packages ${NC}"
echo -e "${YELLOW}# Support: No support provided, use and edit to your needs ${NC}"
echo -e "${YELLOW}# PowerFlex API Reference: https://developer.dell.com/apis/4008/versions/4.6.1/PowerFlex_REST_API.json ${NC}"
echo -e "${YELLOW}######################################################################################################## ${NC}"
echo " "

#Log into API and get a token
TOKEN=$(curl -s -k --location --request POST "https://${PFXM_IP}/rest/auth/login" --header "Accept: application/json" --header "Content-Type: application/json" --data "{\"username\": \"${PFXM_USER}\",\"password\": \"${PFXM_PASSWORD}\"}") 
ACCESS_TOKEN=$(echo "${TOKEN}" | jq -r .access_token) 

#Get the system id to use for the csv file name
SYSTEM=$(curl -k -s -X GET "https://$PFXM_IP/api/types/System/instances/" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Bearer $ACCESS_TOKEN")
SYSTEM_ID=$(echo $SYSTEM | jq .[].id| tr -d '"')
echo -e "${GREEN}[SUCCESS] - Connected to PowerFlex system ${SYSTEM_ID}${NC}"
echo " "
echo -e "${CYAN}[QUERYING RCGs]${NC}"

#Create CSV file to hold information for hosts
CSV_NAME="${SYSTEM_ID}_rcg_report.csv"
echo "RCG_NAME,RCG_ID,RCG_STATE,RCG_RPO_SECONDS,VOLUME_PAIRS,RCG_PROVISIONED_GIB,RCG_USED_GIB" > $CSV_NAME

#Get all RCGs in the system so we can extract all RCG IDs into an array
RCGS=$(curl -k -s -X GET "https://$PFXM_IP/api/types/ReplicationConsistencyGroup/instances" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Bearer $ACCESS_TOKEN")

#Extract the RCG IDs
RCG_IDS=$(echo $RCGS | jq .[].id)

#create an array from the RCG IDs
readarray -t bash_array < <(echo "$RCG_IDS")


#For each RCG ID
for RCG in "${bash_array[@]}"; do
  #extract the RCG ID into a format that works with curl
  RCG_ID=$(echo $RCG | tr -d '"')
  
  #Get all volumes inside the RCG 
  PAIRS=$(curl -k -s -X GET "https://$PFXM_IP/api/instances/ReplicationConsistencyGroup::$RCG_ID/relationships/ReplicationPair" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Accept: application/json")

  #Extract the local volume IDs (source volumes)
  VOLUME_IDS=$(echo $PAIRS | jq -r '.[].localVolumeId')
  
  #Get the RCG's info
  RCG_INFO=$(curl -k -s -X GET "https://$PFXM_IP/api/instances/ReplicationConsistencyGroup::$RCG_ID" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Accept: application/json")
  
  #Extract out the RCG name, state, and RPO
  RCG_Name=$(echo $RCG_INFO | jq .name | tr -d '"')
  RCG_RPO=$(echo $RCG_INFO | jq .rpoInSeconds | tr -d '"')
  RCG_STATE=$(echo $RCG_INFO | jq .abstractState | tr -d '"')
  
  echo -e "${CYAN}-RCG [${RCG_Name}] FOUND${NC}"   
  
  #Variables to total up the volume stats for this RCG
  TOTAL_VOLUMES=0
  TOTAL_SIZE_KIB=0
  TOTAL_IN_USE_KIB=0
  
  #for each volume id collect its information and add it to the totals
  for volume in $VOLUME_IDS; do
    
    #get all volume info
    VOLUME_INFO=$(curl -k -s -X GET "https://$PFXM_IP/api/instances/Volume::$volume" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Accept: application/json")
    
    #extract the volume size
    VOLUME_SIZE=$(echo $VOLUME_INFO | jq .sizeInKb)
    
    #extract vtree id and use it to find how much is written to the volume
    VTREE_ID=$(echo $VOLUME_INFO | jq -r '.vtreeId')
    VTREE_STATS=$(curl -k -s -X GET "https://$PFXM_IP/api/instances/VTree::$VTREE_ID/relationships/Statistics" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Accept: application/json")
    VTREE_IN_USE=$(echo $VTREE_STATS | jq -r '.netCapacityInUseInKb')
    
    #Update the RCG totals
    TOTAL_IN_USE_KIB=$(($TOTAL_IN_USE_KIB + $VTREE_IN_USE))
    TOTAL_SIZE_KIB=$(($TOTAL_SIZE_KIB + $VOLUME_SIZE))
    TOTAL_VOLUMES=$(($TOTAL_VOLUMES+1))
	
  done
  
  #convert from KIB to GIB using bc so its not rounded down, using two decimal places
  TOTAL_SIZE_GIB=$(echo "scale=2; ${TOTAL_SIZE_KIB}/1024/1024" | bc) 
  TOTAL_IN_USE_GIB=$(echo "scale=2; ${TOTAL_IN_USE_KIB}/1024/1024" | bc) 
  
  #Add the RCGs entry to CSV file
  echo "${RCG_Name},${RCG_ID},${RCG_STATE},${RCG_RPO},${TOTAL_VOLUMES},${TOTAL_SIZE_GIB},${TOTAL_IN_USE_GIB}" >> $CSV_NAME
 
  #sleep before next RCG
  echo -e "${CYAN}-RCG [${RCG_Name}] COMPLETE ${NC}"  
  sleep 2
  
done

#print out the final status
echo -e "${CYAN}[QUERYING RCGs COMPLETE]${NC}"
echo " "
echo -e "${GREEN}######################################################################################################## ${NC}"
echo -e "${GREEN}# Script has completed. ${NC}"
echo -e "${GREEN}# CSV output can be found at $PWD$/$CSV_NAME ${NC}"
echo -e "${GREEN}######################################################################################################## ${NC}"
echo " "

