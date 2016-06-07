function [snr_requested, snr_theoretical, snr_empirical, target_empirical, attenuation, noise_empirical, target_theoretical, noise_theoretical, haspi] = analysis_Hagerman(results, varargin)
%% DESCRIPTION:
%
%   This function analyzes Hagerman-style (that is, phase inversion
%   technique) recordings to estimate the target/noise tracks, estimate
%   the noise floor of the playback/recording loop (this includes
%   environmental noise), and estimates the signal to noise ratio of the
%   input and output signals.
%
% INPUT:
% 
%   results:   data information. Can be one of the following formats
%               - results structure from SIN_runTest.
%               - string, path to a mat file containing the results 
%               structure. 
%
% Parameters:
%
%   Parameters for Hagerman Labeling:
%
%   'target_string': string used to name the target (e.g., 'T')
%
%   'noise_string':     string used to name the noise (e.g., 'N')
%
%   'inverted_string':  string used to flag phase inverted target/noise
%                       (e.g., 'inv')
%
%   'original_string':  string used to flag non-phase inverted target/noise
%                       (e.g., 'orig')
%   
%   'pflag':     integer, sets plotting level. This parameter is inherited
%                by secondary functions as well. At time of writing, 2 is
%                the highest level of plotting detail. 0 means no plots. 
%
%   'absolute_noise_floor': string. This string is compared against
%                           all file names in the playback list. If a match
%                           is found, then this file is assumed to contain
%                           the absolute noise floor estimate, however the
%                           user decides to estimate it. This is typically
%                           done by recording "silence" for some period of
%                           time. 
%
%   'average_estimates':   bool, if set then the target waveforms are
%                          collapsed (temporally averaged) to create a
%                          single target waveform. Recall that the target
%                          can be estimated in two was ( (oo - oi)/2 and
%                          (io - ii)/2 ). The same is done for the noise
%                          waveform.
%
%                           Note: only "true" supported at time this was
%                           written. See development section for more
%                           notes. 
%
%                           Note: Also note that estimates may NOT be
%                           averaged if a temporal misalignment is
%                           detected. In these cases, one of the two
%                           estimates is discarded. 
%
%   'channels': integer array, contains channel numbers to include in
%               Hagerman analysis. Note that the user should EXCLUDE all
%               channels that have no data (all zeros). On the Amp Lab PC,
%               that means only including channels 1 and 2. 
%
%   'analysis_window':  two-element array specifying the window used for
%                       analysis. Positive elements are referenced to the
%                       start of the file, while negative elements are
%                       referenced to the end of the file.
%
%                       Note: the time reference refers to the time of the
%                       original playback file. These times are
%                       (approximately) remapped onto the recordings. 
%
%                       Example 1: [0 inf] uses the whole time trace
%
%                       Example 2: [30 inf] excludes the first 30 sec of the
%                       recording
%
%                       Example 3: [-30 inf] uses only the last 30 sec of
%                       the recording
%
%
% Weight Estimation Parameters:
%
% When we record from multiple speakers at once and are using directional
% microphones (e.g., recording from KEMAR), then we have to adjust our
% input SNR estimates for head shadowing and directional effects. This can
% be done by playing a reference sound from each location in turn and
% recording it through the identical recording loop. These recordings can
% then be reduced to a series of weights (e.g., relative RMS values) that
% can be used to adjust the input SNR *at the ear*. The parameters below
% control weight estimation.
%
%   'apply_weights':    string, path to results file used to estimate
%                       location and channel specific weights. These
%                       weights are used to "adjust" the theoretical SNR
%                       estimates. This, in "theory", will produce a better
%                       match between theoretical and empirical estimates. 
%
%                       This has a special value 'auto' that will
%                       automatically select the best matched weights file.
%                       This is done in the function
%                       Hagerman_find_weight_estimation.m. See that
%                       function for more details. 
%
% HASPI/HASQI Parameters:
%
% We would like to incorporate metrics other than SNR in our Hagerman
% analyses as well. One is the hearing-aid speech perception index (HASPI)
% described by Kates and Arehart (2014) Speech Comm. The parameters here
% are used (in conjunction with others) to configure the HASPI estimates.
% These parameters are also applied to the hearing-aid speech quality index
% (HASQI) described elsewhere (CWB can't get the paper at the moment). 
%
% NOTE: At time of writing, CWB is not sure if HASPI and HASQI should be
% calculated using the full (aided) recordings or the truncated segments.
% He *thinks* the truncated segments is a better idea (e.g., the last 30
% seconds), but definitely unsure. Need to think about this more.
%
% NOTE: HASPI/HASQI absolutely *require* the user to include a weight
% estimation file. The weight estimation file is used to estimate absolute
% levels of the microphones.
%
%   'run_haspi':    bool, flag to run HASPI/HASQI analyses. These are *very
%                   *slow, so we don't want to enable these analyses during
%                   run time for "spot checking". Instead, we'll want to
%                   run these when we have more time and computational
%                   resources.
%
%   'HL':   a 2 x 6 vector of pure tone thresholds (audiogram). HLs should
%           correspond to [250, 500, 1000, 2000, 4000, 6000] Hz. The first
%           row corresponds to the first channel (typically left ear) and
%           the second row corresponds to the second channel (typically
%           right ear). 
%
%   'haspi_mic_gain':               the microphone gain difference between
%                                   weight estimation and the recording
%                                   session. Often times the gain settings
%                                   are adjusted and we have to account for
%                                   these adjustments here. For instance,
%                                   the mic gain may be turned down in the
%                                   aided condition relative to the weight
%                                   estimation segment. XXX Description of
%                                   sign XXX
%
%   'haspi_reference_mixer':    D x 1 vector, where D is the number of
%                               channels in the original playback file.
%                               These are mixing weights used to estimate
%                               the "ideal" signal for the HASPI/HASQI
%                               calculations. Ex.: [1;0;0;0;0;0]
%
%   'haspi_reference_dbspl':    the SPL level of the reference sound. When
%                               written, this was 65 dB, but this might
%                               change. HASPI/HASQI wants an RMS = 1 to be
%                               equivalent to 65 dB SPL. Need this
%                               information to take care of this scaling in
%                               code. 
%
% Filtering Parameters:
%
% While running analyses at UofI in November 2014, CWB discovered that the
% high-power, low-frequency drift present in recordings at UofI will often
% dominate some of the routines used here (e.g., temporal alignment). Here,
% CWB describes parameters that can be used to filter the raw recordings
% prior to further calculation/manipulation (e.g., apply a highpass
% filter). The filtering routines invoke MATLAB's butter and filtfilt
% methods. Recall that filtfilt effectively doubles the order of the IIR,
% so adjust accordingly if you care.
%
%   'apply_filter': bool, if true, then the filter with the following
%                   specifications is designed and applied to the
%                   recordings prior to any further calculations. This
%                   proved useful at UofI which had a tremendous amount of
%                   low-frequency drift. 
%
%                   Note that the fulter is designed using MATLAB's
%                   'butter' function combined with 'filtfilt'. Thus, the
%                   practical order of the filter is double what is
%                   specified below. User should adjust if necessary. 
%
%   'filter_type':  filter type, see butter for details (e.g., 'high')
%
%   'filter_order': filter order, see butter for details (e.g., 4)
%
%   'filter_frequency_range':   corner frequency information for filter design.
%                           This may be a one- or two-element vector
%                           depending on filter_type. See butter for
%                           details (e.g., 125).
%
% OUTPUT:
%
%   results:    modified results structure with analysis results field
%               populated.
%
% Development:
%
%   1) Allow users to provide a string with tags in it (e.g.,
%   %%target_string%% to denote where labels should be in the file name. A
%   regular expression, perhaps? Currently, this is hard-coded. Could cause
%   some issues down the road if we decide to change the file name format. 
%
%   2) Allow users to break down SNR estimates by channel AND estimate
%   (recall that signal and noise can be estimated in two ways, each). The
%   code currently temporally averages these two estimates to get a concise
%   picture of what the SNR looks like.
%
%   3) Add in a binary masker for use in RMS calculations. This should
%   improve the accuracy of RMS calculations. 
%
%   4) Add in option for RMS estimation routine (e.g., unweighted,
%   A-weighted, etc.) 
%
% Christopher W Bishop
%   University of Washington
%   9/14

%% GET INPUT PARAMETERS
d=varargin2struct(varargin{:});

%% GATHER FILENAMES AND RECORDINGS
filenames = results.RunTime.sandbox.playback_list; 
playback_data = results.RunTime.sandbox.stim; 
recordings = results.RunTime.sandbox.mic_recording; 

%% GET THE MIXER USED DURING PLAYBACK
mixer = results.RunTime.player.mod_mixer; 

%% GET SAMPLING RATE/NUMBER OF CHANNELS
FS = results.RunTime.player.record.device.DefaultSampleRate;

%% QUICK SAFETY CHECK
if numel(filenames) ~= numel(recordings)
    error('Number of filenames does not match the number of recordings'); 
end % if numel(fnames)

%% GROUP FILENAMES AND DATA TRACES
%   The data traces are the recordings written to the structure
display('Loading files from structure'); 

for i=1:numel(filenames)
    
    data{i,1} = filenames{i};
    
    % Do we need to design a filter?
    %   We will only estimate filter coefficients if the user wants to apply a
    %   filter below.
    if d.apply_filter
        
        display(['Filtering (' num2str(i) '/' num2str(numel(filenames)) ')']); 
        
        % Note that frequency vector is normalized to Nyquist
        [b, a] = butter(d.filter_order, d.filter_frequency_range./(FS/2), d.filter_type);

        data{i,2} = filtfilt(b,a,recordings{i}); 
    else
        data{i,2} = recordings{i};
    end % d.apply_filter
    
end % for i=1:numel ...

%% LOOK FOR NOISE FLOOR RECORDING
%   In some instances, the user may acquire an absolute noise floor
%   estimate - that is, a recording of "silence" to estimate the noise
%   levels in the sound playback/recording loop and any ambient noise. This
%   can be helpful for SNR estimation and correction or offline filter
%   design to remove (ambient) noise contaminants. 
noise_floor_mask = ~cellfun(@isempty, strfind(filenames, d.absolute_noise_floor)); 

% Sanity check to make sure there's only one noise floor estimate
if numel(noise_floor_mask(noise_floor_mask)) > 1
    error('More than one match found for noise floor estimation. Multiple estimates not supported (yet)');
end 

% Save the noise floor recording for further analysis below
noise_floor_recording = recordings{noise_floor_mask}(:,d.channels); 

% Apply filter if use tells us to.
if d.apply_filter
    noise_floor_recording = filtfilt(b,a,noise_floor_recording);
end % if d.apply_filter
noise_floor_rms = rms(noise_floor_recording); 

%% CLEAN FILENAMES FOR MATCHING
%   We want to strip the filenames of the target/noise inversion
%   information and just match the basenames. First step is to get the base
%   names. 
basename = cell(numel(filenames), 1); 
for i=1:numel(filenames)
    
    % Get the current file name
    tmp = filenames{i};
    
    % Remove all 4 possible naming combinations
    tmp = strrep(tmp, [d.target_string d.original_string d.noise_string d.original_string], ''); % +1, +1
    tmp = strrep(tmp, [d.target_string d.original_string d.noise_string d.inverted_string], '');  % +1, -1
    tmp = strrep(tmp, [d.target_string d.inverted_string d.noise_string d.inverted_string], '');  % -1, -1
    tmp = strrep(tmp, [d.target_string d.inverted_string d.noise_string d.original_string], '');  % -1, +1
    
    basename{i,1} = tmp;
    
    clear tmp
end % for i=1:numel(fnames)

%% GROUP FILES BY BASENAME
%   Now that we have the basenames for the original files, we can figure
%   out which recordings should be grouped together based on the filename
%   alone. 

% fgroup is a grouping variable
file_group =zeros(numel(filenames),1); 

% while ~isempty(basename)
for i=1:numel(basename)
    mask = false(numel(basename),1); 
    
    ind = strmatch(basename{i}, basename, 'exact'); 
    if file_group(ind(1)) == 0
       file_group(ind) = max(file_group)+1; 
    end % if fgroup
    
end % for i=1:numel(fnames)

%% NOW TOSS OUT GROUPS WITH FEWER THAN 4 SAMPLES
%   - Fewer than 4 samples will be found for noise floor matching. 
%   - This will implicitly remove the noise floor estimate, if it's here. 
group_numbers = unique(file_group);
for i=1:numel(group_numbers)
    
    if numel(file_group(file_group == group_numbers(i))) < 4
        file_group(file_group==group_numbers(i)) = NaN;
    end % if numel ...
    
end  % for i=1:numel(grps)

%% FOR REMAINING GROUPS, LOOP THROUGH AND PERFORM ANALYSES

% Number of groups tells us how many file groupings we have. This should
% correspond to the number of SNRs we have recorded. 
group_numbers = unique(file_group(~isnan(file_group))); 

% snr will tell us the SNR corresponding to each group. This is discovered
% below using some simple string matching. Granted, it assumes the filename
% structure (which is a little silly), but making this more flexible would
% probably take a lot of time to do. CWB isn't up for it at the moment. 

% snr_requested tells us what the user requested the SNR to be in the call
% to createHagerman
snr_requested = nan(numel(group_numbers), numel(d.channels));

% snr_theoretical is the SNR derived from the wav files. Ideally,
% snr_requested and snr_theoretical should match very well
snr_theoretical = nan(numel(group_numbers), numel(d.channels));

% snr_empirical is the SNR derived from the recordings. This should match
% snr_theoretical well in the unaided condition
snr_empirical = nan(numel(group_numbers), numel(d.channels));

% Load weights if the user tells us to. 
display('Weight Estimation'); 
if ~isempty(d.apply_weights)

    % Modified call to use centralized SIN_load_results function
    weight_results = SIN_load_results(d.apply_weights); 
    weight_results = weight_results{1}; 
    
    [weights_norm, weights] = analysis_weight_estimation(weight_results, ...
        'reference_location', 1, d);     
    
    % Reduce weight estimates to the recording channels we'll be using for
    % analysis
    weights_norm = weights_norm(:, d.channels); 
    
else
    
    % If the user does not give us any corrective weights, then set all
    % weights to 1, which effectively means no correction is applied. 
    weights_norm = ones(size(mixer,2), numel(d.channels));
    
end % if ~isempty(d.apply_weights)

for i=1:numel(group_numbers)
    
    % Create logical mask
    mask = false(numel(file_group),1);
    mask(file_group == group_numbers(i)) = true; 
    mask = find(mask); % convert to indices.
    
    % Get the filenames from the data variable. Will use this to figure out
    % which data traces go where
    group_filenames = {data{mask,1}}; 
    
    % What's the SNR for this group of recordings?
    %   - We'll assume theres an SNR label in a ';' delimited file name.
    %   The SNR should be the first element in one segment of the file name
    %   - Also does a basic sanity check to (re)confirm that all files in
    %   this group have the same SNR according to this (clunky) algorithm
    for k=1:numel(group_filenames)
        
        % Get the individual sections
        filename_sections = strsplit(group_filenames{k}, ';'); 
        
        % Now find the SNR segment
        %   - This looks super complicated ... and it is. BUT seems to work
        %   - Should be insensitive to "SNR" string's case (snr or SNR both
        %   recognized) 
        snr_string = filename_sections(~cell2mat(cellfun(@isempty, strfind(cellfun(@lower, filename_sections, 'uniformoutput', false), 'snr'), 'uniformoutput', false))');
        
        % Get the leading digit. This should be our SNR value
        
        snr_string = regexp(snr_string,['[-]{0,1}\d+\.?\d*'],'match');
        temp_snr(k,1) = str2double(snr_string{1}); 
        
    end % for i=1:numel(group_filenames
    
    % Check to make sure there's only ONE SNR in this file group
    if numel(unique(temp_snr)) ~= 1
        error('Multiple SNRs found in this file group');
    else
        % Assign the SNR value to our SNR array. We'll use this below for
        % plotting/analysis purposes. 
        snr_requested(i, :) = [unique(temp_snr)*ones(1, size(snr_requested,2))]; 
    end % if numel(unique ...
    
    % Create a variable to store data traces
    %   Col 1 = +1/+1
    %   Col 2 =  +1/-1
    %   Col 3 = -1/-1
    %   Col 4 = -1/+1    
    
    % Find +1/+1
    ind = findcell(group_filenames, [d.target_string d.original_string d.noise_string d.original_string]);
    oo_original = playback_data{mask(ind)};
    oo_empirical = data{mask(ind), 2}; 
    
    % Only look at selected channels
    oo_empirical = oo_empirical(:, d.channels); 
    
    % Extract the speech mask
    %   This is a logical vector written to file that tells us at which
    %   samples the signal is nominally present. Only these samples should
    %   be used in SNR estimation. 
    signal_mask = logical(oo_original(:, end));     
    
    % Apply mixer and corrective weights. 
    %   In order to derive the "theoretical" waveform, we need to mix the
    %   data with the mod_mixer used in player_main, then sum over
    %   channels.
    oo_theoretical = oo_original * mixer * weights_norm; 
    
    % Find +1/-1
    ind = findcell(group_filenames, [d.target_string d.original_string d.noise_string d.inverted_string]);
    oi_theoretical = playback_data{mask(ind)};
    oi_theoretical = oi_theoretical * mixer * weights_norm; 
    oi_empirical = data{mask(ind), 2}; 
    oi_empirical = oi_empirical(:, d.channels); 
    
    % Find -1/-1
    ind = findcell(group_filenames, [d.target_string d.inverted_string d.noise_string d.inverted_string]);
    ii_theoretical = playback_data{mask(ind)};
    ii_theoretical = ii_theoretical * mixer * weights_norm; 
    ii_empirical = data{mask(ind), 2}; 
    ii_empirical = ii_empirical(:, d.channels); 
    
    % Find -1/+1
    ind = findcell(group_filenames, [d.target_string d.inverted_string d.noise_string d.original_string]);
    io_theoretical = playback_data{mask(ind)};
    io_theoretical = io_theoretical * mixer * weights_norm; 
    io_empirical = data{mask(ind), 2};     
    io_empirical = io_empirical(:, d.channels); 
    
    % Get empirical target and noise waveforms
    [target_empirical{i}, noise_empirical{i}] = process_hagerman(...
        oo_empirical, oi_empirical, ii_empirical, io_empirical, FS, d); 
    
    % Get theoretical target and noise waveforms
    %   We have to replace d.channels with 1 since we will never have more
    %   than 1 channel    
    [target_theoretical{i}, noise_theoretical{i}] = process_hagerman(...
        oo_theoretical, oi_theoretical, ii_theoretical, io_theoretical, FS, d); 
    
    % Compute residuals used for quality index computations below. 
    %   Intuitively, this gives us a way to quantify how well our signal
    %   cancellation (through summing phase inverted signals) is working. A
    %   small residual means we're doing well. A large residual means this
    %   approach doesn't work well. 
    %
    %   We calculate the residual_track as the sum of the two inverted
    %   tracks.
    residual_track{i} = oo_empirical + ii_empirical;    
    
    %% QUALITY INDICES
    %
    %   Calculate the quality index. This is a relative measure that can be
    %   loosely thought of as "attenuation due to summation". Intuitively,
    %   we're comparing the signal loss due to summing two signals together.
    %
    %   Our reference point is the quietest signal in each channel. Note
    %   that this may result in the db(rms()) of channel 1 from oo and
    %   channel 2 from ii. This is just an example, all combinations
    %   possible. CWB decided to do this because it would be the most
    %   conservative estimate of "attenuation due to summation" we can
    %   calculate. 
    %   
    %   CWB, Wu, and Miller devised this quality index. There are others
    %   described below. 
%   
    display('Estimating Attenuation'); 
    attenuation(i, :) = db(rms(residual_track{i})) - min([db(rms(oo_empirical)); db(rms(ii_empirical))]);
%     attenuation(i, :) = db(rms(residual_track{i})) - min([db(rms(target_empirical{i})); db(rms(noise_empirical{i}))]);
    attenuation(i,:) = attenuation(i,:).*-1; % flip sign; 
    
    %% HASPI/HASQI (James Kates) 
    %
    %   In this section, we estimate the HASPI/HASQI values for the
    %   each SNR. This is done just one input (oo_theoretical) and output
    %   (oo_empirical). Each ear is estimated separately. oo_empirical used
    %   because that's the original phase orientation for noise and target
    %   track.
    if d.run_haspi
        
        display('Estimating HASPI/HASQI'); 

        % HASPI reference track
        %   Mix the sound and collapse into a single reference track. 
        d.haspi_reference_mixer=[1; 0; 0; 0; 0; 0; 0]
        d.HL=[0 0 0 0 0 0; 0 0 0 0 0 0]
        haspi_reference = sum(oo_original * d.haspi_reference_mixer, 2);

        % Calculate scaling factor for haspi_reference. This will force the RMS 
        % of the reference sound to equal 1 
    %     haspi_scale = db2amp(-db(rms(haspi_reference)));

        % Apply scaling factor to haspi_reference
    %     haspi_reference = haspi_reference * haspi_scale; 

        % Here we loop through each recording channel and calculate the
        % intelligibility (HASPI) and quality (HASQI) indices.
        for c=1:numel(d.channels)
            display(['Estimating HASPI, SNR = ' num2str(snr_requested(i,1)) ', Channel = ' num2str(d.channels(c))]);

            % HASPI        
            warning('Have not accounted for changes in mic gain in empirical recording'); 
            haspi(i,c) = HASPI_v1(haspi_reference, FS, oo_empirical(:,d.channels(c)), FS, d.HL(c,:), 65 - db(rms(haspi_reference)));

        end % for c=1:numel(d.channels)
        % Check to make sure we are only dealing with a SINGLE channel in the
        % reference. Any more than that gets *extremely* complex with the
        % weighting matrix. 
    %     if numel(find(d.haspi_reference_mixer)) ~= 1
    %         error('Can only accept a single data/speaker combination for HASPI calculations (for now)');
    %     end % if numel(find(d.haspi_referece_mixer)) ~= 1
    else
        
        % Define empty variables so things won't crash. 
        haspi = [];
        hasqi = [];
    end % if d.run_haspi    
    % Loop through each channel
    
    
end % for i=1:numel(grps)

% By this point, we should have an N-element cell array, where N is the
% number of SNRs tested. Each element should by a Txnumel(d.channels) array, where
% T is the number of samples and numel(d.channels) is the number of
% channels the user specifies in the analysis.

%% SORT TARGET/NOISE
%   Want the target/noise traces to be in ascending order of SNR.

% Get sorting index (I)
[~, I] = sort(snr_requested(:,1));

% Apply sorting index to target and noise tracks
target_empirical = {target_empirical{I}}';
target_theoretical = {target_theoretical{I}}';
noise_empirical = {noise_empirical{I}}';
noise_theoretical = {noise_theoretical{I}}';
snr_requested = snr_requested(I, :); 
residual_track = residual_track(I); 
attenuation = attenuation(I,:); 

if d.run_haspi
    haspi = haspi(I,:); 
end 

%% ESTIMATE THEORETICAL SNR (RMS)
%   As a first pass, we'll take a look at the SNR as measured using a basic
%   RMS of the target_theoretical and noise_theoretical

% Before we do this, we need to make a temporal mask based on the
% analysis_window parameter.

% Total playback time
track_duration = size(target_theoretical{1},1)./FS;
analysis_window_sec = d.analysis_window;
analysis_window_samps = nan(size(analysis_window_sec));
for i=1:numel(analysis_window_sec)
    
    % If it's a negative value, the time point is relative to the end of
    % the file. Otherwise, it's relative to the beginning of the file.
    if analysis_window_sec(i) < 0
        analysis_window_samps(i) = (track_duration + analysis_window_sec(i)) * FS;
    else
        analysis_window_samps(i) = analysis_window_sec(i) * FS; 
    end % if analysis_window_sec    
    
end % for i=1:numel(d.analysis_window)

% Make the temporal mask
temporal_mask = SIN_maskdomain(1:size(target_theoretical{1},1), analysis_window_samps); 

% Check dimensions
temporal_mask = SIN_loaddata(temporal_mask); 

% Combine with signal_mask
signal_mask = signal_mask & temporal_mask; 

for i=1:numel(target_theoretical)
    
    % Apply mask to target
    %   Recall that we used a signal mask to do the RMS estimation during
    %   stimulus creation. Now we'll use that SAME MASK to determine over
    %   which samples we should do our RMS estimation. 
    target_masked = target_theoretical{i}(signal_mask,:); 
    
    % We also want to mask the noise sample, but only as a function of
    % time ... or at least that's what CWB has convinced himself of at the
    % moment. Alternatively, we can mask the noise samples in an identical
    % way to get a more accurate "local" SNR estimate. But that seems like
    % overkill. Will need to talk to Wu and Christi. 
    noise_masked = noise_theoretical{i}(temporal_mask,:); 
    snr_theoretical(i, :) = db(rms(target_masked)) - db(rms(noise_masked));
    
end % i=1:numel(target_theoretical)

%% ESTIMATE EMPIRICAL SNR (RMS)
%   This process requires an additional realignment step. In a nutshell, we
%   must realign the recording with the original file in order to apply the
%   signal_mask to our RMS calculations.
for i=1:numel(target_empirical)
    
    % Realign empirical recordings to the first channel of the theoretical
    % target. 
    [aligned_theoretical, aligned_empirical, lag] = ...
            align_timeseries(target_theoretical{i}(:,1), ... % align to the first channel, this can be multiple channels, but they should be identical.
                target_empirical{i}, 'xcorr', 'fsx', FS, 'fsy', FS, 'pflag', d.pflag >= 2);

    % Create signal_mask for each channel and apply it to the data
    target_masked = []; noise_masked = [];
    for c=1:numel(lag)
        
        mask = logical([false(abs(lag(c)),1); signal_mask; false(size(target_empirical{i},1) - (abs(lag(c)) + numel(signal_mask)),1)]);
        target_masked(:,c) = target_empirical{i}(mask,c); 
        
        % Apply the lag to the noise sample as well
        %   Note that using the noise sample for realignment can lead to
        %   errors due to differences in relative timing between noise
        %   samples (speakers) and their relative weights if a weights
        %   other than 1 are used. 
        %
        %   For (more) robust realignment, use the target signal, which
        %   should be less susceptible to these issues since it has more
        %   defined temporal dynamics (i.e., is non-stationary). 
        mask = logical([false(abs(lag(c)),1); temporal_mask; false(size(target_empirical{i},1) - (abs(lag(c)) + numel(signal_mask)),1)]);
%         mask = logical([false(abs(lag(c)),1); true(size(noise_theoretical{i},1),1); false(size(noise_empirical{i},1) - (abs(lag(c)) +size(noise_theoretical{i},1)),1)]);
        noise_masked(:,c) = noise_empirical{i}(mask,c); 
        
    end % for c=1:numel(lag)
    
    % Now find the noise samples
    %   There is often silence at the beginning/end of the recordings that
    %   can artificially inflate our SNR estimates. So, we'll realign the
    %   recorded noise sample to the noise theoretical_noise sample and
    %   only use those samples in noise RMS estimation
%     [aligned_theoretical, aligned_empirical, lag] = ...
%             align_timeseries(noise_theoretical{i}(:,1), ...
%                 noise_empirical{i}, 'xcorr', 'fsx', fs, 'fsy', fs, 'pflag', d.pflag >= 2);
%     
%     for c=1:numel(lag)
%         mask = logical([false(abs(lag(c)),1); true(size(noise_theoretical{i},1),1); false(size(noise_empirical{i},1) - (abs(lag(c)) +size(noise_theoretical{i},1)),1)]);
%         noise_masked(:,c) = noise_empirical{i}(mask,c); 
%     end % forc=1:numel(lag)
%     noise_masked = noise_empirical{i}; 
    % This gives a relative measure within each recording channel ... I
    % think. CWB is very tired and probably should not be writing this ...
    snr_empirical(i,:) = db(rms(target_masked)) - db(rms(noise_masked)); 
    
end % for i=1:numel(target_empirical)

%% GENERATE PLOTS

if d.pflag > 0
    
    % Theoretical vs. Requested SNR plot
    %   This plot should help us quantify any slop in our analysis routine.
    %   There's no reason why the the theoretical and requested SNRs should
    %   not match point for point. Unless, of course, there's an error or
    %   something somewhere ... 
    figure, hold on
    
    % Plot unity line
    %   This is what would be "perfect" all things being equal.
    x = [min(min(snr_requested)):0.01:max(max(snr_requested))]';
    plot(x, x, 'k--', 'linewidth', 2)
    
    % Plot channel estimates
    plot(snr_requested, snr_theoretical, '*', 'linewidth', 1, 'markersize', 10)
       
    % Plot the absolute noise floor
%     plot(x*ones(1, numel(d.channels)), repmat(db(noise_floor_rms), length(x), 1), '--', 'linewidth', 1); 
    
    % Markup
    xlabel('Requested SNR (dB)');
    ylabel('Theoretical SNR (dB)'); 
    legend(strvcat('Perfect SNR', [repmat('SNR: Channel ', numel(d.channels)+1, 1) strvcat(num2str(d.channels'), 'Mean')], strvcat([repmat('Channel ', numel(d.channels), 1) num2str(d.channels') repmat(' Noise Floor', numel(d.channels), 1)])), 'location', 'eastoutside')    
    grid on
    
    % Empirical vs. Theoretical SNR plot
    figure, hold on
    
    % Plot unity line
    plot(x, x, 'k--', 'linewidth', 2)
    
    % Now plot the "theoretical" unity line. That's the SNR after weights
    % have been applied. If weights are just 1s, then the two unity lines
    % will be identical. Otherwise, the unity lines will differ. The
    % theoretical is the best we can do, however, with regards to empirical
    % estimation.
    
    plot(mean(snr_theoretical, 2), mean(snr_theoretical, 2), 'ro--', 'linewidth', 2)
    
    % Plot channel estimates
    plot(snr_theoretical, snr_empirical, '*', 'linewidth', 1, 'markersize', 10)
    
    % Plot mean(across channel) estimates
    plot(mean(snr_theoretical, 2), mean(snr_empirical,2), 'sk', 'linewidth', 2); 
    
    % Plot the absolute noise floor
%     plot(x*ones(1, numel(d.channels)), repmat(db(noise_floor_rms), length(x), 1), '--', 'linewidth', 1); 
    
    % Markup
    xlabel('Theoretical SNR (dB)');
    ylabel('Empirical SNR (dB)'); 
    legend(strvcat('Unity', '"Perfect" SNR', [repmat('SNR: Channel ', numel(d.channels)+1, 1) strvcat(num2str(d.channels'), 'Mean')], strvcat([repmat('Channel ', numel(d.channels), 1) num2str(d.channels') repmat(' Noise Floor', numel(d.channels), 1)])), 'location', 'eastoutside')    
    grid on
    
    % Attenuation due to summation plot
    figure, hold on
    plot(snr_theoretical, attenuation, '*', 'linewidth', 1, 'markersize', 10); 
    plot(mean(snr_theoretical,2), mean(attenuation,2), 'sk', 'linewidth', 2); 
    xlabel('Theoretical SNR (dB)');
    ylabel('Attenuation (more positive is better)');
    grid on
    
    % HASPI plots
    if d.run_haspi
        figure
        hold on
        plot(snr_requested, haspi, 's-', 'linewidth', 2)
        grid on
        xlabel('Input SNR (dB, approx.)');
        ylabel('HASPI');
        title(results.RunTime.specific.testID)
    end % if d.run_haspi
end % if d.pflag

function [target, noise] = process_hagerman(oo, oi, ii, io, fs, varargin)
%% DESCRIPTION:
%
%   This function estimates the target and noise tracks extracted from the
%   files above. 
%
% INPUT:
%
%   oo, oi, ii, io: 
%
% Parameters:
%
%   'average_estimates':    bool, if set then we will attempt to average
%                           over estimates. See main help for more
%                           information
%
% OUTPUT:
%
%   target: trace of target track
%
%   noise:  trace of noise track
%
% Development:
%
%   None (yet)
%
% Christopher W Bishop
%   University of Washington
%   11/14

%% GET INPUT PARAMETERS
d = varargin2struct(varargin{:});

% Number of channels
%   Assumes that all data traces have the same number of channels
number_of_channels = size(oo,2); 

% Calculate the target signal by averaging over the two ways we can
% solve for the target. These will be averaged below

if d.average_estimates

    % Compute target and noise samples in two ways each. These
    % estimates will be checked for temporal alignment below. 
    %
    % Note that the second estimate's polarity is inverted (multiplied
    % by -1) so the polarities match. 
    target   = [Hagerman_getsignal(oo, oi, 'fsx', fs, 'fsy', fs, 'pflag', d.pflag>=2) Hagerman_getsignal(io, ii, 'fsx', fs, 'fsy', fs, 'pflag', false).*-1 ]; 
    noise    = [Hagerman_getsignal(oo, io, 'fsx', fs, 'fsy', fs, 'pflag', d.pflag>=2) Hagerman_getsignal(oi, ii, 'fsx', fs, 'fsy', fs, 'pflag', false).*-1 ]; 

    % Check alignment of each channel
    %   Intuitively, this gives us a measure of how well-aligned the two
    %   estimates are within each channel. If the lags are estimated to any
    %   non-zero value, then the same two computed estimates are misaligned
    %   in the corresponding channel. 
    target_lag = [];
    noise_lag = [];
    aligned_noise1 = {};
    aligned_noise2 = {};        
    aligned_target1 = {};
    aligned_target2 = {}; 
    for c=1:numel(d.channels)

        % Check noise alignment
        [aligned_noise1{c}, aligned_noise2{c}, noise_lag(c,1)] = ...
            align_timeseries(noise(:,c), noise(:,c + number_of_channels), 'xcorr', 'fsx', fs, 'fsy', fs, 'pflag', d.pflag >= 2);

        % Check target alignment
        [aligned_target1{c}, aligned_target2{c}, target_lag(c,1)] = ...
            align_timeseries(target(:,c), target(:,c + number_of_channels), 'xcorr', 'fsx', fs, 'fsy', fs, 'pflag', d.pflag>=2);

    end % for c=1:number_of_channels

    % Error checking for temporal alignment. If we plan to temporally
    % average over the two target/noise estimates, then they need to be
    % *perfectly* aligned. Verify that empirically with
    % align_timeseries.

    % Verify that the targets and noise estimates are well-aligned
    if any(noise_lag ~= 0) || any(target_lag ~= 0) 
%         error('Temporal misalignment in noise estimates. No recovery coded, but it can be.');
        
        warning('Temporal misalignment in noise estimates. Single recording trace will be used rather than the temporal average of two.')
        
        target = target(:, 1:number_of_channels); 
        noise = noise(:, 1:number_of_channels); 
    else
        % Average over noise estimates        
%         noise = mean(noise, 2); 
        target = (target(:,1:number_of_channels) + target(:,[1:number_of_channels] + number_of_channels)) ./ 2;
        noise = (noise(:,1:number_of_channels) + noise(:, [1:number_of_channels] + number_of_channels)) ./ 2;
    end % if noise_lag ~= 0

else
    error('Unsupported option ... see development'); 
end 