classdef TreadmillRewardTestBehavior < handle

%
% TreadmillRewardTestBehavior.m
%
%   copyright 2026, Vulintus, Inc.
%
%   TREADMILLREWARDTESTBEHAVIOR supplies mock controller callbacks and
%   session data for the hardware-free treadmill reward regression tests.
%
%   UPDATE LOG:
%   2026-10-11 - Codex - Test fixture first created for walking rewards.
%


    properties
        session
        program
        stage
        ctrl
        ui
        status
        run
        feed_count = 0
        sync_count = 0
        last_sync = 0
        test_file
        stream_enabled = false
        read_mode
        read_index = 0
        drain_reads = 0
        feed_times = []
        saw_pause = false
        feeder_setting = []
        trigger_setting = []
        setter_calls = {}
    end
    methods
        function obj = TreadmillRewardTestBehavior()
            obj.session = Vulintus_Behavior_Session_Class;
            obj.run = Vulintus_Behavior_Run_Class.session;
            obj.status = struct('initialized',false);
            obj.program = struct('num_instances',1,...
                'instance',struct('port',1,'sku',{{'MT-ST'}}),...
                'params',struct,'fcn',struct('process_input',@(varargin)[]));
            obj.stage = struct('current',1,'list',struct,'sync',struct);
            obj.ctrl = struct;
            obj.ctrl.device.sku = 'OT-CC';
            obj.ctrl.device.clocks.get = @(varargin)obj.clock_sync();
            obj.ctrl.optiflow.reset = @(varargin)[];
            obj.ctrl.feed.start = @()obj.feed();
            obj.ctrl.feed.stop = @()[];
            obj.ctrl.feed.cur_feeder.get = @()error('TreadmillTest:UnexpectedQuery','Feeder query is forbidden.');
            obj.ctrl.feed.cur_feeder.set = @(value)obj.set_feeder(value);
            obj.ctrl.feed.trig_dur.get = @()error('TreadmillTest:UnexpectedQuery','Duration query is forbidden.');
            obj.ctrl.feed.trig_dur.set = @(value)obj.set_duration(value);
            obj.ctrl.stream.fcn = dictionary;
            obj.ui = struct('edit',struct);
        end
        function set_feeder(obj,value)
            obj.feeder_setting = value;
            obj.setter_calls{end+1} = 'feeder';
        end
        function set_duration(obj,value)
            obj.trigger_setting = value;
            obj.setter_calls{end+1} = 'duration';
        end
        function feed(obj)
            obj.feed_count = obj.feed_count + 1;
            obj.feed_times(end+1) = toc(obj.session.timer.main);
        end
        function stream_read(obj,wait)
            pause(wait);
            obj.read_index = obj.read_index + 1;
            if ~obj.stream_enabled
                obj.drain_reads = obj.drain_reads + 1;
                return
            end
            timestamp = uint32(1e9+round(toc(obj.session.timer.main)*1e6));
            if obj.sync_count > obj.last_sync
                obj.last_sync = obj.sync_count;
                Treadmill_Walking_Process_Input(obj,'MILLIS_MICROS',1,uint32([floor(double(timestamp)/1000),double(timestamp)]));
            end
            Treadmill_Walking_Process_Input(obj,'OPTICAL_FLOW_DELTA_3VEC',1,timestamp,int16([0,-2,0]));
            if strcmp(obj.read_mode,'error') && obj.read_index == 2
                error('TreadmillTest:StreamFailure','Injected stream failure.');
            end
            if strcmp(obj.read_mode,'lifecycle')
                switch obj.read_index
                    case 2, obj.run = Vulintus_Behavior_Run_Class.session_stimulate;
                    case 3, obj.run = Vulintus_Behavior_Run_Class.session_pause;
                    case 4
                        obj.saw_pause = ~obj.session.is_running;
                        obj.run = Vulintus_Behavior_Run_Class.session;
                    case 6, obj.run = Vulintus_Behavior_Run_Class.session_reset;
                    case 8, obj.run = Vulintus_Behavior_Run_Class.session_webcam_preview;
                    case 10, obj.run = Vulintus_Behavior_Run_Class.idle;
                end
            else
                switch obj.read_index
                    case 30, obj.run = Vulintus_Behavior_Run_Class.session_pause;
                    case 31
                        obj.saw_pause = ~obj.session.is_running;
                        obj.run = Vulintus_Behavior_Run_Class.session;
                    case 80, obj.run = Vulintus_Behavior_Run_Class.idle;
                end
            end
        end
        function clock_sync(obj)
            obj.sync_count = obj.sync_count + 1;
        end
    end
end
