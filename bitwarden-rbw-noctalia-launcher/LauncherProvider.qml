import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    
    // Favicon cache
    FaviconCache {
        id: faviconCache
        
        onFaviconUpdated: function(hostname) {
            if (launcher) {
                launcher.updateResults();
            }
        }
    }

    // Plugin API provided by PluginService
    property var pluginApi: null

    // Provider metadata
    property string name: "RBW"
    property var launcher: null
    property bool handleSearch: false
    property string supportedLayouts: "list"
    property bool supportsAutoPaste: false
    property string emptyBrowsingMessage: "No entries found"
    
    // Category support for folders
    property bool showsCategories: true
    property string selectedCategory: "all"
    property var categories: ["all"]
    property var categoryIcons: ({
        "all": "list",
        "no-folder": "folder-off"
    })
    
    property bool locked: true
    property var entries: []
    property var foldersList: []



    function handleCommand(query) {
        return query.startsWith(">rbw");
    }
    
    function getCategoryName(category) {
        if (category === "all") return "All";
        if (category === "no-folder") return "No Folder";
        return category;
    }
    
    function selectCategory(category) {
        selectedCategory = category;
        if (launcher) {
            launcher.updateResults();
        }
    }
    
    function updateCategories() {
        var folders = ["all", "no-folder"];
        var folderSet = {};
        
        for (var i = 0; i < root.entries.length; i++) {
            var folder = root.entries[i].folder;
            if (folder && !folderSet[folder]) {
                folderSet[folder] = true;
                folders.push(folder);
                categoryIcons[folder] = "folder";
            }
        }
        
        root.categories = folders;
        root.foldersList = folders;
    }
    
    function extractDomain(uri) {
        if (!uri) return "";
        try {
            var match = uri.match(/^(?:https?:\/\/)?(?:[^@\n]+@)?(?:www\.)?([^:\/\n?]+)/im);
            return match ? match[1] : "";
        } catch(e) {
            return "";
        }
    }
    
    function getFaviconUrl(uris) {
        if (!uris || uris.length === 0) return "";
        return faviconCache.requestFavicon(uris[0]);
    }
    
    function getTypeIcon(type) {
        switch(type) {
            case "Login": return "key";
            case "SecureNote": return "note";
            case "Card": return "credit-card";
            case "Identity": return "id-badge";
            default: return "key";
        }
    }

    function init() {
        Logger.i("RBW", "Initialized");
        checkUnlockedProcess.running = true;
    }

    function onOpened() {
        checkUnlockedProcess.running = true;
        selectedCategory = "all";
    }

    function onClosed() {
        // Handler for launcher closing - can be used for cleanup if needed
        Logger.i("RBW", "Launcher closed");
    }

    function commands() {
        return [
            {
                "name": ">rbw",
                "description": "Search Bitwarden passwords with RBW",
                "icon": "key",
                "isTablerIcon": true,
                "isImage": false,
                "onActivate": function () {
                    launcher.setSearchText(">rbw ");
                }
            }
        ];
    }

    function getResults(query) {
        if (!query.startsWith(">rbw"))
            return [];

        if (root.locked) {
            return [
                {
                    "name": "Unlock",
                    "description": "Unlock to list entries",
                    "icon": "lock",
                    "isTablerIcon": true,
                    "isImage": false,
                    "onActivate": function () {
                        Logger.i("RBW", "Unlocking");
                        launcher.close();
                        unlockProcess.running = true;
                    }
                }
            ];
        }

        let expression = query.substring(4).trim().toLowerCase();
        
        // Determine if we're in browse or search mode
        var isBrowsing = expression === "";
        
        var filtered = root.entries.filter(entry => {
            // Category filter
            if (selectedCategory !== "all") {
                if (selectedCategory === "no-folder" && entry.folder !== null) {
                    return false;
                }
                if (selectedCategory !== "no-folder" && entry.folder !== selectedCategory) {
                    return false;
                }
            }
            
            // Search filter (if not browsing)
            if (!isBrowsing) {
                var nameMatch = entry.name.toLowerCase().includes(expression);
                var userMatch = entry.user && entry.user.toLowerCase().includes(expression);
                var uriMatch = false;
                
                if (entry.uris && entry.uris.length > 0) {
                    for (var i = 0; i < entry.uris.length; i++) {
                        if (entry.uris[i].toLowerCase().includes(expression)) {
                            uriMatch = true;
                            break;
                        }
                    }
                }
                
                return nameMatch || userMatch || uriMatch;
            }
            
            return true;
        }).map(entry => {
            // Capture entry data by value using an IIFE to avoid closure issues
            return (function(entryId, entryName, entryUser, entryUris, entryType, entryFolder) {
            var rawFaviconPath = getFaviconUrl(entryUris);
            var faviconUrl = rawFaviconPath ? "file://" + rawFaviconPath : "";
            var hasUri = entryUris && entryUris.length > 0;
            var description = entryUser || "";
            
            // Add URI to description if available
            if (hasUri && entryUris[0]) {
                var domain = extractDomain(entryUris[0]);
                if (domain) {
                description = description ? description + " • " + domain : domain;
                }
            }
            
            // Add folder to description if in "all" category
            if (selectedCategory === "all" && entryFolder) {
                description = description ? description + " • 📁 " + entryFolder : "📁 " + entryFolder;
            }
            
            return {
                "name": entryName,
                "description": description,
                "icon": faviconUrl || getTypeIcon(entryType),
                "isTablerIcon": !faviconUrl,
                "isImage": !!faviconUrl,
                "provider": root,
                "onActivate": function () {
                    Logger.i("RBW", "Entry activated: " + entryName);
                    Logger.i("RBW", "Retrieving entry with ID: " + entryId + " for clipboard copy");
                    getEntryProcess.getEntry(entryId, "copy");
                    launcher.close();
                }
            };
            })(entry.id, entry.name, entry.user, entry.uris, entry.type, entry.folder);
        });

        filtered.sort((a, b) => {
            const nameA = a.name.toLowerCase();
            const nameB = b.name.toLowerCase();
            if (nameA < nameB) return -1;
            if (nameA > nameB) return 1;
            return 0;
        });

        filtered.push({
            "name": "Lock",
            "description": "Lock rbw agent",
            "icon": "lock",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function () {
                Logger.i("RBW", "Locking");
                launcher.close();
                lockProcess.running = true;
            }
        });

        return filtered;
    }

    function getImageUrl(modelData) {
        if (modelData.isImage) {
            return modelData.icon;
        } else {
            return null;
        }
    }

    // Processes
    Process {
        id: checkUnlockedProcess
        running: false
        command: ["rbw", "unlocked"]

        onExited: function (exitCode, _) {
            root.locked = exitCode !== 0;
            Logger.i("RBW", "Locked: " + root.locked);
            if (!root.locked) {
                entriesProcess.running = true;
            }
        }
    }

    Process {
        id: unlockProcess
        running: false
        command: ["rbw", "unlock"]

        onExited: function (exitCode, _exitStatus) {
            root.locked = exitCode !== 0;
            Logger.i("RBW", "Locked: " + root.locked);
            if (!root.locked && launcher) {
                launcher.setSearchText(">rbw ");
                launcher.open();
            }
        }
    }

    Process {
        id: lockProcess
        running: false
        command: ["rbw", "lock"]

        onExited: function (exitCode, _exitStatus) {
            root.locked = exitCode == 0;
            Logger.i("RBW", "Locked: " + root.locked);
        }
    }

    Process {
        id: entriesProcess
        running: false
        command: ["rbw", "list", "--raw"]
        property string entries: ""

        stdout: StdioCollector {
            onStreamFinished: {
                entriesProcess.entries = this.text;
            }
        }

        onExited: function (exitCode, _exitStatus) {
            if (exitCode !== 0) {
                return;
            }
            root.entries = JSON.parse(entriesProcess.entries);
            Logger.i("RBW", `Loaded ${root.entries.length} entries`);
            
            // Update categories based on folders
            updateCategories();
            
            // Verify existing cache and preload missing favicons
            faviconCache.verifyEntries(root.entries);
            faviconCache.preloadFavicons(root.entries);
            
            // Update launcher results if open
            if (launcher) {
                launcher.updateResults();
            }
        }
    }

    Process {
        id: getEntryProcess
        running: false

        property string output: ""
        property string pendingAction: ""

        onExited: function (exitCode, _exitStatus) {
            if (exitCode !== 0) {
                Logger.e("RBW", `rbw get failed with ${exitCode}`);
                return;
            }
            Logger.d("RBW", `rbw get succeeded, parsing output`);
            var entry = JSON.parse(getEntryProcess.output);
            Logger.i("RBW", "Entry retrieved, copying to clipboard");
            wlCopyProcess.copy(entry.data.password);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                getEntryProcess.output = this.text;
            }
        }

        function getEntry(passwordId, action) {
            Logger.i("RBW", "getEntry called with ID: " + passwordId + " for clipboard copy");
            getEntryProcess.pendingAction = action || "copy";
            getEntryProcess.exec(["rbw", "get", passwordId, "--raw"]);
        }
    }

    Process {
        id: wlCopyProcess
        running: false
        property bool isFallback: false

        onExited: function (exitCode, _exitStatus) {
            if (exitCode !== 0) {
                var toolName = wlCopyProcess.isFallback ? "xclip" : "wl-copy";
                Logger.e("RBW", `${toolName} failed with ${exitCode}. Ensure wl-copy is installed and WAYLAND_DISPLAY is set.`);
                
                // If wl-copy failed and we haven't tried fallback, try xclip
                if (!wlCopyProcess.isFallback) {
                    Logger.i("RBW", "Attempting fallback to xclip");
                    wlCopyProcess.isFallback = true;
                    var escaped = wlCopyProcess.lastPassword.replace(/'/g, "'\\''");
                    wlCopyProcess.exec(["sh", "-c", "printf '%s' '" + escaped + "' | xclip -selection clipboard"]);
                }
                return;
            }
            var toolName = wlCopyProcess.isFallback ? "xclip" : "wl-copy";
            Logger.d("RBW", `Copied to clipboard using ${toolName}`);
        }

        property string lastPassword: ""

        function copy(password) {
            Logger.i("RBW", "copy() called, password length: " + password.length);
            lastPassword = password;
            isFallback = false;
            Logger.d("RBW", "Copying password to clipboard via wl-copy");
            // Properly escape single quotes in the password for shell safety
            // Single quotes preserve everything literally except single quotes themselves
            var escaped = password.replace(/'/g, "'\\''");
            Logger.d("RBW", "Escaped password, calling exec with wl-copy");
            wlCopyProcess.exec(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
        }
    }
}
