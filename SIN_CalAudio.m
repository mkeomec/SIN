function scale = SIN_CalAudio(REF, varargin)
%% DESCRIPTION:
%
%   The calibration procedure for SIN sets the HINT-Noise.wav (a speech
%   shaped noise sample) to 0 dB and scales all other stimuli or stimulus
%   sets to also rest at 0 dB. The user can then present the HINT-Noise
%   stimulus through their sound playback system and adjust (via hardware)
%   the sound pressure level (SPL) to the desired level. Following this
%   procedure, all stimuli/stimulus sets should be have a nearly identical
%   SPL, provided that the frequency response of the playback/recording
%   loop is flat (enough). CWB recommends using hardware (e.g., a graphical
%   equalizer) to flatten the frequency response of your playback/recording
%   loop. 
%
% INPUT:
%
%   REF:    path to reference file. (e.g., fullfile('playback', 'Noise', 'HINT-Noise.wav'))
%
% General Parameters:
%
%   'testID':   string, testID used in call to SIN_TestSetup that is then
%               used to gather stimulus information 
%               
%   'nmixer':   Nx1 scaling matrix, where N is the number of data channels
%               in the reference signal (typically 2x1 for HINT-Noise.wav) 
%
%   'targetdB': double, the relative decibel level to scale output stimuli
%               to. This is useful if, for instance, the reference sound is
%               calibrated to 65 dB, but the user wants the remaining sound
%               files to be calibrated to 80 dB. In this example,
%               'targetdB' would be +15. 
%
%   'removesilence':    bool, remove silence from beginning and end of
%                       sounds. If true, requires ampThresh argument below.
%                       CWB generally recommends this since excess silence
%                       at beginning and end of sounds can reduce RMS
%                       estimates considerably (and variably) depending on
%                       the length of the silent period. 
%
%   'ampthresh':    used to remove silence from beginning and end of
%                   acoustic waveforms prior to RMS estimation. 
%
%   'bitdepth': bit depth for written audio files. Note: CWB is not sure if
%               this applies to MP4s since these invoke FFmpeg for scaling
%               purposes. 
%
%               Note: audioread does not give bitdepth information from
%               MP4s, so CWB cannot confirm the bitdepth of the audio in
%               these files. But the log readout from FFmpeg suggests
%               16-bit audio. Unconfirmed. 
%
%   'suffix':   string to append to end of file name for newly created
%               files.
%
%   'tmixer':   Dx1 scaling matrix, where D is the number of data channels
%               in the to-be-calibrated target files. The code will
%               essentially combine (linearly) data from the D channels in
%               each file. These data are then used (perhaps with some
%               additional processing) to estimate the RMS of the target
%               file.
%
%   'omixer':   1xP scaling matrix, where 1 is the number of data channels
%               (the result of .tmixer) and P is the number of output
%               channels in the generated file (.wav or .mp4). 
%
%   'saveref':  bool, flag to write the reference data to file (.wav
%               format).
%
%   'wav_regexp':   regular expression. If provided, the
%                   specific.wav_regexp field is overwritten with this
%                   parameter. This proved necessary to guarantee that the
%                   user knows which files are being used for calibration
%                   purposes. 
%
%   'overwritemp4': bool, if true, automatically overwrite MP4s. If false,
%                   user is prompted for each overwrite. False is safer,
%                   but time consuming. 
%
% Filtering Parameters:
%
%   Parameters below allow the user to specify filtering settings for
%   sound files. Typically, filter settings are applied to both the
%   reference sound AND the to-be-calibrated sounds. 
%
%   Note that filtering is achieved using MATLAB's butter and filtfilt
%   functions.
%
%   'apply_filter': bool, if set, then all sounds are filtered using the
%                   filter specifications below. If false, then no
%                   filtering applied. 
%
%   'filter_type':  string, filter type supported by butter. 
%
%                   These include the following. See doc butter for
%                   details.
%
%                   'low':
%                   'high':
%                   'stop:
%                   'bandpass': 
%
%   'frequency_cutoff': equivalent to butter's Wn argument. Specifies the 
%                       cutoff frequency(ies). 
%
%   'filter_order': filter order
%
% AV Alignment Options (only applies to MP4s presently)
%
%   Note that these procedures circularly shift the data to account for
%   changes in timing. So it's important that there be significant periods
%   of silence (at least relative silence) at the beginning and end of each
%   track. If there is NOT, data may be moved from the beginning of the
%   sound to the end or vice versa. Also, if the noise floor is relatively
%   high, there may be transients introduced following this procedure. If
%   this is the case, then try fading sounds in/out prior to applying a
%   shift. 
%
% Transcoding Correction:
%
%   These options have been removed after CWB learned that FFmpeg was not 
%   introducing misalignments in audiovisual files, but instead prepending
%   a duplicate video frame and delaying the audio by the duration of this
%   frame. 
%
% Development:
%
%   Note (anymore)
%
% Christopher W. Bishop
%   University of Washington
%   9/14

%% GATHER PARAMETERS
d=varargin2struct(varargin{:}); 

%% SET THE RMS ESTIMATOR
rms_function = @rms;

%% GET TEST INFORMATION
%   The general field also has information we'll need regarding the
%   location of noise files. 
opts = SIN_TestSetup(d.testID, ''); 
opts = opts(1); 

%% OVERWRITE FILE FILTER IF NECESSARY
if isfield(d, 'wav_regexp')
    
    input(['Overwriting ' opts(1).specific.wav_regexp ' with ' d.wav_regexp '. Press enter to continue']);
    
    % Error check to make sure we haven't changed the field name to
    % something else.
    if ~isfield(opts.specific, 'wav_regexp')
        error('wav_regexp field name may have changed');
    end % 
    
    opts.specific.wav_regexp = d.wav_regexp;
    
end % isfield

%% LOAD THE REFERENCE NOISE
[ref_data, FS] = audioread(REF);

%% SCALE NOISE
ref_data = ref_data*d.nmixer; 

%% FILTER REFERENCE DATA:
%   Filter the reference data. This is often needed for Project AD in which
%   we want to bandpass all sounds between [0.125 10] kHz. 
if d.apply_filter
    
    % Convert cutoff frequencies to normalized units (normalized to
    % Nyquist)
    d.frequency_cutoff = d.frequency_cutoff / (FS/2);
    
    % Get filter coefficients
    [b, a] = butter(d.filter_order, d.frequency_cutoff, d.filter_type); 
    
    % Apply filter to reference sound
    ref_data = filtfilt(b, a, ref_data); 
    
end % if d.apply_filter

%% WRITE SCALED REFERENCE
%   Write the (scaled) reference file back to disk? 
if d.writeref
    
    % Get file parts
    [PATHSTR,NAME,EXT] = fileparts(REF);
    
    % Create output filename
    audio_file_out = fullfile(PATHSTR, [NAME d.suffix EXT]); 
    
    % Write to file
    audiowrite(audio_file_out, ref_data, FS, 'BitsperSample', d.bitdepth); 
    
end % if d.writeref

%% WRITE CALIBRATED STIMULI
%   - Now, we load in the stimuli for the specific test we want to rewrite
%   stimuli for. 
%   - Grab file names
[~, files] = SIN_stiminfo(opts);

%% LOAD ALL FILES IN STIMULUS LIST
%   - Load all files, concatenate into larger file for RMS estimation
%   - We need to save the (potentially filtered) audio files for use below.

% fs is the sampling rate of the to-be-scaled stimulus(i). There's an error
% check built in to catch cases in which fs does not match between these
% stimuli and the reference stimuli. No recovery mechanisms coded, however.
fs = [];

audio_data = {}; 
for i=1:numel(files)
    
    % Loop through files
    for k=1:numel(files{i})
        
        % Load data file
        [audio_data{i}{k}, nfs] = SIN_loaddata(files{i}{k}); 
        
        % Sampling rate check
        if isempty(fs)
            fs = nfs;
        elseif fs ~= nfs
            error('Sampling rates do not match');
        end % if isempty(fs)
        
        % Double check that reference and files are at the same sampling
        % rate
        if fs ~= FS
            audio_data{i}{k} = resample(audio_data{i}{k}, FS, nfs); 
            display(['Resampling ' files{i}{k} ]); 
        end % if fs ~= rfs    
        
        % Apply appropriate mixer
        %   This should reduce the data to a single channel. 
        audio_data{i}{k} = audio_data{i}{k}*d.tmixer;
        
        % Do we filter the waveforms before concatenating them? \
        if d.apply_filter
            % Note that d.frequency_cutoff already converted to Nyquist
            % normalized values above.
%             d.frequency_cutoff = d.frequency_cutoff / (rfs/2);

            % Get filter coefficients
            [b, a] = butter(d.filter_order, d.frequency_cutoff, d.filter_type); 

            % Apply filter to reference sound
            audio_data{i}{k} = filtfilt(b, a, audio_data{i}{k}); 
            
        end % if d.apply_filter
        
        
        
    end % for k=1:numel(files{i})
    
end % for i=1:length(files)

% Concatenate files
%   Now we'll concatenate the filtered files. 
concat = concat_audio_files(concatenate_lists(audio_data), ...
    'fs', fs, ...
    'remove_silence', d.removesilence, ...
    'amplitude_threshold', d.ampthresh, ...
    'mixer', 1);    % set mixer to 1 since we've already collapsed to a single
                    % channel above

%% CALCULATE SCALING FACTOR
%
%   The target tracks (generally speech) are scaled to match the RMS value.
scale = db2amp(db(rms_function(ref_data)) - db(rms_function(concat)) + d.targetdB);

%% APPLY SCALING FACTOR, WRITE STIMULI
%   Now, load/scale each stimulu, write to file. 
for i=1:numel(files)
    
    for k=1:numel(files{i})
        
        % We need to do something different depending on the file format. 
        [PATHSTR,NAME,EXT] = fileparts(files{i}{k});        
        
        % Create output file name
        %   We always want to write audio data as wav files
        audio_file_out = fullfile(PATHSTR, [NAME d.suffix '.wav']);  

        % Scale audio data
        audio_data{i}{k} = audio_data{i}{k}.*scale; 

        % Multiply by omixer to generate appropriately sized output
        % matrix.
        audio_data{i}{k} = audio_data{i}{k}*d.omixer; 
        
        if max(max(abs(audio_data{i}{k}))) > 1, error('Signal Clipped'); end 
        
        % Write audio track(s) to file                               
        audiowrite(audio_file_out, audio_data{i}{k}, FS, 'BitsperSample', d.bitdepth); 
        
        % If a .wav/.mp3, then use audiowrite
        switch EXT
            case {'.mp3', '.wav'}
                % Nothing else to do here, it's all done above. 
                
            case {'.mp4'}
                
                % Now we need to rewrite the MP4s with the scaled (and
                % potentially filtered) audio data. It turns out that the
                % encoder used for the .wav files written above is
                % incompatible with MP4 files. So we have to rewrite the
                % audio track as a temporary MP4 file, then use that audio
                % track (with the proper AAC encoder) as the audio track
                % for the output MP4.
                temp_audio_file = fullfile(PATHSTR, [NAME d.suffix '_temp.mp4']);
                audiowrite(temp_audio_file, audio_data{i}{k}, FS, 'Bitrate', d.bitrate); 
                
                % Is overwriteMP4 set?
                %   -y overwrites without asking in ffmpeg. Not used by
                %   default. Maybe a separate parameter?
                if d.overwritemp4
                    cmd = 'ffmpeg -y ';
                else
                    cmd = 'ffmpeg ';
                end % if d.overwritemp4
                
                % Replace audio in MP4              
                %   Revised to use only MP4 as video and audio inputs, so
                %   we can copy the codecs and save time/improve data
                %   precision. 
                mp4_file_out = fullfile(PATHSTR, [NAME d.suffix '.mp4']); 
                cmd = [cmd '-i "' files{i}{k} '" -i "' temp_audio_file '"' ...
                    ' -map 0:0 -map 1 -c copy "' mp4_file_out '"'];
                
                % Issue system call 
                [status, cmdout] = system(cmd);
                
                % Remove the temporary audio file
                delete(temp_audio_file); 
                
                % If there's an error, then print the command output.
                % Otherwise, post the file name to give the user some
                % information about progress.
                if status
                    display(cmdout);
                else
                    display([num2str((i-1)*numel(files{1}) + k) ' of ' num2str(numel(files) .* numel(files{1}))])
                end % if ~status                
                
            otherwise
                
                error('Unknown file extension');
                
        end % switch EXT
        
        % If MP4, then use FFmpeg (see MLST_makemono for details)
        
    end % for k=1:numel(files{i})
end % for i=1:numel(files)
