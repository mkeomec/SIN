function [is_rev, nrev] = is_reversal(data, varargin)
%% DESCRIPTION:
%
%   This function takes a time series, data, and determines which points
%   are likely reversals (e.g., a reversal in the direction of change).
%   This was written and intended to be used in combination with tests like
%   the HINT (SNR-80 ...) and other adaptive algorithms that are required
%   to terminate after a specific number of reversals. 
%
% INPUT:
%
%   data:   Nx1 vector, the time series to find reversals in.
%
% Parameters:
%
%   'plot': bool, if set, then a descriptive plot is generated. If false,
%           then no plot generated. (default = false); 
%
% OUTPUT:
%
%   isrev:  Nx1 vector, bool (true/false). The element is true if that
%           specific element is a reversal. Otherwise, false.
%
%   nrev:   integer, the number of reversals in the time series. This is
%           derived directly from isrev by counting the number of true
%           elements in isrev. This additional return variable will
%           centralize the counting and make this easier to use ... or so
%           CWB thinks.
%
% Development:
%
%   None (yet)
%
% Christopher W Bishop
%   University of Washington
%   10/14

%% GET PARAMETERS 
d=varargin2struct(varargin{:});

%% SET DEFAULTS

% Don't plot results by default 
if ~isfield(d, 'plot') || isempty(d.plot), d.plot = false; end

%% INITIALIZE RETURN VARIABLES
is_rev = false(size(data)); 

% The section below is rather confusing, to be honest. CWB has tried to
% comment as well as possible here, but ultimately it's still very
% confusing. Another resource worth looking into is algo_NALadaptive. That
% is where CWB first wrote the reversal tracking algorithm. Commenting and
% explanations there might be better. 

% We need to remove repeated values since these will not be informative in
% detecting reversals. However, we want to keep the LAST instance of a
% repeated value in consecutive trials - that way the reversal is assigned
% to the last trial - that's treally the "reversal" point.

% Determine in which direction the time series is moving in.
step_direction = (sign(diff(data)));

data_clean = [];

% This creates an array index (clean2orig) that can be used to mask the
% original data. When the original data are masked, only the *potential*
% reversonal points are returned. 
start_index = 1; 
clean2orig = [];
while start_index < numel(step_direction)
    
    % Focus on the next chunk of data
    tstep_direction = step_direction(start_index:end); 
    
    % Find first zero (no change)
    first_zero = find(tstep_direction == 0, 1, 'first'); 
    
    % If there are NOT any repeats (i.e., no changes of 0), then take the
    % whole time series and break out of the loop. No cleaning necessary. 
    if isempty(first_zero)
%         first_zero = numel(data) + 1; 
        clean2orig = [clean2orig; [start_index : numel(data)]'];
        break
    end % 
    
    % Add beginning samples to data
    clean2orig = [clean2orig; [start_index : start_index + first_zero - 2]'];
    
    % Truncate data 
    tstep_direction = tstep_direction(first_zero:end);
    
    % Find last zero (no change)
    last_zero = find(tstep_direction ~= 0, 1, 'first'); 
    
    % Add last_zero to clean2orig
    clean2orig = [clean2orig; last_zero + first_zero + start_index - 2]; %#ok<*AGROW>
    
    start_index = last_zero + first_zero + start_index - 1; 
end % while

%% LOOK AT POTENTIAL REVERSAL POINTS
data_clean = data(clean2orig);

% This complicated piece of code here is the reversal detection algo.
is_rev(clean2orig(find(diff(sign(diff(data_clean)))~=0)+1')) = true;

% Count the number of reversals 
nrev = numel(find(is_rev)); 

%% VISUALIZATION PLOTS
if d.plot
         
    lineplot2d(1:numel(data), data, ...
        'xlabel',   'Data Point', ...
        'ylabel',   'Data Value', ...
        'title',    '', ...
        'grid',     'on', ...
        'linewidth',    2, ...
        'color',    'k', ...
        'marker',   'o', ...
        'fignum',   gcf); 
    
    hold on
    plot(find(is_rev), data(is_rev), 'ro', 'linewidth', 2)
        
    legend({'Data Trace', 'Reversals'}, 'location', 'best')
    
end % if d.plot 