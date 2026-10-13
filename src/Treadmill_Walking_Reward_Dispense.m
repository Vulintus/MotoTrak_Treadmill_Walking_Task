function dispensed = Treadmill_Walking_Reward_Dispense(behavior)

%
% Treadmill_Walking_Reward_Dispense.m
%
%   copyright 2026, Vulintus, Inc.
%
%   TREADMILL_WALKING_REWARD_DISPENSE issues and records one liquid-reward
%   command when walking qualification and reward timing requirements
%   are met. The session loop calls this function after reading packets.
%   Feed counts describe commands, not confirmed liquid delivery.
%
%   UPDATE LOG:
%   2026-10-11 - Codex - Function first created for liquid-rewarded
%                       treadmill walking.
%


dispensed = false;
session = behavior.session(1);
if ~session.is_running || ...
        behavior.run ~= Vulintus_Behavior_Run_Class.session || ...
        ~session.params.reward_enable || ...
        ~is_fcn_field(session.fcn,'feed') || ...
        ~session.file.data.is_open()
    return
end
host_time = toc(session.timer.main);
[state,ready] = Treadmill_Walking_Reward_Update(session.buffer.reward,...
    session.params,[],[],host_time,'check');
session.buffer.reward = state;
if ~ready
    return
end

%Disarm before writing to the controller so reentrant stream callbacks cannot
%reuse the qualifying window. A feed error aborts the session, without retry.
session.buffer.reward = Treadmill_Walking_Reward_Update([],session.params,...
    [],[],host_time,'reset');
session.fcn.feed();
session.count.feed = session.count.feed + 1;
session.time.reward_host = toc(session.timer.main);
session.buffer.reward = Treadmill_Walking_Reward_Update([],session.params,...
    [],[],session.time.reward_host,'reset');
session.file.data.write{'SW_OPERANT_FEED'}(session.params.reward_feeder_index);
if isfield(behavior.ui.edit,'walk_rewards')
    behavior.ui.edit.walk_rewards.Value = sprintf('%1.0f',session.count.feed);
end

%No other in-session clock requests are issued in reward mode. This reply
%therefore marks movement acquired after the command, even with a backlog.
session.buffer.reward.sync_requested = true;
session.fcn.clock_sync();
dispensed = true;
