function Treadmill_Walking_Load_Stage(behavior, varargin)

%
% Treadmill_Walking_Load_Stage.m
%
%   copyright 2024, Vulintus, Inc.
%
%   TREADMILL_WALKING_LOAD_STAGE loads in the parameters for a single
%   MotoTrak treadmill walking  task training/testing stage and displays 
%   the stage information on the GUI.
%   
%   UPDATE LOG:
%   2024-11-21 - Drew Sloan - Function first created, adapted from
%                             Pellet_Presentation_Load_Stage.m.
%   2026-10-11 - Codex - Added reward validation, dispenser callbacks,
%                        sampling settings, and invalid-stage disarming.
%




for i = 1:behavior.program.num_instances                                    %Step through each program instance.

    s = behavior.stage.current(i);                                          %Grab the current stage index.

    if length(behavior.session) < i || isempty(behavior.session(i))         %If the behavioral session class hasn't yet been created...
        behavior.session(i) = Vulintus_Behavior_Session_Class;              %Create an instance of the Vulintus Behavior session class.
    end

    if isnt_empty_field(behavior.program,'params')                          %If there's a parameters field in the program info...
        behavior.session(i).params = behavior.program.params;               %Copy over all default session parameters.
    end

    exclude_fields = {'filename','name','description','list_str'};          %List the fields that we *don't* want to copy to the session class.
    stage_fields = fieldnames(behavior.stage.list)';                        %Grab the stage parameters.
    for field = stage_fields                                                %Step through each field.
        if ~any(strcmpi(field{1},exclude_fields)) && ...
                ~isempty(behavior.stage.list(s).(field{1}))                 %If this isn't a field we don't want to copy...
            behavior.session(i).params(1).(field{1}) = ...
                behavior.stage.list(s).(field{1}).value;                    %Save the stage setting to the session class.
        end
    end
    
    %Disarm first, including when validation throws after an ON stage.
    behavior.session(i).params.reward_validated = false;
    behavior.session(i).buffer(1).reward = [];
    behavior.session(i).fcn.feed = [];
    behavior.session(i).fcn.stop_feed = [];

    %Validate the optional walking-reward parameters after the stage overlay.
    params = behavior.session(i).params;
    if ~isfield(params,'reward_enable') || isempty(params.reward_enable)
        params.reward_enable = false;
    elseif islogical(params.reward_enable) && isscalar(params.reward_enable)

        %Allow the already-normalized value in configuration files.
        
    elseif (ischar(params.reward_enable) && isrow(params.reward_enable)) || ...
            (isstring(params.reward_enable) && isscalar(params.reward_enable))
        flag = upper(strtrim(string(params.reward_enable)));
        if strlength(flag) == 0 || flag == "OFF"
            params.reward_enable = false;
        elseif flag == "ON"
            params.reward_enable = true;
        else
            error('TreadmillWalking:RewardEnable','Reward Enabled must be ON or OFF.');
        end
    else
        error('TreadmillWalking:RewardEnable','Reward Enabled must be ON or OFF.');
    end
    for field = {'cpi','sampling_rate'}
        value = params.(field{1});
        if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
            error('TreadmillWalking:MotionSetting','%s must be a finite positive scalar.',field{1});
        end
    end
    if params.reward_enable
        for field = {'reward_thresh','reward_period','reward_dir','reward_bound'}
            if ~isfield(params,field{1}) || ~isnumeric(params.(field{1})) || ...
                    ~isreal(params.(field{1})) || ...
                    ~isscalar(params.(field{1})) || ~isfinite(params.(field{1}))
                error('TreadmillWalking:RewardParameter',...
                    'Reward-enabled stage requires a finite scalar %s.',field{1});
            end
        end
        if params.reward_thresh <= 0 || params.reward_period <= 0 || ...
                params.reward_bound < 0 || params.reward_bound > 180
            error('TreadmillWalking:RewardParameter',...
                'Reward threshold/period must be positive; direction bound must be 0 to 180 degrees.');
        end
        params.reward_dir = mod(params.reward_dir,360);
        params.reward_distance = params.reward_thresh*params.reward_period;
        if ~isfinite(params.reward_distance)
            error('TreadmillWalking:RewardParameter','Required reward distance is out of range.');
        end
    end
    behavior.session(i).params = params;
    behavior.session(i).buffer(1).reward = [];
    behavior.session(i).fcn.feed = [];
    behavior.session(i).fcn.stop_feed = [];
    if params.reward_enable
        if ~strcmpi(behavior.ctrl.device.sku,'OT-CC') || ...
                ~is_fcn_field(behavior.ctrl,'feed','start') || ...
                ~is_fcn_field(behavior.ctrl,'device','clocks','get')
            error('TreadmillWalking:RewardController',...
                'Rewarded walking requires the OmniTrak Common Controller feed and clock APIs.');
        end
        behavior.session(i).fcn.feed = @()behavior.ctrl.feed.start();
        if is_fcn_field(behavior.ctrl,'feed','stop')
            behavior.session(i).fcn.stop_feed = @()behavior.ctrl.feed.stop();
        end
    end

    %The existing shared stream helper reads program.params, not session.params.
    settings = behavior.program.params.stream_settings;
    for j = 1:numel(settings)
        if strcmpi(settings(j).sku,'MT-ST')
            settings(j).sample_period = round(1e6/params.sampling_rate);
        end
    end
    behavior.program.params.stream_settings = settings;
    if isfield(behavior.ui(i).edit,'walk_rewards')
        if params.reward_enable
            description = sprintf('ON: %g mm in %g s; direction %g +/- %g degrees.',...
                params.reward_distance,params.reward_period,params.reward_dir,params.reward_bound);
            behavior.ui(i).label.walk_rewards.Text = 'REWARDS:';
        else
            description = 'OFF: walking rewards disabled.';
            behavior.ui(i).label.walk_rewards.Text = 'REW. OFF:';
        end
        behavior.ui(i).edit.walk_rewards.Value = '0';
        behavior.ui(i).edit.walk_rewards.Tooltip = description;
        behavior.ui(i).label.walk_rewards.Tooltip = description;
        Add_Msg(behavior.ui(i).msgbox,['Walking rewards ' description]);
    end

    sensor_pos = behavior.session(i).params(1).sensor_pos;                  %Grab the sensor position vectors.
    sensor_angle = behavior.session(i).params(1).sensor_angle;              %Grab the sensor angle relative to the azimuthal plane.
    behavior.session(i).params(1).conversion_matrix = ...
        Treadmill_Walking_Conversion_Matrix(sensor_pos, sensor_angle);      %Calculate the conversion matrix.

    Vulintus_Behavior_Update_Module_Settings(behavior.ctrl,...    
        behavior.session(i).params, behavior.program.instance(i).port,...
        behavior.program.instance(i).sku);                                  %Update any settings on the instance modules.    
    
    behavior.session(i).fcn.start_ttl = [];                                 %Clear any TTL send function.
    behavior.session(i).fcn.stop_ttl = [];                                  %Clear any TTL stop function.
    behavior.session(i).fcn.clock_sync = [];                                %Clear any clock synchronization function.

    behavior.session(i).fcn.reset_count = ...
        @()behavior.ctrl.optiflow.reset('passthrough',...
        behavior.program.instance(1).port(1));                              %Set the reset function with the passthrough option.

    if is_fcn_field(behavior.ctrl,'device','clocks','get')                  %If this version of "Connect_OmniTrak" has the clock synchronization function.
        behavior.session(i).fcn.clock_sync = ...
            @()behavior.ctrl.device.clocks.get('passthrough',...
            behavior.program.instance(1).port(1),'nowait');                 %Set the clock synchronization function.
    end

    if isnt_empty_field(behavior.ctrl,'ttl')                                %If the primary device has TTL outputs.
        behavior.ctrl.ttl.index.set(1);                                     %Set the TTL output index to 1.
        behavior.session(i).fcn.start_ttl = @()behavior.ctrl.ttl.start(1);  %Set the TTL pulsetrain start function.
        behavior.session(i).fcn.stop_ttl = @()behavior.ctrl.ttl.stop(1);    %Set the TTL pulsetrain stop function.
        ttl_dur = 1000*behavior.session(i).params.ttl_pulse_dur;            %Convert the TTL pulse duration to milliseconds.
        behavior.ctrl.ttl.pulse.dur.set(ttl_dur);                           %Set the TTL duration.
        ttl_ipi = 1000*behavior.session(i).params.ttl_pulse_ipi;            %Convert the TTL inter-pulse interval to milliseconds.
        behavior.ctrl.ttl.pulse.ipi.set(ttl_ipi);                           %Set the TTL duration.
        if is_empty_field(behavior.stage.list(s),'ttl_pulsetrain_n')        %If no pulsetrain count was set...
            pulse_count = 65535;                                            %Set the pulsetrain count to indicate indefinite repeats.
        else                                                                %Otherwise...
            pulse_count = behavior.session(i).params.ttl_pulsetrain_n;      %Grab the specified value.
        end
        if isnan(pulse_count) || pulse_count <= 0                           %If the pulse count is out of range...
            pulse_count = 1;                                                %Set the pulse count to 1.
            warning(['The "TTL Pulsetrain Count" for stage %s is '...
                'out-of-range! The specified value will be ignored and '...
                'the pulsetrain count will be set to 1.\n'],...
                behavior.stage.list(s).name.value);                         %Show a warning.
        end
        behavior.session(i).params.ttl_pulsetrain_n = pulse_count;          %Save pulsetrain count.
        behavior.ctrl.ttl.pulse.count.set(pulse_count);                     %Set the TTL duration.
        if is_empty_field(behavior.stage.list(s),'ttl_pulsetrain_ipp') || ...
                isnan(behavior.stage.list(s).ttl_pulsetrain_ipp.value)      %If no pulsetrain period was set...
            behavior.session(i).params.ttl_pulsetrain_ipp = 0;              %Set the pulsetrain period to zero (to indicate no repeats).
        else                                                                %Otherwise.
            pulsetrain_dur = (ttl_dur + ttl_ipi)*pulse_count/1000;          %Calculate the total pulsetrain duration.
            if pulsetrain_dur > ...
                    behavior.session(i).params.ttl_pulsetrain_ipp           %If the pulsetrain duration exceeds the pulsetrain period...
                warning(['The specified "TTL Pulsetrain Onset-to_Onset '...
                    'Period (s)" of %g seconds for stage %s is less '...
                    'than the specified pulsetrain duration of %g '...
                    'seconds!\n\tThe specified value will be ignored '...
                    'and the pulsetrain onset-to-onset period will be '...
                    'set to %g seconds.\n'],...
                    behavior.session(i).params.ttl_pulsetrain_ipp,...
                    behavior.stage.list(s).name.value,...
                    pulsetrain_dur, pulsetrain_dur);                        %Show a warning.
                behavior.session(i).params.ttl_pulsetrain_ipp = ...
                    pulsetrain_dur;                                         %Set the pulsetrain period to the pulsetrain duration.
            end
        end
    end

    behavior.session(i).params.reward_validated = true;
end
