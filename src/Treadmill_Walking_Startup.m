function Treadmill_Walking_Startup(varargin)

%
% Treadmill_Walking_Startup.m - Vulintus, Inc.
%
%   copyright 2024, Vulintus, Inc.
%
%   TREADMILL_WALKING_STARTUP starts the MotoTrak treadmill walking
%   behavioral program. It loads in default parameters, creates the GUI, 
%   and creates the connection to the OmniTrak controller or directly to 
%   the spherical treadmill.
%   
%   UPDATE LOG:
%   2024-11-14 - Drew Sloan - Function first created.
%                            


%% Use the Vulintus Common Behavior startup function.
if nargin                                                                   %If there were any input arguments.
    behavior = varargin{1};                                                 %Assume the behavior class is the first input.
else                                                                        %Otherwise...
    behavior = Vulintus_Behavior_Class('Treadmill Walking');                %Create a Vulintus Behavior class instance.
end
Vulintus_Behavior_Startup(behavior);                                        %Call the common behavior startup functions.