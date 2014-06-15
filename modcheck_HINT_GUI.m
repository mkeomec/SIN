function [mod_code, d]=modcheck_HINT_GUI(varargin)
%% DESCRIPTION:
%
%   Function to handle HINT scoring via the HINT GUI. When paired with
%   portaudio_adaptiveplay and a suitable modifier, this can be used to
%   administer the HINT. 
%
% INPUT:
%
% Parameters (set by portaudio_adaptiveplay)
%
%   'playback_list':    cell array, sentences being presented in
%                       portaudio_adaptiveplay.m. Sentence order should
%                       match that in portaudio_adaptiveplay. 
%
%                       Note: This field (should) be automatically set by
%                       portaudio_adaptive play. That is, the user
%                       typically does not need to specify this. 
%
%   'data_channels':     XXX
%
%   'physical_channels': XXX
%
%           XXX Needs data/physical_channels for plotting purposes. This
%           should correspond to the data being tracked/adapted. XXX
%
%   The following parameters can (and probably should) be set in
%   SIN_defaults.m 
%
%   'scoring_method':   string, type of scoring approach to use. This can
%                       be expanded easily to incorporate new scoring
%                       schemes.
%
%                           'word_based':   each word has an equal score
%                                           associated with it. 
%
%                           'keyword_based':    Only keywords (capitalized)
%                                               are scored.
%
%                           'sentence_based':   a binary scoring scheme in
%                                               which the sentence is 
%                                               "correct" if all words are
%                                               repeateded correctly.
%                                               Othewrise, the sentence is
%                                               incorrect. This is the
%                                               scoring scheme used in
%                                               traditional HINT scoring. 
%
% OUTPUT:
%
%   'mod_code':     modification code.
%                       0:  no modification necessary.
%                       -1: make target quieter
%                       1:  make target louder
%
%   d:  updated data structure used by portaudio_adaptiveplay.m
%
% Development:
%
%   1. Need to store word information for quick access later. See variable
%   'w' below. 
%
%   2. Reconfigure call to HINT_GUI so HINT_GUI just refreshes the plot.
%   The modifier should populate the data in the axis. 
%
% Christopher W. Bishop
%   University of Washington
%   5/14

%% INPUT CHECK AND DEFAULTS

% initialize mod_code to zero (do nothing) 
mod_code=0;

%% INPUT ARGS TO STRUCTURE
d=varargin2struct(varargin{:});

if ~isfield(d, 'player')
    d.player=d; 
end % opts

% Grab important variables from sandbox
%   Sandbox is a "scratch pad" of sorts that allows the user to share
%   variables between the player, modchecks, and modifiers. CWB originally
%   used globals to do this, but globals are scary and very difficult to
%   control. Debugging can also be a pain since a variable can be changed
%   in a totally unrelated function to the error being generated.
trial = d.sandbox.trial;

%% IMPORT SENTENCES FROM FILE
%   This should only be run during initialization. 
%       - Read in sentence information from xlsx file. 
%       - Very slow step, so keep calls to a minimum. 
if ~isfield(d.player.modcheck, 'sentence') || isempty(d.player.modcheck.sentence)
    
    % Grab sentence information
    %   This initial step will update the 'modcheck' field by adding in
    %   HINT list information from an XLS spreadsheet.
    d=importHINT(d); 
    
    %% Initialize other fields
    
    % Plotting information for HINT_GUI
    %   Initialize other fields that are important later. 
%     d.sandbox.xdata=1; % first trial
%     d.sandbox.ydata=0; % no changes applied
    d.player.modcheck.xlabel='Trial #';
    d.player.modcheck.ylabel='SNR (dB)'; 
    d.player.modcheck.ntrials=length(d.sandbox.playback_list); % number of trials (sets axes later)
%     d.modcheck.score_labels={'Correct', 'Incorrect'}; % This is set in SIN_defaults

    % Scoring information
    %   Use dynamic field names 
    for i=1:length(d.player.modcheck.score_labels)
        d.player.modcheck.(d.player.modcheck.score_labels{i})=0;        
    end % for i=1:length ...
    
    % After we initialize, return control to invoking function
    %   This way we don't bring up the scoring GUI until after the first
    %   sentence is complete. 
    return; 
    
end % if ~isfield p ...

% FIND SENTENCE FOR SCORING
%   finds information for the sentence to be sored.
fname=d.sandbox.playback_list{trial}; 

% Stupid way to handle this, but a decent place to start.
fname=fname(end-12:end); 

% Find sentence information by matching the filepath between. 
%   Don't reassign 'd' return, since this will be updated in stupid ways on
%   account of the additional search parameters. Essentially there will be
%   an added 'filepath' field that will be very confusing. In comparison,
%   the 'o' structure should contain just the information we're looking
%   for. 
[~, o]=importHINT(d, 'filepath', fname); 

%% DETERMINE SCORING VECTOR
%   Scoring vector will change depending on the 'scoring_method' parameter.
%   The various methods require some or all words to be scored. This
%   section of code determines the scoring vector, which is then used to
%   change the GUI below.
%
%   See help for a conceptual description of each of these scoring methods

% Break up sentence into words
w=strsplit(o.sentence{1}); 

% Set scores to zero to begin with
isscored=false(length(w),1); 

% Determine scoring method
%   Each scoring method has slightly different characteristics. These
%   options can be expanded to incorporate nearly any scoring scheme. 
switch d.player.modcheck.scoring_method
    case {'word_based', 'sentence_based'}
        % All words are scored, but the # of correct is based on the number
        % of correct words. 
        %
        % OR
        %
        % All words are scored, but only 100% correct responses counts as
        % correct.        
        
        % Score all words
        isscored=true(size(isscored)); 
        
    case {'keyword_based'}
        
        % Determine keywords by capitalization in spreadsheet. 
        for n=1:length(w)
    
            % First, remove potential markups, like brackets ([]) and '/'
            tw=strrep(w{d}, '[', '');
            tw=strrep(tw, ']', '');
            tw=strrep(tw, '/', '');    
            
            % Only score if all the text is capitalized - that's the flag
            % we're using to tag "key words"
            if isstrprop(tw, 'upper')
                isscored(n)=true;
            else
                isscored(n)=false;
            end % if isstrprop ...
            
        end % for i=1:length(w)
        
    otherwise
        error('Unknown scoring method'); 
end % switch/otherwise

%% CALL SCORING GUI
%   Pulls up a scoring GUI designed by CWB in GUIDE + lots of other manual
%   customizations. 
[fhand, score]=HINT_GUI(...
    'title', ['HINT: ' o.id{1} ' (' num2str(numel(isscored(isscored))) ' possible)'], ...
    'words', {w}, ...
    'xdata',  1:d.sandbox.trial, ...
    'ydata',  db(squeeze(d.sandbox.mod_mixer(d.player.modcheck.data_channels, d.player.modcheck.physical_channels, :))), ...
    'xlabel', d.player.modcheck.xlabel, ...
    'ylabel', d.player.modcheck.ylabel, ...
    'ntrials', d.player.modcheck.ntrials, ...
    'score_labels', {d.player.modcheck.score_labels}, ...
    'isscored', isscored); 

% Copy figure handle over to d structure.
d.player.modcheck.handles=guidata(fhand); 

% Get all handles
h=guidata(fhand);

% Assign axis handle back to a more central location (so other functions
% can plot if necessary).
d.sandbox.axes=h.panel_plot; 
d.sandbox.figure=h.figure1; 

%% DETERMINE SCORE
%   This will vary depending on the scoring_method parameter
switch d.player.modcheck.scoring_method
    
    case {'keyword_based', 'word_based'}
        
        % use dynamic field names to make the function more intuitive and
        % generalizable. 
        %   Use isscored as masker so we only look at words that were
        %   intended to be scored
        d.player.modcheck.(d.player.score_labels{1})=d.player.modcheck.(d.player.score_labels{1}) + numel(find(score(isscored)==1));
        d.player.modcheck.(d.player.score_labels{2})=d.player.modcheck.(d.player.score_labels{2}) + numel(find(score(isscored)==2));
        
    case {'sentence_based'}
        
        % Only count as correct if the whole sentence is scored as 100%
        % correct. 
        if score(isscored)==1 % if everything is correct
            d.player.modcheck.(d.player.modcheck.score_labels{1})=d.player.modcheck.(d.player.modcheck.score_labels{1})+1;
            
            % Make the sound quieter
            mod_code=-1;
        else
            d.player.modcheck.(d.player.modcheck.score_labels{2})=d.player.modcheck.(d.player.modcheck.score_labels{2})+1;
            
            % Make the sound louder
            mod_code=1;
        end % if 
        
    otherwise
        error('Unknown scoring_method');
end % switch

%% DETERMINE IF A MODIFICATION IS NECESSARY
%   
% mod_mode=0; % hard coded for now for debugging. 

%% COPY SCORE INFORMATION OVER TO d STRUCTURE

% Save the raw scores for error checking later
d.player.modcheck.score{trial}=score; 

%% CLOSE GUI
%   Only close it down if we're done. 
if trial==length(d.sandbox.playback_list)
    close(d.sandbox.figure);
end % 