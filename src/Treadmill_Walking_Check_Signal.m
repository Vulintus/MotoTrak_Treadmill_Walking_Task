function Treadmill_Walking_Check_Signal(behavior)

%
% Treadmill_Walking_Check_Signal.m
% 
%   copyright 2024, Vulintus, Inc.
%
%   TREADMILL_WALKING_CHECK_SIGNAL checks for new streaming data during a 
%   behavioral session on the MotoTrak Treadmill Walking program and 
%   calls to update the system plots when new data is available.
%   
%   UPDATE LOG:
%   2024-11-13 - Drew Sloan - Function first implemented, adapted from
%                             "Vibrotactile_Detection_Check_Signal.m"
%


[data, N] = behavior.ctrl.stream.read();                                    %Read in any new stream output from the controller.

if N == 0                                                                   %If there's no new data...
    return                                                                  %Skip the rest of the function.
end

behavior.program.fcn.process_input(data);                                   %Call the function to process input signals.
behavior.program.fcn.plot_system();                                         %Call the function to create or update the diagram.

drawnow;                                                                    %Update the plots.