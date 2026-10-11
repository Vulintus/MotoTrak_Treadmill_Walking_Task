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

end