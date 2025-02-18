#!/bin/sh

# Checking the input arguments
usage="Usage: vfvs_postprocess_atg-prescreen_slurm.sh [top_N_results]

Description: Postprocessing the ATG Prescreen, and preparing the todo files for the ATG Primary Screens.
The script can handle multiple docking scenarios in the ATG Prescreen. Optionally, you can provide a number
which specifies how many top results to retrieve per scenario.
"

if [ "$1" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi

if [ "$#" -gt 1 ]; then
   echo -e "\nWrong number of arguments.\n"
   echo -e "\n${usage}\n\n"
   echo -e "Exiting..."
   exit 1
fi

# Determine if --top is used and:
# 1. Extract the value for --top (if argument is used)
# 2. Set file suffix accordingly (some files are named differently depending on whether this argument is used)
top_arg=""
file_suffix="ranking.complete.csv"
if [ "$#" -eq 1 ]; then
   if ! [[ "$1" =~ ^[0-9]+$ ]]; then
      echo -e "\nError: The argument must be a positive integer.\n"
      echo -e "\n${usage}\n\n"
      echo -e "Exiting..."
      exit 1
   fi
   top_arg="--top $1"
   file_suffix="top-$1.csv"
else
   echo -e "\nWarning: Running vfvs_get_top_results_slurm.py without --top. All results will be saved.\n"
fi

# Output-files directory
echo "Creating output-files folder (if it does not yet exist) ..."
mkdir -p ../output-files
cd ../output-files

# Getting the CSV files with the ligand rankings
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do
  echo "Generating the ranking of docking scenario ${ds} and downloading it to ../output-files/${ds}.${file_suffix} ..."
  ../tools/vfvs_get_top_results_slurm.py --scenario-name $ds $top_arg --download
done

# Creating subset of the CSV files
for ds in $(cat ../workflow/config.json | jq -r ".docking_scenario_names" | tr "," " " | tr -d '\"\n[]' | tr -s " "); do
  input_file="${ds}.${file_suffix}"
  if [ ! -f "$input_file" ]; then
      echo "Error: Expected file $input_file not found! Skipping subset creation for $ds."
      continue
  fi
  echo "Creating a subset of the ranking file with fewer columns and storing it in ../output-files/${ds}.ranking.subset-1.csv.gz ..."
  awk 'BEGIN { FS=OFS="," } { gsub("_", ",", $2); print }' "$input_file" | awk -F ',' '{print $2","$3","$1","$8}' | sed "1s/.*/Tranche,Collection,LigandVFID,ScoreMin/" | tr -d '\"' | pigz -c > "${ds}.ranking.subset-1.csv.gz"
done

# Compressing the complete ranking files
for ds in $(cat ../workflow/config.json | jq -r ".docking_scenario_names" | tr "," " " | tr -d '\"\n[]' | tr -s " "); do
  input_file="${ds}.${file_suffix}"
  if [ ! -f "$input_file" ]; then
      echo "Error: Expected file $input_file not found! Skipping compression for $ds."
      continue
  fi
  echo "Compressing the file ../output-files/${input_file} into ../output-files/${ds}.ranking.complete.csv.gz ..."
  cat "$input_file" | tr -d '\"' | pigz -c > "${ds}.ranking.complete.csv.gz"
  rm "$input_file"
done

wait 

cd ../tools
