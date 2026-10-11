function Treadmill_Walking_Trial_Start(behavior)

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
%   2025-08-25 - Drew Sloan - Moved the TTL timer to the session
%                             initialization function.
%


%Create a new Vulintus_Behavior_Trial_Class instance.
behavior.session.count.trial = behavior.session.count.trial + 1;            %Increment the trial count.
t = behavior.session.count.trial;                                           %Copy the current trial index to a simpler variable.
behavior.session.trial(t) = Vulintus_Behavior_Trial_Class;                  %Create a new trial class instance.
behavior.session.trial(t).time.start.micros = behavior.status.last_read;    %Grab the most recent optical flow polling time.
behavior.session.trial(t).params.dur = behavior.session.params.trial_dur;   %Set the trial duration.
behavior.status.total_distance = 0;                                         %Reset the total distance count.
behavior.ui.edit.rewards.Value = ...
    sprintf('%1.0f',behavior.session.count.trial);                          %Update the trial count display.

%Write the trial number to the file.
behavior.session.file.data.write{'TRIAL_START_SERIAL_DATE'}(behavior.session.count.trial);     
if behavior.status.idle                                                     %If the ball was idle on the last reading.                        
    behavior.session.file.data.write{'AMBULATION_XY_THETA'}(behavior.status.last_read,...
        behavior.status.xy, behavior.status.direction);                     %Write the previous datapoint to the file.
    behavior.status.idle = false;                                           %Indicate the ball is not idle.
end     
behavior.session.fcn.clock_sync();                                          %Request a clock synchronization block.             

new_table_row = {   sprintf('%1.0f',t),...                                  %"Trial"
                    char(datetime,'hh:mm:ss'),...                           %"Time"
                    '-',...                                                 %"Pulse Dur."
                    '-',...                                                 %"Pulse IPI"
                    '-',...                                                 %"Pulses/Train"
                    '-',...                                                 %"Train IPP"
                    '-',...                                                 %"Train Count"
                    '-',...                                                 %"Distance"
                };                                                          %Create a new table row.                       

if is_fcn_field(behavior.session.fcn,'start_ttl')                           %If this session has TTL-sending enabled...
    start(behavior.session.timer.ttl);                                      %Start the TTL timer.
    new_table_row{3} = ...
        sprintf('%1.3f',behavior.session.params.ttl_pulse_dur);             %"Pulse Dur."
    new_table_row{4} =  ...
        sprintf('%1.3f',behavior.session.params.ttl_pulse_ipi);             %"Pulse IPI"
    if behavior.session.params.ttl_pulsetrain_n ~= 65535                    %If we're not doing infinite pulses...
        new_table_row{5} = ...
            sprintf('%1.0f',behavior.session.params.ttl_pulsetrain_n);      %"Pulses/Train"
    end
    if behavior.session.params.ttl_pulsetrain_ipp > 0                       %If an inter-pulsetrain period is set...
        new_table_row{6} = ...
            sprintf('%1.3f',behavior.session.params.ttl_pulsetrain_ipp);    %"Train IPP"
    end    
end

behavior.session.trial(t).start();                                          %Start the trial clock.

behavior.ui.table.trial.Data(end+1,:) = new_table_row;                      %Clear the table data.
scroll(behavior.ui.table.trial,'bottom');                                   %Scroll to the bottom of the table.

behavior.ui.btn.stimulate.Text = {'STOP'; 'STIMULATION'};                   %Update the stimulate button text.

str = sprintf('%s - Trial #%1.0f...',...
        char(behavior.session.trial(t).time.start.datetime,'HH:mm:ss'),...
        behavior.session.count.trial);                                      %Create a text string.
Add_Msg(behavior.ui.msgbox,str);                                            %Show the text string on the messagebox.



