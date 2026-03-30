#!/bin/bash -x

#SBATCH --job-name=Homework5
#SBATCH --output=Homework5.out
#SBATCH -N 1
#SBATCH -t 5
#SBATCH --partition=el8-rpi
#SBATCH --gres=gpu:4
#SBATCH --gres=nvme:1

module load xl_r spectrum-mpi cuda

# OUTPUT="csv"
OUTPUT="latex"

DIR="$(dirname $0)"
SCRATCH="$HOME/scratch"
NVME="/mnt/nvme/uid_${SLURM_JOB_UID}/job_${SLURM_JOB_ID}"
RESULTS="$DIR/data/$(date +%Y%m%d-%H%M%S)-results.txt"

mkdir -p "$DIR/data"

if [ "$OUTPUT" = "latex" ]; then
  echo "Ranks & NVME? & Time \\\\" > "$RESULTS"
else
  echo "Ranks,NVME?,Time" > "$RESULTS"
fi

run() {
  RANK="$1"
  CPULIST="$2"
  NVME="$3"

  FILE="$SCRATCH/hw05.bin"
  if [ "$NVME" = "true" ]; then
    FILE="$NVME/hw05.bin"
  fi

  echo "Running with $RANK ranks on CPUs $CPULIST with output file $FILE"

  temp="$(mktemp)"

  taskset --cpu-list "$CPULIST" \
    mpirun --bind-to core -np "$RANK" "$DIR/hw05" "$FILE" | tee "$temp"

  # echo "Time: $RANDOM" > "$temp" # DEBUG

  time="$(grep -oP 'Time: \K[0-9.]*' "$temp")"

  if [ "$OUTPUT" = "latex" ]; then
    echo "$RANK & $NVME & $time \\\\" >> "$RESULTS"
  else
    echo "$RANK,$NVME,$time" >> "$RESULTS"
  fi

  echo "Done with $RANK ranks, removing file..."
  rm -f "$FILE"
  rm -f "$temp"
}

run 2 "0,4" false
run 4 "0,4,8,12" false
run 8 "0,4,8,12,16,20,24,28" false
run 16 "0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60" false
run 32 "0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124" false

run 2 "0,4" true
run 4 "0,4,8,12" true
run 8 "0,4,8,12,16,20,24,28" true
run 16 "0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60" true
run 32 "0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124" true

echo
echo "All runs completed. Results:"

cat "$RESULTS"

