function addnoise2HINT(varargin)
%% DESCRIPTION:
%
%   Function to add noise to HINT stimuli. User must provide a wav file
%   with the noise. Assumes HINT stimuli are in the ../playback/HINT
%   directory (hard coded for ease).
%
% INPUT:
%
% Parameters:
%
%   'mixer':    NoiseChannel x HintChannel mixing matrix. 
%
%   'suffix':   tag appended to rewritten file
%
%   'leadlag':      two element double array, temporal onset/offset of noise
%                   relative to start/end of HINT stimuli. (units in sec)
%
%   'noiserange':   two-element double array, which time range of the noise
%                   sample to use. The noise sample is often already faded
%                   in/out, so we need to use stable samples somewhere in
%                   the middle. 
%
% OUTPUT:
%
% Development:
%
% Christopher W. Bishop
%   University of Washington
%   6/14

%% PLACE PARAMETERS IN STRUCTURE
d=varargin2struct(varargin{:});  

hintdir = fullfile('playback', 'HINT'); % hint directory
noise = fullfile(hintdir, 'HINT-Noise.wav'); % hint noise

% Gather HINT file list
wavlist = regexpdir(hintdir, '[0-9]{2}.wav$', true); 

% Load noise stimulus
t.dtype=2; % only allow wav
[noise, nfs] = SIN_loaddata(noise, t); 

% Find appropriate range for noise stimulus.
%   Recall that the noise sample (at least for HINT) is faded in/out
%   already, so we need to use some samples in the middle. 
d.noiserange = round(d.noiserange .* nfs); 
noise = noise(d.noiserange(1):d.noiserange(2), :); 

% Check noise dimensions
t.fs = nfs; 
noise = SIN_loaddata(noise, t); 

% Loop through each stimulus
for i=1:numel(wavlist)
    
    % Send filename to terminal.
    display(wavlist{i}); 
    
    % Load the wav file
    t.dtype=2; 
    [wav, fs] = SIN_loaddata(wavlist{i}, t);     
    
    % Error check for mismatch in sampling rate
    if fs ~= nfs, error('Sampling rates do not match. Something amiss'); end 
    
    % Calculate number of samples to append to beginning (lead) and end
    % (lag) of wav file
    leadsamps = round(d.leadlag(1)*fs); 
    lagsamps = round(d.leadlag(2)*fs); 
    
    % Create padded data
    wavout = [zeros(leadsamps, size(wav,2)); wav; zeros(lagsamps, size(wav,2))];    
    
    % How many times must the noise be repeated?
    nreps = ceil(size(wavout,1)/size(noise,1));
    
    % Repeat noise nreps times
    %   Use rnoise variable to store "repeated noise". That way, the
    %   original 'noise' samples are not ovewritten or inadvertently
    %   ramped.
    rnoise = repmat(noise, nreps, 1);
    
    % Truncate noise to correct number of samples
    rnoise = rnoise(1:size(wavout,1), :);
    
    % Apply onset/offset ramps to noise
    %   - Use 20 ms ramps
    rnoise = fade(rnoise, fs, true, true, @hann, 0.02); 
    
    % Mix noise with mixer, add to wav file
    wavout = wavout + rnoise*d.mixer; 
    
    % write 32-bit output wav file
    [pathstr,name,ext] = fileparts(wavlist{i});
    fname = fullfile(pathstr, [name d.suffix ext]);
    wavwrite(wavout, fs, 32, fname); % write
    
end % for i