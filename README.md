A MATLAB Pipeline for Electrophysiological Analysis
This repository contains a modular, GUI-based MATLAB pipeline designed for the analysis of electrophysiological data acquired from stretchable microelectrode arrays (sMEAs) using the Intan RHS recording system.

Overview
This tool was developed to address the analytical challenges specific to sMEA recordings, providing a unified workflow that handles raw data from individual channels through to large-scale network activity. The pipeline is open-source and requires no custom scripting, making it accessible for neurotrauma research laboratories.

Key Features
Data Import: Native parsing of Intan RHS binary files
Signal Conditioning: Three-band filter bank (LFP, MUA, and Notch) with zero-phase filtering
Spike Detection: Four threshold modes (Absolute, RMS, MAD, and Peak) with real-time visualization
Spike Sorting: PCA-based dimensionality reduction with automated k-means or GMM clustering using the elbow method
Network Analysis: Automated burst detection and STTC-based synchrony quantification
Quality Control: Automated QC reporting with SNR grading and unit-level isolation metrics.

Prerequisites

MATLAB: Compatible with R2019b and later
Toolboxes: Signal Processing Toolbox
Environment: Compatible with MATLAB or GNU Octave

Getting Started
Clone the repository: git clone [https://github.com/sketch123456/BMSeed-data-analysis-pipeline]
Open in MATLAB: Navigate to the folder and run MEA_GUI.m to launch the GUI.
Configuration: Use the GUI panels to load your .rhs files and adjust parameters.


