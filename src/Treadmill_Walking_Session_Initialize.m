function Treadmill_Walking_Session_Initialize(behavior)

%
% Treadmill_Walking_Session_Initialize.m
%
%   copyright 2025, Vulintus, Inc.
%
%   TREADMILL_WALKING_SESSION_INITIALIZE resets recording and walking-
%   reward state, sets dispenser parameters without waiting for replies,
%   and creates the session-owned TTL stimulation timer.
%
%   UPDATE LOG:
%   2025-08-25 - Drew Sloan - Function first created, adapted from
%                             "Arm_Proprioception_Session_Initialize."
%   2026-10-11 - Codex - Added walking-reward state, separate reward counts,
%                        dispenser settings, and a session-owned TTL timer.
%   2026-10-12 - Codex - Replaced response-dependent queries with write-only
%                        commands for feeder 1 and the configured duration.
%


%Reset the session.
behavior.status.xy(:) = 0;
behavior.status.direction = 0;
behavior.status.R = eye(2);
behavior.status.omega(:) = 0;
behavior.status.total_distance = 0;
behavior.status.idle = false;
behavior.session.count.trial = 0;
behavior.session.count.feed = 0;
behavior.session.is_running = false;
if isfield(behavior.ui.display,'path')
    behavior.ui.display.path.data(:) = 0;
end
behavior.ui.edit.rewards.Value = '0';           %Stimulation trials.
behavior.ui.edit.walk_rewards.Value = '0';      %Liquid reward commands.
if is_fcn_field(behavior.session.fcn,'reset_count')
    behavior.session.fcn.reset_count();
end

%Clear the trial history.
behavior.session.trial = [];

%Set the session start time.
behavior.session.time.start.datetime = datetime('now');
behavior.session.timer.main = tic;
behavior.session.buffer(1).reward = Treadmill_Walking_Reward_Update([],...
    behavior.session.params,[],[],0,'reset');

%Set dispenser parameters without waiting for matching serial responses.
%Residual stream packets can remain after a streaming stop command.
if behavior.session.params.reward_enable
    ctrl = behavior.ctrl;
    if ~is_fcn_field(ctrl,'feed','cur_feeder','set') || ...
            ~is_fcn_field(ctrl,'feed','trig_dur','set')
        error('TreadmillWalking:RewardController','Controller does not expose dispenser setting commands.');
    end
    duration = behavior.session.params.reward_trigger_duration_ms;
    if ~isnumeric(duration) || ~isreal(duration) || ~isscalar(duration) || ...
            ~isfinite(duration) || duration < 0 || duration > 65535 || ...
            duration ~= fix(duration)
        error('TreadmillWalking:DispenserSettings',...
            'Reward trigger duration must be an integer from 0 to 65535 milliseconds.');
    end
    ctrl.feed.cur_feeder.set(1);
    ctrl.feed.trig_dur.set(duration);
    behavior.session.params.reward_feeder_index = 1;
end

%Each session owns its timer; do not reuse/delete unrelated global timers.
behavior.session.timer.ttl = timer('Name','ttl_timer');
if is_fcn_field(behavior.session.fcn,'start_ttl')
    ttl = behavior.session.timer.ttl;
    if behavior.session.params.ttl_pulsetrain_ipp > 0
        ttl.ExecutionMode = 'fixedRate';
        ttl.BusyMode = 'drop';
        ttl.Period = behavior.session.params.ttl_pulsetrain_ipp;
        ttl.TasksToExecute = max(1,floor(behavior.session.params.trial_dur/ttl.Period));
    else
        ttl.ExecutionMode = 'singleShot';
    end
    ttl.TimerFcn = {@Treadmill_Walking_TTL_Timer_Callback,behavior};
end


function Treadmill_Walking_TTL_Timer_Callback(~,~,behavior)

%
% Treadmill_Walking_TTL_Timer_Callback (local function in Treadmill_Walking_Session_Initialize.m)
%
%   copyright 2025, Vulintus, Inc.
%
%   TREADMILL_WALKING_TTL_TIMER_CALLBACK triggers and records a TTL
%   pulsetrain while the session is active. Queued callbacks are ignored
%   during pause, stopping, or cleanup.
%
%   UPDATE LOG:
%   2026-10-11 - Codex - Added active-session guards to the TTL callback.
%


if ~behavior.session.is_running || ...
        behavior.run ~= Vulintus_Behavior_Run_Class.session
    return
end
serial_date = convertTo(datetime('now'),'datenum');
behavior.session.fcn.start_ttl();
behavior.session.fcn.write_ttl_fcn(serial_date);
