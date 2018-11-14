#!/bin/bash
# Script to cleanup Instance Prior to AMI Snapshot

# Function to print OS, Version and Distribution 
print_os_details () {
    echo "OS: $OS"
    echo "Version : $VER"
    echo "Distribution : $DIST"
}

# Function to cleanup ssh keys , authorized file, find and nullify logs
cleanup_files () {
    echo "Removing all authorized_keys files from /"
    # Find all authorized_keys files and remove files.
    find / -name "authorized_keys" -exec rm -f {} \;  
    
    echo "Securely deleting key files from /etc/ssh/*_key."
    shred -u /etc/ssh/*.key /etc/ssh/*.pub 
    
    echo "Cleaning up command history."
    shred -u ~/.*history
    
    echo "Cleaning up all log files in /var/log reset file to 0 bytes."
    find /var/log -type f | while read f; do echo -n "" > $f; done
    
    echo "Removing all files from /tmp."
    rm -rfv /tmp/*

    if python -c "import ansible" &> /dev/null; then
        echo 'pip Ansible package found'
        echo 'Removing pip ansible package....'
        pip uninstall -y ansible
    else
        echo 'pip ansible module not found'
    fi

    echo "Cleaning up /usr/local/bin."
    rm -rfv /usr/local/bin/*
}

# Function to cleanup packages for rpm based distros
cleanup_rpm_cache () {
    echo "cleaning up yum cache..." 
    yum clean all -y
}

# Function to cleanup packages for deb based distros
cleanup_deb_cache () {
    echo "cleaning up deb cache..."
    apt-get clean -y
    apt-get autoremove -y
}

# Main 
# Validate OS distribution
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    DIST=$ID_LIKE
    DEB="debian"
    print_os_details
    cleanup_files
    if [ "$DIST" == "$DEB" ]; then 
        cleanup_deb_cache
    else 
        cleanup_rpm_cache
    fi
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
    print_os_details
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
    print_os_details
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
    print_os_details
    cleanup_files
    cleanup_deb_cache
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    ...
    print_os_details
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    ...
    print_os_details
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
    print_os_details
fi
