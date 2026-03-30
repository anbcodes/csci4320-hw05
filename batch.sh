#!/bin/bash -x

#SBATCH --job-name=Homework5
#SBATCH --output=Homework5.out
#SBATCH -N 1
#SBATCH -t 10
#SBATCH --partition=el8-rpi
#SBATCH --gres=gpu:4
#SBATCH --gres=nvme:1

module load xl_r spectrum-mpi cuda

DIR="$(dirname $0)"
SCRATCH="$HOME/scratch"
NVME="/mnt/nvme/uid_${SLURM_JOB_UID}/job_${SLURM_JOB_ID}"
RESULTS="$DIR/data/$(date +%Y%m%d-%H%M%S)-results"

mkdir -p "$DIR/data"

run() {
  RANK="$1"
  CPULIST="$2"
  NVME="$3"
  BLOCK_SIZE="$4"

  FILE="$SCRATCH/hw05.bin"
  if [ "$NVME" = "true" ]; then
    FILE="$NVME/hw05.bin"
  fi

  echo "Running with $RANK ranks on CPUs $CPULIST with output file $FILE and block size = $4"

  temp="$(mktemp)"

  taskset --cpu-list "$CPULIST" \
    mpirun --bind-to core -np "$RANK" "$DIR/hw05" "$BLOCK_SIZE" "$FILE" | tee "$temp"

  # echo "Read: $RANDOM" > "$temp" # DEBUG
  # echo "Write: $RANDOM" >> "$temp" # DEBUG

  read_bandwidth="$(grep -oP 'Read: \K[0-9.]*' "$temp")"
  write_bandwidth="$(grep -oP 'Write: \K[0-9.]*' "$temp")"

  echo "$RANK & $NVME & $read_bandwidth & $write_bandwidth \\\\" >> "$RESULTS.tex"
  echo "$RANK,$NVME,$read_bandwidth,$write_bandwidth" >> "$RESULTS.csv"

  echo "Done with $RANK ranks, removing file..."
  rm -f "$FILE"
  rm -f "$temp"
}

# for block in 1; do
for block in 1 2 4 8 16; do

  echo "Block size = $block" | tee -a "$RESULTS.tex" "$RESULTS.csv"
  echo "Ranks & NVME? & Read & Write \\\\" >> "$RESULTS.tex"
  echo "Ranks,NVME?,Read,Write" >> "$RESULTS.csv"

  run 2 "0,4" false $block
  run 4 "0,4,8,12" false $block
  run 8 "0,4,8,12,16,20,24,28" false $block
  run 16 "0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60" false $block
  run 32 "0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124" false $block

  run 2 "0,4" true $block
  run 4 "0,4,8,12" true $block
  run 8 "0,4,8,12,16,20,24,28" true $block
  run 16 "0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60" true $block
  run 32 "0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124" true $block
done

echo
echo "All runs completed. Results csv:"

cat "$RESULTS.csv"

echo
echo "Results latex:"
cat "$RESULTS.tex"

