function [lfp, mua, filtered_notch] = filter_bank(signal, Fs, filter_order, notch_freq)
% FILTER_BANK  Three-branch filter applied to a single-channel signal.
%
% INPUTS:
%   signal       — raw signal (uV)
%   Fs           — sampling rate (Hz)
%   filter_order — Butterworth filter order
%   notch_freq   — line noise frequency to reject (50 or 60 Hz)
%
% OUTPUTS:
%   lfp            — low-pass filtered (<300 Hz), local field potential
%   mua            — bandpass filtered (300–3000 Hz), multi-unit activity
%   filtered_notch — notch-filtered signal (line noise removed)

    nyq = Fs / 2;

    % LFP: low-pass <300 Hz
    [b_lfp, a_lfp] = butter(filter_order, 300 / nyq, 'low');
    lfp = filtfilt(b_lfp, a_lfp, signal);

    % MUA: bandpass 300–3000 Hz
    high_mua = min(3000, nyq * 0.95);
    [b_mua, a_mua] = butter(filter_order, [300 high_mua] / nyq, 'bandpass');
    mua = filtfilt(b_mua, a_mua, signal);

    % Notch: narrow reject at 50 or 60 Hz
    bw = notch_freq * 0.05;
    [b_n, a_n] = butter(2, [(notch_freq - bw) (notch_freq + bw)] / nyq, 'stop');
    filtered_notch = filtfilt(b_n, a_n, signal);
end
