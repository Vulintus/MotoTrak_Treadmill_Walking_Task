function tests = test_liquid_rewarded_walking

%
% test_liquid_rewarded_walking.m
%
%   copyright 2026, Vulintus, Inc.
%
%   TEST_LIQUID_REWARDED_WALKING runs hardware-free regression tests
%   for walking qualification, dispensing, session lifecycle, and logging.
%
%   UPDATE LOG:
%   2026-10-11 - Codex - Test fixture first created for walking rewards.
%


tests = functiontests(localfunctions);
end

function params = reward_params()
params = struct('reward_enable',true,'reward_thresh',10,'reward_period',2,...
    'reward_dir',0,'reward_bound',30,'sampling_rate',40);
end

function state = arm(params,raw,host)
state = Treadmill_Walking_Reward_Update([],params,[],[],host,'reset');
state.sync_requested = true;
state = Treadmill_Walking_Reward_Update(state,params,raw,[],host,'sync');

%Establish the first sample (its delta may span the fence).
state = Treadmill_Walking_Reward_Update(state,params,mod(raw+25000,2^32),[0;0],host+.025);
end

function [state,ready] = walk(state,params,start_time,end_time,speed,angle,step)
ready = false;
for t = start_time+step:step:end_time
    delta = speed*step*[cosd(angle);sind(angle)];
    [state,ready] = Treadmill_Walking_Reward_Update(state,params,...
        mod(round(t*1e6),2^32),delta,t);
end
end

function testContinuousAndRepeatedRewards(test)
p = reward_params();
s = arm(p,0,0);
[s,ready] = walk(s,p,.025,2.025,10,0,.025);
verifyTrue(test,ready);
verifyEqual(test,s.distance,20,'AbsTol',1e-9);

%After reset, prior qualifying distance cannot be reused.
s = Treadmill_Walking_Reward_Update([],p,[],[],2.025,'reset');
verifyEmpty(test,s.samples);
s = arm(p,2025000,2.025);
[s,ready] = walk(s,p,2.05,4.05,10,0,.025);
verifyTrue(test,ready);
verifyEqual(test,s.distance,20,'AbsTol',1e-9);
end

function testIntermittentAndFastBurst(test)
p = reward_params();
s = arm(p,0,0);
[s,ready] = walk(s,p,.025,.525,40,0,.025);
verifyFalse(test,ready);                       %Full reward period still required.
[s,ready] = walk(s,p,.525,2.025,0,0,.025);
verifyTrue(test,ready);                        %20 mm, including stationary time.
[s,ready] = walk(s,p,2.025,2.55,0,0,.025);
verifyFalse(test,ready);                       %Burst has expired.
verifyEqual(test,s.distance,0,'AbsTol',1e-9);
end

function testBelowThreshold(test)
p = reward_params();
s = arm(p,0,0);
[s,ready] = walk(s,p,.025,2.025,9.9,0,.025);
verifyFalse(test,ready);
verifyLessThan(test,s.distance,20);
end

function testDirectionAndEdges(test)
p = reward_params();
for angle = [30,-30,360]
    s = arm(p,0,0);
    [~,ready] = walk(s,p,.025,2.025,10,angle,.025);
    verifyTrue(test,ready);
end
for angle = [30.1,90,180]
    s = arm(p,0,0);
    [s,ready] = walk(s,p,.025,2.025,10,angle,.025);
    verifyFalse(test,ready);
    verifyEqual(test,s.distance,0);
end
p.reward_dir = 180;
s = arm(p,0,0);
[~,ready] = walk(s,p,.025,2.025,10,180,.025);
verifyTrue(test,ready);
p.reward_dir = 359;
s = arm(p,0,0);
[~,ready] = walk(s,p,.025,2.025,10,1,.025);
verifyTrue(test,ready);
end

function testDirectionBoundExtremes(test)
p = reward_params();
p.reward_bound = 0;
s = arm(p,0,0);
[~,ready] = walk(s,p,.025,2.025,10,0,.025);
verifyTrue(test,ready);
s = arm(p,0,0);
[~,ready] = walk(s,p,.025,2.025,10,1,.025);
verifyFalse(test,ready);
p.reward_bound = 180;
s = arm(p,0,0);
[~,ready] = walk(s,p,.025,2.025,10,180,.025);
verifyTrue(test,ready);
end

function testSamplingRatesAndWindowClipping(test)
for rate = [20,40,80]
    p = reward_params();
    p.sampling_rate = rate;
    s = arm(p,0,0);
    [s,ready] = walk(s,p,.025,2.025,10,0,1/rate);
    verifyTrue(test,ready);
    verifyEqual(test,s.distance,20,'AbsTol',1e-9);
end
p = reward_params();
s = arm(p,0,0);
[s,~] = walk(s,p,.025,2.025,10,0,.025);
[s,~] = Treadmill_Walking_Reward_Update(s,p,2037500,[0;0],2.0375);
verifyEqual(test,s.distance,19.875,'AbsTol',1e-8);
end

function testDuplicateRebootAndRollover(test)
p = reward_params();
s = arm(p,0,0);
prior = s;
[s,ready] = Treadmill_Walking_Reward_Update(s,p,25000,[100;0],.026);
verifyFalse(test,ready);
verifyEqual(test,s.samples,prior.samples);
[s,ready] = Treadmill_Walking_Reward_Update(s,p,24000,[100;0],.027);
verifyFalse(test,ready);
verifyTrue(test,s.pending_sync);
raw = 2^32-100000;
s = arm(p,raw,0);

%Use host-relative times while keeping device timestamps near rollover.
for t = .05:.025:2.025
    [s,ready] = Treadmill_Walking_Reward_Update(s,p,...
        mod(round(raw+t*1e6),2^32),[.25;0],t);
end
verifyTrue(test,ready);
verifyEqual(test,s.distance,20,'AbsTol',1e-8);
end

function testBacklogOutageAndFence(test)
p = reward_params();
s = arm(p,0,0);
for t = .05:.025:2.025
    [s,ready] = Treadmill_Walking_Reward_Update(s,p,round(t*1e6),[.25;0],.1);
end
verifyFalse(test,ready);                       %Device burst is ahead of host.
[~,ready] = Treadmill_Walking_Reward_Update(s,p,[],[],3,'check');
verifyFalse(test,ready);                       %Old acquisition data is stale.
[s,ready] = Treadmill_Walking_Reward_Update(s,p,2050000,[100;0],3);
verifyFalse(test,ready);
verifyTrue(test,s.pending_sync);               %Long outage requires a fence.
s = Treadmill_Walking_Reward_Update([],p,[],[],3,'reset');
[s,ready] = Treadmill_Walking_Reward_Update(s,p,3000000,[100;0],3);
verifyFalse(test,ready);                       %Pending sync cannot qualify.
verifyEmpty(test,s.samples);
s.sync_requested = true;
s = Treadmill_Walking_Reward_Update(s,p,3000000,[],3,'sync');
[s,ready] = Treadmill_Walking_Reward_Update(s,p,3025000,[100;0],3.025);
verifyFalse(test,ready);
verifyEqual(test,s.distance,0);                %First delta crosses fence.
end

function testStageDefaultsAndValidation(test)
b = TreadmillRewardTestBehavior();
Treadmill_Walking_Default_Config(b);
verifyFalse(test,b.program.params.reward_enable);
verifyEqual(test,b.program.params.cpi,160);
verifyEqual(test,b.program.params.reward_trigger_duration_ms,10);
b.stage.list = struct('name',struct('value','OLD'));
Treadmill_Walking_Load_Stage(b);
verifyFalse(test,b.session.params.reward_enable);
verifyEmpty(test,b.session.fcn.feed);
b.stage.list.reward_enable.value = ' on ';
for item = {'reward_thresh',10;'reward_period',2;'reward_dir',-180;...
        'reward_bound',30;'sampling_rate',80}'
    b.stage.list.(item{1}).value = item{2};
end
Treadmill_Walking_Load_Stage(b);
verifyTrue(test,b.session.params.reward_enable);
verifyEqual(test,b.session.params.reward_dir,180);
verifyEqual(test,b.session.params.reward_distance,20);
verifyEqual(test,b.program.params.stream_settings.sample_period,12500);
verifyClass(test,b.session.fcn.feed,'function_handle');
b.stage.list.reward_period.value = 0;
verifyError(test,@()Treadmill_Walking_Load_Stage(b),'TreadmillWalking:RewardParameter');
b.stage.list.reward_enable.value = 'maybe';
verifyError(test,@()Treadmill_Walking_Load_Stage(b),'TreadmillWalking:RewardEnable');
b.stage.list.reward_enable.value = 'OFF';
b.stage.list.reward_period.value = [];
Treadmill_Walking_Load_Stage(b);
verifyFalse(test,b.session.params.reward_enable);
verifyEmpty(test,b.session.fcn.feed);           %ON->OFF clears callback.
end

function testMissingRewardCriteria(test)
b = TreadmillRewardTestBehavior();
Treadmill_Walking_Default_Config(b);
b.stage.list = struct('name',struct('value','ON'),...
    'reward_enable',struct('value','ON'));
verifyError(test,@()Treadmill_Walking_Load_Stage(b),'TreadmillWalking:RewardParameter');
end

function b = session_fixture(test)
b = TreadmillRewardTestBehavior();
b.session.buffer = struct('reward',[]);
b.session.params = reward_params();
b.session.params.reward_feeder_index = 2;
b.session.params.cpi = 160;
b.session.params.ball_radius = 1;
b.session.params.conversion_matrix = eye(3);
b.session.timer.main = tic;
b.session.is_running = true;
b.session.fcn.feed = @()b.feed();
b.session.fcn.clock_sync = @()b.clock_sync();
b.ui.edit.walk_rewards.Value = '0';
filename = [tempname '.OmniTrak'];
b.session.file.data = OmniTrakFileWrite(filename);
test.addTeardown(@()close_file(b,filename));
end

function close_file(b,filename)
if b.session.file.data.is_open()
    b.session.file.data.close();
end
if isfile(filename)
    delete(filename);
end
end

function testNegativeMotionCpiAndYaw(test)
b = session_fixture(test);
b.session.buffer.reward = arm(b.session.params,0,0);
Treadmill_Walking_Process_Input(b,'OPTICAL_FLOW_DELTA_3VEC',1,uint32(50000),int16([0,-160,0]));
verifyEqual(test,b.status.xy,[25.4;0],'AbsTol',1e-10);
verifyFalse(test,b.status.idle);                %All-negative motion is processed.
verifyEqual(test,b.session.buffer.reward.distance,25.4,'AbsTol',1e-10);
b.session.params.cpi = 320;
Treadmill_Walking_Process_Input(b,'OPTICAL_FLOW_DELTA_3VEC',1,uint32(75000),int16([0,-160,0]));
verifyEqual(test,b.status.xy,[38.1;0],'AbsTol',1e-10);
prior = b.session.buffer.reward.distance;
Treadmill_Walking_Process_Input(b,'OPTICAL_FLOW_DELTA_3VEC',1,uint32(100000),int16([0,0,-160]));
verifyEqual(test,b.session.buffer.reward.distance,prior,'AbsTol',1e-10);
xy = b.status.xy;
Treadmill_Walking_Process_Input(b,'OPTICAL_FLOW_DELTA_3VEC',2,uint32(125000),int16([0,-160,0]));
verifyEqual(test,b.status.xy,xy);              %Unselected source is ignored.
end

function qualify(b)
p = b.session.params;
host = toc(b.session.timer.main);
s = arm(p,0,0);
[s,~] = walk(s,p,.025,2.025,10,0,.025);

%Align fixture device/host clocks without waiting in real time.
s.sync_host = host - 2.025;
s.reset_host = host - 2.025;
s.last_host = host;
b.session.buffer.reward = s;
end

function testDispatchAndBinaryRewardRecord(test)
b = session_fixture(test);
qualify(b);
verifyTrue(test,Treadmill_Walking_Reward_Dispense(b));
verifyEqual(test,b.feed_count,1);
verifyEqual(test,b.session.count.feed,1);
verifyEqual(test,b.sync_count,1);
verifyEqual(test,b.ui.edit.walk_rewards.Value,'1');
verifyTrue(test,b.session.buffer.reward.pending_sync);
verifyEmpty(test,b.session.buffer.reward.samples);
verifyFalse(test,Treadmill_Walking_Reward_Dispense(b));
verifyEqual(test,b.feed_count,1);
filename = b.session.file.data.name;
b.session.file.data.close();

%The existing full reader cannot initialize feeder 2 as the first event.
%Verify exact bytes and decode the payload with the primary block reader.
fid = fopen(filename,'r');
cleaner = onCleanup(@()fclose(fid));
fseek(fid,16,'bof'); %Verification/version (6) + CLOCK_FILE_START (10).
verifyEqual(test,fread(fid,1,'uint16'),2407);
seed.pellet = repmat(struct('time',[],'num',[],'source',{{}}),1,2);
data = OmniTrakFileRead_ReadBlock_SW_OPERANT_FEED(fid,seed);
verifyEqual(test,data.pellet(2).num,1);
verifyEqual(test,data.pellet(2).source,{'operant_software'});
verifySize(test,data.pellet(2).time,[1,1]);
verifyEqual(test,fread(fid,1,'uint16'),7); %CLOCK_FILE_STOP follows one event.

end

function testDispatchStopPauseAndOffGuards(test)
b = session_fixture(test);
for run = [Vulintus_Behavior_Run_Class.idle,...
        Vulintus_Behavior_Run_Class.session_pause,...
        Vulintus_Behavior_Run_Class.session_stop,...
        Vulintus_Behavior_Run_Class.close]
    b.run = run;
    qualify(b);
    verifyFalse(test,Treadmill_Walking_Reward_Dispense(b));
end
b.run = Vulintus_Behavior_Run_Class.session;
b.session.is_running = false;
qualify(b);
verifyFalse(test,Treadmill_Walking_Reward_Dispense(b));
b.session.is_running = true;
b.session.params.reward_enable = false;
verifyFalse(test,Treadmill_Walking_Reward_Dispense(b));
verifyEqual(test,b.feed_count,0);
end

function testRebootAndClockSourceGuards(test)
b = session_fixture(test);
qualify(b);
Treadmill_Walking_Process_Input(b,'REBOOTING',1);
verifyTrue(test,b.session.buffer.reward.pending_sync);
b.session.buffer.reward.sync_requested = true;
Treadmill_Walking_Process_Input(b,'MILLIS_MICROS',2,uint32([0,1000000]));
verifyTrue(test,b.session.buffer.reward.pending_sync);
Treadmill_Walking_Process_Input(b,'MILLIS_MICROS',1,uint32([1000,1000000]));
verifyFalse(test,b.session.buffer.reward.pending_sync);
end

function testFullSessionRewardPauseAndStop(test)
b = loop_fixture(test,'reward');
Treadmill_Walking_Session_Loop(b);
verifyGreaterThanOrEqual(test,b.feed_count,2);
verifyEqual(test,b.session.count.feed,b.feed_count);
verifyGreaterThanOrEqual(test,min(diff(b.feed_times)),b.session.params.reward_period);
verifyFalse(test,b.session.is_running);
verifyFalse(test,b.stream_enabled);
verifyFalse(test,b.session.file.data.is_open());
verifyEqual(test,b.run,Vulintus_Behavior_Run_Class.idle);
verifyTrue(test,b.saw_pause);
data = read_reward_file(b.test_file);
verifyEqual(test,sum(data.pellet(1).num),b.feed_count);
verifyTrue(test,all(strcmp(data.pellet(1).source,'operant_software')));
end

function testFullSessionStimulationLifecycle(test)
b = loop_fixture(test,'lifecycle');
b.session.params.reward_enable = false;
Treadmill_Walking_Session_Loop(b);
verifyEqual(test,b.feed_count,0);
verifyEqual(test,b.session.count.trial,1);
verifyFalse(test,b.session.trial(1).active);
verifyEqual(test,b.read_index,10+ b.drain_reads);
verifyTrue(test,b.saw_pause);
verifyFalse(test,b.session.file.data.is_open());
verifyFalse(test,b.session.is_running);
end

function testGuiCountLayout(test)
fig = uifigure('Visible','off','Position',[100,100,780,480]);
test.addTeardown(@()delete(fig));
panel = uipanel(fig,'Position',[10,410,745,60]);
ui.label.hits = uilabel(panel,'Text','TRIAL COUNT:',...
    'Position',[476,10,125,28],'FontSize',16);
ui.edit.rewards = uieditfield(panel,'text','Position',[604,10,136,28],'FontSize',16);
ui.btn.feed = uibutton(fig,'Position',[10,10,100,35]);
ui.table.trial = uitable(fig,'Position',[130,10,570,390]);
ui = Treadmill_Walking_Modify_GUI(ui);
verifyEqual(test,ui.edit.rewards.Value,'0');
verifyEqual(test,ui.edit.walk_rewards.Value,'0');
verifyLessThanOrEqual(test,sum(ui.edit.rewards.Position([1,3])),...
    ui.label.walk_rewards.Position(1));
verifyLessThanOrEqual(test,sum(ui.edit.walk_rewards.Position([1,3])),panel.Position(3));
exportapp(fig,fullfile(tempdir,'treadmill_reward_gui_test.png'));
end

function b = loop_fixture(test,mode)
b = TreadmillRewardTestBehavior();
Treadmill_Walking_Default_Config(b);
b.session.params = b.program.params;
b.session.params.reward_validated = true;
b.session.params.reward_enable = true;
b.session.params.reward_thresh = 10;
b.session.params.reward_period = .05;
b.session.params.reward_dir = 0;
b.session.params.reward_bound = 30;
b.session.params.conversion_matrix = eye(3);
b.session.params.ball_radius = 1;
b.session.params.trial_dur = .01;
b.session.fcn.reset_count = @()[];
b.session.fcn.clock_sync = @()b.clock_sync();
b.session.fcn.feed = @()b.feed();
b.session.fcn.stop_feed = @()[];
b.session.fcn.start_ttl = [];
b.session.fcn.stop_ttl = [];
b.status = struct('initialized',true,'xy',zeros(2,1),'direction',0,...
    'R',eye(2),'omega',zeros(3,1),'total_distance',0,'idle',false,'last_read',NaN);
fig = uifigure('Visible','off');
test.addTeardown(@()delete(fig));
b.ui = struct('port',1,'display',struct,'msgbox',[]);
b.ui.btn.stimulate = uibutton(fig);
b.ui.btn.pause = uibutton(fig);
b.ui.edit.dur = uieditfield(fig);
b.ui.edit.rewards = uieditfield(fig);
b.ui.edit.walk_rewards = uieditfield(fig);
b.ui.table.trial = uitable(fig);
b.program.fcn.plot_system = @()[];
b.ctrl.stream.read = @(wait)b.stream_read(wait);
b.read_mode = mode;
b.test_file = [tempname '.OmniTrak'];
test.addTeardown(@()close_file(b,b.test_file));

%Only GUI/file setup/stream enable are shadowed, inside this fixture's path.
%The session loop, packet parser, reward helpers, timers, and writer are real.
fixtures = tempname;
mkdir(fixtures);
sources = {
'Vulintus_Behavior_Stream_Enable.m',sprintf('function Vulintus_Behavior_Stream_Enable(behavior,enable,varargin)\nbehavior.stream_enabled = enable;\nend\n');
'Vulintus_Behavior_Update_Controls.m',sprintf('function Vulintus_Behavior_Update_Controls(varargin)\nend\n');
'Vulintus_Behavior_Create_OmniTrak_File.m',sprintf('function Vulintus_Behavior_Create_OmniTrak_File(behavior,varargin)\nbehavior.session.file.data = OmniTrakFileWrite(behavior.test_file);\nend\n');
'Clear_Msg.m',sprintf('function Clear_Msg(varargin)\nend\n');
'Add_Msg.m',sprintf('function Add_Msg(varargin)\nend\n');
'Replace_Msg.m',sprintf('function Replace_Msg(varargin)\nend\n');
'Vulintus_Behavior_Launch_Webcam_Preview.m',sprintf('function Vulintus_Behavior_Launch_Webcam_Preview\nend\n');
};
for item = sources'
    fid = fopen(fullfile(fixtures,item{1}),'w');
    fwrite(fid,item{2},'char');
    fclose(fid);
end
addpath(fixtures,'-begin');
test.addTeardown(@()remove_fixtures(fixtures));
end

function testCachedStageSettings(test)
folder = tempname;
mkdir(folder);
test.addTeardown(@()rmdir(folder,'s'));
fields = {'name','reward_enable','reward_thresh','reward_period','reward_dir','reward_bound'};
values = {'R1F','ON',10,2,0,30};
stage = struct;
for i = 1:numel(fields)
    stage.(fields{i}) = struct('value',values{i},'heading',fields{i});
end
Vulintus_JSON_File_Write(stage,fullfile(folder,'R1F.STAGE'));
stages = Vulintus_Behavior_Stages_Read(folder);
verifyEqual(test,stages.reward_enable.value,'ON');
verifyEqual(test,stages.reward_thresh.value,10);
verifyEqual(test,stages.reward_period.value,2);
verifyEqual(test,stages.reward_dir.value,0);
verifyEqual(test,stages.reward_bound.value,30);
end

function data = read_reward_file(filename)

%Use primary block readers with numeric feed fields initialized. The existing
%full reader initializes these leaves as structs and cannot read a first feed.
fid = fopen(filename,'r');
cleaner = onCleanup(@()fclose(fid));
verify = fread(fid,3,'uint16');
assert(isequal(verify,[hex2dec('ABCD');1;1]));
blocks = OmniTrakFileRead_ReadBlock_Dictionary(fid);
data.file.version = 1;
data.pellet = struct('time',[],'num',[],'source',{{}});
while ~feof(fid)
    code = fread(fid,1,'uint16');
    if isempty(code), break; end
    assert(isKey(blocks,code),'Unexpected block code.');
    data = blocks(code).fcn(data);
end
end

function testExceptionCleanupKeepsOtherTimers(test)
b = loop_fixture(test,'error');
sentinel = timer('Name','ttl_timer','TimerFcn',@(~,~)[]);
test.addTeardown(@()delete(sentinel));
verifyError(test,@()Treadmill_Walking_Session_Loop(b),'TreadmillTest:StreamFailure');
verifyFalse(test,b.session.is_running);
verifyFalse(test,b.stream_enabled);
verifyFalse(test,b.session.file.data.is_open());
verifyFalse(test,isvalid(b.session.timer.ttl));
verifyTrue(test,isvalid(sentinel));
end

function testFeedFailureIsNotRetried(test)
b = session_fixture(test);
qualify(b);
b.session.fcn.feed = @()error('TreadmillTest:FeedFailure','Injected feed failure.');
verifyError(test,@()Treadmill_Walking_Reward_Dispense(b),'TreadmillTest:FeedFailure');
verifyEqual(test,b.session.count.feed,0);
verifyTrue(test,b.session.buffer.reward.pending_sync);
verifyEmpty(test,b.session.buffer.reward.samples);
end

function remove_fixtures(folder)
rmpath(folder);
rmdir(folder,'s');
end

function testInvalidStageCannotStartSession(test)
b = TreadmillRewardTestBehavior();
Treadmill_Walking_Default_Config(b);
b.stage.list = struct('name',struct('value','ON'),...
    'reward_enable',struct('value','ON'),...
    'reward_thresh',struct('value',10),'reward_period',struct('value',2),...
    'reward_dir',struct('value',0),'reward_bound',struct('value',30));
Treadmill_Walking_Load_Stage(b);
verifyTrue(test,b.session.params.reward_validated);
b.stage.list.reward_period.value = 0;
verifyError(test,@()Treadmill_Walking_Load_Stage(b),'TreadmillWalking:RewardParameter');
verifyFalse(test,b.session.params.reward_validated);
verifyEmpty(test,b.session.fcn.feed);
verifyError(test,@()Treadmill_Walking_Session_Loop(b),'TreadmillWalking:InvalidStage');
end

function testDispenserSetupUsesSettersOnly(test)
b = loop_fixture(test,'lifecycle');
Treadmill_Walking_Session_Initialize(b);
test.addTeardown(@()delete(b.session.timer.ttl));
verifyEqual(test,b.feeder_setting,1);
verifyEqual(test,b.trigger_setting,10);
verifyEqual(test,b.setter_calls,{'feeder','duration'});
verifyEqual(test,b.session.params.reward_feeder_index,1);
verifyEqual(test,b.session.params.reward_trigger_duration_ms,10);
end

function testInvalidDurationDoesNotSendCommands(test)
b = loop_fixture(test,'lifecycle');
for duration = [-1,NaN,65536,.5]
    b.session.params.reward_trigger_duration_ms = duration;
    verifyError(test,@()Treadmill_Walking_Session_Initialize(b),...
        'TreadmillWalking:DispenserSettings');
    verifyEmpty(test,b.setter_calls);
end
end

function testDisabledRewardsDoNotConfigureDispenser(test)
b = loop_fixture(test,'lifecycle');
b.session.params.reward_enable = false;
Treadmill_Walking_Session_Initialize(b);
test.addTeardown(@()delete(b.session.timer.ttl));
verifyEmpty(test,b.setter_calls);
end
