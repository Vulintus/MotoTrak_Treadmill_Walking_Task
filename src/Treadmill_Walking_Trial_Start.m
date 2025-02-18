function trial = Treadmill_Walking_Trial_Start(behavior)

%
% Treadmill_Walking_Trial_Start.m
% 
%   copyright 2025, Vulintus, Inc.
%
%   TREADMILL_WALKING_TRIAL_START starts a TTL pulsetrain, resets the
%   position and direction tracking variables, and captures the trial
%   timing.
%   
%   UPDATE LOG:
%   2025-02-09 - Drew Sloan - Function first implemented, adapted from
%                             "Vibrotactile_Detection_Start_Trial.m".
%


trial = Vulintus_Behavior_Trial_Class(datetime('now'));                     %Reset the trial class.

trial.time.start.micros = behavior.status.last_read;                        %Grab the most recent optical flow polling time.
trial.time.end = ...
    toc(behavior.session.timer.main) + behavior.session.params.trial_dur;   %Set the trial duration.

behavior.session.count.trial = behavior.session.count.trial+ 1;             %Increment the trial count.
behavior.status.total_distance = 0;                                         %Reset the total distance count.
behavior.ui.edit.rewards.Value = ...
    sprintf('%1.0f',behavior.session.count.trial);                          %Update the trial count display.

%Write the trial number to the file.
behavior.session.file.write{'TRIAL_START_SERIAL_DATE'}(behavior.session.count.trial);     
if behavior.status.idle                                                     %If the ball was idle on the last reading.                        
    behavior.session.file.write{'AMBULATION_XY_THETA'}(behavior.status.last_read,...
        behavior.status.xy, behavior.status.direction);                     %Write the previous datapoint to the file.
    behavior.status.idle = false;                                           %Indicate the ball is not idle.
end     
behavior.session.fcn.clock_sync();                                          %Request a clock synchronization block.             

if is_fcn_field(behavior.session.fcn,'reset_count')                         %If a treadmill count reset function has been set...
    behavior.session.fcn.reset_count();                                     %Reset the display on the treadmill.
end

new_table_row = {   behavior.session.count.trial,...                        %"Trial"
                    char(datetime,'hh:mm:ss'),...                           %"Time"
                    '-',...                                                 %"Stim. Dur."
                    '-',...                                                 %"Stim. IPI"
                    '-',...                                                 %"Stim. Count"
                    '-',...                                                 %"Distance"
                };                                                          %Create a new table row.                       

trial.timer(1).ttl = timerfind('Name','ttl_timer');                         %Check for an existing TTL timer.
if isempty(trial.timer.ttl)                                                 %If no existing timer was found...
    trial.timer.ttl = timer('Name','ttl_timer');                            %Create a new timer object.
end
if is_fcn_field(behavior.session.fcn,'send_ttl')                            %If this session has TTL-sending enabled...
    trial.timer.ttl.ExecutionMode = 'fixedRate';                            %Set the callback timing to onset-to-onset.
    trial.timer.ttl.BusyMode = 'drop';                                      %Drop a callback if the previous one hasn't executed.
    trial.timer.ttl.Period = behavior.session.params.ttl_pulsetrain_ipp;    %Set the stimulation inter-pulse period.
    trial.timer.ttl.TasksToExecute = ...
        behavior.session.params.ttl_pulsetrain_n;                           %Set the number of stimulation pulses.
    trial.timer.ttl.TimerFcn = {@Treadmill_Walking_Timer_Callback_TTL,...
        behavior.session.fcn};                                              %Set the main timer callback.
    start(trial.timer.ttl);                                                 %Start the TTL timer.
    new_table_row{3} = behavior.session.params.ttl_duration;                %"Stim. Dur."
    new_table_row{4} = behavior.session.params.ttl_pulsetrain_ipp;          %"Stim. IPI"
    new_table_row{5} = '-';                                                 %"Stim. Count"

end

behavior.ui.table.trial.Data(end+1,:) = new_table_row;                      %Clear the table data.
scroll(behavior.ui.table.trial,'bottom');                                   %Scroll to the bottom of the table.

str = sprintf('%s - Trial #%1.0f...',...
        datestr(trial.time.start.datetime,13),...
        behavior.session.count.trial);                                      %Create a text string.
Add_Msg(behavior.ui.msgbox,str);                                            %Show the text string on the messagebox.


%TTL timer main callback.
function Treadmill_Walking_Timer_Callback_TTL(~, ~, fcn)
serial_date = convertTo(datetime('now'),'datenum');                         %Grab the current serial date number.
fcn.send_ttl();                                                             %Send a TTL pulse.
fcn.write_ttl_fcn(serial_date);                                             %Write the TTL timing to file.
