#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab shiftwidth=2 softtabstop=2

import sys
import matplotlib.pyplot as plt
import numpy as np
from openpyxl import load_workbook

def read_xlsx(filename, sheetname):
    wb = load_workbook(filename=filename, data_only=True)
    if sheetname not in wb.sheetnames:
        raise ValueError(f"Sheet '{sheetname}' not found in {filename}")
    ws = wb[sheetname]

    # Read labels
    labels = []
    for col in ws.iter_cols(min_col=2, min_row=1, max_row=1, values_only=True):
        if col[0] is None:
            break
        labels.append(col[0])

    # Read data
    data = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[0] is None:
            break
        data.append((row[0],) + tuple(row[1:]))

    return labels, data

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <xlsx_file> <sheet_name>")
        sys.exit(1)

    filename = sys.argv[1]
    sheetname = sys.argv[2]

    labels, data = read_xlsx(filename, sheetname)

    print(20 * "-", "\n", repr(labels), "\n", 20 * "-")
    print(20 * "-", "\n", repr(data), "\n", 20 * "-")

    benchmarks = [row[0] for row in data]
    values = np.array([row[1:] for row in data], dtype=float)

    n_benchmarks = len(benchmarks)
    n_groups = values.shape[1]

    x = np.arange(n_benchmarks)  # positions
    width = 0.2  # bar width

    fig, ax = plt.subplots(figsize=(14, 7))

    for i in range(n_groups):
        ax.bar(x + i*width, values[:, i], width, label=labels[i])

    ax.set_ylabel('Values')
    ax.set_title('Benchmark Results')
    ax.set_xticks(x + width * (n_groups-1) / 2)
    ax.set_xticklabels(benchmarks, rotation=45, ha="right")
    ax.legend()
    plt.tight_layout()

    plt.savefig("barchart_%s.png" % sys.argv[2], dpi=300)
    plt.show()

if __name__ == "__main__":
    main()

