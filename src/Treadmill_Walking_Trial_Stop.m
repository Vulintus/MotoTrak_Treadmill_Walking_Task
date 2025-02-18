function Treadmill_Walking_Trial_Stop(behavior, trial)

%
% Treadmill_Walking_Trial_Stop.m
% 
%   copyright 2025, Vulintus, Inc.
%
%   TREADMILL_WALKING_TRIAL_STOP updates the GUI at the end of a treadmill
%   walking trial with the total distance covered and number of stimulation
%   pulses delivered.
%   
%   UPDATE LOG:
%   2025-02-11 - Drew Sloan - Function first implemented
%


behavior.ui.table.trial.Data{end,end-1} = trial.timer.ttl.TasksExecuted;    %List the number of stimulation pulses.
behavior.ui.table.trial.Data{end,end} = ...
    sprintf('%1.0f mm', behavior.status.total_distance);                    %Update the distance traveled in the table.

str = sprintf('%s - Trial #%1.0f, distance traveled: %1.0f mm',...
        char(trial.time.start.datetime,'hh:mm:ss'),...
        behavior.session.count.trial,...
        behavior.status.total_distance);                                    %Create a text string.
Replace_Msg(behavior.ui.msgbox,str);                                        %Show the text string on the messagebox.
