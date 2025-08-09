function Treadmill_Walking_Trial_Stop(behavior)

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


t = behavior.session.count.trial;                                           %Copy the current trial index to a simpler variable.
behavior.session.trial(t).stop();                                           %Stop the trial clock.

behavior.ui.table.trial.Data{end,end-1} = ...
    behavior.session.trial(t).timer.ttl.TasksExecuted;                      %List the number of stimulation pulses.
behavior.ui.table.trial.Data{end,end} = ...
    sprintf('%1.0f mm', behavior.status.total_distance);                    %Update the distance traveled in the table.

str = sprintf('%s - Trial #%1.0f, distance traveled: %1.0f mm',...
        char(behavior.session.trial(t).time.start.datetime,'hh:mm:ss'),...
        behavior.session.count.trial,...
        behavior.status.total_distance);                                    %Create a text string.
Replace_Msg(behavior.ui.msgbox,str);                                        %Show the text string on the messagebox.
