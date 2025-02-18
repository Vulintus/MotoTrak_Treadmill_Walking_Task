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
    
    behavior.session(i).fcn.send_ttl = [];                                  %Clear any TTL send function.
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
        behavior.session(i).fcn.send_ttl = @()behavior.ctrl.ttl.start(1);   %Set the TTL sending function.
        if isnt_empty_field(behavior.session(i).params,'ttl_duration')      %If a TTL duration is specified...
            ttl_dur = 1000*behavior.session(i).params.ttl_duration;         %Convert the TTL duration to milliseconds.
            behavior.ctrl.ttl.pulse.dur.set(ttl_dur);                       %Set the TTL duration.
        end        
    end

end