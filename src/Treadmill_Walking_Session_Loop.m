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
Vulintus_Behavior_Update_Controls(behavior, 'session');                     %Call the function to update all of the uicontrols.
Clear_Msg([],[],behavior.ui.msgbox);                                        %Clear the existing messages out of the messagebox.

%Reset the session.
behavior.status.xy(:) = 0;                                                  %Reset the x-y coordinates.
behavior.status.direction = 0;                                              %Reset the animal orientation.
behavior.status.total_distance = 0;                                         %Reset the distance count.
behavior.status.idle = false;                                               %Indicate the ball is not idle.
behavior.session.count.trial = 0;                                           %Reset the trial count.
behavior.ui.display.path.data(:) = 0;                                       %Reset the animal path.
behavior.ui.reward.Text = '0';                                              %Set the trial count display to zero.

%Create the output data file.
Vulintus_Behavior_Create_OmniTrak_File(behavior, 1);                        %Create the output date file-writing structure.
if is_fcn_field(behavior.session.fcn,'send_ttl')                            %If this session has TTL-sending enabled...
    behavior.session.fcn.write_ttl_fcn = ...
        @(timestamp)behavior.session.file.write{'TTL_PULSE'}(timestamp,...
        1, 5, 1000*behavior.session.params.ttl_duration);                   %Capture the TTL pulse parameters in the file-writing function.
end
behavior.session.fcn.clock_sync();                                          %Request a clock synchronization block.  

%Clear the table data.
behavior.ui.table.trial.Data = {};                                          

%Create a session timer function.
session_timer = Vulintus_Behavior_Session_Timer(behavior.ui(1).edit.dur,...
    behavior.session.time.start.datetime);

%Create a display timer function.
display_timer = Vulintus_Behavior_Display_Timer(0.05,...
    behavior.program.fcn.plot_system);                                      %Refresh the system plot at ~20 Hz.

%Enable data streaming.
Vulintus_Behavior_Stream_Enable(behavior, true, behavior.ui.port);          %Enable streaming.
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
    
    stop(timerfind('Name','ttl_timer'));                                    %Stop any TTL timer.

    switch behavior.run                                                     %Switch between the recognized run cases.
       
        case {  Vulintus_Behavior_Run_Class.session,...
                Vulintus_Behavior_Run_Class.session_stimulate,...
             }                                                              %If the session is still running as normal...
            Treadmill_Walking_Trial_Stop(behavior);                         %Stop the current trial.
            
        case Vulintus_Behavior_Run_Class.session_webcam_preview             %If the user wants to open a webcam preview...    
            Vulintus_Behavior_Launch_Webcam_Preview;                        %Call the toolbox function to launch a webcam preview.
            behavior.run = Vulintus_Behavior_Run_Class.session;             %Set the run variable back to session mode.            
            
    end         
    
end
    
%Stop the various display timers.
stop(display_timer);                                                        %Stop the display timer.
stop(session_timer);                                                        %Stop the session timer.
stop(timerfind('Name','ttl_timer'));                                        %Stop the TTL timer.
delete(timerfind('Name','ttl_timer'));                                      %Delete the TTL timer.

%Stop the data stream and request one last clock synchronization block.
Vulintus_Behavior_Stream_Enable(behavior, false, behavior.ui.port);         %Disable streaming.
if is_fcn_field(behavior.session.fcn,'clock_sync')                          %If a clock synchronization function has been set...
    behavior.session.fcn.clock_sync();                                      %Request a clock synchronization block.
end
wait_time = toc(behavior.session.timer.main) + 0.25;                        %Wait 250 milliseconds to let all remaining data come in.
while toc(behavior.session.timer.main) < wait_time                          %Loop through the wait time.
    behavior.ctrl.stream.read(0.005);                                       %Read and process any new streaming data.
end

%Close the session data file.
behavior.session.file.close();

%Clear any residual values from the serial line.
behavior.ctrl.otsc.clear(0.1);                                              

%Show a session end message in the messagebox.
if isfield(behavior.ui,'msgbox')                                            %If there's a messagebox in the GUI.
    str = sprintf('%s - Session ended, %1.0f stimulations.',...
        char(datetime,'hh:mm:ss'), behavior.session.count.trial);           %Create a message string.
    Add_Msg(behavior.ui.msgbox,str);                                        %Show the message in the messagebox.
end

%Update all of the uicontrols.
Vulintus_Behavior_Update_Controls(behavior, 'idle');                        %Call the function to update all of the uicontrols.