function Treadmill_Walking_Session_Loop(behavior)

%
% Treadmill_Walking_Session_Loop.m
% 
%   copyright 2024, Vulintus, Inc.
%
%   VIBROTACTILE_DETECTION_SESSION_LOOP is the main behavioral loop for the 
%   SensiTrak vibrotactile detection task program running through the 
%   Vulintus Common Behavior functions.
%   
%   UPDATE LOG:
%   2024-11-13 - Drew Sloan - Function first implemented, adapted from
%                             "Vibrotactile_Detection_Session_Loop.m".
%


%Update all of the uicontrols.
behavior.ui.btn.stimulate.Text = 'STIMULATE';                               %Revert the stimulate button text to the default.
Vulintus_Behavior_Update_Controls(behavior, 'session');                     %Call the function to update all of the uicontrols.
Clear_Msg([],[],behavior.ui.msgbox);                                        %Clear the existing messages out of the messagebox.

%Create the output data file.
Vulintus_Behavior_Create_OmniTrak_File(behavior, 1);                        %Create the output date file-writing structure.
if is_fcn_field(behavior.session.fcn,'start_ttl')                           %If this session has TTL-sending enabled...
    behavior.session.fcn.write_ttl_fcn = ...
        @(timestamp)...
        behavior.session.file.data.write{'TTL_PULSETRAIN'}(0, 1,...
        'datetime', timestamp,...
        'volts', [0, 5],...
        'pulse_dur', behavior.session.params.ttl_pulse_dur,...
        'pulse_ipi', behavior.session.params.ttl_pulse_ipi,...
        'pulse_num', behavior.session.params.ttl_pulsetrain_n);             %Capture the TTL pulse parameters in the file-writing function.
end
behavior.session.fcn.clock_sync();                                          %Request a clock synchronization block.

%Initialize the session.
Treadmill_Walking_Session_Initialize(behavior);                             %Call the session initialization functions.
behavior.session.file.data.write{'SESSION_PARAMS_JSON'}...
    (behavior.session(1).params);                                           %Write the session parameters as JSON-encoded text.

%Clear the table data.
behavior.ui.table.trial.Data = {};                                          

%Create a session timer function.
session_timer = Vulintus_Behavior_Session_Timer(behavior.ui(1).edit.dur,...
    behavior.session.time.start.datetime);

%Create a display timer function.
display_timer = Vulintus_Behavior_Display_Timer(0.05,...
    behavior.program.fcn.plot_system);                                      %Refresh the system plot at ~20 Hz.

%Enable data streaming.
Vulintus_Behavior_Stream_Enable(behavior, true, [0, behavior.ui.port]);     %Enable streaming.
behavior.run = Vulintus_Behavior_Run_Class.session;                         %Set the run variable to session mode.


%% MAIN LOOP ***********************************************************************************************************************
behavior.session.timer.main = tic;                                          %Create a session timer.
while isequal(behavior.run.root,'session')                                  %Loop until the user stops the session or closes the program.
    
    while behavior.run == Vulintus_Behavior_Run_Class.session               %Loop until the user clicks "STIMULATE".
        behavior.ctrl.stream.read(0.005);                                   %Read and process any new streaming data.
    end

    if behavior.run == Vulintus_Behavior_Run_Class.session_stimulate        %If the user clicked the stimulate button.
        Treadmill_Walking_Trial_Start(behavior);                            %Start a trial...
        behavior.run = Vulintus_Behavior_Run_Class.session;                 %Set the run variable back to session mode.
    end

    while behavior.run == Vulintus_Behavior_Run_Class.session && ...
            ~behavior.session.trial(end).timeout()                          %Loop until the end of the trial.
        behavior.ctrl.stream.read(0.005);                                   %Read and process any new streaming data.
    end

    behavior.session.fcn.stop_ttl();                                        %Stop any ongoing TTL pulse.

    switch behavior.run                                                     %Switch between the recognized run cases.
       
        case {  Vulintus_Behavior_Run_Class.session,...
                Vulintus_Behavior_Run_Class.session_stimulate,...
             }                                                              %If the session is still running as normal...
            Treadmill_Walking_Trial_Stop(behavior);                         %Stop the current trial.
            
        case Vulintus_Behavior_Run_Class.session_webcam_preview             %If the user wants to open a webcam preview...    
            Vulintus_Behavior_Launch_Webcam_Preview;                        %Call the toolbox function to launch a webcam preview.
            behavior.session.delete_last_trial();                           %Delete the last trial data.

        otherwise                                                           %For any other case...
            if isequal(behavior.run.root,'session')                         %If the session is still active.
                behavior.session.delete_last_trial();                       %Delete the last trial data.
            end
            
    end         
    if isequal(behavior.run.root,'session')                                 %If the session is still active.
        behavior.run = Vulintus_Behavior_Run_Class.session;                 %Set the run variable back to general session mode.   
    end
    
end
    
%Stop the various display timers.
stop(display_timer);                                                        %Stop the display timer.
stop(session_timer);                                                        %Stop the session timer.
obj = timerfind('Name','ttl_timer');                                        %Find any TTL timers.
if ~isempty(obj)                                                            %If any timers were found...
    stop(timerfind);                                                        %Stop any active behavior timers.
    delete(timerfind);                                                      %Delete any active behavior timers.
end

%Stop the data stream and request one last clock synchronization block.
Vulintus_Behavior_Stream_Enable(behavior, false);                           %Disable streaming.
if is_fcn_field(behavior.session.fcn,'clock_sync')                          %If a clock synchronization function has been set...
    behavior.session.fcn.clock_sync();                                      %Request a clock synchronization block.
end
wait_time = toc(behavior.session.timer.main) + 0.25;                        %Wait 250 milliseconds to let all remaining data come in.
while toc(behavior.session.timer.main) < wait_time                          %Loop through the wait time.
    behavior.ctrl.stream.read(0.005);                                       %Read and process any new streaming data.
end

%Close the session data file.
behavior.session.file.data.close();

%Clear any residual values from the serial line.
behavior.ctrl.otsc.clear(0.1);                                              

%Show a session end message in the messagebox.
if isfield(behavior.ui,'msgbox')                                            %If there's a messagebox in the GUI.
    str = sprintf('%s - Session ended, %1.0f stimulations.',...
        char(datetime,'hh:mm:ss'), behavior.session.count.trial);           %Create a message string.
    Add_Msg(behavior.ui.msgbox,str);                                        %Show the message in the messagebox.
end

%Update all of the uicontrols.
behavior.ui.btn.stimulate.Text = 'STIMULATE';                               %Revert the stimulate button text to the default.
Vulintus_Behavior_Update_Controls(behavior, 'idle');                        %Call the function to update all of the uicontrols.