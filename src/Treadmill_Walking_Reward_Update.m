function [state, ready] = Treadmill_Walking_Reward_Update(state, params, timestamp, displacement, host_time, action)

%
% Treadmill_Walking_Reward_Update.m
%
%   copyright 2026, Vulintus, Inc.
%
%   TREADMILL_WALKING_REWARD_UPDATE maintains the moving-window distance
%   criterion for liquid-rewarded treadmill walking. Timestamp is the
%   treadmill microsecond clock; displacement is animal-relative movement
%   in millimeters, and host_time is elapsed session time in seconds.
%   The reset, sync, sample, and check actions manage qualification and
%   exclude movement acquired before a session or reward reset.
%
%   UPDATE LOG:
%   2026-10-11 - Codex - Function first created for liquid-rewarded
%                       treadmill walking.
%


if nargin < 6
    action = 'sample';
end
ready = false;
if isempty(state) || strcmp(action,'reset')
    state = struct('raw_time',NaN,'device_time',NaN,...
        'sync_device',NaN,'sync_host',host_time,'reset_host',host_time,...
        'last_host',host_time,'samples',zeros(0,3),'distance',0,...
        'pending_sync',true,'sync_requested',false,'first_sample',true);
    return
end
if strcmp(action,'sync')
    if state.pending_sync && state.sync_requested
        state.raw_time = double(timestamp);
        state.device_time = 1e-6*double(timestamp);
        state.sync_device = state.device_time;
        state.sync_host = host_time;
        state.reset_host = host_time;
        state.last_host = host_time;
        state.samples = zeros(0,3);
        state.distance = 0;
        state.first_sample = true;
        state.pending_sync = false;
        state.sync_requested = false;
    end
    return
end
if state.pending_sync
    return
end

if strcmp(action,'sample')
    raw_time = double(timestamp);
    delta = mod(raw_time - state.raw_time,2^32);
    if delta == 0
        return                                  %Duplicate packet.
    end
    if delta >= 2^31 || host_time - state.last_host > params.reward_period

        %Out-of-order/reboot or a long data outage: require a new clock fence.
        [state,~] = Treadmill_Walking_Reward_Update([],params,[],[],host_time,'reset');
        return
    end
    previous_time = state.device_time;
    state.device_time = state.device_time + 1e-6*delta;
    state.raw_time = raw_time;
    state.last_host = host_time;
    distance = 0;
    if ~state.first_sample
        displacement = double(displacement(:));
        movement = norm(displacement);
        if movement > 0 && all(isfinite(displacement))
            direction = atan2d(displacement(2),displacement(1));
            angle_error = mod(direction - params.reward_dir + 180,360) - 180;
            if abs(angle_error) <= params.reward_bound + 1e-10
                distance = movement;
            end
        end
    end

    %The first delta after a fence may span pre-fence movement; discard it.
    state.first_sample = false;
    state.samples(end+1,:) = [previous_time,state.device_time,distance];
elseif ~strcmp(action,'check')
    error('TreadmillWalking:RewardAction','Unknown reward update action: %s.',action);
end

cutoff = state.device_time - params.reward_period;
state.samples(state.samples(:,2) <= cutoff,:) = [];
if ~isempty(state.samples) && state.samples(1,1) < cutoff

    %Prorate the one interval that straddles the window boundary.
    fraction = (state.samples(1,2) - cutoff)/...
        (state.samples(1,2) - state.samples(1,1));
    state.samples(1,3) = fraction*state.samples(1,3);
    state.samples(1,1) = cutoff;
end
state.distance = sum(state.samples(:,3));
freshness = max(0.1,2/params.sampling_rate);
device_elapsed = state.device_time - state.sync_device;
host_elapsed = host_time - state.sync_host;

%Both clocks must span the period, and the latest device data must be current.
%This rejects old batches even when several seconds of packets arrive at once.
ready = host_time - state.reset_host >= params.reward_period && ...
    device_elapsed >= params.reward_period && ...
    host_time - state.last_host <= freshness && ...
    abs(host_elapsed - device_elapsed) <= freshness && ...
    state.distance + 1e-9 >= params.reward_thresh*params.reward_period;
