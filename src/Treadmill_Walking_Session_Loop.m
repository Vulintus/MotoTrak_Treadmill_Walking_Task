function Treadmill_Walking_Session_Loop(behavior)

%
% Treadmill_Walking_Session_Loop.m
%
%   copyright 2024, Vulintus, Inc.
%
%   TREADMILL_WALKING_SESSION_LOOP records treadmill locomotion and
%   administers optional liquid rewards independently of stimulation
%   trials. Sessions continue until manually stopped or the program
%   is closed. Pause, reset, and cleanup disarm reward qualification.
%
%   UPDATE LOG:
%   2024-11-13 - Drew Sloan - Function first implemented, adapted from
%                             "Vibrotactile_Detection_Session_Loop.m".
%   2026-10-11 - Codex - Added continuous walking rewards, independent
%                        stimulation trials, and scoped session cleanup.
%



if ~isfield(behavior.session.params,'reward_validated') || ...
        ~isequal(behavior.session.params.reward_validated,true)
    error('TreadmillWalking:InvalidStage','Load a valid treadmill stage before starting a session.');
end
behavior.session.timer.duration = [];
behavior.session.timer.display = [];
cleanup_guard = onCleanup(@()Treadmill_Walking_Session_Cleanup(behavior));
behavior.session.is_running = false;

%Update controls for session recording.
behavior.ui.btn.stimulate.Text = 'STIMULATE';
Vulintus_Behavior_Update_Controls(behavior,'session');
Clear_Msg([],[],behavior.ui.msgbox);

%Create the output data file.
Vulintus_Behavior_Create_OmniTrak_File(behavior,1);
if is_fcn_field(behavior.session.fcn,'start_ttl')
    behavior.session.fcn.write_ttl_fcn = @(timestamp)...
        behavior.session.file.data.write{'TTL_PULSETRAIN'}(0,1,...
        'datetime',timestamp,'volts',[0,5],...
        'pulse_dur',behavior.session.params.ttl_pulse_dur,...
        'pulse_ipi',behavior.session.params.ttl_pulse_ipi,...
        'pulse_num',behavior.session.params.ttl_pulsetrain_n);
end

%Initialize the session.
Treadmill_Walking_Session_Initialize(behavior);
if behavior.session.params.reward_enable && ...
        ~isKey(behavior.session.file.data.write,'SW_OPERANT_FEED')
    error('TreadmillWalking:RewardWriter','The file writer does not support SW_OPERANT_FEED.');
end
behavior.session.file.data.write{'SESSION_PARAMS_JSON'}(behavior.session.params);

%Clear the table data.
behavior.ui.table.trial.Data = {};

%Create a session timer function.
behavior.session.timer.duration = Vulintus_Behavior_Session_Timer(behavior.ui.edit.dur,...
    behavior.session.time.start.datetime);

%Create a display timer functions.
behavior.session.timer.display = Vulintus_Behavior_Display_Timer(0.05,behavior.program.fcn.plot_system);

%Enable data streaming.
Vulintus_Behavior_Stream_Enable(behavior,true,[0,behavior.ui.port]);
behavior.run = Vulintus_Behavior_Run_Class.session;
behavior.session.is_running = true;
if ~behavior.session.params.reward_enable && is_fcn_field(behavior.session.fcn,'clock_sync')
    behavior.session.fcn.clock_sync();
end
sync_warning_shown = false;


%% MAIN LOOP ***********************************************************************************************************************
while isequal(behavior.run.root,'session')

    switch behavior.run

        case Vulintus_Behavior_Run_Class.session
            if ~isempty(behavior.session.trial) && ...
                    behavior.session.trial(end).active && ...
                    behavior.session.trial(end).timeout()
                Treadmill_Walking_Trial_Stop(behavior);
            end
            if behavior.session.params.reward_enable
                state = behavior.session.buffer.reward;
                if state.pending_sync && ~state.sync_requested
                    behavior.session.buffer.reward.sync_requested = true;
                    behavior.session.fcn.clock_sync();
                elseif state.pending_sync && ~sync_warning_shown && ...
                        toc(behavior.session.timer.main) - state.reset_host > 2
                    warning('TreadmillWalking:RewardClock',...
                        'Waiting for treadmill clock synchronization; walking rewards remain disarmed.');
                    sync_warning_shown = true;
                end
            end
            behavior.ctrl.stream.read(0.005);

            %read() drains packets and UI events before a single delivery decision.
            Treadmill_Walking_Reward_Dispense(behavior);

        case Vulintus_Behavior_Run_Class.session_stimulate
            behavior.run = Vulintus_Behavior_Run_Class.session;
            if ~isempty(behavior.session.trial) && behavior.session.trial(end).active
                Treadmill_Walking_Trial_Stop(behavior);     %STOP STIMULATION.
            else
                Treadmill_Walking_Trial_Start(behavior);    %STIMULATE.
            end

        case Vulintus_Behavior_Run_Class.session_pause
            behavior.session.is_running = false;
            Treadmill_Walking_Session_Stop_Trial(behavior);
            Treadmill_Walking_Session_Reset_Rewards(behavior);
            if is_fcn_field(behavior.session.fcn,'stop_feed')
                behavior.session.fcn.stop_feed();
            end
            behavior.ui.btn.pause.Text = 'RESUME';
            behavior.ui.btn.pause.ButtonPushedFcn = ...
                {@Vulintus_Behavior_Set_Run_State,Vulintus_Behavior_Run_Class.session,behavior,1};
            behavior.ui.btn.stimulate.Enable = 'off';
            while behavior.run == Vulintus_Behavior_Run_Class.session_pause
                behavior.ctrl.stream.read(0.005);
            end
            if isequal(behavior.run.root,'session')
                Treadmill_Walking_Session_Reset_Rewards(behavior);
                behavior.session.is_running = true;
                behavior.ui.btn.pause.Text = 'PAUSE';
                behavior.ui.btn.pause.ButtonPushedFcn = ...
                    {@Vulintus_Behavior_Set_Run_State,Vulintus_Behavior_Run_Class.session_pause,behavior,1};
                behavior.ui.btn.stimulate.Enable = 'on';
            end

        case Vulintus_Behavior_Run_Class.session_reset
            behavior.session.is_running = false;
            Treadmill_Walking_Session_Stop_Trial(behavior);
            Treadmill_Walking_Session_Reset_Rewards(behavior);
            if is_fcn_field(behavior.session.fcn,'reset_count')
                behavior.session.fcn.reset_count();
            end

            %Counters and recorded history belong to the session, not this reset.
            behavior.run = Vulintus_Behavior_Run_Class.session;
            behavior.session.is_running = true;

        case Vulintus_Behavior_Run_Class.session_webcam_preview
            % behavior.session.is_running = false;
            % Treadmill_Walking_Session_Stop_Trial(behavior);
            % Treadmill_Walking_Session_Reset_Rewards(behavior);
            % Vulintus_Behavior_Launch_Webcam_Preview;
            if isequal(behavior.run.root,'session')
                behavior.run = Vulintus_Behavior_Run_Class.session;
                behavior.session.is_running = true;
            end

        case Vulintus_Behavior_Run_Class.session_stop
            behavior.run = Vulintus_Behavior_Run_Class.idle;

        otherwise

            %Do not treat unrelated session actions as permission to dispense.
            behavior.session.is_running = false;
            Treadmill_Walking_Session_Reset_Rewards(behavior);
            behavior.run = Vulintus_Behavior_Run_Class.session;
            behavior.session.is_running = true;

    end
end

behavior.session.is_running = false;
Treadmill_Walking_Session_Stop_Trial(behavior);
clear cleanup_guard;                          %Also closes timers/stream/file.
if isfield(behavior.ui,'msgbox')
    Add_Msg(behavior.ui.msgbox,sprintf('%s - Session ended, %1.0f stimulations, %1.0f walking rewards.',...
        char(datetime,'hh:mm:ss'),behavior.session.count.trial,behavior.session.count.feed));
end
behavior.ui.btn.stimulate.Text = 'STIMULATE';
behavior.ui.btn.pause.Text = 'PAUSE';
Vulintus_Behavior_Update_Controls(behavior,'idle');


function Treadmill_Walking_Session_Reset_Rewards(behavior)

%
% Treadmill_Walking_Session_Reset_Rewards (local function in Treadmill_Walking_Session_Loop.m)
%
%   copyright 2026, Vulintus, Inc.
%
%   TREADMILL_WALKING_SESSION_RESET_REWARDS clears walking qualification and requires a fresh
%   treadmill clock reply before qualification can resume.
%
%   UPDATE LOG:
%   2026-10-11 - Codex - Function first created as a session reset helper.
%


behavior.session.buffer.reward = Treadmill_Walking_Reward_Update([],...
    behavior.session.params,[],[],toc(behavior.session.timer.main),'reset');


function Treadmill_Walking_Session_Stop_Trial(behavior)

%
% Treadmill_Walking_Session_Stop_Trial (local function in Treadmill_Walking_Session_Loop.m)
%
%   copyright 2026, Vulintus, Inc.
%
%   TREADMILL_WALKING_SESSION_STOP_TRIAL ends the current stimulation trial if one is active,
%   without changing the walking-reward history.
%
%   UPDATE LOG:
%   2026-10-11 - Codex - Function first created as a session stop helper.
%


if ~isempty(behavior.session.trial) && behavior.session.trial(end).active
    Treadmill_Walking_Trial_Stop(behavior);
end


function Treadmill_Walking_Session_Cleanup(behavior)

%
% Treadmill_Walking_Session_Cleanup (local function in Treadmill_Walking_Session_Loop.m)
%
%   copyright 2026, Vulintus, Inc.
%
%   TREADMILL_WALKING_SESSION_CLEANUP disarms rewards, stops session
%   outputs and owned timers, drains the stream, and closes the data file.
%   The session loop also calls this cleanup when an error interrupts it.
%
%   UPDATE LOG:
%   2026-10-11 - Codex - Function first created for scoped session cleanup.
%


behavior.session.is_running = false;
for output_name = {'stop_ttl','stop_feed'}
    try
        if is_fcn_field(behavior.session.fcn,output_name{1})
            behavior.session.fcn.(output_name{1})();
        end
    catch err
        warning('TreadmillWalking:StopOutput','Could not run %s: %s',output_name{1},err.message);
    end
end
timers = {behavior.session.timer.display,behavior.session.timer.duration};
if isfield(behavior.session.timer,'ttl')
    timers{end+1} = behavior.session.timer.ttl;
end
for k = 1:numel(timers)
    obj = timers{k};
    if ~isempty(obj) && isvalid(obj)
        stop(obj);
        if isvalid(obj)
            delete(obj);
        end
    end
end
try
    Vulintus_Behavior_Stream_Enable(behavior,false);
    if is_fcn_field(behavior.session.fcn,'clock_sync')
        behavior.session.fcn.clock_sync();
    end
    drain_timer = tic;
    while toc(drain_timer) < 0.25
        behavior.ctrl.stream.read(0.005);
    end
catch err
    warning('TreadmillWalking:StopStream','Could not drain stream: %s',err.message);
end
if behavior.session.file.data.is_open()
    behavior.session.file.data.close();
end
