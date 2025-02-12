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
behavior.session.file(1).write = ...
    Vulintus_Behavior_Create_OmniTrak_File(behavior);                       %Create the output date file-writing structure.
if is_fcn_field(behavior.session.fcn,'send_ttl')                            %If this session has TTL-sending enabled...
    behavior.session.fcn.write_ttl_fcn = ...
        @(timestamp)behavior.session.file.write.ttl_pulse(timestamp,...
        1, 5, 1000*behavior.session.params.ttl_duration);                   %Capture the TTL pulse parameters in the file-writing function.
end

%Clear the table data.
behavior.ui.table.trial.Data = {};                                          

%Create a session timer function.
session_timer = Vulintus_Behavior_Session_Timer(behavior.ui.edit.dur,...
    behavior.session.time.start);

%Enable data streaming.
behavior.ctrl.otsc.clear(0.1);                                              %Clear any residual values from the serial line.  
behavior.ctrl.stream.enable(2);                                             %Enable event-triggered streaming on the controller.
behavior.ctrl.stream.enable(1,'passthrough',1);                             %Enable periodic streaming on the spherical treadmill.
behavior.run = Vulintus_Behavior_Run_Class.session;                         %Set the run variable to session mode.


%% MAIN LOOP ***********************************************************************************************************************
behavior.session.timer.main = tic;                                          %Create a session timer.
while isequal(behavior.run.root,'session')                                  %Loop until the user stops the session or closes the program.
    
    while behavior.run == Vulintus_Behavior_Run_Class.session               %Loop until the user clicks "STIMULATE".
        Treadmill_Walking_Check_Signal(behavior);                           %Check the incoming signal.
    end

    if behavior.run == Vulintus_Behavior_Run_Class.session_stimulate        %If the user clicked the stimulate button.
        trial = Treadmill_Walking_Trial_Start(behavior);                    %Start a trial...
        behavior.run = Vulintus_Behavior_Run_Class.session;                 %Set the run variable back to session mode.
    end

    while behavior.run == Vulintus_Behavior_Run_Class.session && ...
            toc(behavior.session.timer.main) < trial.time.end               %Loop until the end of the trial.
        Treadmill_Walking_Check_Signal(behavior);                           %Check the incoming signal.
    end
    
    stop(timerfind('Name','ttl_timer'));                                    %Stop any TTL timer.

    switch behavior.run                                                     %Switch between the recognized run cases.
       
        case {  Vulintus_Behavior_Run_Class.session,...
                Vulintus_Behavior_Run_Class.session_stimulate,...
             }                                                              %If the session is still running as normal...
            Treadmill_Walking_Trial_Stop(behavior, trial);                  %Stop the current trial.
            
        case Vulintus_Behavior_Run_Class.session_webcam_preview             %If the user wants to open a webcam preview...    
            Vulintus_Behavior_Launch_Webcam_Preview;                        %Call the toolbox function to launch a webcam preview.
            behavior.run = Vulintus_Behavior_Run_Class.session;             %Set the run variable back to session mode.            
            
    end         
    
end
    
behavior.session.file.write.close();                                        %Close the session data file.

%Stop the data stream.
try                                                                         %Attempt to clear the serial line.    
    behavior.ctrl.stream.enable(0);                                         %Disable streaming on the controller.
    behavior.ctrl.otsc.clear(0.1);                                          %Clear any residual values from the serial line.
catch err                                                                   %If an error occurred...
    err_path = fullfile(behavior.mainpath, 'Error Reports');                %Create the expected directory name for the error reports.
    txt = Vulintus_Behavior_Save_Error_Report(err_path,...
        behavior.task,err,behavior);                                        %Save a copy of the error in the AppData folder.      
end

if isfield(behavior.ui,'msgbox')                                            %If there's a messagebox in the GUI.
    str = sprintf('%s - Session ended, %1.0f stimulations.',...
        char(datetime,'hh:mm:ss'), behavior.session.count.trial);           %Create a message string.
    Add_Msg(behavior.ui.msgbox,str);                                        %Show the message in the messagebox.
end

stop(session_timer);                                                        %Stop the session timer.
stop(timerfind('Name','ttl_timer'));                                        %Stop the TTL timer.
delete(timerfind('Name','ttl_timer'));                                      %Delete the TTL timer.

%Update all of the uicontrols.
Vulintus_Behavior_Update_Controls(behavior, 'idle');                        %Call the function to update all of the uicontrols.