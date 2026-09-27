#!/bin/zsh
set -eu

project_root=${0:A:h:h:h}
suite_root=/Users/Dilan/eda/wire-to-decision/oss-cad-suite
source "$suite_root/environment"

mkdir -p "$project_root/reports/memory_spike"

source_file="$project_root/rtl/memory_spike/memory_spike.sv"
report_dir="$project_root/reports/memory_spike"

run_synth() {
    top=$1
    log="$report_dir/${top}.log"
    json="$report_dir/${top}.json"
    yosys -q -l "$log" -p "read_verilog -sv $source_file; hierarchy -top $top; synth_ecp5 -top $top -json $json"
}

run_synth memory_spike_one_framebuffer_top
run_synth memory_spike_zbuffer_top
run_synth memory_spike_fifo_top
run_synth memory_spike_top

printf '%s\n' "memory spike synthesis complete"
printf '%s\n' "reports: $report_dir"
