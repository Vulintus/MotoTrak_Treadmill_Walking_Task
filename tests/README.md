# Treadmill reward regression tests

Requires the primary Vulintus Common Behavior, Common Toolbox, serial communication, and OmniTrak file-format repositories on the MATLAB path.

```matlab
project = 'H:\My Drive\Vulintus Software (Drew)\Behavior Programs\MotoTrak_Treadmill_Walking_Task';
addpath(fullfile(project,'src'),fullfile(project,'tests'),'-begin');
results = runtests(fullfile(project,'tests','test_liquid_rewarded_walking.m'));
assert(all([results.Passed]));
```

All controller operations use software mocks. Full-session fixtures temporarily load their GUI/stream setup mocks from a generated temporary folder, then remove it. The actual session loop, reward functions, motion parser, MATLAB timers, and file writer are exercised.

The current OmniTrakFileRead entry point cannot initialize the first software feed event correctly. Event tests verify serialized bytes and use the primary block readers with numeric feed fields initialized. The shared reader is unchanged.
