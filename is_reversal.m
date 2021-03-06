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

% Determine in which direction the time series is moving in.
step_direction = (sign(diff(data)));

store = []; % this is the previous direction of change
current = []; % this is the current direction of change
for i=1:numel(step_direction)
    
    % Store the current direction of change
    %   Should this be limited to [-1 1] changes? That is, exclude 0s?
    if isempty(store) && step_direction(i) ~= 0
        store = step_direction(i);
    end % isempty(store) ...
    
    % Store current
    current = step_direction(i); 
    
    % Logic for identifying reversal
    %   We only care about this if the direction of change is not zero
    if current ~= 0 && store ~= 0
        
        % If the direction of change differs, then flag it as a reversal
        if current ~= store            
            is_rev(i) = true;
            store = current;
        end %
        
    end % if current
    
end % for i=1:numel(step_direction)

% Count the number of reversals. 
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