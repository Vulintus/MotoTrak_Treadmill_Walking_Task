function Treadmill_Walking_Process_Input(behavior, packet, src, varargin)

%
% Treadmill_Walking_Process_Input.m
%
%   copyright 2024, Vulintus, Inc.
%
%   TREADMILL_WALKING_PROCESS_INPUT processes incoming streaming data
%   blocks for the MotoTrak treadmill walking behavior and updates the 
%   system status in the handles structure accordingly.
%   
%   UPDATE LOG:
%   2024-11-14 - Drew Sloan - Function first created, adapted from
%                             "Vibrotactile_Detection_Process_Input.m".
%   2025-08-07 - Drew Sloan - Updated to use the Vulintus serial stream
%                             class.
%


data = varargin;                                                            %Copy the variable input arguments.

if ~behavior.status.initialized                                             %If the status fields aren't yet initialized.
    behavior.status.last_read = NaN;                                        %Keep track of the previous read time.
    behavior.status.xy = zeros(2,1);                                        %Current x-y position.
    behavior.status.direction = 0;                                          %Current facing direction.
    behavior.status.total_distance = 0;                                     %Total distance travel tracker.
    behavior.status.R = [1 0; 0 1];                                         %Current rotation matrix.
    behavior.status.omega = zeros(3,1);                                     %Current angular velocity.
    behavior.status.idle = false;                                           %Keep track of whether the ball was idle on the last reading.
    behavior.status.initialized = true;                                     %Indicate the status fields are now initialized.    
end

switch packet                                                               %Switch between the different data types.
            
    case 'MILLIS_MICROS'                                                    %Millisecond and microsecond clock readings.
        if behavior.session.file.data.is_open()                             %If data is being recorded...
            behavior.session.file.data.write{'CLOCK_SYNC'}(src,...
                'datenum',convertTo(datetime,'datenum'),...
                'millis',double(data{1}(1)),...
                'micros',double(data{1}(2)));                               %Write the clock synchronization to the file.
        end   
    
    case 'OPTICAL_FLOW_DELTA_XY'                                            %Current change in x- and y-coordinates from the optical flow sensor.
        behavior.status.distance_buffer(2:end) = ...
            behavior.status.distance_buffer(1:end-1);                       %Shift the values in the force buffer.
        behavior.status.distance_buffer(1) = ...
            sqrt(double(data{3}(1))^2 + double(data{3}(2))^2);              %Add the new value to the buffer.
        
    case 'OPTICAL_FLOW_XY'                                                  %Current x- and y-coordinates from the optical flow sensor.
        if data{2} == 1
            behavior.status.distance_buffer(2:end) = ...
                behavior.status.distance_buffer(1:end-1);                   %Shift the values in the force buffer.
            behavior.status.distance_buffer(1) = ...
            sqrt(double(data{3}(1))^2 + double(data{3}(2))^2);              %Add the new value to the buffer.
        end
    
    case 'OPTICAL_FLOW_DELTA_3VEC'                                          %Change in value from the three selected optical flow vectors.       
        if any(data{2} > 0)                                                 %If there's any non-zero vectors...       
            if behavior.session.file.data.is_open() && ...
                    behavior.status.idle                                    %If the ball was idle on the last reading and there's an active session...                        
                behavior.session.file.data.write{'AMBULATION_XY_THETA'}(...
                    behavior.status.last_read,...
                    behavior.status.xy,...
                    behavior.status.direction);                             %Write the previous datapoint to the file.
            end                    
            v = 25.4*double(data{2})/160;                                   %Convert the distances to millimeters.
            omega = behavior.session.params.conversion_matrix * v';         %Calculate the angular velocity.
            behavior.status.omega = behavior.status.omega + omega;          %Add the current omega to the running total for the display.
            new_xy = cross(omega,...
                [0; 0; behavior.session.params.ball_radius]);               %Calculate the speed of the mouse.
            behavior.status.xy = behavior.status.xy - ...
                behavior.status.R*new_xy(1:2);                              %Save the new x-coordinates (if the vector points backwards, the animal is going forward.
            behavior.status.direction = ...
                behavior.status.direction - rad2deg(omega(3));              %Update the animal's direction.
            behavior.status.R = [cosd(behavior.status.direction),...
                -sind(behavior.status.direction);...
                sind(behavior.status.direction),...
                cosd(behavior.status.direction)];                           %Update the rotation matrix based on the current direction.
            behavior.status.total_distance = ...
                behavior.status.total_distance + norm(new_xy);              %Add to the total distance.
            behavior.status.idle = false;                                   %Indicate the ball is not idle.                     
            if behavior.session.file.data.is_open()                         %If data is being recorded...
                behavior.session.file.data.write{'AMBULATION_XY_THETA'}(...
                    double(data{1}),...
                    behavior.status.xy,...
                    behavior.status.direction);                             %Write the current datapoint to the file.
            end                
        else                                                                %Otherwise, if all vectors are zero...
            behavior.status.idle = true;                                    %Indicate the ball is idle.                    
        end
        behavior.status.last_read = double(data{1});                        %Save the current read time for later use.

    case 'TTL_PULSETRAIN_ABORT'                                             %Aborted TTL pulsetrain indicator.
        if behavior.session.file.data.is_open()                         %If data is being recorded...
            behavior.session.file.data.write{'TTL_PULSETRAIN_ABORT'}(...
                src, data{1},'millis',data{2});                             %Write the pulsetrain abort event block to the file.
        end   

end

behavior.status.update_plots = true;                                        %Update the plots with the new data.   