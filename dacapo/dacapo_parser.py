#!/usr/bin/env python3

import os
import re

_excel = False
try:
    from openpyxl import Workbook
    _excel = True
except Exception as ex:
    print("Warning! openpyxl is not installed") 

# Patterns to extract required data
# ===== DaCapo 23.11-MR2-chopin avrora PASSED in 37673 msec =====
# OR:
# ===== DaCapo 23.11-MR2-chopin avrora TIMED iteration 3 PASSED in 17043 ms ===
# ---------- Execution time ----------
# Average 17043.000000 ms +- 0.000000, total 17043 ms
# Perf counter (RAW:0x17): 130574
# Perf counter (RAW:0x2): 355025
# Perf counter (RAW:0x5): 293906

# benchmark_pattern0 = re.compile(r"^===== DaCapo .+? (\w+) PASSED in (\d+) msec")
# benchmark_pattern1 = re.compile(r"^===== DaCapo .+? (\w+) TIMED iteration \d PASSED in (\d+) ms")
benchmark_pattern = re.compile(r"^===== DaCapo .+? (\w+) .*PASSED in (\d+) ms")
avg_time_pattern = re.compile(r"^Average ([\d\.]+) ms")
counter_pattern = re.compile(r"^Perf counter \(([A-Z]+):(0x[\da-fA-F]+)\): (\d+)")

class Iteration:
    def __init__(self):
        self.benchmark = None
        self.time_raw = 0
        self.time_avg = 0
        self.counters = dict()

    def __str__(self):
        s = "%-10s %.2f %.2f" %  (self.benchmark, self.time_raw, self.time_avg);
        for (k,v) in self.counters.items():
            s += " %s %.2f" % (k, v)
        return s

def extract_data_from_file(file_path):
    results = []
    iter = Iteration()

    with open(file_path, 'r') as file:
        for line in file:
            match = benchmark_pattern.search(line)
            if match:
                iter = Iteration()
                iter.benchmark = match.group(1)
                iter.time_raw = int(match.group(2))
                results.append(iter)
            match = avg_time_pattern.search(line)
            if match:
                results[-1].time_avg = float(match.group(1))
            match = counter_pattern.search(line)
            if match:
                counter_type = match.group(1)
                counter = match.group(2)
                value = int(match.group(3))
                results[-1].counters[counter] = value

    return results[-1] if len(results) > 0 else None

def read_all_files_in_directory(directory):
    all_results = []
    for filename in os.listdir(directory):
        full_path = os.path.join(directory, filename)
        if os.path.isfile(full_path) and full_path.endswith(".log"):
            file_results = extract_data_from_file(full_path)
            # all_results.extend(file_results)
            if file_results != None:
                all_results.append(file_results)
    all_results.sort(key=lambda x: x.benchmark)
    return all_results

def write_to_excel(data, output_file):
    wb = Workbook()
    ws = wb.active
    ws.title = "Benchmark Results"

    # Write headers
    row = ["Benchmark", "Time of run", "Time avg"]
    for k in data[0].counters:
        row.append(k)
    ws.append(row)

    # Write data rows
    for iter in data:
        if iter.benchmark != None:
            row = [iter.benchmark, iter.time_raw, iter.time_avg]
            for (k,v) in iter.counters.items():
                row.append(v)
            ws.append(row)

    wb.save(output_file)
    print(f"Results saved to {output_file}")

# Example usage:
if __name__ == "__main__":
    input_directory = "."   # change this to your directory
    output_excel = "benchmark_results.xlsx"

    extracted_data = read_all_files_in_directory(input_directory)
    if len(extracted_data) > 0:
      if _excel:
        write_to_excel(extracted_data, output_excel)

      # Write data to tty 
      for iter in extracted_data:
        print(iter)
    else:
      print("No data found")
