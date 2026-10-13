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
%   2026-10-11 - Codex - Guarded inactive trials and stopped owned TTL output.
%




t = behavior.session.count.trial;                                           %Copy the current trial index to a simpler variable.
if t == 0 || isempty(behavior.session.trial) || ~behavior.session.trial(t).active
    return
end
behavior.session.trial(t).stop();                                           %Stop the trial clock.
if is_fcn_field(behavior.session.fcn,'stop_ttl')
    behavior.session.fcn.stop_ttl();
end
if isvalid(behavior.session.timer.ttl) && ...
        strcmp(behavior.session.timer.ttl.Running,'on')                                       %If the TTL timer is running...
    stop(behavior.session.timer.ttl);                                       %Stop the TTL timer.
end

behavior.ui.btn.stimulate.Text = 'STIMULATE';                               %Update the stimulate button text.

behavior.ui.table.trial.Data{end,end-1} = ...
    sprintf('%1.0f',behavior.session.timer.ttl.TasksExecuted);              %List the number of stimulation pulstrains.
behavior.ui.table.trial.Data{end,end} = ...
    sprintf('%1.0f mm', behavior.status.total_distance);                    %Update the distance traveled in the table.

str = sprintf('%s - Trial #%1.0f, distance traveled: %1.0f mm',...
        char(behavior.session.trial(t).time.start.datetime,'hh:mm:ss'),...
        behavior.session.count.trial,...
        behavior.status.total_distance);                                    %Create a text string.
Replace_Msg(behavior.ui.msgbox,str);                                        %Show the text string on the messagebox.
