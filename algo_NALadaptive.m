function OUT = algo_NALadaptive(score, varargin)
%% DESCRIPTION:
%
%   Function to use an adaptive algorithm to control signal level (or
%   SNR). 
%
%   The algorithm is divided into three phases (Phases 1 - 3). The phases
%   differ based on decibel step size and termination criteria. Below is a
%   short summary of this information. CWB encourages the user to *read the
%   paper* to double check things.
%
%   Phase 1: (5 dB steps)
%       - Minimum of 4 sentences
%       - Minimum of one reversal
%
%   Phase 2: (2 dB steps)
%       - Minimum of 4 MORE (minimum of 8 total) sentences.
%       - (corrected) Standard Error (cSE) no greater than 1 dB. 
%       - Note that cSE estimates are based on Phase 2 sentences only
%
%   Phase 3: (1 dB steps)
%       - At least N sentences during Phases 2/3.
%       - cSE < 0.8 dB. 
%       - Note that cSE estimates are based on Phases 2 and 3 only.
%       - Note that "N" defaults to 16 in the NAL program   
%
%   This function can be invoked in several ways. 
%
%       1. To initialize the algorithm. This *must* be done at the start of
%       each tracking session. If this is *not* done, the user risks
%       inaccurate results since the function uses 'persistent' scoring
%       variables that must be cleared or otherwise "reset". ('initialize')
%
%       2. Query the current dBstep size. ('querydB')
%
%       3. Algorithm tracking (scoring array provided)
%       
% INPUT:
%   
%   score:  bool array, each element corresponds to a scorable unit (e.g.,
%           phoneme, morpheme, word, etc.). True if the scorable unit is
%           "correct". False if the scorable unit is "false". 
%
% Parameter list:
%
%   'target':   target percentage correct.
%
%   'correction_factor': double, correction factor to apply to SE
%                        calculations. (see Table 1 of Keidser (2013))
%
%   'min_trials':   minumum number of trials to complete during phases 2
%                   and 3.
%
% References:
%
%   1. Keidser, G., et al. (2013). Int J Audiol 52(11): 795-800.
%
% Development:
%
%   1. Phase information is offset by a single trial, I think. Needs more
%   testing and more thinking by CWB. 
%
% Christopher W. Bishop
%   University of Washington
%   6/14

%% INPUT ARGS TO STRUCTURE
% d=varargin2struct(varargin{:});

%% DECLARE PERSISTENT VARIABLES
%   Create persistent structure 
persistent NAL;

% Set NAL to structure. Only done during initialization... need to make
% this smarter. 
if ~isstruct(NAL)
    NAL=varargin2struct(varargin{:});  
    
    % Add default fields
    flds = {'dBstep', 'scoring_history', 'phase', 'isreversal', 'trial_percentage', 'state'};
    for i=1:numel(flds)
        if ~isfield(NAL, flds{i})
            NAL.(flds{i}) = [];
        end % if ~isfield
    end % for i=1:numel(flds)
    
    % Set algorithm state to 'run'
    if isempty(NAL.state)
        NAL.state = 'run'; 
    end 
end % if ~isstruct

% Append score
NAL.scoring_history(:, end+1) = score; 

% Score trial
NAL.trial_percentage(end+1) = numel(score(score))/numel(score)*100;

% Which direction is the next step in?
NAL.dBstep(end+1) = stepSign(NAL); % this just gives us the SIGN, not the step SIZE

% Is this a reversal?
%   Compare signs of last two elements of dBstep. If the signs are
%   different, then it's a reversal. If they are the same, then it is NOT a
%   reversal. 
NAL.isreversal(end+1) = isReversal(NAL); 

% Which phase is the next trial?
% What's the step size (dB) for the upcoming trial?
[tphase, tdBstep] = getNALphase(NAL); 

NAL.phase(end+1) = tphase; 

if ~isempty(tdBstep)
    NAL.dBstep(end) = NAL.dBstep(end).*tdBstep; % multiply sign by dBstep size
end 

% Termination phase
%   getNALphase will return 4 if the algorithm has finished
if tphase == 4
    NAL.state = 'finished'; 
end % if tphase ...

% Assign return variables
OUT = NAL; 

function isRev = isReversal(NAL)
%% DESCRIPTION:
%
%   Function to determine if we just encountered a reversal

% NOTE: dBstep might be 0. Need to not count this as a reversal

% Get sign of steps
tdBstep = sign(NAL.dBstep(NAL.dBstep~=0)); 

if numel(tdBstep) < 2
    % Can't have a reversal with fewer than 2 (signed) changes. Zero
    % doesn't contribute.
    isRev = false; 
    return;
else
    
    tdBstep = tdBstep(end-1:end); 
    
end % if numel(NAL.dBstep) ...

if diff(tdBstep) == 0
    % No reversal if the most recent directional changes are the same
    isRev = false;
elseif diff(tdBstep)~=0
    % It's a reversal if the most recent (signed) Changes do not match. 
    isRev = true;
end % if diff(tdBstep)

function [o]=cSE(NAL)
%% DESCRIPTION:
%
%   Function to calculate corrected SEM from phases 2 and 3. 

% Get phase mask
mask = NAL.phase == 2 | NAL.phase == 3;

% Get temporary data
tdBstep = NAL.dBstep(mask); 

% Calculate cSE
o = NAL.correction_factor * sem(tdBstep); 

%% If we have no variance, should we be kicking back inf instead??? XXX

function [phase, dBstep] = getNALphase(NAL)
%% DESCRIPTION:
%
%   Function to determine which phase of the algorithm we are in, as well
%   as the step size associated with each phase.
%
%       Phase 1: 5 dB
%       Phase 2: 2 dB
%       Phase 3: 1 dB

% Assume we're starting at phase one
phase = 1; 
dBstep = 5; % 5 dB step size

persistent isphase2 isphase3 isphase4;

if isempty(isphase2), isphase2=false; end
if isempty(isphase3), isphase3=false; end

% Set phase
if isphase4
    phase=4; 
elseif isphase3
    phase=3;
elseif isphase2
    phase=2;
end % if isphase4 ...
    
% Get the number of reversals
%   Pass dBstep information, which tells us the history of the step sizes. 
nrevs = numel(find(NAL.isreversal));

% Get (corrected) standard error for each phase
display(cSE(NAL)); % for debuggin'

% Get phase
%   Note that the PHASE refers to the phase of the most recently presented
%   trial. 
%
%   In contrast, dBstep refers to the step for the NEXT trial. So we have
%   to handle the checks independently. 
if (numel(NAL.phase(NAL.phase == 2 | NAL.phase ==3 ) )  > NAL.min_trials ) ...
        && cSE(NAL) < 0.8
    phase = 4;  % phase 4 means we stop.
elseif numel(NAL.phase)>= numel(NAL.phase(NAL.phase==1)) + 3 && cSE(NAL) <= 1
    isphase3 = true; 
elseif numel(NAL.phase) >= 3 && nrevs > 0 % XXX Reversal check    
    isphase2 = true; 
end % 

% Get dBstep
if (numel(NAL.phase(NAL.phase == 2 | NAL.phase ==3 ) )  > NAL.min_trials ) ...
        && cSE(NAL) < 0.8
    dBstep=[];     
elseif numel(NAL.phase)>= numel(NAL.phase(NAL.phase==1)) + 3 && cSE(NAL) <= 1
    dBstep = 1; 
elseif numel(NAL.phase) >= 3 && nrevs > 0 % XXX Reversal check
    dBstep = 2; 
end % 

function [s] = stepSign(NAL)
%% DESCRIPTION:
%
%   Function to determine the sign of dBstep for upcoming trial

if NAL.trial_percentage(end) < NAL.target
    s = 1; % make sounds louder
elseif NAL.trial_percentage(end) > NAL.target
    s = -1; % make sounds quieter
elseif NAL.trial_percentage(end) == NAL.target
    s = 0; % don't change the sound level
else 
    % This should theoretically never happen, but CWB wants to be careful. 
    error('No idea what to do here');
end % if NAL_trial_percentage ...