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
%


ui.btn.stimulate = ui.btn.feed;                                             %Copy the feed button handle to a "stimulate" field.
ui.btn = rmfield(ui.btn,'feed');                                            %Remove the feed button handle.
ui.btn.stimulate.Text = 'STIMULATE';                                        %Update the text on the stimulate button.

ui.label.hits.Text = "TRIAL COUNT: ";                                       %Update the hits/trials label.

%Initialize the table.
ui.table.trial.Data = {};                                                   %Clear the table data.
ui.table.trial.ColumnName = {'Trial', 'Time', 'Pulse Dur.',...
    'Pulse IPI','Pulses/Train','Train IPP','Train Count','Distance'};       %Set the table column headings.
ui.table.trial.ColumnWidth = {40, 60, 75, 75, 85, 80, 80, 'auto'};          %Set the column widths.
ui.table.trial.RowName = [];                                                %Remove the row names.
ui.table.trial.ButtonDownFcn =  @Vulintus_Copy_to_Clipboard;                %Copy the table to the clipboard.

%Change the hit count label.
ui.edit.rewards.Value = '0';                                                %Set the trial count display to zero.