function Treadmill_Walking_Default_Config(behavior)

%
% Treadmill_Walking_Default_Config.m - Vulintus, Inc.
%
%   TREADMILL_WALKING_DEFAULT_CONFIG loads the default configuration 
%   settings for the MotoTrak treadmill walking behavior program running
%   through the Vulintus Common Behavior framework.
%   
%   UPDATE LOG:
%   2024-11-14 - Drew Sloan - Function first created, adapted from
%                             "Vibrotactile_Detection_Default_Config.m".
%   2025-08-07 - Drew sloan - Added handling functions for incoming OTSC
%                             packets.
%


if ~isfield(behavior.stage,'sync')                                          %If the stages synchronization field hasn't been created yet.
    behavior.stage.sync = struct;                                           %Create the field.
end

%Default  google spreadsheet TSV-download address.
behavior.stage.sync.google_spreadsheet_url = ...
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vRxciy_Flv8bqU1mcYcz_qVN4BOo16sIkEEwS5ZC_N0x_rcPH_wdFz6vyDFmhaDa586ueSnf7YDTmfJ/pub?gid=0&single=true&output=tsv';                       

%Default google spreadsheet edit URL.
behavior.stage.sync.google_spreadsheet_edit_url = ...
    'https://docs.google.com/spreadsheets/d/1sYKEQRvg6bywPbAWB4PYj-dwcTsZjC3Wqer36USUypw/';      

%Default optical mouse sensor settings.
%In Vulintus convention, the coordinate system is centered at the center of
%the sphere. The x-axis is parallel to the animal's rostral-caudal axis,
%the y-axis is parallel to the animal's medial-lateral axis, and the z-axis 
% is parallel to the animal's ventral-dorsal axis.
behavior.program.params.cpi = 400;                                          %Sensor counts per inch.
behavior.program.params.sampling_rate = 40;                                 %Sensor sampling rate, in Hz.
behavior.program.params.ball_radius = 195.5/2;                              %Spherical ball radius.
behavior.program.params.sensor_pos = [...
    120,   -40,   behavior.program.params.ball_radius;
    120,   -40,   behavior.program.params.ball_radius;
    -60,   -40,   behavior.program.params.ball_radius;
    ];                                                                      %Sensor position vectors, in spherical coordinates (theta, phi, radius).
behavior.program.params.sensor_angle = 45;                                  %Angle of the sensor's x-axis to the azimuthal plane of the sphere, in degrees.

%Display options.
behavior.program.params.ball_view_angle = [0, 45];                          %View angle for the ball diagram [azimuth, elevation].

%Default TTL output parameters.
behavior.program.params.ttl_pulsetrain_n = 5;
behavior.program.params.ttl_duration = 1;
behavior.program.params.ttl_pulsetrain_ipp = 1;

%Default recording parameters.
behavior.program.params.trial_dur = 30;

%Set the streaming settings for the modules.
behavior.program.params.stream_settings = struct([]);                       %Create an empty structure to hold streaming settings.
behavior.program.params.stream_settings(1).sku = 'MT-ST';                   %Vibrotactile module.
behavior.program.params.stream_settings(1).sample_period = 25000;           %Sampling period is 25,000 microseconds.
behavior.program.params.stream_settings(1).mode = 1;                        %Set the streaming mode to periodic.
behavior.program.params.stream_settings(1).chunk_size = 12;                 %Chunk size is 12 bytes (OPTICAL_FLOW_DELTA_3VEC).
behavior.program.params.stream_settings(1).chunk_timeout = 5000;            %Chunking timeout is 5 milliseconds.

%Handling functions for all relevant incoming OTSC packets.
behavior.ctrl.stream.fcn('MILLIS_MICROS') = ...
    @(src, varargin)behavior.program.fcn.process_input('MILLIS_MICROS',...
    src, varargin{:});                                                      %Millisecond and microsecond clock readings.
behavior.ctrl.stream.fcn('OPTICAL_FLOW_DELTA_XY') = ...
    @(src, varargin)behavior.program.fcn.process_input('OPTICAL_FLOW_DELTA_XY',...
    src, varargin{:});                                                      %Current change in x- and y-coordinates from the optical flow sensor.
behavior.ctrl.stream.fcn('OPTICAL_FLOW_XY') = ...
    @(src, varargin)behavior.program.fcn.process_input('OPTICAL_FLOW_XY',...
    src, varargin{:});                                                      %Current x- and y-coordinates from the optical flow sensor.
behavior.ctrl.stream.fcn('OPTICAL_FLOW_DELTA_3VEC') = ...
    @(src, varargin)behavior.program.fcn.process_input('OPTICAL_FLOW_DELTA_3VEC',...
    src, varargin{:});                                                      %Change in value from the three selected optical flow vectors.