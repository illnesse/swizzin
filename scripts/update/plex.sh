#!/bin/bash

# Migrate plex repo to new repo.plex.tv endpoint if still using old downloads.plex.tv format
_plex_needs_repo_migration() {
    # Check for old-style source files using downloads.plex.tv
    if grep -rq "downloads.plex.tv" /etc/apt/sources.list.d/ 2>/dev/null; then
        return 0
    fi
    # Check if new source file and keyring are both already in place
    if [[ -f /etc/apt/sources.list.d/plex.list ]] && grep -q "repo.plex.tv" /etc/apt/sources.list.d/plex.list && [[ -f /usr/share/keyrings/plexmediaserver.v2.gpg ]]; then
        return 1
    fi
    # Missing new config — needs migration
    return 0
}

if [[ -f /install/.plex.lock ]] && _plex_needs_repo_migration; then
    echo_info "Migrating Plex repository to new repo.plex.tv endpoint..."
    # Remove all old plex source list files
    rm -f /etc/apt/sources.list.d/plex*.list /etc/apt/sources.list.d/plexmediaserver.list
    # Download new v2 signing key
    curl -L https://downloads.plex.tv/plex-keys/PlexSign.v2.key 2>>"${log}" | gpg --yes --dearmor -o /usr/share/keyrings/plexmediaserver.v2.gpg 2>>"${log}"
    # Write new repo source entry
    echo "deb [signed-by=/usr/share/keyrings/plexmediaserver.v2.gpg] https://repo.plex.tv/deb/ public main" > /etc/apt/sources.list.d/plex.list
    apt_update
fi

# removing lockfile for the upgrade script so that it can be re-run as many times as people want
if [ -f "/install/.updateplex.lock" ]; then
    rm /install/.updateplex.lock
fi
