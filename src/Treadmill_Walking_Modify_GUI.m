function ui = Treadmill_Walking_Modify_GUI(ui, varargin)

%
% Treadmill_Walking_Modify_GUI.m
%
%   copyright 2025, Vulintus, Inc.
%
%   TREADMILL_WALKING_MODIFY_GUI modifies the standard Vulintus Common
%   Behavior for the Treadmill Walking behavior program.
%   
%   UPDATE LOG:
%   2025-02-10 - Drew Sloan - Function first created.
%   2026-10-11 - Codex - Added separate stimulation and walking-reward counts.
%




ui.btn.stimulate = ui.btn.feed;                                             %Copy the feed button handle to a "stimulate" field.
ui.btn = rmfield(ui.btn,'feed');                                            %Remove the feed button handle.
ui.btn.stimulate.Text = 'STIMULATE';                                        %Update the text on the stimulate button.

ui.label.hits.Text = "TRIAL COUNT: ";                                       %Update the hits/trials label.

%Split the existing count region into independent stimulation/reward fields.
%Keep edit.rewards as the trial count for compatibility with the trial code.
label_pos = ui.label.hits.Position;
edit_pos = ui.edit.rewards.Position;
region_width = edit_pos(1) + edit_pos(3) - label_pos(1);
half_width = region_width/2;
ui.label.hits.Text = 'TRIALS:';
ui.label.hits.FontSize = min(14,ui.label.hits.FontSize);
ui.edit.rewards.FontSize = min(12,ui.edit.rewards.FontSize);
ui.label.hits.Position = [label_pos(1:2),0.62*half_width,label_pos(4)];
ui.edit.rewards.Position = [label_pos(1)+0.62*half_width,...
    edit_pos(2),0.36*half_width,edit_pos(4)];
ui.label.walk_rewards = uilabel(ui.label.hits.Parent,...
    'Text','REW. OFF:',...
    'Position',[label_pos(1)+half_width,label_pos(2),0.62*half_width,label_pos(4)],...
    'FontName',ui.label.hits.FontName,'FontSize',ui.label.hits.FontSize,...
    'FontWeight','bold','HorizontalAlignment','right');
ui.edit.walk_rewards = uieditfield(ui.edit.rewards.Parent,'text',...
    'Editable','off','Value','0','Enable','on',...
    'Position',[label_pos(1)+1.62*half_width,edit_pos(2),0.36*half_width,edit_pos(4)],...
    'FontName',ui.edit.rewards.FontName,'FontSize',ui.edit.rewards.FontSize,...
    'FontWeight','bold','HorizontalAlignment','center');

%Initialize the table.
ui.table.trial.Data = {};                                                   %Clear the table data.
ui.table.trial.ColumnName = {'Trial', 'Time', 'Pulse Dur.',...
    'Pulse IPI','Pulses/Train','Train IPP','Train Count','Distance'};       %Set the table column headings.
ui.table.trial.ColumnWidth = {40, 60, 75, 75, 85, 80, 80, 'auto'};          %Set the column widths.
ui.table.trial.RowName = [];                                                %Remove the row names.
ui.table.trial.ButtonDownFcn =  @Vulintus_Copy_to_Clipboard;                %Copy the table to the clipboard.

%Change the hit count label.
ui.edit.rewards.Value = '0';                                                %Set the trial count display to zero.