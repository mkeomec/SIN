function varargout = SIN_runAnalysis(results, varargin)
%% DESCRIPTION:
%
%   Function to run SIN analyses using the analysis subfield of the SIN
%   options structure.
%
% INPUT:
%
%   results:    results structure from player_main
%
% OUTPUT:
%
%   varargout:  the nature of varargout will depend on the analysis script
%               called. Varargout will return all variables as they are
%               returned from the invoked analysis function.
%
% Development:
%
%   None (yet)
%
% Christopher W Bishop
%   University of Washington

%% GET INPUT PARAMETERS
filename=load(results);
filename(1).results;
d = varargin2struct(filename(1).results.RunTime.analysis.params);

% Does the analysis structure need to be updated?
%   Get the current analysis and replace the old analysis.
% opts = SIN_TestSetup(results(1).RunTime.specific.testID, results(1).RunTime.subject.subjectID); 
% results(1).RunTime.analysis = opts(1).analysis; 

% Get function handle
function_handle = filename(1).results.RunTime.analysis.fhand;

% How many output args are there in the analysis?
%   Got this idea from http://stackoverflow.com/questions/2821644/if-a-matlab-function-returns-a-variable-number-of-values-how-can-i-get-all-of-t
n_output = nargout(function_handle);
clearvars filename
results.results
% Run analysis
[varargout{1:n_output}] = function_handle(results, results.RunTime.analysis.params);