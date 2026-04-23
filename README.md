# A MATLAB Pipeline for Electrophysiological Analysis

This repository contains a modular, GUI-based MATLAB pipeline designed for the 
analysis of electrophysiological data acquired from stretchable microelectrode 
arrays (sMEAs) using the Intan RHS recording system.

## Overview
This tool was developed to address the analytical challenges specific to sMEA 
recordings, providing a unified workflow that handles raw data from individual 
channels through to large-scale network activity. The pipeline is open-source 
and requires no custom scripting, making it accessible for neurotrauma research 
laboratories.

## Key Features
* **Data Import:** Native parsing of Intan RHS binary files.
* **Signal Conditioning:** Three-band filter bank (LFP, MUA, and Notch) with zero-phase filtering.
* **Spike Detection:** Four threshold modes (Absolute, RMS, MAD, and Peak) with real-time visualization.
* **Spike Sorting:** PCA-based dimensionality reduction with automated k-means or GMM clustering using the elbow method.
* **Network Analysis:** Automated burst detection and STTC-based synchrony quantification.
* **Quality Control:** Automated QC reporting with SNR grading and unit-level isolation metrics.

## Prerequisites
* **MATLAB:** Compatible with R2019b and later.
* **Toolboxes:** Signal Processing Toolbox.
* **Compatibility:** Compatible with both MATLAB and GNU Octave.

## Getting Started
1. **Clone the repository:** `git clone https://github.com/your-username/your-repo-name`
2. **Open in MATLAB:** Navigate to the folder and run `main.m` to launch the GUI.
3. **Configuration:** Use the GUI panels to load your .rhs files and adjust parameters. 
   Detailed parameter logging is performed automatically for all analytical decisions.

## Pipeline Workflow
The pipeline is organized into six sequential modules:
1. **Data Import and Signal Conditioning:** Parses raw Intan data and applies filtering.
2. **Spike Detection:** Detects and classifies action potentials.
3. **Spike Sorting and Feature Extraction:** Resolves single-unit activity via PCA and clustering.
4. **Burst Detection and ISI Analysis:** Analyzes firing statistics and network-level bursts.
5. **Network Analysis and Synchrony:** Quantifies network coordination using the Spike-Time Tiling Coefficient (STTC).
6. **Quality Control Metrics:** Generates automated reports on channel/unit quality.

## Contributing
Feedback and contributions are welcome. Please use the "Issues" tab to report bugs or request features.
