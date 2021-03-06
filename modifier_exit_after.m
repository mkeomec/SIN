function [Y, d] = modifier_exit_after(X, mod_code, varargin)
%% DESCRIPTION:
%
%   This is sort of a wrapper used to check multiple exit criteria
%   (modifiers). For instance, if the user wants to exit only after 7
%   reversals and a minimum of 20 trials, then this is the function to use.
%
% INPUT:
%
%   XXX
%
% Parameters:
%
%   function_handles:   function handles to modifiers to check. These
%                       modifiers must set the player state to 'exit' when
%                       their criteria are satisfied. 
%
%   function_params:    a cell array. each element contains the arguments
%                       to be passed to the corresponding function_handle. 
%
%   'operator': string, operator to use in conditional check. For example,
%               '&&' if the user wants to exit only after ALL modifiers are
%               setting he player state to exit. 
%
% OUTPUT:
%
%   XXX
%
% Development:
%
%   None (yet)
%
% Christopher W Bishop
%   University of Washington
%   12/14

%% GET PARAMETERS
d=varargin2struct(varargin{:}); 

% The player is made to work with a "SIN" style structure. If the user has
% defined inputs just at the commandline, then reassign to make it
% compatible.
if ~isfield(d, 'player')
    d.player = d; 
end % if

%% GET IMPORTANT VARIABLES FROM SANDBOX
modifier_num=d.sandbox.modifier_num; 
trial = d.sandbox.trial; 

%% GET MODIFIER PARAMETERS
function_handles = d.player.modifier{modifier_num}.function_handles;
function_parameters = d.player.modifier{modifier_num}.function_parameters;
operator = d.player.modifier{modifier_num}.operator; 

if ~isfield(d.player.modifier{modifier_num}, 'initialized') || isempty(d.player.modifier{modifier_num}.initialized), d.player.modifier{modifier_num}.initialized=false; end

%% ASSIGN RETURN DATA
%   This function does not alter the data directly, so just spit back the
%   original data
Y=X; 

%% IF THIS IS OUR FIRST CALL, JUST INITIALIZE 
%   - No modifications necessary, just return the data structures and
%   original time series.
if ~d.player.modifier{modifier_num}.initialized
    
    % Set the initialization flag
    d.player.modifier{modifier_num}.initialized=true;
    
    return
    
end % if ~d.player.modifier{modifier_num}.initialized

% Use is_exit to track whether or not each modifier has set player status
% to exit. 
is_exit = false(numel(function_handles),1); 

% Build the evaluation string that will be executed after all modifiers
% have been run
eval_str = ''; 
% Now, check all the function handles we have.
for i=1:numel(function_handles)
    
    % Copy options structure to a temporary variable
    %   We need to copy it so we don't alter the return variable (d). This
    %   should ONLY be modified in the final check below.
    temp = d; 
    
    % Tweak structure and sandbox settings so we can call the modifiers
    % directly.
    temp.sandbox.modifier_num = 1;
    
    temp.player.modifier = {struct(...
        'fhandle',  function_handles{i}, ...
        'initialized',  true)}; % if we're here then trick the modifiers into thinking they've been initialized
    
    % Now copy over the fields from function_parameters
    flds = fieldnames(function_parameters{i});
    
    for m=1:numel(flds)
        temp.player.modifier{1}.(flds{m}) = function_parameters{i}.(flds{m}); 
    end % for m=1:numel(flds)         
    
    % Call the modifier 
    %   We will pass in an empty data trace because we aren't going to
    %   modify it anyway. 
    [~, temp] = temp.player.modifier{1}.fhandle([], mod_code, temp);
    
    % Check player state
    if isequal(temp.player.state, 'exit')
        is_exit(i) = true;
    end % 
    
    % Add to eval_str
    if isempty(eval_str)
        eval_str = ['logical(' num2str(is_exit(i)) ') '];
    else
        eval_str = [eval_str operator ' logical(' num2str(is_exit(i)) ') ']; 
    end % if isempty(eval_str
    
end % for i=1:numel(d.function_handles) 

% Evaluate the expression and see if it's time to set the state to exit
if eval(eval_str)
    d.player.state = 'exit'; 
end % if eval ...