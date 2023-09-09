# YouTrack {#module-services-youtrack}

YouTrack is a browser-based bug tracker, issue tracking system and project management software.

## Installation {#module-services-youtrack-installation}

YouTrack exposes a web GUI installer on first login.
You need a token to access it.
You can find this token in the log of the `youtrack` service. The log line looks like
```
* JetBrains YouTrack 2023.1 Configuration Wizard will be available on [http://127.0.0.1:8090/?wizard_token=somelongtoken] after start
```

## Upgrade from 2022.3 to 2023.1 {#module-services-youtrack-upgrade-2022_3-2023_1}

Starting with YouTrack 2023.1, JetBrains no longer distributes it as as JAR.
The new distribution with the JetBrains Launcher as a ZIP changed the basic data structure and also some configuration parameters.
Check out https://www.jetbrains.com/help/youtrack/server/YouTrack-Java-Start-Parameters.html for more information on the new configuration options.
With the new packaging, we changed the stucture of the YouTrack state directory to directories per major version (e.g. `/var/lib/youtrack/2023_1`).
This migration automatically happens when you first install YouTrack 2023.1 or higher.

1. Before you update take a backup of your YouTrack instance!
2. To start the upgrade set `services.youtrack.package = youtrack_2023_1`
3. YouTrack then starts in upgrade mode, meaning you need to optain the widzard token as above
4. Select you want to **Upgrade** YouTrack
5. As source you select `/var/lib/youtrack/2022_3/teamsysdata/` (adopt if you have a different state path)
6. Change the data directory location to `/var/lib/youtrack/2023_1/data/`. The other paths should already be right
