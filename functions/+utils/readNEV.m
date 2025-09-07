function [spike, waves] = readNEV(nevfile, precision)
% READNEV Reads spike and event data from a Blackrock .nev file.
%
%   This function is a mex-optimized version of a MATLAB script for
%   reading .nev files, providing fast access to event codes and spike data.
%
%   SYNTAX:
%   [spike, waves] = readNEV(nevfile)
%   [spike, waves] = readNEV(nevfile, 1)
%
%   INPUTS:
%   nevfile   - A string containing the full path to the .nev file.
%   precision - (Optional) A flag to specify the precision for waveforms.
%               (default): returns waveforms as doubles in microvolts.
%               1: returns waveforms as raw int16 values to save memory.
%
%   OUTPUTS:
%   spike     - An Nx3 matrix where each row is an event. The columns are:
%               1: Channel ID (0 for digital events)
%               2: Spike classification unit (or digital value for events)
%               3: Timestamp of the event in seconds.
%   waves     - An optional output containing the spike waveforms.
