# MotoTrak Treadmill Walking Task

MATLAB software from **Vulintus, Inc.** for recording locomotion on a MotoTrak spherical treadmill and coordinating TTL stimulation trials. Vulintus provides this software free of charge for use with its hardware.

The program converts optical mouse sensor readings into estimated position, heading, and distance traveled, displays movement during a session, and saves recordings in the OmniTrak data format.

_Disclaimer: This README file was AI-generated, but checked for accuracy by a human._

## Features

- Live treadmill visualization and movement path display.
- Continuous locomotion recording during a session.
- Manually triggered trials with configurable duration and TTL pulse trains.
- A trial table showing timing, stimulation settings, pulse train count, and distance traveled.
- Stage configuration through the shared Vulintus framework, with default Google Sheets links supplied in the code.
- Recording of session parameters, clock synchronization, locomotion, and TTL events.

## Requirements

### Hardware

- A MotoTrak spherical treadmill (`MT-ST`).
- A supported connection to the treadmill, either directly or through an OmniTrak controller (`OT-CC`).
- For stimulation trials, an OmniTrak Controller with TTL output and a 3rd-party stimulator to receive those signals.

The program currently supports one treadmill instance at a time.

### Software

- MATLAB.
- The shared [Vulintus Common Behavior](https://github.com/Vulintus/Vulintus_Common_Behavior) framework and its supporting controller, serial streaming, and OmniTrak file utilities, installed on the MATLAB path.

This repository contains the treadmill-specific functions. The shared framework and hardware communication dependencies are supplied separately. For example, startup requires `Vulintus_Behavior_Class` and `Vulintus_Behavior_Startup`.

For the required MATLAB release, toolboxes, and compatible framework and firmware versions for your hardware, contact Vulintus at **support@vulintus.com**.

## Getting started

1. Download or clone this repository.
2. Install the shared Vulintus MATLAB dependencies and add them to the MATLAB path.
3. Connect your treadmill and, if used, the OmniTrak controller.
4. In MATLAB, change to the repository directory and run:

   ```matlab
   addpath(fullfile(pwd, 'src'));
   Treadmill_Walking_Startup;
   ```

Startup delegates hardware connection and GUI setup to the shared Vulintus framework. Use the GUI to select the appropriate stage and session settings. During a recording session, the **STIMULATE** button starts a trial and its configured TTL pulse trains when TTL output is available.

If MATLAB reports an undefined `Vulintus_*` function or class, check that the shared dependencies are installed and on the MATLAB path.

## Configuration

Default settings are defined in [Treadmill_Walking_Default_Config.m](src/Treadmill_Walking_Default_Config.m). When a stage is loaded, its parameter values override the corresponding defaults for that session.

| Setting | Purpose |
| --- | --- |
| `ball_radius` | Treadmill ball radius in millimeters. |
| `sensor_pos` | Sensor position vectors in spherical coordinates: azimuth, elevation, and radius. Angles are in degrees. |
| `sensor_angle` | Sensor orientation in degrees. |
| `ball_view_angle` | Azimuth and elevation of the treadmill visualization. |
| `trial_dur` | Trial duration in seconds. |
| `ttl_pulse_dur`, `ttl_pulse_ipi` | TTL pulse duration and inter-pulse interval in seconds. |
| `ttl_pulsetrain_n`, `ttl_pulsetrain_ipp` | Pulses per train and onset-to-onset interval between trains in seconds. |
| `stream_settings` | Module streaming settings, including the sampling period in microseconds. |

The default configuration also contains a published TSV download URL and a spreadsheet URL for stage settings. To use your own stage spreadsheet, replace both URLs with the corresponding links for your spreadsheet.

## Recorded data

The session uses the shared Vulintus utilities to create an OmniTrak data file. The treadmill code writes estimated position and heading, session parameters, clock synchronization, trial start markers, and TTL pulse train and abort events. TTL records describe the commands and events recorded by the software; they do not measure the response of connected stimulation equipment.

File naming and output location are managed by the shared framework. Reading or analyzing these recordings requires compatible OmniTrak data utilities, which are not included here.

## Source code

All task functions are in [`src/`](src/):

- **Startup and registration:** `Treadmill_Walking_Startup.m`, `Treadmill_Walking_Program_Info.m`
- **Configuration:** `Treadmill_Walking_Default_Config.m`, `Treadmill_Walking_Load_Stage.m`
- **Session and trials:** `Treadmill_Walking_Session_Initialize.m`, `Treadmill_Walking_Session_Loop.m`, `Treadmill_Walking_Trial_Start.m`, `Treadmill_Walking_Trial_Stop.m`
- **Movement processing:** `Treadmill_Walking_Process_Input.m`, `Treadmill_Walking_Conversion_Matrix.m`
- **Display:** `Treadmill_Walking_Modify_GUI.m`, `Treadmill_Walking_Plot_System.m`, `Treadmill_Walking_Mouse_Model.m`

## Reference

The sensor conversion calculations are based on Kumagai & Hollis (2011), *Development of a three-dimensional ball rotation sensing system using optical mouse sensors.*

## Support

For setup questions, compatible dependencies, or hardware support, contact **support@vulintus.com**. When reporting a problem, include your MATLAB release, hardware and firmware versions, the steps to reproduce it, and the full error message.