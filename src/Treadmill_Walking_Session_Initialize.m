function Treadmill_Walking_Session_Initialize(behavior)

%
% Treadmill_Walking_Session_Initialize.m
%   
%   copyright 2025, Vulintus, Inc.
%
%   TREADMILL_WALKING_SESSION_INITIALIZE creates and populates the 
%   SensiTrak arm proprioception discrimination task session class.
%   
%   UPDATE LOG:
%   2025-08-25 - Drew Sloan - Function first created, adapted from
%                             "Arm_Proprioception_Session_Initialize."
%


%Reset the session.
behavior.status.xy(:) = 0;                                                  %Reset the x-y coordinates.
behavior.status.direction = 0;                                              %Reset the animal orientation.
behavior.status.total_distance = 0;                                         %Reset the distance count.
behavior.status.idle = false;                                               %Indicate the ball is not idle.
behavior.session.count.trial = 0;                                           %Reset the trial count.
behavior.ui.display.path.data(:) = 0;                                       %Reset the animal path.
behavior.ui.reward.Text = '0';                                              %Set the trial count display to zero.
if is_fcn_field(behavior.session.fcn,'reset_count')                         %If a treadmill count reset function has been set...
    behavior.session.fcn.reset_count();                                     %Reset the display on the treadmill.
end

%Clear the trial history.
behavior.session.trial = [];    

%Set the session start time.
behavior.session.time.start.datetime = datetime('now');

%Create the TTL timer.
behavior.session.timer(1).ttl = timerfind('Name','ttl_timer');              %Check for an existing TTL timer.
if isempty(behavior.session.timer.ttl)                                      %If no existing timer was found...
    behavior.session.timer.ttl = timer('Name','ttl_timer');                 %Create a new timer object.
end
if is_fcn_field(behavior.session.fcn,'start_ttl')                           %If this session has TTL-sending enabled...
    if behavior.session.params.ttl_pulsetrain_ipp > 0                       %If there will be multiple pulsetrains...
        behavior.session.timer.ttl.ExecutionMode = 'fixedRate';             %Set the execution mode to periodic.
        behavior.session.timer.ttl.BusyMode = 'drop';                       %Drop a callback if the previous one hasn't executed.
        behavior.session.timer.ttl.Period = ...
            behavior.session.params.ttl_pulsetrain_ipp;                     %Set the stimulation inter-pulse period.        
        behavior.session.timer.ttl.TasksToExecute = ...
            floor(behavior.session.params.trial_dur/...
            behavior.session.params.ttl_pulsetrain_ipp);                    %Set the number of stimulation pulses.
    else                                                                    %Otherwise...
        behavior.session.timer.ttl.ExecutionMode = 'singleShot';            %Set the execution mode to single-shot.
    end        
    behavior.session.timer.ttl.TimerFcn = ...
        {@Treadmill_Walking_TTL_Timer_Callback, behavior.session.fcn};      %Set the main timer callback.
end


%TTL timer main callback.
function Treadmill_Walking_TTL_Timer_Callback(~, ~, fcn)
serial_date = convertTo(datetime('now'),'datenum');                         %Grab the current serial date number.
fcn.start_ttl();                                                             %Send a TTL pulse.
fcn.write_ttl_fcn(serial_date);                                             %Write the TTL timing to file.