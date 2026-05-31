# Get 5 virtual monitors for the price of zero!

# Steps (for experienced pros only!!!)
1. Download the latest release as a zip file.

2. As an administrator, Run the *.bat file to add the driver certificate as a trusted root certificate.

3. Don't install the inf. Open device manager, click on any device, then click on the "Action" menu and click "Add Legacy Hardware"

4. Select "Add hardware from a list (Advanced)" and then select Display adapters

5. Click "Have Disk..." and click the "Browse..." button. Navigate to the extracted files and select the inf file.

6. You are done! Go to display settings to customize the resolution of the additional displays. These displays show up in Oculus and should be able to be streamed from.

## Per-monitor mode overrides (optional)

The driver now supports defining mode lists per monitor in `vdd_settings.xml`.

- Global sections (`<resolutions>` and `<global>`) still work exactly as before.
- Per-monitor entries are optional and use 1-based monitor indices.
- Any monitor without an override automatically falls back to the global mode list.

Example:

```xml
<per_monitor_modes>
    <monitor index="1">
        <resolution>
            <width>1920</width>
            <height>1080</height>
            <refresh_rate>60</refresh_rate>
        </resolution>
    </monitor>
    <monitor index="2">
        <resolution>
            <width>2560</width>
            <height>1440</height>
            <refresh_rate>120</refresh_rate>
        </resolution>
    </monitor>
</per_monitor_modes>
```
