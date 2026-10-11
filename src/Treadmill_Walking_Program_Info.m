function program = Treadmill_Walking_Program_Info(behavior, varargin)

%
%Treadmill_Walking_Program_Info.m - Vulintus, Inc.
%
%   TREADMILL_WALKING_PROGRAM_INFO sets the system type, minimum required
%   hardware, and function callbacks for the treadmill walking task, which
%   can operate as a rewarded behavior or as an unrewarded recording
%   program, running through the Vulintus Common Behavior functions.
%   
%   UPDATE LOG:
%   2024-11-14 - Drew Sloan - Function first created, adapted from
%                             "Treadmill_Walking_Program_Info.m"
%                            

if nargin == 1                                                              %If no inputs were passed...
    program = struct;                                                       %Create a program structure.
    i = 1;                                                                  %Set the index to 1.
else                                                                        %Otherwise...
    program = varargin{1};                                                  %Grab the program structure that was passed.
    if length(program) <= 1 || isempty(program(1).task)                     %If the program structure isn't initialized...
        i = 1;                                                              %Set the index to 1.
    else                                                                    %Otherwise...
        i = length(program) + 1;                                            %Increment the program index.
    end
end

program(i).task = 'Treadmill Walking';                                      %Set the task name.
program(i).abbreviation = 'TW';                                             %Abbreviation of the task name for use in filename.
program(i).script_root = 'Treadmill_Walking_*';                             %Root name of all behavior-specific scripts.
program(i).system_name = 'OmniTrak';                                        %Vulintus system name.
program(i).primary_device = {'MT-ST', 'OT-CC'};                             %Set the primary device name.
program(i).required_modules = {
    {'MT-ST', 1};
    };                                                                      %Required modules.
program(i).max_instances = 1;                                               %Maximum number of instances supported by hardware.
program(i).ui.menus = { 'system',...
                        'stages',...
                        'preferences',...
                        'camera'};                                          %List the menus to show on the GUI.

%Default configuration function.
program(i).fcn.default_config = ...
    @()Treadmill_Walking_Default_Config(behavior); 

%GUI creation function.
% program(i).fcn.create_gui = ...
%     @(ui_index, varargin)Treadmill_Walking_GUI(behavior,...
%     ui_index, varargin{:});

%GUI modification function.
program(i).fcn.modify_gui = ...
    @(ui, varargin)Treadmill_Walking_Modify_GUI(ui, varargin{:});
    
%Stage loading function.
program(i).fcn.load_stage = ...
    @(varargin)Treadmill_Walking_Load_Stage(behavior,...
    varargin{:});

% %Idle loop function.
% program(i).fcn.idle = ...   

%Behavioral session function.
program(i).fcn.session = ...
    @()Treadmill_Walking_Session_Loop(behavior);

%System diagram update function.
program(i).fcn.plot_system = ...
    @()Treadmill_Walking_Plot_System(behavior);

%Data plot update function.
% program(i).fcn.plot_data = ...

%Input signals processing function.
program(i).fcn.process_input = ...
    @(packet, src, varargin)Treadmill_Walking_Process_Input(behavior, packet, src, varargin{:});

